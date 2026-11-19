import '../widgets/tc025/tc025_widgets.dart';

/// One product in Zyndio's Precision Nutrition line (zyndio.com/supplements),
/// developed with Professor Jin-Xiong She, PhD. Purchase happens on the
/// website (secure Stripe checkout); the app shows the line and links to it.
class NutritionProduct {
  const NutritionProduct({
    required this.id,
    required this.name,
    required this.summary,
    required this.serving,
    required this.priceUsd,
    required this.path,
    required this.glyph,
    required this.tint,
    this.isTest = false,
  });

  final String id;
  final String name;
  final String summary;

  /// Per-serving amount and pack size, as printed on the product page.
  final String serving;
  final int priceUsd;

  /// Product page path on zyndio.com.
  final String path;
  final ZyndioGlyph glyph;
  final ZyndioTint tint;

  /// The at-home NAD+ test kit (a test, not a supplement).
  final bool isTest;

  Uri get url => Uri.parse('https://www.zyndio.com$path');
  String get price => '\$$priceUsd.00';
}

/// The eight products, in the website's order. Prices in USD.
const List<NutritionProduct> precisionNutritionProducts = [
  NutritionProduct(
    id: 'nad',
    name: 'Vitality↑ NAD+ Optimization',
    summary:
        'A dual-action daily powder that supports healthy NAD+ levels and cellular energy.*',
    serving: '1,000 mg active formula per serving · 62 servings',
    priceUsd: 118,
    path: '/nad',
    glyph: ZyndioGlyph.molecule,
    tint: ZyndioTint.violet,
  ),
  NutritionProduct(
    id: 'nad-chewable',
    name: 'Vitality↑ NAD+ Optimization Chewable',
    summary:
        'The same 1,000 mg NAD+ formula in a lozenge to dissolve under the tongue or chew on the go.*',
    serving: '1,000 mg active formula per tablet · 62 chewable tablets',
    priceUsd: 118,
    path: '/nad-chewable',
    glyph: ZyndioGlyph.capsule,
    tint: ZyndioTint.indigo,
  ),
  NutritionProduct(
    id: 'nad-kit',
    name: 'Intracellular NAD+ Test Kit',
    summary:
        'Find out your NAD+ level from home, then use the result to guide your routine.',
    serving: 'At-home sample collection · Lab-processed results',
    priceUsd: 198,
    path: '/nad-kit',
    glyph: ZyndioGlyph.testTube,
    tint: ZyndioTint.teal,
    isTest: true,
  ),
  NutritionProduct(
    id: 'pure-nmn',
    name: 'Pure NMN',
    summary:
        'Pure β-nicotinamide mononucleotide, a direct NAD+ precursor, with nothing added.*',
    serving: '500 mg NMN per serving · 62 servings',
    priceUsd: 58,
    path: '/pure-nmn',
    glyph: ZyndioGlyph.sparkle,
    tint: ZyndioTint.blue,
  ),
  NutritionProduct(
    id: 'mitoaid',
    name: 'MitoAid',
    summary:
        'Mitochondrial support with CoQ10, PQQ and vitamin E, for cellular energy and cardiovascular health.*',
    serving: '2 softgels per serving · 30 servings',
    priceUsd: 56,
    path: '/mitoaid',
    glyph: ZyndioGlyph.flame,
    tint: ZyndioTint.rose,
  ),
  NutritionProduct(
    id: 'creatine',
    name: 'Creatine + ATP',
    summary:
        'Creatine monohydrate plus ATP, two of the body’s key energy molecules, in one daily scoop.*',
    serving: '4.4 g per serving · 30 servings',
    priceUsd: 58,
    path: '/creatine',
    glyph: ZyndioGlyph.kettlebell,
    tint: ZyndioTint.green,
  ),
  NutritionProduct(
    id: 'd3-k2',
    name: 'D3 + K2',
    summary: 'Vitamin D3 and vitamin K2 together, for bone and immune support.*',
    serving: '5,000 IU D3 + 100 mcg K2 per softgel · 180 softgels',
    priceUsd: 42,
    path: '/d3-k2',
    glyph: ZyndioGlyph.sun,
    tint: ZyndioTint.amber,
  ),
  NutritionProduct(
    id: 'vital-minerals',
    name: 'Vital Minerals',
    summary:
        'An iron-free mineral complex for bone, muscle and nervous-system support.*',
    serving: '2 capsules per serving · 90 servings',
    priceUsd: 45,
    path: '/vital-minerals',
    glyph: ZyndioGlyph.droplet,
    tint: ZyndioTint.teal,
  ),
];

/// Required wording from the product pages; shown wherever the line is sold.
const String precisionNutritionDisclaimer =
    '*These statements have not been evaluated by the Food and Drug Administration. '
    'These products are not intended to diagnose, treat, cure, or prevent any disease. '
    'These are over-the-counter supplements, separate from your prescribed care. '
    'Consult your healthcare provider before starting any supplement.';
