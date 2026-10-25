import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../config/theme.dart';
import '../../../providers/shop_provider.dart';

class ShopProductCard extends ConsumerWidget {
  final ShopProduct product;
  final VoidCallback onTap;

  const ShopProductCard({
    super.key,
    required this.product,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final cartIndex = cart.indexWhere((item) => item.product.id == product.id);
    final quantity = cartIndex != -1 ? cart[cartIndex].quantity : 0;

    final hasDiscount = product.originalPrice != null &&
        product.originalPrice! > product.price;

    final discountAmount = hasDiscount
        ? (product.originalPrice! - product.price).round()
        : 0;

    final discountPercent = hasDiscount
        ? (((product.originalPrice! - product.price) / product.originalPrice!) *
                100)
            .round()
        : 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: context.nc.cardSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: context.nc.isDark
                ? context.nc.cardBorder
                : BrandColors.slate200.withValues(alpha: 0.7),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: context.nc.shadowColor,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Product Image (55% of card) ──
            Expanded(
              flex: 55,
              child: Stack(
                children: [
                  // Image
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      child: Container(
                        color: context.nc.isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : const Color(0xFFF8FAFB),
                        child: Image.network(
                          product.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Icon(
                              LucideIcons.packageOpen,
                              size: 32,
                              color: context.nc.textTertiary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Discount Badge — top left
                  if (hasDiscount)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: BrandColors.emerald500,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          discountPercent >= 10
                              ? '$discountPercent% OFF'
                              : '₹$discountAmount OFF',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),

                  // Wishlist Heart — top right (decorative)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: context.nc.isDark
                            ? Colors.black.withValues(alpha: 0.4)
                            : Colors.white.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Icon(
                        LucideIcons.heart,
                        size: 14,
                        color: context.nc.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Divider line ──
            Container(
              height: 0.5,
              color: context.nc.isDark
                  ? context.nc.divider
                  : BrandColors.slate200.withValues(alpha: 0.5),
            ),

            // ── Product Details (45% of card) ──
            Expanded(
              flex: 45,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title — max 2 lines
                    Text(
                      product.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.nc.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 2),

                    // Description — max 1 line
                    Text(
                      product.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.nc.textTertiary,
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),

                    const Spacer(),

                    // ── Price + ADD Row ──
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Price Section
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Current price — green badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: BrandColors.emerald500,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '₹${product.price.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              if (hasDiscount) ...[
                                const SizedBox(height: 2),
                                Text(
                                  '₹${product.originalPrice!.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    color: context.nc.textTertiary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w400,
                                    decoration: TextDecoration.lineThrough,
                                    decorationColor: context.nc.textTertiary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(width: 6),

                        // ADD Button / Quantity Counter
                        _AddToCartButton(
                          product: product,
                          quantity: quantity,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ADD BUTTON — Outlined Zepto-style with quantity counter
// ─────────────────────────────────────────────────────────────

class _AddToCartButton extends ConsumerWidget {
  final ShopProduct product;
  final int quantity;

  const _AddToCartButton({
    required this.product,
    required this.quantity,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: animation,
        child: child,
      ),
      child: quantity == 0
          ? _buildAddButton(context, ref)
          : _buildQuantityCounter(context, ref),
    );
  }

  Widget _buildAddButton(BuildContext context, WidgetRef ref) {
    return SizedBox(
      key: const ValueKey('add'),
      height: 32,
      child: OutlinedButton(
        onPressed: () {
          HapticFeedback.mediumImpact();
          ref.read(cartProvider.notifier).addToCart(product);
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: BrandColors.emerald500,
          side: const BorderSide(
            color: BrandColors.emerald500,
            width: 1.5,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: const Text(
          'ADD',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildQuantityCounter(BuildContext context, WidgetRef ref) {
    return Container(
      key: const ValueKey('counter'),
      height: 32,
      decoration: BoxDecoration(
        color: BrandColors.emerald500,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Minus
          _counterButton(
            icon: LucideIcons.minus,
            onTap: () {
              HapticFeedback.lightImpact();
              ref.read(cartProvider.notifier).removeFromCart(product);
            },
          ),

          // Quantity
          Container(
            constraints: const BoxConstraints(minWidth: 24),
            alignment: Alignment.center,
            child: Text(
              '$quantity',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),

          // Plus
          _counterButton(
            icon: LucideIcons.plus,
            onTap: () {
              HapticFeedback.lightImpact();
              ref.read(cartProvider.notifier).addToCart(product);
            },
          ),
        ],
      ),
    );
  }

  Widget _counterButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Icon(
          icon,
          size: 14,
          color: Colors.white,
        ),
      ),
    );
  }
}
