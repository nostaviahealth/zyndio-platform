
class FoodAnalysis {
  final int score;
  final String foodName;
  final int calories;
  final List<Ingredient> ingredients;
  final Macronutrients macros;
  final List<Micronutrient> micros;
  final MetabolicImpact metabolicImpact;
  final List<BioImpactItem> bioImpact; // Hormonal, Cellular, etc.
  final List<Toxin> toxins;
  final AyurvedicBalance ayurvedicBalance;
  final List<String> healthImpacts; // Immediate vs Long-term
  final String intelligenceInsight; // 3-4 line personalized analysis

  // ── NEW: V2 Enhancement Fields ──────────────────────────────────────────────
  final UPFAnalysis upfAnalysis;
  final CircadianMatch circadianMatch;
  final BioHack bioHack;
  final HormonalImpact hormonalImpact;
  final Bioavailability bioavailability;
  final LongevityImpact longevityImpact;

  FoodAnalysis({
    required this.score,
    required this.foodName,
    required this.calories,
    required this.ingredients,
    required this.macros,
    required this.micros,
    required this.metabolicImpact,
    required this.bioImpact,
    required this.toxins,
    required this.ayurvedicBalance,
    required this.healthImpacts,
    this.intelligenceInsight = '',
    // V2 fields
    UPFAnalysis? upfAnalysis,
    CircadianMatch? circadianMatch,
    BioHack? bioHack,
    HormonalImpact? hormonalImpact,
    Bioavailability? bioavailability,
    LongevityImpact? longevityImpact,
  }) : upfAnalysis = upfAnalysis ?? UPFAnalysis.empty(),
       circadianMatch = circadianMatch ?? CircadianMatch.empty(),
       bioHack = bioHack ?? BioHack.empty(),
       hormonalImpact = hormonalImpact ?? HormonalImpact.empty(),
       bioavailability = bioavailability ?? Bioavailability.empty(),
       longevityImpact = longevityImpact ?? LongevityImpact.empty();

  factory FoodAnalysis.fromJson(Map<String, dynamic> json) {
    return FoodAnalysis(
      score: json['score'] ?? 0,
       foodName: json['food_name'] ?? 'Unknown Food',
      calories: json['calories'] ?? 0,
      ingredients: (json['ingredients'] as List?)?.map((e) => Ingredient.fromJson(e)).toList() ?? [],
      macros: Macronutrients.fromJson(json['macros'] ?? {}),
      micros: (json['micros'] as List?)?.map((e) => Micronutrient.fromJson(e)).toList() ?? [],
      metabolicImpact: MetabolicImpact.fromJson(json['metabolic_impact'] ?? {}),
      bioImpact: (json['bio_impact'] as List?)?.map((e) => BioImpactItem.fromJson(e)).toList() ?? [],
      toxins: (json['toxins'] as List?)?.map((e) => Toxin.fromJson(e)).toList() ?? [],
      ayurvedicBalance: AyurvedicBalance.fromJson(json['ayurvedic_balance'] ?? {}),
      healthImpacts: (json['health_impacts'] as List?)?.map((e) => e.toString()).toList() ?? [],
      intelligenceInsight: json['intelligence_insight'] ?? json['intelligence_insights'] ?? '',
      // V2 fields
      upfAnalysis: json['upf_analysis'] != null ? UPFAnalysis.fromJson(json['upf_analysis']) : UPFAnalysis.empty(),
      circadianMatch: json['circadian_match'] != null ? CircadianMatch.fromJson(json['circadian_match']) : CircadianMatch.empty(),
      bioHack: json['bio_hack'] != null ? BioHack.fromJson(json['bio_hack']) : BioHack.empty(),
      hormonalImpact: json['hormonal_impact'] != null ? HormonalImpact.fromJson(json['hormonal_impact']) : HormonalImpact.empty(),
      bioavailability: json['bioavailability'] != null ? Bioavailability.fromJson(json['bioavailability']) : Bioavailability.empty(),
      longevityImpact: json['longevity_impact'] != null ? LongevityImpact.fromJson(json['longevity_impact']) : LongevityImpact.empty(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'score': score,
      'food_name': foodName,
      'calories': calories,
      'ingredients': ingredients.map((e) => e.toJson()).toList(),
      'macros': macros.toJson(),
      'micros': micros.map((e) => e.toJson()).toList(),
      'metabolic_impact': metabolicImpact.toJson(),
      'bio_impact': bioImpact.map((e) => e.toJson()).toList(),
      'toxins': toxins.map((e) => e.toJson()).toList(),
      'ayurvedic_balance': ayurvedicBalance.toJson(),
      'health_impacts': healthImpacts,
      'intelligence_insight': intelligenceInsight,
      'upf_analysis': upfAnalysis.toJson(),
      'circadian_match': circadianMatch.toJson(),
      'bio_hack': bioHack.toJson(),
      'hormonal_impact': hormonalImpact.toJson(),
      'bioavailability': bioavailability.toJson(),
      'longevity_impact': longevityImpact.toJson(),
    };
  }

  /// Whether the deep V2 analysis has been populated (Phase 2 complete).
  bool get hasDeepAnalysis =>
      hormonalImpact.insulin.response != 'Unknown' ||
      longevityImpact.longevityScore > 0 ||
      circadianMatch.match != 'Unknown' ||
      bioHack.tip.isNotEmpty;

  /// Merge Phase 2 deep analysis JSON into this instance, returning a new FoodAnalysis.
  FoodAnalysis mergeDeep(Map<String, dynamic> deepJson) {
    // Phase 2 score is intentionally more refined (considering biological context)
    // Always prefer Phase 2 score if it exists and is != 0
    final int refinedScore = deepJson['score'] != null && deepJson['score'] != 0 
        ? deepJson['score'] 
        : score;

    return FoodAnalysis(
      score: refinedScore,
      foodName: foodName,
      calories: calories,
      ingredients: ingredients,
      macros: macros,
      micros: micros,
      metabolicImpact: metabolicImpact,
      bioImpact: bioImpact,
      toxins: deepJson['toxins'] != null
          ? (deepJson['toxins'] as List).map((e) => Toxin.fromJson(e)).toList()
          : toxins,
      ayurvedicBalance: ayurvedicBalance,
      healthImpacts: healthImpacts,
      intelligenceInsight: (deepJson['intelligence_insight'] != null && deepJson['intelligence_insight'].toString().isNotEmpty)
          ? deepJson['intelligence_insight']
          : (deepJson['intelligence_insights'] != null && deepJson['intelligence_insights'].toString().isNotEmpty)
              ? deepJson['intelligence_insights']
              : intelligenceInsight,
      // Merge Phase 2 deep fields
      upfAnalysis: deepJson['upf_analysis'] != null
          ? UPFAnalysis.fromJson(deepJson['upf_analysis'])
          : upfAnalysis,
      circadianMatch: deepJson['circadian_match'] != null
          ? CircadianMatch.fromJson(deepJson['circadian_match'])
          : circadianMatch,
      bioHack: deepJson['bio_hack'] != null
          ? BioHack.fromJson(deepJson['bio_hack'])
          : bioHack,
      hormonalImpact: deepJson['hormonal_impact'] != null
          ? HormonalImpact.fromJson(deepJson['hormonal_impact'])
          : hormonalImpact,
      bioavailability: deepJson['bioavailability'] != null
          ? Bioavailability.fromJson(deepJson['bioavailability'])
          : bioavailability,
      longevityImpact: deepJson['longevity_impact'] != null
          ? LongevityImpact.fromJson(deepJson['longevity_impact'])
          : longevityImpact,
    );
  }
}

class Ingredient {
  final String name;
  final String amount;
  final int matchPercentage;

  Ingredient({required this.name, required this.amount, required this.matchPercentage});

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      name: json['name'] ?? '',
      amount: json['amount'] ?? '',
      matchPercentage: json['match_percentage'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'amount': amount,
      'match_percentage': matchPercentage,
    };
  }
}

class Macronutrients {
  final int protein;
  final int carbs;
  final int fat;
  final int fiber;

  Macronutrients({required this.protein, required this.carbs, required this.fat, this.fiber = 0});

  factory Macronutrients.fromJson(Map<String, dynamic> json) {
    return Macronutrients(
      protein: json['protein'] ?? 0,
      carbs: json['carbs'] ?? 0,
      fat: json['fat'] ?? 0,
      fiber: json['fiber'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'fiber': fiber,
    };
  }
}

class Micronutrient {
  final String name;
  final String amount;
  final int percentDV;
  final String color; // hex code or name

  Micronutrient({required this.name, required this.amount, required this.percentDV, this.color = 'green'});

  factory Micronutrient.fromJson(Map<String, dynamic> json) {
    return Micronutrient(
      name: json['name'] ?? '',
      amount: json['amount'] ?? '',
      percentDV: json['percent_daily_value'] ?? 0,
      color: json['color'] ?? 'green',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'amount': amount,
      'percent_daily_value': percentDV,
      'color': color,
    };
  }
}

class MetabolicImpact {
  final String digestionTime;
  final String energyCurve; // Spike, Sustained, Crash

  MetabolicImpact({required this.digestionTime, required this.energyCurve});

  factory MetabolicImpact.fromJson(Map<String, dynamic> json) {
    return MetabolicImpact(
      digestionTime: json['digestion_time'] ?? 'Unknown',
      energyCurve: json['energy_curve'] ?? 'Unknown',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'digestion_time': digestionTime,
      'energy_curve': energyCurve,
    };
  }
}

class BioImpactItem {
  final String category; // Hormonal Response, Cellular Aging, etc.
  final String title;
  final String description;
  final String impact; // "negative", "positive", "neutral"

  BioImpactItem({required this.category, required this.title, required this.description, required this.impact});

  factory BioImpactItem.fromJson(Map<String, dynamic> json) {
    return BioImpactItem(
      category: json['category'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      impact: json['impact'] ?? 'neutral',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'title': title,
      'description': description,
      'impact': impact,
    };
  }
}

class Toxin {
  final String name;
  final String details;
  final String severity; // High, Medium, Low

  Toxin({required this.name, required this.details, required this.severity});

  factory Toxin.fromJson(Map<String, dynamic> json) {
    return Toxin(
      name: json['name'] ?? '',
      details: json['details'] ?? '',
      severity: json['severity'] ?? 'Low',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'details': details,
      'severity': severity,
    };
  }
}

class AyurvedicBalance {
  final String vata; // balancing, neutral, aggravating
  final String pitta;
  final String kapha;

  AyurvedicBalance({required this.vata, required this.pitta, required this.kapha});

  factory AyurvedicBalance.fromJson(Map<String, dynamic> json) {
    return AyurvedicBalance(
      vata: json['vata'] ?? 'neutral',
      pitta: json['pitta'] ?? 'neutral',
      kapha: json['kapha'] ?? 'neutral',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'vata': vata,
      'pitta': pitta,
      'kapha': kapha,
    };
  }
}

// ── NEW V2 MODELS ──────────────────────────────────────────────────────────────

/// Ultra-Processed Food analysis
class UPFAnalysis {
  final int score; // 0 (clean) to 10 (ultra-processed)
  final String level; // "Whole Food", "Minimally Processed", "Processed", "Ultra-Processed"
  final List<String> additives; // identified additives/chemicals
  final String verdict; // one-sentence verdict

  UPFAnalysis({
    required this.score,
    required this.level,
    required this.additives,
    required this.verdict,
  });

  factory UPFAnalysis.empty() => UPFAnalysis(score: 0, level: 'Unknown', additives: [], verdict: '');

  factory UPFAnalysis.fromJson(Map<String, dynamic> json) {
    return UPFAnalysis(
      score: json['score'] ?? 0,
      level: json['level'] ?? 'Unknown',
      additives: (json['additives'] as List?)?.map((e) => e.toString()).toList() ?? [],
      verdict: json['verdict'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'score': score,
    'level': level,
    'additives': additives,
    'verdict': verdict,
  };
}

/// Circadian alignment analysis
class CircadianMatch {
  final String mealTime; // e.g. "Morning", "Afternoon", "Evening", "Late Night"
  final String match; // "Excellent", "Good", "Fair", "Poor"
  final int matchScore; // 0-100
  final String reason; // Why it matches/doesn't match this time of day
  final String recommendation; // What to eat instead or when

  CircadianMatch({
    required this.mealTime,
    required this.match,
    required this.matchScore,
    required this.reason,
    required this.recommendation,
  });

  factory CircadianMatch.empty() => CircadianMatch(
    mealTime: '', match: 'Unknown', matchScore: 0, reason: '', recommendation: '',
  );

  factory CircadianMatch.fromJson(Map<String, dynamic> json) {
    return CircadianMatch(
      mealTime: json['meal_time'] ?? '',
      match: json['match'] ?? 'Unknown',
      matchScore: json['match_score'] ?? 0,
      reason: json['reason'] ?? '',
      recommendation: json['recommendation'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'meal_time': mealTime,
    'match': match,
    'match_score': matchScore,
    'reason': reason,
    'recommendation': recommendation,
  };
}

/// Proactive "hacking" tip for the meal
class BioHack {
  final String tip; // The actionable tip
  final String mechanism; // The biological mechanism behind it
  final String timing; // When to apply (e.g., "Before eating", "30 mins after")
  final int potencyPercent; // Estimated % improvement

  BioHack({
    required this.tip,
    required this.mechanism,
    required this.timing,
    required this.potencyPercent,
  });

  factory BioHack.empty() => BioHack(tip: '', mechanism: '', timing: '', potencyPercent: 0);

  factory BioHack.fromJson(Map<String, dynamic> json) {
    return BioHack(
      tip: json['tip'] ?? '',
      mechanism: json['mechanism'] ?? '',
      timing: json['timing'] ?? '',
      potencyPercent: json['potency_percent'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'tip': tip,
    'mechanism': mechanism,
    'timing': timing,
    'potency_percent': potencyPercent,
  };
}

/// Impact on the "Big Three" hormones
class HormonalImpact {
  final HormoneReading insulin; // Pancreatic response
  final HormoneReading leptin; // Satiety signal
  final HormoneReading ghrelin; // Hunger signal

  HormonalImpact({required this.insulin, required this.leptin, required this.ghrelin});

  factory HormonalImpact.empty() => HormonalImpact(
    insulin: HormoneReading.empty('Insulin'),
    leptin: HormoneReading.empty('Leptin'),
    ghrelin: HormoneReading.empty('Ghrelin'),
  );

  factory HormonalImpact.fromJson(Map<String, dynamic> json) {
    return HormonalImpact(
      insulin: HormoneReading.fromJson(json['insulin'] ?? {}, 'Insulin'),
      leptin: HormoneReading.fromJson(json['leptin'] ?? {}, 'Leptin'),
      ghrelin: HormoneReading.fromJson(json['ghrelin'] ?? {}, 'Ghrelin'),
    );
  }

  Map<String, dynamic> toJson() => {
    'insulin': insulin.toJson(),
    'leptin': leptin.toJson(),
    'ghrelin': ghrelin.toJson(),
  };
}

class HormoneReading {
  final String name;
  final String response; // "Spike", "Moderate Rise", "Stable", "Decrease"
  final String impact; // "positive", "negative", "neutral"
  final String detail; // One sentence detail

  HormoneReading({
    required this.name,
    required this.response,
    required this.impact,
    required this.detail,
  });

  factory HormoneReading.empty(String name) =>
      HormoneReading(name: name, response: 'Unknown', impact: 'neutral', detail: '');

  factory HormoneReading.fromJson(Map<String, dynamic> json, String defaultName) {
    return HormoneReading(
      name: json['name'] ?? defaultName,
      response: json['response'] ?? 'Unknown',
      impact: json['impact'] ?? 'neutral',
      detail: json['detail'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'response': response,
    'impact': impact,
    'detail': detail,
  };
}

/// Nutrient absorption and preparation optimization
class Bioavailability {
  final int absorptionScore; // 0-100, how well nutrients are absorbed
  final List<BioavailabilityTip> tips; // Synergy and preparation tips

  Bioavailability({required this.absorptionScore, required this.tips});

  factory Bioavailability.empty() => Bioavailability(absorptionScore: 0, tips: []);

  factory Bioavailability.fromJson(Map<String, dynamic> json) {
    return Bioavailability(
      absorptionScore: json['absorption_score'] ?? 0,
      tips: (json['tips'] as List?)?.map((e) => BioavailabilityTip.fromJson(e)).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
    'absorption_score': absorptionScore,
    'tips': tips.map((e) => e.toJson()).toList(),
  };
}

class BioavailabilityTip {
  final String type; // "Synergy", "Anti-Nutrient", "Preparation"
  final String title;
  final String description;
  final String impact; // "positive", "negative"

  BioavailabilityTip({
    required this.type,
    required this.title,
    required this.description,
    required this.impact,
  });

  factory BioavailabilityTip.fromJson(Map<String, dynamic> json) {
    return BioavailabilityTip(
      type: json['type'] ?? 'Synergy',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      impact: json['impact'] ?? 'positive',
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'title': title,
    'description': description,
    'impact': impact,
  };
}

/// Cellular aging and longevity impact
class LongevityImpact {
  final int longevityScore; // 0-100, impact on longevity pathways
  final String sirtuinEffect; // "Activating", "Neutral", "Suppressing"
  final String mTorEffect; // "Activating" (bad for longevity if chronic), "Neutral", "Inhibiting" (good)
  final String inflammationEffect; // "Anti-inflammatory", "Neutral", "Pro-inflammatory"
  final String longevitySummary; // One-sentence longevity verdict
  final int longevityCredit; // Positive or negative, like a credit system

  LongevityImpact({
    required this.longevityScore,
    required this.sirtuinEffect,
    required this.mTorEffect,
    required this.inflammationEffect,
    required this.longevitySummary,
    required this.longevityCredit,
  });

  factory LongevityImpact.empty() => LongevityImpact(
    longevityScore: 0, sirtuinEffect: 'Unknown', mTorEffect: 'Unknown',
    inflammationEffect: 'Unknown', longevitySummary: '', longevityCredit: 0,
  );

  factory LongevityImpact.fromJson(Map<String, dynamic> json) {
    return LongevityImpact(
      longevityScore: json['longevity_score'] ?? 0,
      sirtuinEffect: json['sirtuin_effect'] ?? 'Unknown',
      mTorEffect: json['mtor_effect'] ?? 'Unknown',
      inflammationEffect: json['inflammation_effect'] ?? 'Unknown',
      longevitySummary: json['longevity_summary'] ?? '',
      longevityCredit: json['longevity_credit'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'longevity_score': longevityScore,
    'sirtuin_effect': sirtuinEffect,
    'mtor_effect': mTorEffect,
    'inflammation_effect': inflammationEffect,
    'longevity_summary': longevitySummary,
    'longevity_credit': longevityCredit,
  };
}
