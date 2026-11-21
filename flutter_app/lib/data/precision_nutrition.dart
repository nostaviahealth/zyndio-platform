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
    required this.image,
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

  /// Product image file in zyndio.com's /supplements folder.
  final String image;
  final ZyndioGlyph glyph;
  final ZyndioTint tint;

  /// The at-home NAD+ test kit (a test, not a supplement).
  final bool isTest;

  Uri get url => Uri.parse('https://www.zyndio.com$path');

  /// The website's own product image, resized to 640px by the site's image
  /// service (about 40–120 KB, versus up to 1.4 MB for the originals).
  String get imageUrl =>
      'https://www.zyndio.com/_next/image?url=%2Fsupplements%2F$image&w=640&q=75';
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
    image: 'nad-jar-v2.png',
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
    image: 'nad-chewable-bottle-v1.png',
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
    image: 'nad-kit-box-v2.png',
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
    image: 'pure-nmn.jpg',
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
    image: 'mitoaid.jpg',
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
    image: 'creatine.jpg',
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
    image: 'd3-k2.jpg',
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
    image: 'vital-minerals.jpg',
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

/// The Precision Nutrition line as context for the AI companion (client
/// walkthrough, 19 Nov 2026): when a patient's uploaded blood work points at a
/// supplement, the companion suggests products from this catalogue (the ones
/// in the app's store) instead of generic brands, and says which result led
/// to each suggestion. It stays within the companion's wellness boundaries:
/// no diagnosis, no dosing beyond the label, care team first.
String precisionNutritionAiContext() {
  final b = StringBuffer()
    ..writeln('=== ZYNDIO PRECISION NUTRITION (the in-app store) ===')
    ..writeln(
        'When the user asks which supplements could help, or their lab results point to an area a supplement can support, recommend ONLY from this list. Never name other brands.')
    ..writeln(
        'For each suggestion: tie it to a specific marker in LATEST LAB RESULTS (name and value) when there is one, say what the product supports in plain words, and give its price. Suggest at most 3.')
    ..writeln(
        "If the lab results don't point to any of these, say so plainly instead of forcing a product.")
    ..writeln(
        'These are over-the-counter wellness supplements, not treatment. Never claim a product treats, cures or prevents a condition, and never suggest a dose beyond the label serving. Tell the user to check with their care team before starting anything new, especially if they take medication or are on a GLP-1 therapy.')
    ..writeln(
        'The at-home NAD+ test kit measures NAD+ levels; suggest it when NAD+ status is unknown.')
    ..writeln(
        'When you recommend any of these, add the navigate_to_supplements CTA so the user can see them in the app.')
    ..writeln('Catalogue:');
  for (final p in precisionNutritionProducts) {
    b.writeln(
        '- ${p.name} (${p.isTest ? 'test kit' : 'supplement'}, ${p.price}): ${p.summary.replaceAll('*', '')} ${p.serving}.');
  }
  return b.toString();
}
