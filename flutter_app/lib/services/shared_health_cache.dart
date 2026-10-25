import '../data/health_repository.dart';
import '../data/meditation_repository.dart' as import_meditation;

/// Pre-fetched wearable history data that can be shared across services
/// (WearableContextService, CorrelationEngine) to avoid duplicate DB calls.
///
/// Fetch once via [SharedHealthCache.fetch], then pass to both services.
class SharedHealthCache {
  final List<Map<String, dynamic>> sleepHistory;
  final List<Map<String, dynamic>> hrvHistory;
  final List<Map<String, dynamic>> rhrHistory;
  final List<Map<String, dynamic>> energyHistory;
  final List<int> strainHistory;
  final List<Map<String, dynamic>> spo2History;
  final List<Map<String, dynamic>> cardioHistory;
  final List<Map<String, dynamic>> workoutHistory;
  final List<Map<String, dynamic>> meditationHistory;

  SharedHealthCache({
    required this.sleepHistory,
    required this.hrvHistory,
    required this.rhrHistory,
    required this.energyHistory,
    required this.strainHistory,
    required this.spo2History,
    required this.cardioHistory,
    required this.workoutHistory,
    required this.meditationHistory,
  });

  /// Fetches all wearable history data in a single parallel batch.
  /// This eliminates duplicate calls when multiple services need the same data.
  static Future<SharedHealthCache> fetch(HealthRepository repo) async {
    final results = await Future.wait([
      repo.getSleepHistory(days: 14).catchError((_) => <Map<String, dynamic>>[]),       // 0
      repo.getHrvHistory(days: 14).catchError((_) => <Map<String, dynamic>>[]),         // 1
      repo.getRhrHistory(days: 14).catchError((_) => <Map<String, dynamic>>[]),         // 2
      repo.getActiveEnergyHistory(days: 7).catchError((_) => <Map<String, dynamic>>[]), // 3
      repo.getWeeklyStrainHistory(days: 7).catchError((_) => <int>[]),                  // 4
      repo.getSpO2History(days: 7).catchError((_) => <Map<String, dynamic>>[]),         // 5
      repo.getCardioLoadHistory(days: 14).catchError((_) => <Map<String, dynamic>>[]),  // 6
      repo.getWorkoutHistory(days: 30).catchError((_) => <Map<String, dynamic>>[]),     // 7
      import_meditation.MeditationRepository.fetchMeditationHistory(limit: 14).catchError((_) => <Map<String, dynamic>>[]), // 8
    ]);

    return SharedHealthCache(
      sleepHistory: results[0] as List<Map<String, dynamic>>,
      hrvHistory: results[1] as List<Map<String, dynamic>>,
      rhrHistory: results[2] as List<Map<String, dynamic>>,
      energyHistory: results[3] as List<Map<String, dynamic>>,
      strainHistory: results[4] as List<int>,
      spo2History: results[5] as List<Map<String, dynamic>>,
      cardioHistory: results[6] as List<Map<String, dynamic>>,
      workoutHistory: results[7] as List<Map<String, dynamic>>,
      meditationHistory: results[8] as List<Map<String, dynamic>>,
    );
  }

  /// Whether any meaningful wearable history was found.
  bool get hasData =>
      sleepHistory.isNotEmpty ||
      hrvHistory.isNotEmpty ||
      rhrHistory.isNotEmpty ||
      energyHistory.isNotEmpty ||
      strainHistory.any((s) => s > 0) ||
      workoutHistory.isNotEmpty;
}
