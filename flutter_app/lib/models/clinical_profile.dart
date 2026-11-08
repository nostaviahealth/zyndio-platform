import 'package:flutter/foundation.dart';

/// APP-04: sex assigned at birth. Drives lab reference ranges, so it is a
/// fixed set the server also enforces (patient_profiles_sex_at_birth_check).
enum SexAtBirth {
  female('female', 'Female'),
  male('male', 'Male'),
  intersex('intersex', 'Intersex');

  const SexAtBirth(this.wire, this.label);
  final String wire;
  final String label;

  static SexAtBirth? fromWire(Object? value) {
    for (final s in SexAtBirth.values) {
      if (s.wire == value) return s;
    }
    return null;
  }
}

/// APP-04: how the patient wants heights/weights shown. Storage is always
/// metric (height_cm); this only changes display and entry.
enum UnitSystem {
  imperial('imperial', 'US (ft, lb)'),
  metric('metric', 'Metric (cm, kg)');

  const UnitSystem(this.wire, this.label);
  final String wire;
  final String label;

  static UnitSystem? fromWire(Object? value) {
    for (final u in UnitSystem.values) {
      if (u.wire == value) return u;
    }
    return null;
  }
}

/// Height limits the server enforces (update_patient_profile / column check).
const double kMinHeightCm = 50;
const double kMaxHeightCm = 272;

/// The program is adults-only: the server refuses a DOB under 18.
const int kMinPatientAge = 18;

const double _cmPerInch = 2.54;

/// Converts feet + inches to centimetres, rounded to 0.1 cm.
double feetInchesToCm(int feet, double inches) =>
    ((feet * 12 + inches) * _cmPerInch * 10).roundToDouble() / 10;

/// Converts centimetres to whole feet + inches (inches rounded to the
/// nearest whole inch, carrying 12 in into a foot).
({int feet, int inches}) cmToFeetInches(double cm) {
  final totalInches = (cm / _cmPerInch).round();
  return (feet: totalInches ~/ 12, inches: totalInches % 12);
}

/// Whole years between [dob] and [today].
int ageOn(DateTime dob, DateTime today) {
  var age = today.year - dob.year;
  if (today.month < dob.month ||
      (today.month == dob.month && today.day < dob.day)) {
    age--;
  }
  return age;
}

/// Latest date of birth that is still [kMinPatientAge] on [today].
DateTime latestAllowedDob(DateTime today) {
  final y = today.year - kMinPatientAge;
  // 29 Feb on a non-leap target year falls back to 28 Feb.
  final lastDay = DateTime(y, today.month + 1, 0).day;
  return DateTime(y, today.month, today.day > lastDay ? lastDay : today.day);
}

/// APP-04: the clinical profile (patients.display_name + patient_profiles'
/// typed columns), read with `my_patient_profile()` and written with
/// `update_patient_profile()`.
@immutable
class ClinicalProfile {
  const ClinicalProfile({
    required this.displayName,
    this.dateOfBirth,
    this.sexAtBirth,
    this.heightCm,
    this.unitSystem,
  });

  final String displayName;
  final DateTime? dateOfBirth;
  final SexAtBirth? sexAtBirth;
  final double? heightCm;
  final UnitSystem? unitSystem;

  bool get isComplete =>
      displayName.trim().isNotEmpty &&
      dateOfBirth != null &&
      sexAtBirth != null &&
      heightCm != null &&
      unitSystem != null;

  factory ClinicalProfile.fromJson(Map<String, dynamic> json) {
    final dob = json['date_of_birth'];
    final height = json['height_cm'];
    return ClinicalProfile(
      displayName: (json['display_name'] as String?) ?? '',
      dateOfBirth: dob is String ? DateTime.tryParse(dob) : null,
      sexAtBirth: SexAtBirth.fromWire(json['sex_at_birth']),
      heightCm: height is num ? height.toDouble() : null,
      unitSystem: UnitSystem.fromWire(json['unit_system']),
    );
  }

  /// Params for `update_patient_profile`. Only valid when [isComplete].
  Map<String, dynamic> toRpcParams() => {
        'p_display_name': displayName.trim(),
        'p_date_of_birth': _isoDate(dateOfBirth!),
        'p_sex_at_birth': sexAtBirth!.wire,
        'p_height_cm': heightCm,
        'p_unit_system': unitSystem!.wire,
      };

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      other is ClinicalProfile &&
      other.displayName == displayName &&
      other.dateOfBirth == dateOfBirth &&
      other.sexAtBirth == sexAtBirth &&
      other.heightCm == heightCm &&
      other.unitSystem == unitSystem;

  @override
  int get hashCode =>
      Object.hash(displayName, dateOfBirth, sexAtBirth, heightCm, unitSystem);
}
