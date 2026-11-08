/// The patient's place in the "From Scan to Plan" programme (PRD core
/// journey): baseline labs and DEXASCAN, a physician plan, then follow-up
/// scans and labs at Day 90, 180 and 365 (APP-14).
///
/// Everything here is derived from records the patient already has: bound
/// scan dates, whether any lab report exists and whether the care team has
/// set a plan. Nothing is invented; with no baseline scan there are no
/// milestone dates.
library;

/// Follow-up milestones, in days after the baseline scan.
const List<int> kProgrammeMilestoneDays = [90, 180, 365];

/// A follow-up scan counts for a milestone when it falls within this many
/// days either side of the milestone date. Booking windows are not exact, so
/// the app asks the patient to book once the window opens.
const int kMilestoneWindowDays = 30;


/// The setup steps before the programme starts, in order.
enum ProgrammeSetupStep { baselineLabs, baselineScan, carePlan }

class ProgrammeSetupItem {
  const ProgrammeSetupItem(this.step, {required this.done});

  final ProgrammeSetupStep step;
  final bool done;

  String get title => switch (step) {
        ProgrammeSetupStep.baselineLabs => 'Upload your baseline labs',
        ProgrammeSetupStep.baselineScan => 'Get your baseline DEXASCAN',
        ProgrammeSetupStep.carePlan => 'Your physician starts your plan',
      };

  String get detail => switch (step) {
        ProgrammeSetupStep.baselineLabs =>
          'Add a recent lab report by photo or PDF.',
        ProgrammeSetupStep.baselineScan =>
          'Your result appears here once DEXASCAN sends it to your clinic.',
        ProgrammeSetupStep.carePlan =>
          'Your care team reviews your baseline, then sets your plan.',
      };

  String get doneDetail => switch (step) {
        ProgrammeSetupStep.baselineLabs => 'Lab results added.',
        ProgrammeSetupStep.baselineScan => 'Baseline scan received.',
        ProgrammeSetupStep.carePlan => 'Your plan is in My Plan.',
      };
}

enum MilestoneStatus {
  /// A follow-up scan arrived within the milestone window.
  completed,

  /// The window is open now and no scan has arrived yet.
  dueNow,

  /// The window has not opened yet.
  upcoming,

  /// The window closed without a scan. Worded neutrally, never as a failure.
  notRecorded,
}

class ProgrammeMilestone {
  const ProgrammeMilestone({
    required this.day,
    required this.target,
    required this.status,
    this.scanDate,
  });

  final int day;

  /// Baseline date + [day] days (date only, UTC midnight).
  final DateTime target;
  final MilestoneStatus status;

  /// The follow-up scan that completed this milestone, if any.
  final DateTime? scanDate;

  String get label => 'Day $day';
}

class ProgrammeJourney {
  const ProgrammeJourney({
    required this.setup,
    required this.today,
    this.baselineDate,
    this.milestones = const [],
  });

  final List<ProgrammeSetupItem> setup;

  /// Today's date (date only, UTC midnight).
  final DateTime today;

  /// The earliest bound scan, or null before the baseline scan.
  final DateTime? baselineDate;

  /// Empty until there is a baseline scan.
  final List<ProgrammeMilestone> milestones;

  int get setupDone => setup.where((s) => s.done).length;
  bool get setupComplete => setupDone == setup.length;

  /// The first setup step not yet done.
  ProgrammeSetupItem? get nextSetupStep {
    for (final s in setup) {
      if (!s.done) return s;
    }
    return null;
  }

  bool get hasBaseline => baselineDate != null;

  /// Days since the baseline scan (the baseline itself is Day 0).
  int? get programmeDay =>
      baselineDate == null ? null : today.difference(baselineDate!).inDays;

  /// The milestone the patient should act on next, or null once every
  /// milestone is completed or past.
  ProgrammeMilestone? get nextMilestone {
    for (final m in milestones) {
      if (m.status == MilestoneStatus.dueNow ||
          m.status == MilestoneStatus.upcoming) {
        return m;
      }
    }
    return null;
  }

  /// Days from today to [m]'s date (negative once the date has passed).
  int daysUntil(ProgrammeMilestone m) => m.target.difference(today).inDays;

  /// True when the next milestone's window is open: time to book.
  bool get bookingOpen => nextMilestone?.status == MilestoneStatus.dueNow;

  int get completedMilestones =>
      milestones.where((m) => m.status == MilestoneStatus.completed).length;
}

/// Parses a stored `yyyy-MM-dd` (or ISO) date to a UTC calendar date.
DateTime? parseCalendarDate(String raw) {
  final d = DateTime.tryParse(raw.trim());
  if (d == null) return null;
  return DateTime.utc(d.year, d.month, d.day);
}

DateTime calendarDate(DateTime d) => DateTime.utc(d.year, d.month, d.day);

/// Builds the journey from the patient's records.
///
/// [scanDates] are the bound DEXASCAN dates in any order; the earliest is the
/// baseline. Each later scan completes at most one milestone: the one whose
/// date it is closest to, if within [kMilestoneWindowDays].
ProgrammeJourney buildProgrammeJourney({
  required Iterable<DateTime> scanDates,
  required bool hasLabResults,
  required bool hasCarePlan,
  required DateTime today,
}) {
  final day = calendarDate(today);
  final scans = scanDates.map(calendarDate).toSet().toList()..sort();
  final setup = [
    ProgrammeSetupItem(ProgrammeSetupStep.baselineLabs, done: hasLabResults),
    ProgrammeSetupItem(ProgrammeSetupStep.baselineScan,
        done: scans.isNotEmpty),
    ProgrammeSetupItem(ProgrammeSetupStep.carePlan, done: hasCarePlan),
  ];
  if (scans.isEmpty) {
    return ProgrammeJourney(setup: setup, today: day);
  }

  final baseline = scans.first;
  final targets = [
    for (final d in kProgrammeMilestoneDays) baseline.add(Duration(days: d)),
  ];

  // Assign each follow-up scan to its nearest milestone within the window.
  final matched = <int, DateTime>{};
  for (final scan in scans.skip(1)) {
    int? best;
    var bestGap = kMilestoneWindowDays + 1;
    for (var i = 0; i < targets.length; i++) {
      final gap = scan.difference(targets[i]).inDays.abs();
      if (gap <= kMilestoneWindowDays && gap < bestGap) {
        best = i;
        bestGap = gap;
      }
    }
    if (best != null) {
      // Keep the scan closest to the milestone date if two fall in a window.
      final prev = matched[best];
      if (prev == null ||
          scan.difference(targets[best]).inDays.abs() <
              prev.difference(targets[best]).inDays.abs()) {
        matched[best] = scan;
      }
    }
  }

  final milestones = <ProgrammeMilestone>[];
  for (var i = 0; i < targets.length; i++) {
    final target = targets[i];
    final scan = matched[i];
    final MilestoneStatus status;
    if (scan != null) {
      status = MilestoneStatus.completed;
    } else if (day.isBefore(
        target.subtract(const Duration(days: kMilestoneWindowDays)))) {
      status = MilestoneStatus.upcoming;
    } else if (!day
        .isAfter(target.add(const Duration(days: kMilestoneWindowDays)))) {
      status = MilestoneStatus.dueNow;
    } else {
      status = MilestoneStatus.notRecorded;
    }
    milestones.add(ProgrammeMilestone(
      day: kProgrammeMilestoneDays[i],
      target: target,
      status: status,
      scanDate: scan,
    ));
  }

  return ProgrammeJourney(
    setup: setup,
    today: day,
    baselineDate: baseline,
    milestones: milestones,
  );
}
