/// Intelligence data model matching React IntelligenceData type
class IntelligenceData {
  final String id;
  final String patientId;
  final int? overallScore;
  final int? biomarkersScore;
  final int? lifestyleScore;
  final int? riskFactorsScore;
  final List<HealthDomain> healthDomains;
  final List<DiseaseRisk> diseaseRisks;
  final bool approved;
  final bool published;
  final int? biologicalAge;
  final DateTime? generatedAt;
  final DateTime? publishedAt;

  const IntelligenceData({
    required this.id,
    required this.patientId,
    this.overallScore,
    this.biomarkersScore,
    this.lifestyleScore,
    this.riskFactorsScore,
    this.healthDomains = const [],
    this.diseaseRisks = const [],
    this.approved = false,
    this.published = false,
    this.biologicalAge,
    this.generatedAt,
    this.publishedAt,
  });

  factory IntelligenceData.fromJson(Map<String, dynamic> json) {
    // Helper to safely access nested maps
    final summary = json['biomarker_summary'] as Map<String, dynamic>?;
    final keyInsights = json['key_insights'] as Map<String, dynamic>?;

    return IntelligenceData(
      id: json['id'] as String,
      patientId: json['profile_id'] as String,
      overallScore: (json['longevity_score'] as num?)?.toInt(),
      biomarkersScore: (summary?['overall_score'] as num?)?.toInt(),
      lifestyleScore: (summary?['lifestyle_score'] as num?)?.toInt(),
      riskFactorsScore: (summary?['risk_score'] as num?)?.toInt(),
      healthDomains: (keyInsights?['health_domains'] as List<dynamic>?)
              ?.map((e) => HealthDomain.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      diseaseRisks: (json['disease_risks'] as List<dynamic>?)
              ?.map((e) => DiseaseRisk.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      approved: json['approved'] as bool? ?? false,
      published: json['published'] as bool? ?? false,
      biologicalAge: (json['biological_age'] as num?)?.toInt(),
      generatedAt: json['generated_at'] != null
          ? DateTime.parse(json['generated_at'] as String)
          : null,
      publishedAt: json['published_at'] != null
          ? DateTime.parse(json['published_at'] as String)
          : null,
    );
  }
}

/// Health domain score
class HealthDomain {
  final String name;
  final int score;
  final String? status;
  final String? grade; // e.g. "D"
  final String? targetGrade; // e.g. "B+"
  final String? description;

  const HealthDomain({
    required this.name,
    required this.score,
    this.status,
    this.grade,
    this.targetGrade,
    this.description,
  });

  factory HealthDomain.fromJson(Map<String, dynamic> json) {
    return HealthDomain(
      name: json['name'] as String,
      score: (json['score'] as num).toInt(),
      status: json['status'] as String?,
      grade: json['grade'] as String?,
      targetGrade: json['target_grade'] as String?,
      description: json['description'] as String?,
    );
  }
}

/// Disease risk assessment
class DiseaseRisk {
  final String condition;
  final int probability;
  final String level;
  final List<String> drivers;
  final String? mitigationStrategy;
  final String? methodology;
  final String? primaryValidation;
  final String? description;
  final Map<String, dynamic> debugJson;

  const DiseaseRisk({
    required this.condition,
    required this.probability,
    required this.level,
    this.drivers = const [],
    this.mitigationStrategy,
    this.methodology,
    this.primaryValidation,
    this.description,
    this.debugJson = const {},
  });
  
  String? get smartDescription {
    if (description != null && description!.isNotEmpty) return description;
    
    // Try common keys
    final candidates = [
      'explanation',
      'summary',
      'analysis',
      'reasoning',
      'text',
      'content',
      'details',
      'notes'
    ];
    
    for (final key in candidates) {
      if (debugJson[key] is String && (debugJson[key] as String).isNotEmpty) {
        return debugJson[key] as String;
      }
    }
    
    return null;
  }

  factory DiseaseRisk.fromJson(Map<String, dynamic> json) {
    return DiseaseRisk(
      condition: json['condition'] as String,
      probability: (json['probability'] as num).toInt(),
      level: json['level'] as String,
      drivers: (json['drivers'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      mitigationStrategy: json['mitigation_strategy'] as String?,
      methodology: json['methodology'] as String?,
      primaryValidation: json['primary_validation'] as String?,
      description: json['description'] as String?,
      debugJson: json,
    );
  }
}
