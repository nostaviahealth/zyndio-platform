import 'package:flutter/foundation.dart';

@immutable
class DiscoveredCorrelation {
  final String id;
  final String signalA;        // e.g., "sleep_hours"
  final String signalB;        // e.g., "hrv_next_morning"  
  final double coefficient;    // Pearson r: -1.0 to 1.0
  final int sampleSize;        // Number of paired data points
  final String direction;      // "positive" | "negative"
  final String insight;        // Natural language insight
  final String strength;       // "strong" | "moderate" | "weak"
  final DateTime discoveredAt;
  final DateTime? lastConfirmedAt;
  final int confirmationCount; // How many times this pattern has been re-validated
  final bool isNovel;          // First time seeing this pattern
  final bool dismissed;        // User dismissed this insight

  const DiscoveredCorrelation({
    required this.id,
    required this.signalA,
    required this.signalB,
    required this.coefficient,
    required this.sampleSize,
    required this.direction,
    required this.insight,
    required this.strength,
    required this.discoveredAt,
    this.lastConfirmedAt,
    this.confirmationCount = 1,
    this.isNovel = true,
    this.dismissed = false,
  });

  factory DiscoveredCorrelation.fromJson(Map<String, dynamic> json) {
    return DiscoveredCorrelation(
      id: json['id'] as String,
      signalA: json['signal_a'] as String,
      signalB: json['signal_b'] as String,
      coefficient: (json['coefficient'] as num).toDouble(),
      sampleSize: json['sample_size'] as int,
      direction: json['direction'] as String,
      insight: json['insight'] as String,
      strength: json['strength'] as String,
      discoveredAt: DateTime.parse(json['discovered_at'] as String),
      lastConfirmedAt: json['last_confirmed_at'] != null 
          ? DateTime.parse(json['last_confirmed_at'] as String) 
          : null,
      confirmationCount: json['confirmation_count'] as int? ?? 1,
      isNovel: json['is_novel'] as bool? ?? false,
      dismissed: json['dismissed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson({String? userId}) {
    return {
      if (userId != null) 'user_id': userId,
      'id': id,
      'signal_a': signalA,
      'signal_b': signalB,
      'coefficient': coefficient,
      'sample_size': sampleSize,
      'direction': direction,
      'insight': insight,
      'strength': strength,
      'discovered_at': discoveredAt.toIso8601String(),
      'last_confirmed_at': lastConfirmedAt?.toIso8601String(),
      'confirmation_count': confirmationCount,
      'is_novel': isNovel,
      'dismissed': dismissed,
    };
  }

  DiscoveredCorrelation copyWith({
    String? id,
    String? signalA,
    String? signalB,
    double? coefficient,
    int? sampleSize,
    String? direction,
    String? insight,
    String? strength,
    DateTime? discoveredAt,
    DateTime? lastConfirmedAt,
    int? confirmationCount,
    bool? isNovel,
    bool? dismissed,
  }) {
    return DiscoveredCorrelation(
      id: id ?? this.id,
      signalA: signalA ?? this.signalA,
      signalB: signalB ?? this.signalB,
      coefficient: coefficient ?? this.coefficient,
      sampleSize: sampleSize ?? this.sampleSize,
      direction: direction ?? this.direction,
      insight: insight ?? this.insight,
      strength: strength ?? this.strength,
      discoveredAt: discoveredAt ?? this.discoveredAt,
      lastConfirmedAt: lastConfirmedAt ?? this.lastConfirmedAt,
      confirmationCount: confirmationCount ?? this.confirmationCount,
      isNovel: isNovel ?? this.isNovel,
      dismissed: dismissed ?? this.dismissed,
    );
  }
}
