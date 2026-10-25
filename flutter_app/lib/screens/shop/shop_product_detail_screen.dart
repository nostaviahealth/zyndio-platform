import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../providers/shop_provider.dart';
import '../../../config/theme.dart';
import 'shop_cart_sheet.dart';

class ShopProductDetailScreen extends ConsumerStatefulWidget {
  final String productId;

  const ShopProductDetailScreen({
    super.key,
    required this.productId,
  });

  @override
  ConsumerState<ShopProductDetailScreen> createState() =>
      _ShopProductDetailScreenState();
}

class _ShopProductDetailScreenState
    extends ConsumerState<ShopProductDetailScreen> {
  // Page states
  int _currentImageIndex = 0;
  String _selectedSize = '30ml';
  bool _descExpanded = true;
  bool _ingredientsExpanded = false;
  bool _howToUseExpanded = false;
  bool _returnExpanded = false;

  // Premium Luxury Dark-Themed Color System (Matched exactly with Shop module)
  static const Color _bgDark = Color(0xFF2C3039);
  static const Color _bgDarker = Color(0xFF1F2228);
  static const Color _borderDark = Color(0xFF3A3F4A);
  static const Color _textWhite = Colors.white;
  static const Color _textMuted = Color(0xFFA0A5AE);
  static const Color _textGrey = Color(0xFF7A7F88);

  static const Color _goldAccent = Color(0xFFD4A857);
  static const Color _goldAccentDark = Color(0xFFB38634);
  static const Color _goldAccentGlow = Color(0xFFF7C973);

  // Accent pointers mapped to the premium gold brand color palette
  static const Color _emerald = _goldAccent;
  static const Color _emeraldDark = _goldAccentDark;
  static const Color _emeraldGlow = _goldAccentGlow;

  // Mock list of additional carousel images
  final List<String> _carouselImages = [
    'https://images.unsplash.com/photo-1556228578-0d85b1a4d571?w=800&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1563729784474-d77dbb933a9e?w=800&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1611930022073-b7a4ba5fcccd?w=800&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1599643478518-a784e5dc4c8f?w=800&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1608248597279-f99d160bfcbc?w=800&auto=format&fit=crop&q=80',
  ];

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(shopProductsActiveDefaultProvider);
    final cart = ref.watch(cartProvider);
    final cartTotalItems = ref.watch(cartTotalItemsProvider);

    final product = products.firstWhere(
      (p) => p.id == widget.productId,
      orElse: () => products.first,
    );

    final cartIndex = cart.indexWhere((item) => item.product.id == product.id);
    final quantity = cartIndex != -1 ? cart[cartIndex].quantity : 0;

    // Prices matching selected size
    final double basePrice = product.price;
    final double originalPrice = product.originalPrice ?? (product.price * 1.2);
    final double activePrice = _selectedSize == '30ml' ? basePrice : basePrice * 1.8;
    final double activeOriginalPrice = _selectedSize == '30ml' ? originalPrice : originalPrice * 1.8;

    final hasDiscount = product.originalPrice != null;
    final discountPercent = (((activeOriginalPrice - activePrice) / activeOriginalPrice) * 100).round();

    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Theme(
      data: BrandTheme.darkTheme,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        child: Scaffold(
          backgroundColor: _bgDark,
          body: Column(
            children: [
              // ─── COMPACT APP BAR (Matches EXACT Nykaa Man Header) ───
              _buildAppBar(context, cartTotalItems),

              // ─── SCROLLABLE CONTENT ───
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. PRODUCT IMAGE CAROUSEL (Horizontal scroll + indicators + view similar)
                      _buildImageCarousel(product),

                      const SizedBox(height: 16),

                      // 2. PRODUCT INFO (Brand, Title, Ratings Tag, Bestseller Row, Elegant Price)
                      _buildMainProductInfo(product, activePrice, activeOriginalPrice, discountPercent, hasDiscount),

                      // 3. SELECT SIZE
                      _buildSizeSelector(activePrice),

                      // 4. COLLECT MULTIPLE COUPONS (Premium Horizontally scrolling cards)
                      _buildCouponSection(),

                      // 5. CHECK DELIVERY DATE
                      _buildDeliveryChecker(),

                      // 6. TRUST BADGES ROW (100% Authentic, Easy Returns)
                      _buildTrustBadges(),

                      // 7. TOP SELLING COMBOS (Luxury styled bundle)
                      _buildCombosSection(),

                      // Highlights Section
                      _buildHighlightsSection(),

                      // 8. ACCORDIONS: KNOW YOUR PRODUCT
                      _buildKnowYourProduct(product),

                      // 9. SOLD BY
                      _buildSoldBySection(),

                      // 10. RATINGS & REVIEWS (Full metrics breakdown, photo review & user review card)
                      _buildRatingsReviews(),

                      // 11. CUSTOMERS ALSO VIEWED
                      _buildCustomersAlsoViewed(products),

                      // More from Zyndio (Brand)
                      _buildMoreFromBrand(products),

                      // Recently Viewed
                      _buildRecentlyViewed(products),

                      // Bottom spacing for sticky bar
                      SizedBox(height: 80 + bottomPadding + 16),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ─── STICKY BOTTOM BAR (Matches Nykaa Bottom checkout row) ───
          bottomNavigationBar: _buildStickyBottom(product, quantity, cartTotalItems),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 1. COMPACT APP BAR
  // ═══════════════════════════════════════════════════════════

  Widget _buildAppBar(BuildContext context, int cartTotalItems) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.only(top: topPadding),
      color: _bgDarker,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: _bgDarker,
          border: Border(
            bottom: BorderSide(
              color: Colors.white.withOpacity(0.06),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: () => context.pop(),
              icon: const Icon(LucideIcons.arrowLeft, color: _textWhite, size: 22),
            ),
            const SizedBox(width: 4),
            const Text(
              'ZYNDIO LUXE',
              style: TextStyle(
                color: _textWhite,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: () => context.push('/shop?tab=search'),
              icon: const Icon(LucideIcons.search, color: _textWhite, size: 20),
            ),
            IconButton(
              onPressed: () => context.push('/shop?tab=wishlist'),
              icon: const Icon(LucideIcons.heart, color: _textWhite, size: 20),
            ),
            GestureDetector(
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (ctx) => const ShopCartSheet(),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(right: 12, left: 4),
                width: 32,
                height: 32,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(LucideIcons.shoppingBag, color: _textWhite, size: 20),
                    if (cartTotalItems > 0)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: const BoxDecoration(
                            color: _emerald,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '$cartTotalItems',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
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

  // ═══════════════════════════════════════════════════════════
  // 2. IMAGE CAROUSEL SECTION
  // ═══════════════════════════════════════════════════════════

  Widget _buildImageCarousel(ShopProduct product) {
    // Collect all images (main + details)
    final images = [product.imageUrl, ..._carouselImages];

    return AspectRatio(
      aspectRatio: 1.0, // Standard professional 1:1 square aspect ratio matching Shopify APIs
      child: Container(
        color: _bgDarker,
        width: double.infinity,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            PageView.builder(
              onPageChanged: (index) => setState(() => _currentImageIndex = index),
              itemCount: images.length,
              itemBuilder: (context, index) {
                return Image.network(
                  images[index],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(
                      LucideIcons.image,
                      size: 64,
                      color: _textGrey,
                    ),
                  ),
                );
              },
            ),
            // Carousel dot indicators
            Positioned(
              bottom: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  images.length,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentImageIndex == index
                          ? _emeraldGlow
                          : Colors.white.withOpacity(0.25),
                    ),
                  ),
                ),
              ),
            ),
          // Floating "View similar" badge
          Positioned(
            bottom: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: const Row(
                children: [
                  Icon(LucideIcons.layers, color: Colors.white, size: 12),
                  SizedBox(width: 4),
                  Text(
                    'View similar',
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
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

  // ═══════════════════════════════════════════════════════════
  // 3. MAIN PRODUCT INFO SECTION
  // ═══════════════════════════════════════════════════════════

  Widget _buildMainProductInfo(ShopProduct product, double activePrice, double activeOriginalPrice, int discountPercent, bool hasDiscount) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brand Title
          const Text(
            'Zyndio Biotech Labs',
            style: TextStyle(
              color: _emeraldGlow,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),

          // Title
          Text(
            product.title,
            style: const TextStyle(
              color: _textWhite,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),

          // Ratings Badge Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star, color: _goldAccent, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      '${product.longevityScore}/10',
                      style: const TextStyle(color: _textWhite, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '  (162.2K Ratings) >',
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Best Seller Badge Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: _emerald.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '#1 BESTSELLER',
                  style: TextStyle(color: _emeraldGlow, fontSize: 9, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Clinical Diagnostics',
                style: TextStyle(color: _textMuted, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              const Text(
                'See Top 20 >',
                style: TextStyle(color: _emeraldGlow, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Price Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '₹${activePrice.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: _textWhite,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (hasDiscount) ...[
                const SizedBox(width: 10),
                Text(
                  '₹${activeOriginalPrice.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: _textGrey,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '$discountPercent% OFF',
                  style: const TextStyle(
                    color: _emeraldGlow,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 3),
          const Text(
            'Inclusive of all biotechnology taxes & duties',
            style: TextStyle(color: _textGrey, fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 4. SIZE SELECTOR
  // ═══════════════════════════════════════════════════════════

  Widget _buildSizeSelector(double activePrice) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select size',
            style: TextStyle(color: _textWhite, fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _sizeCard('30ml', activePrice),
              const SizedBox(width: 12),
              _sizeCard('60ml', activePrice * 1.8),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sizeCard(String size, double price) {
    final isSelected = _selectedSize == size;
    return GestureDetector(
      onTap: () => setState(() => _selectedSize = size),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _emerald.withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? _emeraldGlow : Colors.white.withOpacity(0.12),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Text(
              size,
              style: TextStyle(
                color: isSelected ? _textWhite : _textMuted,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '₹${price.toStringAsFixed(0)}',
              style: TextStyle(
                color: isSelected ? _emeraldGlow : _textGrey,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 5. COUPON SECTION
  // ═══════════════════════════════════════════════════════════

  Widget _buildCouponSection() {
    return Container(
      color: _bgDarker,
      padding: const EdgeInsets.symmetric(vertical: 20),
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Collect Multiple Coupons',
              style: TextStyle(color: _textWhite, fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _bulletPoint('Now, avail multiple coupon discounts in a single order'),
                _bulletPoint('Collected coupons will be auto-applied to bag'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Sub heading
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 14,
                  color: _emeraldGlow,
                ),
                const SizedBox(width: 6),
                const Text(
                  'APPLY ANY "ONE" OF THESE',
                  style: TextStyle(color: _textWhite, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Horizontal scrolling list of Coupons
          SizedBox(
            height: 104,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _couponCard('Flat 150 Off', 'On your 1st order from app...', 'NMAN150', 'Shop for ₹1000 more'),
                const SizedBox(width: 12),
                _couponCard('Flat 400 Off', 'On premium clinical wear...', 'NMAN400', 'Shop for ₹2500 more'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: _emeraldGlow, fontSize: 12, fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: _textMuted, fontSize: 12, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _couponCard(String title, String desc, String code, String action) {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: _bgDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: _textWhite, fontSize: 13, fontWeight: FontWeight.w800),
                ),
                Text(
                  desc,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Dashed Divider
          Container(
            height: 1,
            color: Colors.white.withOpacity(0.08),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  code,
                  style: const TextStyle(color: _textMuted, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                Text(
                  '$action >',
                  style: const TextStyle(color: _emeraldGlow, fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 6. DELIVERY checker
  // ═══════════════════════════════════════════════════════════

  Widget _buildDeliveryChecker() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Check delivery date',
            style: TextStyle(color: _textWhite, fontSize: 14, fontWeight: FontWeight.w700),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: const Text(
              'Enter Pincode',
              style: TextStyle(color: _emeraldGlow, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 7. TRUST BADGES
  // ═══════════════════════════════════════════════════════════

  Widget _buildTrustBadges() {
    return Container(
      color: _bgDarker,
      padding: const EdgeInsets.symmetric(vertical: 14),
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      child: Row(
        children: [
          Expanded(child: _trustBadge(LucideIcons.shieldCheck, '100% Authentic')),
          Container(width: 0.5, height: 24, color: Colors.white.withOpacity(0.1)),
          Expanded(child: _trustBadge(LucideIcons.refreshCw, 'Easy return policy')),
        ],
      ),
    );
  }

  Widget _trustBadge(IconData icon, String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: _emeraldGlow, size: 16),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(color: _textWhite, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 8. COMBOS SECTION
  // ═══════════════════════════════════════════════════════════

  Widget _buildCombosSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top Selling Combos',
            style: TextStyle(color: _textWhite, fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          // Combo card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _bgDarker,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bundle thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    'https://images.unsplash.com/photo-1556228578-0d85b1a4d571?w=150&auto=format&fit=crop&q=80',
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 14),
                // Combo details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'BESTSELLER',
                        style: TextStyle(color: _emeraldGlow, fontSize: 9, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Cell-Boost Duo: NMN Platinum + Bio-Soma Trans-Resveratrol',
                        style: TextStyle(
                          color: _textWhite,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Rating
                      Row(
                        children: [
                          const Icon(Icons.star, color: _goldAccent, size: 12),
                          const SizedBox(width: 3),
                          Text(
                            '4.8/5  (1,65,935)',
                            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '₹1,875',
                        style: TextStyle(color: _textWhite, fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Show more button
          const Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Show More ',
                  style: TextStyle(color: _emeraldGlow, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Icon(LucideIcons.chevronDown, color: _emeraldGlow, size: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 9. ACCORDIONS: KNOW YOUR PRODUCT
  // ═══════════════════════════════════════════════════════════

  Widget _buildKnowYourProduct(ShopProduct product) {
    return Container(
      color: _bgDarker,
      padding: const EdgeInsets.symmetric(vertical: 20),
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Know Your Product',
              style: TextStyle(color: _textWhite, fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 12),
          _buildAccordion(
            title: 'Description',
            icon: LucideIcons.fileText,
            isExpanded: _descExpanded,
            onToggle: () => setState(() => _descExpanded = !_descExpanded),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(color: _textMuted, fontSize: 13, height: 1.5),
                    children: [
                      const TextSpan(
                        text: 'Description : ',
                        style: TextStyle(color: _textWhite, fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: product.description),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Note: Pairs wonderfully with cellular diagnostic monitors to actively trace biomarkers before & after supplementation.',
                  style: TextStyle(color: _textGrey, fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          _buildAccordion(
            title: 'Ingredients',
            icon: LucideIcons.leaf,
            isExpanded: _ingredientsExpanded,
            onToggle: () => setState(() => _ingredientsExpanded = !_ingredientsExpanded),
            child: const Text(
              '99.8% pure biotech extract, free of synthetics, heavy metals, gluten, soy, and dairy. Non-GMO active ingredients only.',
              style: TextStyle(color: _textMuted, fontSize: 13, height: 1.5),
            ),
          ),
          _buildAccordion(
            title: 'How to Use',
            icon: LucideIcons.helpCircle,
            isExpanded: _howToUseExpanded,
            onToggle: () => setState(() => _howToUseExpanded = !_howToUseExpanded),
            child: const Text(
              'Take 1 or 2 capsules in the morning before food, paired with clinical diagnostic tests for absolute tracking precision.',
              style: TextStyle(color: _textMuted, fontSize: 13, height: 1.5),
            ),
          ),
          _buildAccordion(
            title: 'Easy Return Policy',
            icon: LucideIcons.refreshCw,
            isExpanded: _returnExpanded,
            onToggle: () => setState(() => _returnExpanded = !_returnExpanded),
            child: const Text(
              'Enjoy a complete 15-day return policy on unopened items, processed automatically via your biotech clinical concierge.',
              style: TextStyle(color: _textMuted, fontSize: 13, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccordion({
    required String title,
    required IconData icon,
    required bool isExpanded,
    required VoidCallback onToggle,
    required Widget child,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onToggle,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: _textMuted, size: 16),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(color: _textWhite, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(LucideIcons.chevronDown, color: _textGrey, size: 18),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: child,
          ),
          secondChild: const SizedBox.shrink(),
          crossFadeState: isExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          duration: const Duration(milliseconds: 200),
        ),
        Divider(height: 1, color: Colors.white.withOpacity(0.04)),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 10. SOLD BY
  // ═══════════════════════════════════════════════════════════

  Widget _buildSoldBySection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(
        'Sold by : Zyndio Biotech Lab, Inc.',
        style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 11. RATINGS & REVIEWS
  // ═══════════════════════════════════════════════════════════

  Widget _buildRatingsReviews() {
    return Container(
      color: _bgDarker,
      padding: const EdgeInsets.symmetric(vertical: 20),
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Ratings & Reviews',
              style: TextStyle(color: _textWhite, fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 14),

          // Rating layout
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text(
                  '4.4',
                  style: TextStyle(color: _textWhite, fontSize: 36, fontWeight: FontWeight.w900),
                ),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Overall rating',
                      style: TextStyle(color: _textWhite, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '1,62,207 verified ratings',
                      style: TextStyle(color: _textGrey, fontSize: 11),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white.withOpacity(0.12)),
                  ),
                  child: const Text(
                    'Rate',
                    style: TextStyle(color: _emeraldGlow, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Users images review gallery
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 5,
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.only(right: 10),
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      _carouselImages[index % _carouselImages.length],
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          // Most Useful Reviews List
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Most Useful Reviews',
                  style: TextStyle(color: _textWhite, fontSize: 13, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                
                // Review 1
                _buildReviewItem(
                  userName: 'Humairah Warsi',
                  date: '28/08/2025',
                  rating: 5,
                  title: 'Indeed Effective!',
                  comment: 'This is my first-ever review, and I am writing it because this product genuinely healed my breakouts, acne marks, and pustules. I initially used this serum with Neutrogena\'s Water Gel moisturizer. After finishing the...',
                  helpfulCount: 22,
                ),
                
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Divider(color: Colors.white10, height: 1),
                ),

                // Review 2
                _buildReviewItem(
                  userName: 'Karan Sharma',
                  date: '14/09/2025',
                  rating: 4,
                  title: 'Amazing results in 2 weeks',
                  comment: 'I was highly skeptical about changing my skincare routine, but Zyndio\'s clinical serum did wonders for my skin texture. It feels extremely light, absorbs in seconds, and has zero artificial fragrance. Extremely premium packaging too!',
                  helpfulCount: 15,
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Divider(color: Colors.white10, height: 1),
                ),

                // Review 3
                _buildReviewItem(
                  userName: 'Priya Patel',
                  date: '02/10/2025',
                  rating: 5,
                  title: 'Absolute holy grail!',
                  comment: 'My dry skin absolutely loves this! It feels so soothing, hydrating and premium. Waking up with a glowing, calm face has become the norm since I started using this. It really is worth every single penny.',
                  helpfulCount: 38,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewItem({
    required String userName,
    required String date,
    required int rating,
    required String title,
    required String comment,
    required int helpfulCount,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white.withOpacity(0.08),
              child: Text(
                userName.substring(0, 1),
                style: const TextStyle(color: _emeraldGlow, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  style: const TextStyle(color: _textWhite, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    const Icon(LucideIcons.checkCircle, color: _emeraldGlow, size: 10),
                    const SizedBox(width: 4),
                    Text(
                      'Verified Buyer  •  $date',
                      style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Star count badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: _emeraldDark,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$rating ', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              const Icon(Icons.star, color: Colors.white, size: 10),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Comment Title
        Text(
          title,
          style: const TextStyle(color: _textWhite, fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        // Comment text
        Text(
          comment,
          style: const TextStyle(color: _textMuted, fontSize: 12, height: 1.45),
        ),
        const SizedBox(height: 12),
        Text(
          '$helpfulCount people found this helpful',
          style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 12. CUSTOMERS ALSO VIEWED
  // ═══════════════════════════════════════════════════════════

  Widget _buildCustomersAlsoViewed(List<ShopProduct> products) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Customers Also Viewed',
                  style: TextStyle(color: _textWhite, fontSize: 15, fontWeight: FontWeight.w800),
                ),
                GestureDetector(
                  onTap: () => context.push('/shop'),
                  child: const Text(
                    'View all',
                    style: TextStyle(color: _emeraldGlow, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 310,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final prod = products[index];
                return _buildViewedCard(prod);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewedCard(ShopProduct product) {
    final originalPrice = product.originalPrice ?? (product.price * 1.25);
    final discountPercent = (((originalPrice - product.price) / originalPrice) * 100).round();

    return Container(
      width: 155, // Exact premium Nykaa Man card width
      margin: const EdgeInsets.only(right: 14),
      decoration: BoxDecoration(
        color: _bgDarker,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1:1 AspectRatio Image Stack
          AspectRatio(
            aspectRatio: 1.0,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  child: Container(
                    color: const Color(0xFF2A2D35),
                    width: double.infinity,
                    height: double.infinity,
                    child: Image.network(product.imageUrl, fit: BoxFit.cover),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9800).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Text(
                      'OFFER',
                      style: TextStyle(
                        color: Color(0xFFFF9800),
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Clean standard Product Info block
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _textWhite,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '1 Size',
                    style: TextStyle(color: _textGrey, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  
                  // Price row: real price + original price + discount % in green
                  Row(
                    children: [
                      Text(
                        '₹${product.price.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: _textWhite,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '₹${originalPrice.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: _textGrey,
                          fontSize: 9,
                          decoration: TextDecoration.lineThrough,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$discountPercent%',
                        style: const TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  
                  // Star Rating Row
                  Row(
                    children: [
                      ...List.generate(5, (starIndex) {
                        return Icon(
                          starIndex < 4 ? Icons.star : Icons.star_border,
                          color: _goldAccent,
                          size: 9,
                        );
                      }),
                      const SizedBox(width: 4),
                      Text(
                        '4.3/5 (${(product.longevityScore * 7).round()})',
                        style: const TextStyle(
                          color: _textGrey,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  
                  // Action buttons row: Heart button + Deep teal Select Size button
                  Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.white.withOpacity(0.08)),
                        ),
                        child: const Icon(LucideIcons.heart, color: _textGrey, size: 12),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Container(
                          height: 26,
                          decoration: BoxDecoration(
                            color: const Color(0xFF003243), // Deep Nykaa Man Teal
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Center(
                            child: Text(
                              'Select Size',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // NEW SECTIONS: HIGHLIGHTS & HORIZONTAL MERCH LISTS
  // ═══════════════════════════════════════════════════════════

  Widget _buildHighlightsSection() {
    return Container(
      color: _bgDarker,
      padding: const EdgeInsets.symmetric(vertical: 20),
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Highlights',
              style: TextStyle(color: _textWhite, fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHighlightItem('Closure', 'Lace-Ups'),
                      _buildHighlightItem('Sole Material', 'Rubber'),
                      _buildHighlightItem('Season', 'Spring/Summer 2026'),
                      _buildHighlightItem('Activity', 'Running'),
                      _buildHighlightItem('Net Qty', '1N'),
                      _buildHighlightItem('Color', 'Grey'),
                    ],
                  ),
                ),
                
                // Vertical Divider
                Container(
                  height: 280,
                  width: 1,
                  color: Colors.white.withOpacity(0.08),
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                ),
                
                // Right Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHighlightItem('Fabric', 'Mesh'),
                      _buildHighlightItem('Toe Shape', 'Round Toe'),
                      _buildHighlightItem('Gender', 'Men'),
                      _buildHighlightItem('Outsole Type', 'Non-Marking'),
                      _buildHighlightItem('Size', 'UK 6, UK 7, UK 8'),
                      _buildHighlightItem('Filter Size', 'Single'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: _textGrey, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(color: _textWhite, fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildMoreFromBrand(List<ShopProduct> products) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'More from Zyndio',
                  style: TextStyle(color: _textWhite, fontSize: 15, fontWeight: FontWeight.w800),
                ),
                GestureDetector(
                  onTap: () => context.push('/shop'),
                  child: const Text(
                    'View all',
                    style: TextStyle(color: _emeraldGlow, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 310,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final prod = products[(index + 1) % products.length];
                return _buildViewedCard(prod);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentlyViewed(List<ShopProduct> products) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recently Viewed',
                  style: TextStyle(color: _textWhite, fontSize: 15, fontWeight: FontWeight.w800),
                ),
                GestureDetector(
                  onTap: () => context.push('/shop'),
                  child: const Text(
                    'View all',
                    style: TextStyle(color: _emeraldGlow, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 310,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final prod = products[(index + 3) % products.length];
                return _buildViewedCard(prod);
              },
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 13. STICKY BOTTOM BAR
  // ═══════════════════════════════════════════════════════════

  Widget _buildStickyBottom(ShopProduct product, int quantity, int cartTotalItems) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPadding + 12),
      decoration: BoxDecoration(
        color: _bgDarker,
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.06), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Wishlist Icon Box
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              // Toggle wishlist logic
            },
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _bgDark,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: const Center(
                child: Icon(
                  LucideIcons.heart,
                  color: _textWhite,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Add to Bag / Stepper Button
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: quantity == 0
                  ? GestureDetector(
                      key: const ValueKey('add'),
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        ref.read(cartProvider.notifier).addToCart(product);
                      },
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_emerald, _emeraldDark],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: _emerald.withOpacity(0.24),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.shoppingBag, color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Add to Bag',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Container(
                      key: const ValueKey('counter'),
                      height: 48,
                      decoration: BoxDecoration(
                        color: _bgDark,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: const BorderRadius.horizontal(
                                left: Radius.circular(10),
                              ),
                              onTap: () {
                                HapticFeedback.lightImpact();
                                ref.read(cartProvider.notifier).removeFromCart(product);
                              },
                              child: SizedBox(
                                width: 56,
                                height: 48,
                                child: Icon(
                                  LucideIcons.minus,
                                  color: Colors.white.withOpacity(0.6),
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                          Text(
                            '$quantity',
                            style: const TextStyle(
                              color: _emeraldGlow,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: const BorderRadius.horizontal(
                                right: Radius.circular(10),
                              ),
                              onTap: () {
                                HapticFeedback.lightImpact();
                                ref.read(cartProvider.notifier).addToCart(product);
                              },
                              child: SizedBox(
                                width: 56,
                                height: 48,
                                child: Icon(
                                  LucideIcons.plus,
                                  color: Colors.white.withOpacity(0.6),
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
