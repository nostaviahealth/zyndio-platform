
class LongevityQuestionnaire {
  // SECTION 0: Body Composition
  double? weightKg;
  double? heightCm;
  double? waistCm;
  double? hipCm;
  String gender; // 'Male' | 'Female'
  String dateOfBirth; // ISO 8601 date string

  // SECTION 1: Health Baseline
  String currentHealth;
  String energyLevel;
  String sleepHours;
  int refreshmentWaking; // 1-10
  String digestiveDiscomfort;
  List<String> diagnosedConditions;
  List<String> familyHistory;

  // SECTION 2: Lifestyle & Habits
  String weeklyActivity;
  String dailySittingHours;
  String alcoholConsumption;
  String workTravel;
  String routineConsistency;

  // SECTION 3: Stress & Psychology
  int stressScale; // 1-10
  List<String> stressResponse;
  String adherencePattern;
  String primaryMotivation;
  String planPreference;

  // SECTION 4: Environment
  String cityResidence;
  String waterSource;
  String plasticHeating;
  String screenExposureSleep;
  String acExposure;

  // SECTION 5: Goals & Intent
  List<String> topPriorities;
  String aggressionLevel;
  String commitmentLevel;

  // SECTION 6: Identity Layer
  String agingBelief;
  String healthDefinition;
  int futureHealthConcern; // 1-10
  String reportingDepth;

  bool isComplete;

  LongevityQuestionnaire({
    this.weightKg,
    this.heightCm,
    this.waistCm,
    this.hipCm,
    this.gender = '',
    this.dateOfBirth = '',
    this.currentHealth = '',
    this.energyLevel = '',
    this.sleepHours = '',
    this.refreshmentWaking = 5,
    this.digestiveDiscomfort = '',
    this.diagnosedConditions = const [],
    this.familyHistory = const [],
    this.weeklyActivity = '',
    this.dailySittingHours = '',
    this.alcoholConsumption = '',
    this.workTravel = '',
    this.routineConsistency = '',
    this.stressScale = 5,
    this.stressResponse = const [],
    this.adherencePattern = '',
    this.primaryMotivation = '',
    this.planPreference = '',
    this.cityResidence = '',
    this.waterSource = '',
    this.plasticHeating = '',
    this.screenExposureSleep = '',
    this.acExposure = '',
    this.topPriorities = const [],
    this.aggressionLevel = '',
    this.commitmentLevel = '',
    this.agingBelief = '',
    this.healthDefinition = '',
    this.futureHealthConcern = 5,
    this.reportingDepth = '',
    this.isComplete = false,
  });

  // ── Auto-Calculated Metrics ──────────────────────────────────────

  /// BMI = weight(kg) / height(m)²
  double? get bmi {
    if (weightKg == null || heightCm == null || heightCm! <= 0) return null;
    final heightM = heightCm! / 100.0;
    return weightKg! / (heightM * heightM);
  }

  /// Waist-to-Hip Ratio
  double? get waistToHipRatio {
    if (waistCm == null || hipCm == null || hipCm! <= 0) return null;
    return waistCm! / hipCm!;
  }

  /// BMR using Mifflin-St Jeor Equation
  /// Male:   10 × weight(kg) + 6.25 × height(cm) – 5 × age(y) + 5
  /// Female: 10 × weight(kg) + 6.25 × height(cm) – 5 × age(y) – 161
  double? get bmr {
    if (weightKg == null || heightCm == null || gender.isEmpty || dateOfBirth.isEmpty) return null;
    final age = _calculateAge();
    if (age == null || age <= 0) return null;
    final base = 10 * weightKg! + 6.25 * heightCm! - 5 * age;
    return gender == 'Male' ? base + 5 : base - 161;
  }

  int? _calculateAge() {
    if (dateOfBirth.isEmpty) return null;
    try {
      final dob = DateTime.parse(dateOfBirth);
      final now = DateTime.now();
      int age = now.year - dob.year;
      if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
        age--;
      }
      return age;
    } catch (_) {
      return null;
    }
  }

  // ── Serialization ────────────────────────────────────────────────

  Map<String, dynamic> toJson() {
    return {
      'weightKg': weightKg,
      'heightCm': heightCm,
      'waistCm': waistCm,
      'hipCm': hipCm,
      'gender': gender,
      'dateOfBirth': dateOfBirth,
      'currentHealth': currentHealth,
      'energyLevel': energyLevel,
      'sleepHours': sleepHours,
      'refreshmentWaking': refreshmentWaking,
      'digestiveDiscomfort': digestiveDiscomfort,
      'diagnosedConditions': diagnosedConditions,
      'familyHistory': familyHistory,
      'weeklyActivity': weeklyActivity,
      'dailySittingHours': dailySittingHours,
      'alcoholConsumption': alcoholConsumption,
      'workTravel': workTravel,
      'routineConsistency': routineConsistency,
      'stressScale': stressScale,
      'stressResponse': stressResponse,
      'adherencePattern': adherencePattern,
      'primaryMotivation': primaryMotivation,
      'planPreference': planPreference,
      'cityResidence': cityResidence,
      'waterSource': waterSource,
      'plasticHeating': plasticHeating,
      'screenExposureSleep': screenExposureSleep,
      'acExposure': acExposure,
      'topPriorities': topPriorities,
      'aggressionLevel': aggressionLevel,
      'commitmentLevel': commitmentLevel,
      'agingBelief': agingBelief,
      'healthDefinition': healthDefinition,
      'futureHealthConcern': futureHealthConcern,
      'reportingDepth': reportingDepth,
      'isComplete': isComplete,
    };
  }

  factory LongevityQuestionnaire.fromJson(Map<String, dynamic> json) {
    return LongevityQuestionnaire(
      weightKg: (json['weightKg'] as num?)?.toDouble(),
      heightCm: (json['heightCm'] as num?)?.toDouble(),
      waistCm: (json['waistCm'] as num?)?.toDouble(),
      hipCm: (json['hipCm'] as num?)?.toDouble(),
      gender: json['gender'] ?? '',
      dateOfBirth: json['dateOfBirth'] ?? '',
      currentHealth: json['currentHealth'] ?? '',
      energyLevel: json['energyLevel'] ?? '',
      sleepHours: json['sleepHours'] ?? '',
      refreshmentWaking: json['refreshmentWaking'] ?? 5,
      digestiveDiscomfort: json['digestiveDiscomfort'] ?? '',
      diagnosedConditions: List<String>.from(json['diagnosedConditions'] ?? []),
      familyHistory: List<String>.from(json['familyHistory'] ?? []),
      weeklyActivity: json['weeklyActivity'] ?? '',
      dailySittingHours: json['dailySittingHours'] ?? '',
      alcoholConsumption: json['alcoholConsumption'] ?? '',
      workTravel: json['workTravel'] ?? '',
      routineConsistency: json['routineConsistency'] ?? '',
      stressScale: json['stressScale'] ?? 5,
      stressResponse: List<String>.from(json['stressResponse'] ?? []),
      adherencePattern: json['adherencePattern'] ?? '',
      primaryMotivation: json['primaryMotivation'] ?? '',
      planPreference: json['planPreference'] ?? '',
      cityResidence: json['cityResidence'] ?? '',
      waterSource: json['waterSource'] ?? '',
      plasticHeating: json['plasticHeating'] ?? '',
      screenExposureSleep: json['screenExposureSleep'] ?? '',
      acExposure: json['acExposure'] ?? '',
      topPriorities: List<String>.from(json['topPriorities'] ?? []),
      aggressionLevel: json['aggressionLevel'] ?? '',
      commitmentLevel: json['commitmentLevel'] ?? '',
      agingBelief: json['agingBelief'] ?? '',
      healthDefinition: json['healthDefinition'] ?? '',
      futureHealthConcern: json['futureHealthConcern'] ?? 5,
      reportingDepth: json['reportingDepth'] ?? '',
      isComplete: json['isComplete'] ?? false,
    );
  }
}
