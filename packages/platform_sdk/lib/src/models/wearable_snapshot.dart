class WearableSnapshot {
  final int strainScore;
  final int recoveryScore;
  final int stressScore;
  final int stressHigh;
  final int stressLow;
  final int stressAvg;
  final int sleepScore;
  final int energyScore;
  final double sleepHours;
  final double sleepEfficiency;
  final double? hrv;
  final int? rhr;
  final double? hrvBaseline;
  final int? rhrBaseline;
  final int steps;
  final int exerciseMinutes;
  final double? respiratoryRate;
  final double? bloodOxygen;
  final double? skinTemperature;
  final double? vo2Max;
  final double activeEnergy;
  final int? heartRateAvg;

  const WearableSnapshot({
    this.strainScore = 0,
    this.recoveryScore = 0,
    this.stressScore = 0,
    this.stressHigh = 0,
    this.stressLow = 0,
    this.stressAvg = 0,
    this.sleepScore = 0,
    this.energyScore = 0,
    this.sleepHours = 0,
    this.sleepEfficiency = 0,
    this.hrv,
    this.rhr,
    this.hrvBaseline,
    this.rhrBaseline,
    this.steps = 0,
    this.exerciseMinutes = 0,
    this.respiratoryRate,
    this.bloodOxygen,
    this.skinTemperature,
    this.vo2Max,
    this.activeEnergy = 0,
    this.heartRateAvg,
  });

  Map<String, dynamic> toJson() {
    return {
      'strainScore': strainScore,
      'recoveryScore': recoveryScore,
      'stressScore': stressScore,
      'sleepScore': sleepScore,
      'energyScore': energyScore,
      'sleepHours': sleepHours,
      'hrv': hrv,
      'rhr': rhr,
      'steps': steps,
      'exerciseMinutes': exerciseMinutes,
      'vo2Max': vo2Max,
    };
  }

  factory WearableSnapshot.fromJson(Map<String, dynamic> json) {
    return WearableSnapshot(
      strainScore: json['strainScore'] ?? 0,
      recoveryScore: json['recoveryScore'] ?? 0,
      stressScore: json['stressScore'] ?? 0,
      sleepScore: json['sleepScore'] ?? 0,
      energyScore: json['energyScore'] ?? 0,
      sleepHours: (json['sleepHours'] as num?)?.toDouble() ?? 0.0,
      hrv: (json['hrv'] as num?)?.toDouble(),
      rhr: json['rhr'] as int?,
      steps: json['steps'] ?? 0,
      exerciseMinutes: json['exerciseMinutes'] ?? 0,
      vo2Max: (json['vo2Max'] as num?)?.toDouble(),
    );
  }

  WearableSnapshot copyWith({
    int? strainScore,
    int? recoveryScore,
    int? stressScore,
    int? stressHigh,
    int? stressLow,
    int? stressAvg,
    int? sleepScore,
    int? energyScore,
    double? sleepHours,
    double? sleepEfficiency,
    double? hrv,
    int? rhr,
    double? hrvBaseline,
    int? rhrBaseline,
    int? steps,
    int? exerciseMinutes,
    double? respiratoryRate,
    double? bloodOxygen,
    double? skinTemperature,
    double? vo2Max,
    double? activeEnergy,
    int? heartRateAvg,
  }) {
    return WearableSnapshot(
      strainScore: strainScore ?? this.strainScore,
      recoveryScore: recoveryScore ?? this.recoveryScore,
      stressScore: stressScore ?? this.stressScore,
      stressHigh: stressHigh ?? this.stressHigh,
      stressLow: stressLow ?? this.stressLow,
      stressAvg: stressAvg ?? this.stressAvg,
      sleepScore: sleepScore ?? this.sleepScore,
      energyScore: energyScore ?? this.energyScore,
      sleepHours: sleepHours ?? this.sleepHours,
      sleepEfficiency: sleepEfficiency ?? this.sleepEfficiency,
      hrv: hrv ?? this.hrv,
      rhr: rhr ?? this.rhr,
      hrvBaseline: hrvBaseline ?? this.hrvBaseline,
      rhrBaseline: rhrBaseline ?? this.rhrBaseline,
      steps: steps ?? this.steps,
      exerciseMinutes: exerciseMinutes ?? this.exerciseMinutes,
      respiratoryRate: respiratoryRate ?? this.respiratoryRate,
      bloodOxygen: bloodOxygen ?? this.bloodOxygen,
      skinTemperature: skinTemperature ?? this.skinTemperature,
      vo2Max: vo2Max ?? this.vo2Max,
      activeEnergy: activeEnergy ?? this.activeEnergy,
      heartRateAvg: heartRateAvg ?? this.heartRateAvg,
    );
  }
}
