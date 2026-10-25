/// Unit Converter — Clinical-Grade Biomarker Normalization Engine
/// 
/// This service handles the automatic conversion of biomarker values between
/// clinically equivalent units reported by different labs. 
///
/// Design Principles:
/// - Zero-Assumption: If a conversion is not explicitly defined, no conversion
///   is attempted and the original value is returned as-is.
/// - Traceability: Every conversion returns both the converted value AND the
///   canonical target unit, so the UI can display the correct label.
/// - Safety: Conversion factors are sourced from SI/IUPAC standards.

class UnitConversionResult {
  /// The value in the normalized/canonical unit
  final double normalizedValue;

  /// The canonical unit string (e.g., 'mg/dL')
  final String canonicalUnit;

  /// Whether a conversion was actually performed
  final bool wasConverted;

  const UnitConversionResult({
    required this.normalizedValue,
    required this.canonicalUnit,
    required this.wasConverted,
  });
}

class UnitConverter {
  UnitConverter._(); // Prevent instantiation

  // ─────────────────────────────────────────────────────────────────────────
  // CANONICAL UNIT MAP
  // For each biomarker (by canonical name), defines the preferred target unit.
  // This is the "gold standard" unit the system will normalize to.
  // ─────────────────────────────────────────────────────────────────────────
  static const Map<String, String> _canonicalUnit = {
    'hba1c': '%',
    'glucose': 'mg/dL',
    'total cholesterol': 'mg/dL',
    'ldl cholesterol': 'mg/dL',
    'hdl cholesterol': 'mg/dL',
    'triglycerides': 'mg/dL',
    'creatinine': 'mg/dL',
    'uric acid': 'mg/dL',
    'vitamin d': 'ng/mL',
    'vitamin b12': 'pg/mL',
    'iron': 'µg/dL',
    'ferritin': 'ng/mL',
    'tsh': 'µIU/mL',
    'ft3': 'pg/mL',
    'ft4': 'ng/dL',
    'hemoglobin': 'g/dL',
    'crp': 'mg/L',
    'alt': 'U/L',
    'ast': 'U/L',
    'testosterone': 'ng/dL',
    'albumin': 'g/dL',
    'egfr': 'mL/min',
    'homocysteine': 'µmol/L',
    'non hdl cholesterol': 'mg/dL',
  };

  // ─────────────────────────────────────────────────────────────────────────
  // CONVERSION TABLE
  // Key: 'fromUnit->toUnit' (lowercase, trimmed)
  // Value: Multiplicative factor (result = input * factor)
  // ─────────────────────────────────────────────────────────────────────────
  static const Map<String, double> _conversionFactors = {
    // ── Glucose ──────────────────────────────────────────────────────────
    'mmol/l->mg/dl': 18.0182,
    'mg/dl->mmol/l': 0.05551,

    // ── Cholesterol / Lipids (same factor as glucose family) ─────────────
    // These are also reported in mmol/L in many countries
    'mmol/l->mg/dl_lipid': 38.67, // specific for cholesterol
    // We use a generic mmol/L -> mg/dL for lipids via biomarker context

    // ── Creatinine ────────────────────────────────────────────────────────
    'µmol/l->mg/dl': 0.01131,
    'umol/l->mg/dl': 0.01131,
    'mg/dl->µmol/l': 88.42,
    'mg/dl->umol/l': 88.42,

    // ── Uric Acid ─────────────────────────────────────────────────────────
    'µmol/l->mg/dl_uricacid': 0.01681,
    'umol/l->mg/dl_uricacid': 0.01681,

    // ── Vitamin D ─────────────────────────────────────────────────────────
    'nmol/l->ng/ml': 0.4006,
    'ng/ml->nmol/l': 2.496,

    // ── Vitamin B12 ───────────────────────────────────────────────────────
    'pmol/l->pg/ml': 1.3548,
    'pg/ml->pmol/l': 0.7378,

    // ── Iron / Ferritin ───────────────────────────────────────────────────
    'µmol/l->µg/dl': 5.585,
    'umol/l->µg/dl': 5.585,
    'µg/dl->µmol/l': 0.1791,
    'µg/l->ng/ml': 1.0,   // µg/L == ng/mL (same magnitude)
    'ng/ml->µg/l': 1.0,

    // ── TSH ───────────────────────────────────────────────────────────────
    'miu/l->µiu/ml': 1.0,  // mIU/L == µIU/mL (same magnitude)
    'µiu/ml->miu/l': 1.0,
    'miu/ml->µiu/ml': 1.0,

    // ── CRP ───────────────────────────────────────────────────────────────
    'mg/dl->mg/l': 10.0,
    'mg/l->mg/dl': 0.1,

    // ── Testosterone (nmol/L <-> ng/dL handled via context overrides) ─────
    'nmol/l->ng/dl': 28.842,
    'ng/dl->nmol/l': 0.03467,

    // ── Hemoglobin ────────────────────────────────────────────────────────
    'g/l->g/dl': 0.1,
    'g/dl->g/l': 10.0,
    'mmol/l->g/dl': 1.6113,  // hemoglobin specific
  };

  // ─────────────────────────────────────────────────────────────────────────
  // LIPID-SPECIFIC CONVERSION (mmol/L -> mg/dL)
  // Different from glucose because the molar mass differs per lipid type.
  // ─────────────────────────────────────────────────────────────────────────
  static const Map<String, double> _lipidMmolFactor = {
    'total cholesterol': 38.67,
    'ldl cholesterol': 38.67,
    'hdl cholesterol': 38.67,
    'non hdl cholesterol': 38.67,
    'triglycerides': 88.57,
  };

  /// Attempts to convert [value] from [fromUnit] to the canonical unit
  /// for the given [biomarkerCanonicalName].
  ///
  /// Returns a [UnitConversionResult] with:
  /// - The converted value (or original if no conversion found)
  /// - The canonical unit used
  /// - Whether a conversion was actually applied
  static UnitConversionResult normalize({
    required double value,
    required String fromUnit,
    required String biomarkerCanonicalName,
  }) {
    final canonicalName = biomarkerCanonicalName.toLowerCase().trim();
    final from = fromUnit.toLowerCase().trim();
    final toUnit = _canonicalUnit[canonicalName];

    // If we don't have a canonical unit defined for this biomarker,
    // or the unit is already the canonical one — return as-is
    if (toUnit == null || from == toUnit.toLowerCase()) {
      return UnitConversionResult(
        normalizedValue: value,
        canonicalUnit: toUnit ?? fromUnit,
        wasConverted: false,
      );
    }

    final to = toUnit.toLowerCase();

    // ── Biomarker-context-specific overrides ──────────────────────────────
    // Some conversions differ per biomarker (e.g., Vitamin D vs Testosterone
    // both use nmol/L but convert to different canonical units)
    final contextKey = '$canonicalName|$from->$to';
    const contextOverrides = <String, double>{
      'vitamin d|nmol/l->ng/ml': 0.4006,
      'vitamin d|ng/ml->nmol/l': 2.496,
      'testosterone|nmol/l->ng/dl': 28.842,
      'testosterone|ng/dl->nmol/l': 0.03467,
    };
    final contextFactor = contextOverrides[contextKey];
    if (contextFactor != null) {
      return UnitConversionResult(
        normalizedValue: value * contextFactor,
        canonicalUnit: toUnit,
        wasConverted: true,
      );
    }

    // Try lipid-specific mmol/L conversion first
    if (from == 'mmol/l' && to == 'mg/dl') {
      final lipidFactor = _lipidMmolFactor[canonicalName];
      if (lipidFactor != null) {
        return UnitConversionResult(
          normalizedValue: value * lipidFactor,
          canonicalUnit: toUnit,
          wasConverted: true,
        );
      }
    }

    // Try generic conversion table
    final key = '$from->$to';
    final factor = _conversionFactors[key];
    if (factor != null) {
      return UnitConversionResult(
        normalizedValue: value * factor,
        canonicalUnit: toUnit,
        wasConverted: true,
      );
    }

    // No conversion found — return original, but use defined canonical unit
    return UnitConversionResult(
      normalizedValue: value,
      canonicalUnit: fromUnit, // preserve original since we can't convert
      wasConverted: false,
    );
  }

  /// Returns the canonical/preferred unit for a given biomarker.
  /// Returns null if the biomarker is not in our conversion database.
  static String? canonicalUnitFor(String biomarkerCanonicalName) {
    return _canonicalUnit[biomarkerCanonicalName.toLowerCase().trim()];
  }

  /// Checks if two unit strings are equivalent (case-insensitive, trimmed).
  static bool areEquivalent(String unit1, String unit2) {
    final a = unit1.toLowerCase().trim();
    final b = unit2.toLowerCase().trim();
    if (a == b) return true;

    // Known equivalences
    final equivalences = [
      {'miu/l', 'µiu/ml', 'miu/ml'},
      {'µmol/l', 'umol/l'},
      {'µg/l', 'ng/ml'},
    ];

    for (final group in equivalences) {
      if (group.contains(a) && group.contains(b)) return true;
    }
    return false;
  }
}
