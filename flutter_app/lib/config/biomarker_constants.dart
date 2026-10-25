class BiomarkerRange {
  final String name;
  final List<String> aliases;
  final String unit;
  final double? optimalMin;
  final double? optimalMax;
  final double? inRangeMin;
  final double? inRangeMax;
  final bool higherIsBetter;
  final String category;

  const BiomarkerRange({
    required this.name,
    required this.aliases,
    required this.unit,
    this.optimalMin,
    this.optimalMax,
    this.inRangeMin,
    this.inRangeMax,
    this.higherIsBetter = false,
    required this.category,
  });
}

final List<BiomarkerRange> biomarkerRanges = [
  // LIPID PANEL
  const BiomarkerRange(
    name: "Total Cholesterol",
    aliases: ["cholesterol", "total chol", "tc"],
    unit: "mg/dL",
    optimalMax: 200,
    inRangeMax: 239,
    category: "Cardiovascular",
  ),
  const BiomarkerRange(
    name: "LDL Cholesterol",
    aliases: ["ldl", "ldl-c", "low density lipoprotein"],
    unit: "mg/dL",
    optimalMax: 100,
    inRangeMax: 129,
    category: "Cardiovascular",
  ),
  const BiomarkerRange(
    name: "HDL Cholesterol",
    aliases: ["hdl", "hdl-c", "high density lipoprotein"],
    unit: "mg/dL",
    optimalMin: 60,
    inRangeMin: 40,
    higherIsBetter: true,
    category: "Cardiovascular",
  ),
  const BiomarkerRange(
    name: "Triglycerides",
    aliases: ["tg", "trigs"],
    unit: "mg/dL",
    optimalMax: 100,
    inRangeMax: 150,
    category: "Cardiovascular",
  ),
  // METABOLIC PANEL
  const BiomarkerRange(
    name: "Glucose",
    aliases: ["blood glucose", "fasting glucose", "fbs", "blood sugar"],
    unit: "mg/dL",
    optimalMin: 70,
    optimalMax: 85,
    inRangeMin: 65,
    inRangeMax: 99,
    category: "Metabolic",
  ),
  const BiomarkerRange(
    name: "HbA1c",
    aliases: ["hemoglobin a1c", "glycated hemoglobin", "a1c"],
    unit: "%",
    optimalMax: 5.4,
    inRangeMax: 5.6,
    category: "Metabolic",
  ),
  const BiomarkerRange(
    name: "Insulin",
    aliases: ["fasting insulin"],
    unit: "µIU/mL",
    optimalMax: 5,
    inRangeMax: 10,
    category: "Metabolic",
  ),
  // LIVER FUNCTION
  const BiomarkerRange(
    name: "ALT",
    aliases: ["alanine aminotransferase", "sgpt"],
    unit: "U/L",
    optimalMax: 25,
    inRangeMax: 40,
    category: "Liver",
  ),
  const BiomarkerRange(
    name: "AST",
    aliases: ["aspartate aminotransferase", "sgot"],
    unit: "U/L",
    optimalMax: 25,
    inRangeMax: 40,
    category: "Liver",
  ),
  // KIDNEY FUNCTION
  const BiomarkerRange(
    name: "Creatinine",
    aliases: ["serum creatinine", "cr"],
    unit: "mg/dL",
    optimalMax: 1.0,
    inRangeMax: 1.2,
    category: "Kidney",
  ),
  // THYROID
  const BiomarkerRange(
    name: "TSH",
    aliases: ["thyroid stimulating hormone"],
    unit: "mIU/L",
    optimalMin: 1.0,
    optimalMax: 2.5,
    inRangeMin: 0.4,
    inRangeMax: 4.0,
    category: "Thyroid",
  ),
  // VITAMINS
  const BiomarkerRange(
    name: "Vitamin D",
    aliases: ["25-oh vitamin d", "25-hydroxyvitamin d", "vit d"],
    unit: "ng/mL",
    optimalMin: 50,
    optimalMax: 80,
    inRangeMin: 30,
    inRangeMax: 100,
    category: "Vitamins",
  ),
  const BiomarkerRange(
    name: "Vitamin B12",
    aliases: ["b12", "cobalamin"],
    unit: "pg/mL",
    optimalMin: 500,
    optimalMax: 1000,
    inRangeMin: 200,
    inRangeMax: 1100,
    category: "Vitamins",
  ),
  // BLOOD COUNT
  const BiomarkerRange(
    name: "Hemoglobin",
    aliases: ["hgb", "hb"],
    unit: "g/dL",
    optimalMin: 13.5,
    optimalMax: 16.0,
    inRangeMin: 12.0,
    inRangeMax: 17.5,
    category: "Blood Count",
  ),
];
