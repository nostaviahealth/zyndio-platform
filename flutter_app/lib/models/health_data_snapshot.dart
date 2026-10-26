import '../models/lab_report.dart';
import '../models/intelligence_data.dart';
import '../models/appointment_model.dart';

/// Represents the complete date range for the exported snapshot
class ExportDateRange {
  final DateTime start;
  final DateTime end;
  final String label;

  const ExportDateRange({required this.start, required this.end, required this.label});
}

/// Configuration for which sections to include in the exported PDF
class ExportSections {
  final bool demographics;
  final bool intelligence;
  final bool labReports;
  final bool wearableVitals;
  final bool sleepAnalysis;
  final bool nutrition;
  final bool protocols;
  final bool menstrualCycle;
  final bool questionnaireBaseline;
  final bool appointments;

  const ExportSections({
    this.demographics = true,
    this.intelligence = true,
    this.labReports = true,
    this.wearableVitals = true,
    this.sleepAnalysis = true,
    this.nutrition = true,
    this.protocols = true,
    this.menstrualCycle = false,
    this.questionnaireBaseline = false,
    this.appointments = true,
  });

  ExportSections copyWith({
    bool? demographics,
    bool? intelligence,
    bool? labReports,
    bool? wearableVitals,
    bool? sleepAnalysis,
    bool? nutrition,
    bool? protocols,
    bool? menstrualCycle,
    bool? questionnaireBaseline,
    bool? appointments,
  }) {
    return ExportSections(
      demographics: demographics ?? this.demographics,
      intelligence: intelligence ?? this.intelligence,
      labReports: labReports ?? this.labReports,
      wearableVitals: wearableVitals ?? this.wearableVitals,
      sleepAnalysis: sleepAnalysis ?? this.sleepAnalysis,
      nutrition: nutrition ?? this.nutrition,
      protocols: protocols ?? this.protocols,
      menstrualCycle: menstrualCycle ?? this.menstrualCycle,
      questionnaireBaseline: questionnaireBaseline ?? this.questionnaireBaseline,
      appointments: appointments ?? this.appointments,
    );
  }
}

/// A single day's worth of wearable vital data (daily aggregate)
class DailyVitalAggregate {
  final DateTime date;
  final int? steps;
  final double? activeCalories;
  final int? exerciseMinutes;
  final double? avgHeartRate;
  final double? minHeartRate;
  final double? maxHeartRate;
  final double? avgHrv;
  final double? restingHeartRate;
  final double? spo2;
  final double? respiratoryRate;
  final double? skinTemp;
  final double? vo2Max;

  const DailyVitalAggregate({
    required this.date,
    this.steps,
    this.activeCalories,
    this.exerciseMinutes,
    this.avgHeartRate,
    this.minHeartRate,
    this.maxHeartRate,
    this.avgHrv,
    this.restingHeartRate,
    this.spo2,
    this.respiratoryRate,
    this.skinTemp,
    this.vo2Max,
  });
}

/// A single day's sleep data aggregate
class DailySleepAggregate {
  final DateTime date;
  final double? totalHours;
  final double? efficiency;
  final int? sleepScore;
  final double? deepSleepHours;
  final double? remSleepHours;
  final double? lightSleepHours;
  final double? awakeHours;

  const DailySleepAggregate({
    required this.date,
    this.totalHours,
    this.efficiency,
    this.sleepScore,
    this.deepSleepHours,
    this.remSleepHours,
    this.lightSleepHours,
    this.awakeHours,
  });
}

/// A single day's nutrition intake aggregate
class DailyNutritionAggregate {
  final DateTime date;
  final int? calories;
  final int? proteinG;
  final int? carbsG;
  final int? fatG;
  final int? fiberG;
  final int? mealsLogged;

  const DailyNutritionAggregate({
    required this.date,
    this.calories,
    this.proteinG,
    this.carbsG,
    this.fatG,
    this.fiberG,
    this.mealsLogged,
  });
}

/// Protocol adherence summary for the export
class ProtocolAdherenceSummary {
  final String protocolTitle;
  final String protocolType;
  final double adherencePercent;
  final int currentStreakDays;
  final List<String> lifestyleItems;
  final List<String> dietItems;
  final List<String> fitnessItems;
  final List<String> supplementItems;

  const ProtocolAdherenceSummary({
    required this.protocolTitle,
    required this.protocolType,
    required this.adherencePercent,
    required this.currentStreakDays,
    this.lifestyleItems = const [],
    this.dietItems = const [],
    this.fitnessItems = const [],
    this.supplementItems = const [],
  });
}

/// Questionnaire baseline health summary for export
class QuestionnaireBaseline {
  final String currentHealth;
  final String energyLevel;
  final String sleepHours;
  final int stressScale;
  final String digestiveDiscomfort;
  final List<String> diagnosedConditions;
  final List<String> familyHistory;
  final String weeklyActivity;
  final String alcoholConsumption;
  final String cityResidence;
  final String waterSource;
  final String primaryMotivation;
  final String commitmentLevel;
  final double? bmi;
  final double? waistToHipRatio;

  const QuestionnaireBaseline({
    required this.currentHealth,
    required this.energyLevel,
    required this.sleepHours,
    required this.stressScale,
    required this.digestiveDiscomfort,
    this.diagnosedConditions = const [],
    this.familyHistory = const [],
    required this.weeklyActivity,
    required this.alcoholConsumption,
    required this.cityResidence,
    required this.waterSource,
    required this.primaryMotivation,
    required this.commitmentLevel,
    this.bmi,
    this.waistToHipRatio,
  });
}

/// The complete, unified health data snapshot for PDF export.
/// This is the single source of truth passed to the PDF generator.
class HealthDataSnapshot {
  final DateTime generatedAt;
  final ExportDateRange dateRange;
  final ExportSections sections;

  // Patient Demographics
  final String patientName;
  final int? age;
  final int? bioAge;
  final String? gender;
  final String? healthGrade;
  final String? primaryGoal;
  final double? paceOfAging;
  final String? subscriptionPlan;

  // Longevity Intelligence
  final int? overallLongevityScore;
  final int? biologicalAge;
  final List<HealthDomain> healthDomains;
  final List<DiseaseRisk> diseaseRisks;

  // Lab Reports & Biomarkers
  final List<LabReport> labReports;

  // Wearable Vitals (daily aggregates)
  final List<DailyVitalAggregate> vitalTrends;

  // Sleep Analysis (daily aggregates)
  final List<DailySleepAggregate> sleepTrends;

  // Nutrition & Diet
  final List<DailyNutritionAggregate> nutritionTrends;
  final int? dailyCalorieTarget;
  final int? dailyProteinTarget;
  final int? dailyCarbsTarget;
  final int? dailyFatTarget;

  // Active Health Protocols
  final List<ProtocolAdherenceSummary> protocols;

  // Menstrual Cycle (if applicable)
  final String? currentCyclePhase;
  final int? cycleDay;
  final DateTime? nextPeriodPrediction;

  // Questionnaire Baseline
  final QuestionnaireBaseline? questionnaire;

  // Appointments
  final List<AppointmentBooking> recentAppointments;

  // White-label branding
  final String hospitalBrandName;
  final String currencySymbol;

  const HealthDataSnapshot({
    required this.generatedAt,
    required this.dateRange,
    required this.sections,
    required this.patientName,
    this.age,
    this.bioAge,
    this.gender,
    this.healthGrade,
    this.primaryGoal,
    this.paceOfAging,
    this.subscriptionPlan,
    this.overallLongevityScore,
    this.biologicalAge,
    this.healthDomains = const [],
    this.diseaseRisks = const [],
    this.labReports = const [],
    this.vitalTrends = const [],
    this.sleepTrends = const [],
    this.nutritionTrends = const [],
    this.dailyCalorieTarget,
    this.dailyProteinTarget,
    this.dailyCarbsTarget,
    this.dailyFatTarget,
    this.protocols = const [],
    this.currentCyclePhase,
    this.cycleDay,
    this.nextPeriodPrediction,
    this.questionnaire,
    this.recentAppointments = const [],
    this.hospitalBrandName = 'ZYNDIO',
    this.currencySymbol = '\$',
  });
}
