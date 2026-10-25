import 'package:flutter/foundation.dart';

enum CyclePhase {
  menstrual,
  follicular,
  ovulatory,
  luteal,
  unknown
}

extension CyclePhaseExtension on CyclePhase {
  String get name {
    switch (this) {
      case CyclePhase.menstrual:
        return 'Menstrual';
      case CyclePhase.follicular:
        return 'Follicular';
      case CyclePhase.ovulatory:
        return 'Ovulatory';
      case CyclePhase.luteal:
        return 'Luteal';
      case CyclePhase.unknown:
        return 'Unknown';
    }
  }
}

@immutable
class MenstrualLog {
  final String id;
  final String userId;
  final DateTime startDate;
  final DateTime? endDate;
  final String? flowIntensity;
  final Map<String, dynamic>? symptoms;

  const MenstrualLog({
    required this.id,
    required this.userId,
    required this.startDate,
    this.endDate,
    this.flowIntensity,
    this.symptoms,
  });

  factory MenstrualLog.fromJson(Map<String, dynamic> json) {
    return MenstrualLog(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: json['end_date'] != null ? DateTime.parse(json['end_date'] as String) : null,
      flowIntensity: json['flow_intensity'] as String?,
      symptoms: json['symptoms'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'start_date': startDate.toIso8601String().substring(0, 10),
      'end_date': endDate?.toIso8601String().substring(0, 10),
      'flow_intensity': flowIntensity,
      'symptoms': symptoms,
    };
  }
}
