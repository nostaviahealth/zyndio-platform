import 'dart:math';

int calculateStrainScore({
  required int exerciseMinutes,
  int? exerciseHrAvg,
  int? allDayHrAvg,
  required int? restingHeartRate,
  required int steps,
  int? ageYears,
}) {
  final double rhr = (restingHeartRate ?? 65.0).toDouble();
  final double maxHr = ageYears != null ? (208.0 - 0.7 * ageYears) : 190.0;
  final double hrAvg = (exerciseHrAvg ?? allDayHrAvg ?? 0).toDouble();

  double trimp = 0.0;
  if (hrAvg > rhr && exerciseMinutes > 0) {
    final double deltaRatio = (hrAvg - rhr) / (maxHr - rhr);
    final double clamped = deltaRatio.clamp(0.0, 1.0);
    trimp = clamped * exerciseMinutes * exp(1.92 * clamped);
  }

  if (trimp == 0.0) {
    final double stepsScore = (steps / 10000.0).clamp(0.0, 1.0) * 60.0;
    final double timeScore = (exerciseMinutes / 60.0).clamp(0.0, 1.0) * 80.0;
    trimp = (stepsScore * 0.4) + (timeScore * 0.6);
  }

  return (trimp / 150.0 * 100.0).clamp(0.0, 100.0).round();
}

void main() {
  print("Empty: ${calculateStrainScore(exerciseMinutes: 0, restingHeartRate: null, steps: 0)}");
  print("Steps=496, Mins=1: ${calculateStrainScore(exerciseMinutes: 1, restingHeartRate: null, steps: 496)}");
  
  // Find what gives 18
  for (int s = 0; s < 20000; s += 100) {
    for (int m = 0; m < 60; m++) {
      int score = calculateStrainScore(exerciseMinutes: m, restingHeartRate: null, steps: s);
      if (score == 18) {
        print("Strain 18 possible with steps: $s, mins: $m");
        return;
      }
    }
  }
}
