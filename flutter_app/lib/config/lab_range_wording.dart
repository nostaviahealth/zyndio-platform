import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'theme.dart';

/// APP-06: bounded, non-diagnostic wording for lab values.
///
/// Every patient-facing lab view states where a value sits against a range
/// and points to the care team. It never names a condition ("you have X"),
/// never grades the patient ("needs focus", "optimal profile") and never
/// gives advice. Keep all such strings here so one test can pin them
/// (`test/lab_range_wording_test.dart`).

/// Caption for a value outside the range.
const String kOutsideClinicRange =
    "Outside your clinic's range: discuss with your care team";

/// Short form for a pill or badge where the full caption doesn't fit. The
/// full [kOutsideClinicRange] must also be on screen (or in the semantics
/// label) wherever this is used.
const String kOutsideClinicRangeShort = 'Outside range';

/// Caption for a value inside the range.
const String kWithinClinicRange = "Within your clinic's range";

/// Caption when no range was reported for the value.
const String kNoRangeProvided = 'No lab range provided';

/// Default-ranges caveat (APP-06). Shown on every lab view until the clinic's
/// physician-approved range set applies to this patient's results.
const String kDefaultRangesCaveat =
    'These are general default ranges, not yet confirmed by your clinic. '
    'Your care team will confirm the ranges used for your care.';

/// Whether this patient's lab results use the clinic's physician-approved
/// ranges (POR-05). The patient app has no read path for that yet: the range
/// sets in PR #40 are staff-only RPCs. Until a patient-readable flag exists,
/// this is false and the [kDefaultRangesCaveat] stays visible.
final clinicLabRangesApprovedProvider = Provider<bool>((ref) => false);

/// The default-ranges caveat as a card. Renders nothing once the clinic's
/// ranges are approved.
class DefaultRangesCaveat extends ConsumerWidget {
  const DefaultRangesCaveat({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(clinicLabRangesApprovedProvider)) return const SizedBox.shrink();
    final c = Theme.of(context).extension<ZyndioColors>()!;
    return Semantics(
      container: true,
      label: kDefaultRangesCaveat,
      child: ExcludeSemantics(
        child: Container(
          key: const Key('default-ranges-caveat'),
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.bgSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.borderSubtle),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(LucideIcons.info, size: 18, color: c.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  kDefaultRangesCaveat,
                  style: ZyndioType.footnote.copyWith(color: c.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
