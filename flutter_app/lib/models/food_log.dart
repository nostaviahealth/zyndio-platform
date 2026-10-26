class FoodLog {
  final String id;
  final String userId;
  final String? imagePath;
  final Map<String, dynamic> analysis;
  final DateTime loggedAt;
  final String? mealType;

  FoodLog({
    required this.id,
    required this.userId,
    this.imagePath,
    required this.analysis,
    required this.loggedAt,
    this.mealType,
  });

  factory FoodLog.fromJson(Map<String, dynamic> json) {
    return FoodLog(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      imagePath: json['image_path'] as String?,
      analysis: json['analysis_json'] as Map<String, dynamic>? ?? {},
      loggedAt: DateTime.parse(json['logged_at'] as String),
      mealType: json['meal_type'] as String?,
    );
  }

  // Helper to get nutrition summary safely
  String get nutritionSummary {
    if (analysis.isEmpty) return 'No analysis available';
    
    final calories = analysis['calories'] ?? analysis['total_calories'];
    final protein = analysis['protein'] ?? analysis['protein_g'];
    
    final buffer = StringBuffer();
    if (calories != null) buffer.write('$calories kcal');
    if (calories != null && protein != null) buffer.write(' • ');
    if (protein != null) buffer.write('${protein}g protein');
    
    return buffer.toString();
  }
}
