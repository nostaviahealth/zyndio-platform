import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../config/theme.dart';
import '../../data/precision_nutrition.dart';
import '../../services/zyndio_links.dart';
import '../../widgets/tc025/tc025_widgets.dart';

/// Zyndio Precision Nutrition: the eight products from zyndio.com/supplements.
/// Tapping a product shows its details; buying opens that product's page on
/// zyndio.com (secure Stripe checkout) in the in-app browser.
class PrecisionNutritionScreen extends StatelessWidget {
  const PrecisionNutritionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.zc;
    return ZyndioDetailScaffold(
      title: 'Precision Nutrition',
      subtitle: 'Developed with Professor Jin-Xiong She, PhD.',
      children: [
        const _IntroCard(),
        const SizedBox(height: 22),
        const ZyndioSectionLabel('Shop the line'),
        for (final p in precisionNutritionProducts) ...[
          _ProductCard(product: p),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 4),
        ZyndioOutlineButton(
          label: 'Visit zyndio.com/supplements',
          icon: LucideIcons.externalLink,
          onTap: () => openZyndioLink(context, ZyndioLinks.supplements),
        ),
        const SizedBox(height: 18),
        Text(
          precisionNutritionDisclaimer,
          style: TextStyle(
            fontFamily: ZyndioType.family,
            fontSize: 12,
            height: 17 / 12,
            color: c.textTertiary,
          ),
        ),
      ],
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    final c = context.zc;
    return ZyndioCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ZyndioIconTile(
              glyph: ZyndioGlyph.labReport, tint: ZyndioTint.violet, size: 52),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Test. Act. Optimize.',
                    style: TextStyle(
                        fontFamily: ZyndioType.family,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary)),
                const SizedBox(height: 4),
                Text(
                  'Start with the NAD+ test kit to see where you are, choose '
                  'support with your care team, then measure again.',
                  style: TextStyle(
                      fontFamily: ZyndioType.family,
                      fontSize: 14,
                      height: 20 / 14,
                      color: c.textSecondary),
                ),
                const SizedBox(height: 8),
                const ZyndioPill('Free US shipping',
                    tone: ZyndioPillTone.brand, icon: LucideIcons.truck),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product});
  final NutritionProduct product;

  @override
  Widget build(BuildContext context) {
    final c = context.zc;
    final p = product;
    return Semantics(
      button: true,
      label: '${p.name}, ${p.price}. ${p.summary}',
      onTap: () => showNutritionProductSheet(context, p),
      child: ExcludeSemantics(
        child: ZyndioCard(
          padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
          onTap: () => showNutritionProductSheet(context, p),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NutritionProductImage(product: p, size: 84),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name,
                        style: TextStyle(
                            fontFamily: ZyndioType.family,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: c.textPrimary)),
                    const SizedBox(height: 3),
                    Text(p.summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontFamily: ZyndioType.family,
                            fontSize: 14,
                            height: 20 / 14,
                            color: c.textSecondary)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(p.price,
                            style: TextStyle(
                                fontFamily: ZyndioType.family,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: c.textPrimary)),
                        if (p.isTest)
                          const ZyndioPill('At-home test',
                              tone: ZyndioPillTone.brand),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(LucideIcons.chevronRight,
                    size: 20, color: c.textTertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Product details with a "Buy on zyndio.com" action.
Future<void> showNutritionProductSheet(
    BuildContext context, NutritionProduct p) {
  final c = context.zc;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: c.bgSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetCtx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NutritionProductImage(product: p, size: 200, wide: true),
            const SizedBox(height: 6),
            Center(
              child: Text('Product rendering · Final packaging may vary',
                  style: TextStyle(
                      fontFamily: ZyndioType.family,
                      fontSize: 11,
                      color: c.textTertiary)),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name,
                          style: TextStyle(
                              fontFamily: ZyndioType.family,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: c.textPrimary)),
                      const SizedBox(height: 2),
                      Text(p.price,
                          style: TextStyle(
                              fontFamily: ZyndioType.family,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: c.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(p.summary,
                style: TextStyle(
                    fontFamily: ZyndioType.family,
                    fontSize: 15,
                    height: 22 / 15,
                    color: c.textPrimary)),
            const SizedBox(height: 10),
            Text(p.serving,
                style: TextStyle(
                    fontFamily: ZyndioType.family,
                    fontSize: 14,
                    color: c.textSecondary)),
            const SizedBox(height: 4),
            Text('Free US shipping · Secure checkout by Stripe',
                style: TextStyle(
                    fontFamily: ZyndioType.family,
                    fontSize: 14,
                    color: c.textSecondary)),
            const SizedBox(height: 20),
            ZyndioGradientButton(
              label: 'Buy on zyndio.com · ${p.price}',
              onTap: () {
                Navigator.of(sheetCtx).pop();
                openZyndioLink(context, p.url);
              },
            ),
            const SizedBox(height: 12),
            Text(
              p.isTest
                  ? 'Results are lab-processed. Share them with your care team.'
                  : 'Over-the-counter supplement, separate from your prescribed care. '
                      'Check with your care team before starting.',
              style: TextStyle(
                  fontFamily: ZyndioType.family,
                  fontSize: 12,
                  height: 17 / 12,
                  color: c.textTertiary),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Off in widget tests (no network or cache plugins there); the glyph tile
/// stands in, exactly as it does while an image loads or when offline.
@visibleForTesting
bool precisionNutritionNetworkImages = true;

/// The product's photo from zyndio.com on a soft tile, cached after the first
/// load. While loading, offline, or if the site moves the image, the
/// product's own glyph tile shows instead.
class NutritionProductImage extends StatelessWidget {
  const NutritionProductImage(
      {super.key, required this.product, required this.size, this.wide = false});

  final NutritionProduct product;
  final double size;

  /// Full-width banner (details sheet) instead of a square thumbnail.
  final bool wide;

  @override
  Widget build(BuildContext context) {
    // zyndio.com shows these photos on white, and the JPGs carry a white
    // background, so the tile stays white in both themes.
    final fallback = Center(
      child: ZyndioIconTile(
          glyph: product.glyph, tint: product.tint, size: wide ? 72 : size * 0.62),
    );
    return Semantics(
      image: true,
      label: '${product.name} product packaging',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(wide ? 20 : 18),
        child: Container(
          width: wide ? double.infinity : size,
          height: size,
          padding: EdgeInsets.all(wide ? 12 : 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(wide ? 20 : 18),
            border: Border.all(color: context.zc.borderSubtle),
          ),
          child: !precisionNutritionNetworkImages
              ? fallback
              : CachedNetworkImage(
                  imageUrl: product.imageUrl,
                  fit: BoxFit.contain,
                  fadeInDuration: const Duration(milliseconds: 200),
                  placeholder: (_, __) => fallback,
                  errorWidget: (_, __, ___) => fallback,
                ),
        ),
      ),
    );
  }
}
