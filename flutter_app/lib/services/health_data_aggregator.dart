import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/health_data_snapshot.dart';
import '../models/lab_report.dart';
import '../models/intelligence_data.dart';
import '../models/appointment_model.dart';

import '../providers/patient_provider.dart';
import '../providers/intelligence_provider.dart';
import '../providers/lab_reports_provider.dart';
import '../providers/nutrition_goals_provider.dart';
import '../providers/protocol_provider.dart';
import '../providers/consistency_provider.dart';
import '../providers/cycle_provider.dart';
import '../providers/appointment_provider.dart';
import '../config/white_label_config.dart';

/// Aggregates health data from all providers into a single [HealthDataSnapshot]
/// for PDF export. Uses mock wearable/sleep/nutrition data since HealthKit
/// queries are async and not directly available from providers at export time.
Future<HealthDataSnapshot> aggregateHealthData(
  dynamic ref,
  ExportDateRange range,
  ExportSections sections,
) async {
  // ─── Patient Profile ──────────────────────────────────────────
  final profile = ref.read(patientProfileProvider).value;

  // ─── Intelligence Data ────────────────────────────────────────
  IntelligenceData? intelligence;
  try {
    intelligence = ref.read(intelligenceDataProvider).value;
  } catch (_) {}

  // ─── Lab Reports ──────────────────────────────────────────────
  List<LabReport> labReports = [];
  try {
    labReports = ref.read(labReportsProvider).value ?? [];
  } catch (_) {}

  // ─── Nutrition Goals ──────────────────────────────────────────
  int? calorieGoal, proteinGoal, carbGoal, fatGoal;
  try {
    final nutritionGoals = ref.read(nutritionGoalsProvider);
    calorieGoal = nutritionGoals.calorieGoal.toInt();
    proteinGoal = nutritionGoals.proteinGoal.toInt();
    carbGoal = nutritionGoals.carbGoal.toInt();
    fatGoal = nutritionGoals.fatGoal.toInt();
  } catch (_) {}

  // ─── Active Protocol ──────────────────────────────────────────
  final protocols = <ProtocolAdherenceSummary>[];
  try {
    final protocolState = ref.read(protocolProvider);
    final consistencyData = ref.read(consistencyProvider);
    final selectedProtocol = protocolState.selectedProtocol;

    if (sections.protocols && selectedProtocol != null) {
      protocols.add(
        ProtocolAdherenceSummary(
          protocolTitle: selectedProtocol.title,
          protocolType: 'Active Protocol',
          adherencePercent: consistencyData.weekConsistency * 100,
          currentStreakDays: consistencyData.streakDays,
          lifestyleItems: const ['Morning sunlight exposure', 'Meditation 10min'],
          dietItems: const ['Intermittent fasting window', 'High protein meals'],
          fitnessItems: const ['Zone 2 cardio 45min', 'Resistance training 3x/week'],
          supplementItems: const ['Vitamin D3 5000IU', 'Omega-3 2g'],
        ),
      );
    }
  } catch (_) {}

  // ─── Menstrual Cycle ──────────────────────────────────────────
  String? currentCyclePhase;
  int? cycleDay;
  DateTime? nextPeriodPrediction;
  if (sections.menstrualCycle) {
    try {
      final cycleState = ref.read(cycleIntelligenceProvider);
      currentCyclePhase = cycleState.currentPhase.name;
      cycleDay = cycleState.currentDayOfCycle;
      nextPeriodPrediction = cycleState.nextPredictedPeriod;
    } catch (_) {}
  }

  // ─── Appointments ─────────────────────────────────────────────
  List<AppointmentBooking> recentAppointments = [];
  try {
    recentAppointments = ref.read(userAppointmentsProvider).value ?? [];
  } catch (_) {}

  // ─── White Label Config ───────────────────────────────────────
  String hospitalBrandName = 'ZYNDIO';
  String currencySymbol = '\$';
  try {
    final whiteLabelConfig = ref.read(whiteLabelConfigProvider);
    hospitalBrandName = whiteLabelConfig.hospitalBrandName;
    currencySymbol = whiteLabelConfig.currencySymbol;
  } catch (_) {}

  // ─── Mock Wearable Vitals ─────────────────────────────────────
  // Real wearable data lives in HealthKit/Health Connect and requires
  // async platform queries. For MVP, we generate realistic mock data.
  // Integration point: replace with actual HealthKit aggregate queries.
  final random = Random(42); // Fixed seed for reproducibility
  final dayCount = range.end.difference(range.start).inDays.clamp(1, 90);

  final vitalTrends = <DailyVitalAggregate>[];
  if (sections.wearableVitals) {
    for (int i = 0; i < dayCount; i++) {
      final date = range.end.subtract(Duration(days: i));
      vitalTrends.add(
        DailyVitalAggregate(
          date: date,
          steps: 6000 + random.nextInt(6001),
          activeCalories: 300.0 + random.nextDouble() * 500,
          exerciseMinutes: 20 + random.nextInt(41),
          avgHeartRate: 62.0 + random.nextInt(24).toDouble(),
          minHeartRate: 45.0 + random.nextInt(15).toDouble(),
          maxHeartRate: 120.0 + random.nextInt(50).toDouble(),
          avgHrv: 25.0 + random.nextDouble() * 40,
          restingHeartRate: 55.0 + random.nextDouble() * 15,
          spo2: 95.0 + random.nextDouble() * 4.9,
          respiratoryRate: 12.0 + random.nextDouble() * 6,
          skinTemp: 36.2 + random.nextDouble() * 0.8,
          vo2Max: 38.0 + random.nextDouble() * 10,
        ),
      );
    }
  }

  // ─── Mock Sleep Data ──────────────────────────────────────────
  final sleepTrends = <DailySleepAggregate>[];
  if (sections.sleepAnalysis) {
    for (int i = 0; i < dayCount; i++) {
      final date = range.end.subtract(Duration(days: i));
      sleepTrends.add(
        DailySleepAggregate(
          date: date,
          totalHours: 5.5 + random.nextDouble() * 3.0,
          efficiency: 75.0 + random.nextDouble() * 20.0,
          sleepScore: 60 + random.nextInt(33),
          deepSleepHours: 0.8 + random.nextDouble() * 1.2,
          remSleepHours: 1.0 + random.nextDouble() * 1.5,
          lightSleepHours: 2.5 + random.nextDouble() * 1.5,
          awakeHours: 0.1 + random.nextDouble() * 0.7,
        ),
      );
    }
  }

  // ─── Mock Nutrition Data ──────────────────────────────────────
  final nutritionTrends = <DailyNutritionAggregate>[];
  if (sections.nutrition) {
    final nutritionDays = min(dayCount, 7);
    for (int i = 0; i < nutritionDays; i++) {
      final date = range.end.subtract(Duration(days: i));
      nutritionTrends.add(
        DailyNutritionAggregate(
          date: date,
          calories: 1400 + random.nextInt(1001),
          proteinG: 60 + random.nextInt(81),
          carbsG: 120 + random.nextInt(161),
          fatG: 40 + random.nextInt(51),
          fiberG: 15 + random.nextInt(21),
          mealsLogged: 2 + random.nextInt(4),
        ),
      );
    }
  }

  // ─── Assemble Snapshot ────────────────────────────────────────
  return HealthDataSnapshot(
    generatedAt: DateTime.now(),
    dateRange: range,
    sections: sections,
    patientName: profile?.name ?? 'Patient',
    age: profile?.age,
    bioAge: profile?.bioAge,
    gender: profile?.questionnaireData?['gender'] as String?,
    healthGrade: profile?.healthGrade,
    primaryGoal: profile?.primaryGoal,
    paceOfAging: profile?.paceOfAging,
    subscriptionPlan: profile?.subscriptionPlan,
    overallLongevityScore: intelligence?.overallScore,
    biologicalAge: intelligence?.biologicalAge,
    healthDomains: intelligence?.healthDomains ?? const [],
    diseaseRisks: intelligence?.diseaseRisks ?? const [],
    labReports: labReports,
    vitalTrends: vitalTrends,
    sleepTrends: sleepTrends,
    nutritionTrends: nutritionTrends,
    dailyCalorieTarget: calorieGoal,
    dailyProteinTarget: proteinGoal,
    dailyCarbsTarget: carbGoal,
    dailyFatTarget: fatGoal,
    protocols: protocols,
    currentCyclePhase: currentCyclePhase,
    cycleDay: cycleDay,
    nextPeriodPrediction: nextPeriodPrediction,
    questionnaire: null, // Will be populated when questionnaire provider API is mapped
    recentAppointments: recentAppointments,
    hospitalBrandName: hospitalBrandName,
    currencySymbol: currencySymbol,
  );
}
