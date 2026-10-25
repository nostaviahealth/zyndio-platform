class Meal {
  final String time;
  final String name;
  final String desc;
  final int calories;
  final String protein;
  final String carbs;
  final String fats;
  final String? clinicalRationale;

  Meal({
    required this.time,
    required this.name,
    required this.desc,
    this.calories = 0,
    this.protein = '0g',
    this.carbs = '0g',
    this.fats = '0g',
    this.clinicalRationale,
  });

  factory Meal.fromJson(Map<String, dynamic> json) {
    return Meal(
      time: json['time'] ?? '',
      name: json['name'] ?? '',
      desc: json['desc'] ?? '',
      calories: json['calories'] is int ? json['calories'] : int.tryParse(json['calories'].toString()) ?? 0,
      protein: json['protein']?.toString() ?? '0g',
      carbs: json['carbs']?.toString() ?? '0g',
      fats: json['fats']?.toString() ?? '0g',
      clinicalRationale: json['clinical_rationale'],
    );
  }

  Map<String, dynamic> toJson() => {
    'time': time,
    'name': name,
    'desc': desc,
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fats': fats,
    if (clinicalRationale != null) 'clinical_rationale': clinicalRationale,
  };
}


class DayPlan {
  final String day;
  final String date;
  final List<Meal> meals;

  DayPlan({
    required this.day,
    required this.date,
    required this.meals,
  });

  factory DayPlan.fromJson(Map<String, dynamic> json) {
    var mealsList = json['meals'] as List?;
    List<Meal> meals = mealsList != null 
        ? mealsList.map((m) => Meal.fromJson(m)).toList() 
        : [];
    
    return DayPlan(
      day: json['day'] ?? '',
      date: json['date'] ?? '',
      meals: meals,
    );
  }

  Map<String, dynamic> toJson() => {
    'day': day,
    'date': date,
    'meals': meals.map((m) => m.toJson()).toList(),
  };
}

class MealPlan {
  final String id;
  final String name;
  final String weekStartDate;
  final bool approved;
  final List<DayPlan> weeklyPlan;

  MealPlan({
    required this.id,
    this.name = 'Personalized Meal Plan',
    required this.weekStartDate,
    required this.approved,
    required this.weeklyPlan,
  });

  factory MealPlan.fromJson(Map<String, dynamic> json) {
    var rawPlan = json['weekly_plan'];
    List<DayPlan> weeklyPlan = [];
    
    if (rawPlan is List) {
      weeklyPlan = rawPlan.map((d) => DayPlan.fromJson(d)).toList();
    }

    return MealPlan(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: json['name'] ?? 'Personalized Meal Plan',
      weekStartDate: json['week_start_date'] ?? '',
      approved: json['approved'] ?? false,
      weeklyPlan: weeklyPlan,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'week_start_date': weekStartDate,
    'approved': approved,
    'weekly_plan': weeklyPlan.map((d) => d.toJson()).toList(),
  };

  String toMarkdown() {
    final buffer = StringBuffer();
    buffer.writeln('# $name');
    if (weekStartDate.isNotEmpty) {
      buffer.writeln('_Starting: \${weekStartDate}_\\n');
    }
    
    for (final day in weeklyPlan) {
      buffer.writeln('## ${day.day} ${day.date.isNotEmpty ? '(${day.date})' : ''}');
      for (final meal in day.meals) {
        buffer.writeln('### ${meal.name} (${meal.time})');
        buffer.writeln('${meal.desc}\\n');
        buffer.writeln('- **Calories:** ${meal.calories}');
        buffer.writeln('- **Protein:** ${meal.protein}');
        buffer.writeln('- **Carbs:** ${meal.carbs}');
        buffer.writeln('- **Fats:** ${meal.fats}\\n');
      }
    }

    return buffer.toString().trim();
  }
}
