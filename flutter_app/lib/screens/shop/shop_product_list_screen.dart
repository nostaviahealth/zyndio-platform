import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../config/theme.dart';
import '../../../providers/shop_provider.dart';
import 'shop_cart_sheet.dart';

class ShopProductListScreen extends ConsumerStatefulWidget {
  final String category;

  const ShopProductListScreen({
    super.key,
    required this.category,
  });

  @override
  ConsumerState<ShopProductListScreen> createState() =>
      _ShopProductListScreenState();
}

class _ShopProductListScreenState extends ConsumerState<ShopProductListScreen> {
  // Filtering & Sorting states
  String _searchQuery = '';
  String _selectedSort = 'Popularity';
  
  // Selected Filter Dimensions
  final Set<String> _selectedSizes = {};
  final Set<String> _selectedBrands = {};
  final Set<String> _selectedCategories = {};
  final Set<String> _selectedColors = {};
  
  bool _onlyOnOffer = false;
  bool _onlyPriceDrop = false;
  bool _onlyNew = false;

  // Active Category clicked at top/tabs
  late String _activeCategory;

  // Pre-defined multi-faceted options
  final List<String> _allSizes = ['32', '34', '36', '38', '39', '40', '42', '44', '46', 'Free Size', 'XS', 'S', 'M', 'L', 'XL'];
  final List<String> _allBrands = [
    'Rare Rabbit', 'Snitch', 'American Eagle', 'Arrow', 'The Indian Garage Co', 
    'Levi\'s', 'Puma', 'Allen Solly', 'Weezy', 'WROGN', 'Dot & Key', 'Plum', 
    'Cetaphil', 'Bioderma', 'The Derma Co', 'CeraVe', 'Forest Essentials', 
    'Tom Ford', 'ALDO', 'CLINIQUE', 'BVLGARI'
  ];
  final List<String> _allCategories = [
    'Supplements', 'Diagnostics', 'Wearables', 'Skin Care', 'Hair Care', 
    'Fragrance', 'Grooming', 'Luxe', 'Clinical', 'Fashion & Lifestyle', 'Fashion'
  ];
  final List<String> _allColors = ['Black', 'White', 'Beige', 'Blue', 'Green', 'Grey', 'Red', 'Orange', 'Yellow'];

  // Helper lists for inline display
  final List<String> _quickBrands = ['Rare Rabbit', 'Snitch', 'American Eagle', 'Arrow', 'The Indian Garage Co', 'Levi\'s', 'Puma'];

  @override
  void initState() {
    super.initState();
    final cat = widget.category.trim();
    final lowerCat = cat.toLowerCase();

    // Check if it is a brand name
    final matchedBrand = _allBrands.firstWhere(
      (b) => b.toLowerCase() == lowerCat,
      orElse: () => '',
    );

    if (matchedBrand.isNotEmpty) {
      _selectedBrands.add(matchedBrand);
      _activeCategory = 'All';
    } else {
      // Check if it is a category
      final matchedCategory = _allCategories.firstWhere(
        (c) => c.toLowerCase() == lowerCat || 
               c.toLowerCase().replaceAll(' ', '') == lowerCat.replaceAll(' ', ''),
        orElse: () => '',
      );
      
      if (matchedCategory.isNotEmpty) {
        _activeCategory = matchedCategory;
      } else {
        _activeCategory = 'All';
        
        // Custom lookups for promos, activities, and outfits
        if (lowerCat.contains('wedding') || 
            lowerCat.contains('work') || 
            lowerCat.contains('sporty') || 
            lowerCat.contains('casual') || 
            lowerCat.contains('winter')) {
          _searchQuery = cat.replaceAll('Sale', '').replaceAll('Fits', '').replaceAll('Training', '').replaceAll('Outings', '').replaceAll('Elegance', '').trim();
        } else if (lowerCat.contains('running') || 
                   lowerCat.contains('sportswear') || 
                   lowerCat.contains('training') || 
                   lowerCat.contains('outdoor')) {
          _searchQuery = cat;
        } else if (lowerCat.contains('fresh') || 
                   lowerCat.contains('summer') || 
                   lowerCat.contains('nighttime') || 
                   lowerCat.contains('metabolic')) {
          _searchQuery = cat.split(' ')[0];
        } else {
          _activeCategory = widget.category;
        }
      }
    }
  }

  // Get total applied filters count
  int get _appliedFiltersCount {
    int count = 0;
    count += _selectedSizes.length;
    count += _selectedBrands.length;
    count += _selectedCategories.length;
    count += _selectedColors.length;
    if (_onlyOnOffer) count++;
    if (_onlyPriceDrop) count++;
    if (_onlyNew) count++;
    return count;
  }

  void _resetAllFilters() {
    setState(() {
      _selectedSizes.clear();
      _selectedBrands.clear();
      _selectedCategories.clear();
      _selectedColors.clear();
      _onlyOnOffer = false;
      _onlyPriceDrop = false;
      _onlyNew = false;
    });
  }

  // Sorting and Filtering logic applied to Mock Products
  List<ShopProduct> _getProcessedProducts(List<ShopProduct> products) {
    // 1. Filter by category parameter & dynamic category tab selection
    List<ShopProduct> result = products.where((prod) {
      final active = _activeCategory.toLowerCase().replaceAll(' ', '');
      if (active != 'all' && active != 'fashion&lifestyle') {
        final prodCat = prod.category.toLowerCase().replaceAll(' ', '');
        if (active == 'clinical') return prodCat == 'diagnostics';
        if (active == 'health&wellness') return prodCat == 'supplements';
        return prodCat.contains(active) || active.contains(prodCat);
      }
      return true;
    }).toList();

    // 2. Multi-faceted filter selections
    if (_selectedSizes.isNotEmpty) {
      // In a real e-commerce setup, products have sizes. Let's mock match or match details containing sizes
      result = result.where((prod) {
        return prod.details.any((d) => _selectedSizes.any((size) => d.contains(size)));
      }).toList();
    }

    if (_selectedBrands.isNotEmpty) {
      result = result.where((prod) {
        return _selectedBrands.any((brand) => prod.title.toLowerCase().contains(brand.toLowerCase()) || 
                                              prod.description.toLowerCase().contains(brand.toLowerCase()));
      }).toList();
    }

    if (_selectedCategories.isNotEmpty) {
      result = result.where((prod) {
        return _selectedCategories.any((cat) => prod.category.toLowerCase() == cat.toLowerCase());
      }).toList();
    }

    // 3. Search query
    if (_searchQuery.isNotEmpty) {
      result = result.where((prod) {
        return prod.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               prod.description.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // 4. Quick Badge Offer filters
    if (_onlyOnOffer) {
      result = result.where((prod) => prod.originalPrice != null && prod.originalPrice! > prod.price).toList();
    }
    if (_onlyPriceDrop) {
      // Products with a drop of more than $10
      result = result.where((prod) => prod.originalPrice != null && (prod.originalPrice! - prod.price) > 10).toList();
    }
    if (_onlyNew) {
      result = result.where((prod) => prod.longevityScore > 9.0).toList();
    }

    // 5. Apply Sorting
    if (_selectedSort == 'Price: Low to High') {
      result.sort((a, b) => a.price.compareTo(b.price));
    } else if (_selectedSort == 'Price: High to Low') {
      result.sort((a, b) => b.price.compareTo(a.price));
    } else if (_selectedSort == 'Discount: High to Low') {
      result.sort((a, b) {
        final discA = a.originalPrice != null ? (a.originalPrice! - a.price) / a.originalPrice! : 0.0;
        final discB = b.originalPrice != null ? (b.originalPrice! - b.price) / b.originalPrice! : 0.0;
        return discB.compareTo(discA);
      });
    } else if (_selectedSort == 'Customer Top Rated') {
      result.sort((a, b) => b.longevityScore.compareTo(a.longevityScore));
    } else if (_selectedSort == 'New Arrivals') {
      result.sort((a, b) => b.id.compareTo(a.id));
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(shopProductsActiveProvider(_searchQuery.isNotEmpty ? _searchQuery : null));
    final totalCartItems = ref.watch(cartTotalItemsProvider);
    final processed = _getProcessedProducts(products);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: context.nc.isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: context.nc.isDark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: context.nc.isDark ? context.nc.scaffoldBg : Colors.white,
        
        // ── APP BAR matching Nykaa Man Luxe ──
        appBar: AppBar(
          backgroundColor: context.nc.isDark ? const Color(0xFF0F172A) : Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0.5,
          leading: IconButton(
            icon: Icon(LucideIcons.arrowLeft, color: context.nc.textPrimary, size: 22),
            onPressed: () => context.pop(),
          ),
          titleSpacing: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _activeCategory.toUpperCase() == 'ALL' ? 'FASHION & LIFESTYLE' : _activeCategory,
                style: TextStyle(
                  color: context.nc.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${processed.length} products',
                style: TextStyle(
                  color: context.nc.textTertiary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(LucideIcons.search, color: context.nc.textPrimary, size: 20),
              onPressed: () => _showSearchDialog(context),
            ),
            IconButton(
              icon: Icon(LucideIcons.heart, color: context.nc.textPrimary, size: 20),
              onPressed: () {},
            ),
            GestureDetector(
              onTap: () {
                if (totalCartItems > 0) {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    isScrollControlled: true,
                    builder: (ctx) => const ShopCartSheet(),
                  );
                }
              },
              child: Padding(
                padding: const EdgeInsets.only(right: 16, left: 8),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(LucideIcons.shoppingBag, color: context.nc.textPrimary, size: 21),
                    if (totalCartItems > 0)
                      Positioned(
                        top: 2,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 14,
                            minHeight: 14,
                          ),
                          child: Text(
                            '$totalCartItems',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),

        body: Stack(
          children: [
            Column(
              children: [
                // ── QUICK CHIPS ROW ──
                _buildQuickChipsRow(),

                // ── PRODUCT LIST & GRID ──
                Expanded(
                  child: processed.isEmpty
                      ? _buildEmptyState()
                      : CustomScrollView(
                          physics: const BouncingScrollPhysics(),
                          slivers: [
                            if (processed.length <= 4) ...[
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(10, 10, 10, 80),
                                sliver: SliverGrid(
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    childAspectRatio: 0.54,
                                    mainAxisSpacing: 10,
                                    crossAxisSpacing: 10,
                                  ),
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      return _buildPremiumCard(processed[index]);
                                    },
                                    childCount: processed.length,
                                  ),
                                ),
                              ),
                            ] else ...[
                              // First 4 items (2 rows)
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                                sliver: SliverGrid(
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    childAspectRatio: 0.54,
                                    mainAxisSpacing: 10,
                                    crossAxisSpacing: 10,
                                  ),
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      return _buildPremiumCard(processed[index]);
                                    },
                                    childCount: 4,
                                  ),
                                ),
                              ),
                              
                              // Inline Brand Row
                              SliverPadding(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                sliver: SliverToBoxAdapter(
                                  child: _buildInlineBrandRow(),
                                ),
                              ),

                              // Remaining items
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(10, 0, 10, 80),
                                sliver: SliverGrid(
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    childAspectRatio: 0.54,
                                    mainAxisSpacing: 10,
                                    crossAxisSpacing: 10,
                                  ),
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      return _buildPremiumCard(processed[index + 4]);
                                    },
                                    childCount: processed.length - 4,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
              ],
            ),

            // ── STICKY BOTTOM BAR (Sort & Filter) ──
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildStickyBottomBar(context),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // WIDGET BUILDERS
  // ─────────────────────────────────────────────────────────────

  Widget _buildQuickChipsRow() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: context.nc.isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(bottom: BorderSide(color: context.nc.divider, width: 0.5)),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          // On Offer Chip
          _buildQuickChip(
            label: 'On Offer',
            isSelected: _onlyOnOffer,
            icon: LucideIcons.tag,
            onTap: () => setState(() => _onlyOnOffer = !_onlyOnOffer),
          ),
          const SizedBox(width: 8),
          // Price Drop Chip
          _buildQuickChip(
            label: 'Price Drop',
            isSelected: _onlyPriceDrop,
            icon: LucideIcons.trendingDown,
            onTap: () => setState(() => _onlyPriceDrop = !_onlyPriceDrop),
          ),
          const SizedBox(width: 8),
          // New Chip
          _buildQuickChip(
            label: 'New',
            isSelected: _onlyNew,
            icon: LucideIcons.sparkles,
            onTap: () => setState(() => _onlyNew = !_onlyNew),
          ),
          
          // Show active category filters with cancel button
          if (_selectedCategories.isNotEmpty) ...[
            const SizedBox(width: 8),
            ..._selectedCategories.map((cat) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildQuickChip(
                label: cat,
                isSelected: true,
                isRemovable: true,
                onTap: () => setState(() => _selectedCategories.remove(cat)),
              ),
            )),
          ],

          // Show size filters with cancel button
          if (_selectedSizes.isNotEmpty) ...[
            ..._selectedSizes.map((size) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildQuickChip(
                label: 'Size: $size',
                isSelected: true,
                isRemovable: true,
                onTap: () => setState(() => _selectedSizes.remove(size)),
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickChip({
    required String label,
    required bool isSelected,
    IconData? icon,
    bool isRemovable = false,
    required VoidCallback onTap,
  }) {
    final activeColor = context.nc.isDark ? Colors.white : Colors.black;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected 
              ? activeColor.withOpacity(0.08) 
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected 
                ? activeColor 
                : context.nc.divider,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: isSelected ? activeColor : context.nc.textSecondary),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? activeColor : context.nc.textSecondary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            if (isRemovable) ...[
              const SizedBox(width: 5),
              Icon(LucideIcons.x, size: 12, color: isSelected ? activeColor : context.nc.textSecondary),
            ],
          ],
        ),
      ),
    );
  }

  // Beautiful Premium Grid Card layout matching Nykaa Man Luxe
  Widget _buildPremiumCard(ShopProduct prod) {
    final hasDiscount = prod.originalPrice != null && prod.originalPrice! > prod.price;
    final discountPercent = hasDiscount
        ? (((prod.originalPrice! - prod.price) / prod.originalPrice!) * 100).round()
        : 0;

    // Detect if we want to display bestseller or new badges dynamically
    final isBestseller = prod.longevityScore >= 9.4;
    final isNew = prod.longevityScore < 9.4 && prod.longevityScore >= 9.0;

    return Container(
      decoration: BoxDecoration(
        color: context.nc.isDark ? const Color(0xFF1E293B).withOpacity(0.3) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.nc.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── IMAGE SECTION with Fixed Aspect Ratio ──
          AspectRatio(
            aspectRatio: 1.0,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  child: Image.network(
                    prod.imageUrl,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey.withOpacity(0.1),
                      child: Icon(LucideIcons.package, color: context.nc.textTertiary),
                    ),
                  ),
                ),
                
                // Badges (Bestseller / New)
                if (isBestseller)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade800,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: const Row(
                        children: [
                          Icon(LucideIcons.thumbsUp, size: 9, color: Colors.white),
                          SizedBox(width: 3),
                          Text(
                            'BESTSELLER',
                            style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (isNew)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade700,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: const Row(
                        children: [
                          Icon(LucideIcons.sparkles, size: 9, color: Colors.white),
                          SizedBox(width: 3),
                          Text(
                            'NEW',
                            style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Star Rating Overlay inside bottom left of image
                Positioned(
                  bottom: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.star, size: 8, color: Colors.amber),
                        const SizedBox(width: 2),
                        Text(
                          '${(prod.longevityScore / 2).toStringAsFixed(1)} (12)',
                          style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),

                // Heart Overlay Button
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.heart, size: 14, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),

          // ── DETAILS SECTION ──
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Upper Case Brand Name
                  Text(
                    prod.title.split(' ')[0].toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.nc.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 1),
                  // Short title description
                  Text(
                    prod.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.nc.textSecondary,
                      fontSize: 11,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Color selection dots (decorative)
                  Row(
                    children: [
                      _buildColorDot(Colors.amber),
                      _buildColorDot(BrandColors.emerald500),
                      _buildColorDot(Colors.blue),
                    ],
                  ),
                  
                  const Spacer(),

                  // Pricing Row
                  Row(
                    children: [
                      Text(
                        '₹${prod.price.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: context.nc.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (hasDiscount) ...[
                        const SizedBox(width: 4),
                        Text(
                          '₹${prod.originalPrice!.toStringAsFixed(0)}',
                          style: TextStyle(
                            color: context.nc.textTertiary,
                            fontSize: 10,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$discountPercent% Off',
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Green Highlight tag
                  if (hasDiscount) ...[
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.tag, size: 8, color: Colors.green.shade600),
                          const SizedBox(width: 3),
                          Text(
                            'Price dropped by ₹${(prod.originalPrice! - prod.price).toStringAsFixed(0)}',
                            style: TextStyle(color: Colors.green.shade600, fontSize: 8, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 4),
                  // Tap to View / Quick Add trigger
                  SizedBox(
                    width: double.infinity,
                    height: 28,
                    child: ElevatedButton(
                      onPressed: () {
                        context.push('/shop/product/${prod.id}');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.nc.isDark ? const Color(0xFF1E293B) : Colors.black,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                      child: const Text('View Details', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorDot(Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  // Inline Brand filter banner in the grid
  Widget _buildInlineBrandRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      color: context.nc.isDark ? const Color(0xFF0F172A).withOpacity(0.4) : Colors.grey.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'FILTER BY BRAND',
                style: TextStyle(
                  color: context.nc.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              GestureDetector(
                onTap: () => _openFilterDrawer(context, initialTab: 'Brand'),
                child: const Text(
                  'More Filters',
                  style: TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 32,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _quickBrands.length,
              itemBuilder: (ctx, idx) {
                final b = _quickBrands[idx];
                final isSelected = _selectedBrands.contains(b);
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(b, style: const TextStyle(fontSize: 11)),
                    selected: isSelected,
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          _selectedBrands.add(b);
                        } else {
                          _selectedBrands.remove(b);
                        }
                      });
                    },
                    selectedColor: Colors.blue.withOpacity(0.1),
                    checkmarkColor: Colors.blue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Empty state view
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.packageSearch, size: 48, color: context.nc.textTertiary),
          const SizedBox(height: 16),
          Text(
            'No matching products found',
            style: TextStyle(color: context.nc.textSecondary, fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _resetAllFilters,
            child: const Text('Reset All Filters', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // Sticky Bottom Sort & Filter Row
  Widget _buildStickyBottomBar(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: context.nc.isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(top: BorderSide(color: context.nc.divider, width: 0.5)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4, offset: const Offset(0, -2)),
        ],
      ),
      child: Row(
        children: [
          // Sort Button
          Expanded(
            child: InkWell(
              onTap: () => _showSortBottomSheet(context),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.arrowUpDown, size: 16, color: context.nc.textPrimary),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sort by',
                        style: TextStyle(color: context.nc.textTertiary, fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        _selectedSort,
                        style: TextStyle(color: context.nc.textPrimary, fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Divider
          Container(width: 0.5, height: 28, color: context.nc.divider),

          // Filter Button
          Expanded(
            child: InkWell(
              onTap: () => _openFilterDrawer(context),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.slidersHorizontal, size: 16, color: context.nc.textPrimary),
                  const SizedBox(width: 8),
                  Row(
                    children: [
                      Text(
                        'Filter',
                        style: TextStyle(color: context.nc.textPrimary, fontSize: 13, fontWeight: FontWeight.w800),
                      ),
                      if (_appliedFiltersCount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: const BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.all(Radius.circular(10))),
                          child: Text(
                            '$_appliedFiltersCount Applied',
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
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

  // ─────────────────────────────────────────────────────────────
  // BOTTOM DRAWERS & FILTER DIALOGS
  // ─────────────────────────────────────────────────────────────

  // Dynamic Search Dialog
  void _showSearchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        String currentQuery = _searchQuery;
        return AlertDialog(
          backgroundColor: context.nc.isDark ? const Color(0xFF0F172A) : Colors.white,
          title: const Text('Search Products', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          content: TextField(
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Enter brand or product name...',
              prefixIcon: const Icon(LucideIcons.search, size: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: (val) => currentQuery = val,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() => _searchQuery = currentQuery);
                Navigator.pop(ctx);
              },
              child: const Text('Search'),
            ),
          ],
        );
      },
    );
  }

  // Premium Sort Drawer matching Screenshot 2
  void _showSortBottomSheet(BuildContext context) {
    final sortOptions = [
      'Popularity',
      'Discount: High to Low',
      'Price: Low to High',
      'Price: High to Low',
      'Customer Top Rated',
      'New Arrivals'
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: context.nc.isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text(
                      'Sort By',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                  ),
                  const Divider(),
                  ...sortOptions.map((opt) {
                    final isSelected = _selectedSort == opt;
                    return InkWell(
                      onTap: () {
                        setSheetState(() => _selectedSort = opt);
                        setState(() => _selectedSort = opt);
                        Navigator.pop(ctx);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              opt,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? Colors.blue : context.nc.textPrimary,
                              ),
                            ),
                            Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? Colors.blue : context.nc.textTertiary,
                                  width: isSelected ? 5 : 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Interactive full screen Multi-Faceted Two-column Sidebar Filter Dialog
  void _openFilterDrawer(BuildContext context, {String initialTab = 'Size'}) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, anim1, anim2) {
        return _FilterFullScreenDialog(
          allSizes: _allSizes,
          allBrands: _allBrands,
          allCategories: _allCategories,
          allColors: _allColors,
          initialTab: initialTab,
          selectedSizes: _selectedSizes,
          selectedBrands: _selectedBrands,
          selectedCategories: _selectedCategories,
          selectedColors: _selectedColors,
          onApply: (sizes, brands, cats, colors) {
            setState(() {
              _selectedSizes.clear();
              _selectedSizes.addAll(sizes);
              _selectedBrands.clear();
              _selectedBrands.addAll(brands);
              _selectedCategories.clear();
              _selectedCategories.addAll(cats);
              _selectedColors.clear();
              _selectedColors.addAll(colors);
            });
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// FULL SCREEN FILTER DIALOG WIDGET
// ─────────────────────────────────────────────────────────────

class _FilterFullScreenDialog extends StatefulWidget {
  final List<String> allSizes;
  final List<String> allBrands;
  final List<String> allCategories;
  final List<String> allColors;
  final String initialTab;
  
  final Set<String> selectedSizes;
  final Set<String> selectedBrands;
  final Set<String> selectedCategories;
  final Set<String> selectedColors;

  final Function(Set<String>, Set<String>, Set<String>, Set<String>) onApply;

  const _FilterFullScreenDialog({
    required this.allSizes,
    required this.allBrands,
    required this.allCategories,
    required this.allColors,
    required this.initialTab,
    required this.selectedSizes,
    required this.selectedBrands,
    required this.selectedCategories,
    required this.selectedColors,
    required this.onApply,
  });

  @override
  State<_FilterFullScreenDialog> createState() => _FilterFullScreenDialogState();
}

class _FilterFullScreenDialogState extends State<_FilterFullScreenDialog> {
  late String _activeTab;
  String _optionSearch = '';

  // Local filter sets
  final Set<String> _localSizes = {};
  final Set<String> _localBrands = {};
  final Set<String> _localCategories = {};
  final Set<String> _localColors = {};

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
    _localSizes.addAll(widget.selectedSizes);
    _localBrands.addAll(widget.selectedBrands);
    _localCategories.addAll(widget.selectedCategories);
    _localColors.addAll(widget.selectedColors);
  }

  List<String> _getActiveTabOptions() {
    List<String> raw = [];
    if (_activeTab == 'Size') raw = widget.allSizes;
    else if (_activeTab == 'Brand') raw = widget.allBrands;
    else if (_activeTab == 'Category') raw = widget.allCategories;
    else if (_activeTab == 'Color') raw = widget.allColors;

    if (_optionSearch.isNotEmpty) {
      return raw.where((s) => s.toLowerCase().contains(_optionSearch.toLowerCase())).toList();
    }
    return raw;
  }

  void _toggleOption(String opt) {
    setState(() {
      if (_activeTab == 'Size') {
        if (_localSizes.contains(opt)) _localSizes.remove(opt);
        else _localSizes.add(opt);
      } else if (_activeTab == 'Brand') {
        if (_localBrands.contains(opt)) _localBrands.remove(opt);
        else _localBrands.add(opt);
      } else if (_activeTab == 'Category') {
        if (_localCategories.contains(opt)) _localCategories.remove(opt);
        else _localCategories.add(opt);
      } else if (_activeTab == 'Color') {
        if (_localColors.contains(opt)) _localColors.remove(opt);
        else _localColors.add(opt);
      }
    });
  }

  bool _isOptionSelected(String opt) {
    if (_activeTab == 'Size') return _localSizes.contains(opt);
    if (_activeTab == 'Brand') return _localBrands.contains(opt);
    if (_activeTab == 'Category') return _localCategories.contains(opt);
    if (_activeTab == 'Color') return _localColors.contains(opt);
    return false;
  }

  int _getTabSelectionCount(String tab) {
    if (tab == 'Size') return _localSizes.length;
    if (tab == 'Brand') return _localBrands.length;
    if (tab == 'Category') return _localCategories.length;
    if (tab == 'Color') return _localColors.length;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final tabs = ['Size', 'Brand', 'Category', 'Color', 'Price', 'Discount', 'Avg Customer Rating', 'Pattern', 'Occasion', 'Fabric', 'Sleeve Style', 'Season'];
    final options = _getActiveTabOptions();

    return Scaffold(
      backgroundColor: context.nc.isDark ? const Color(0xFF0F172A) : Colors.white,
      appBar: AppBar(
        backgroundColor: context.nc.isDark ? const Color(0xFF0F172A) : Colors.white,
        elevation: 0.5,
        title: const Text('Filters', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _localSizes.clear();
                _localBrands.clear();
                _localCategories.clear();
                _localColors.clear();
              });
            },
            child: const Text('Reset Filters', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
          ),
        ],
      ),

      body: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── LEFT COLUMN SIDEBAR ──
                Container(
                  width: 140,
                  color: context.nc.isDark ? const Color(0xFF1E293B).withOpacity(0.3) : Colors.grey.shade100,
                  child: ListView.builder(
                    itemCount: tabs.length,
                    itemBuilder: (ctx, idx) {
                      final t = tabs[idx];
                      final isSelected = _activeTab == t;
                      final count = _getTabSelectionCount(t);

                      return InkWell(
                        onTap: () => setState(() {
                          _activeTab = t;
                          _optionSearch = '';
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? (context.nc.isDark ? const Color(0xFF0F172A) : Colors.white) 
                                : Colors.transparent,
                            border: Border(
                              left: BorderSide(
                                color: isSelected ? Colors.blue : Colors.transparent,
                                width: 4,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                t,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                                  color: isSelected ? context.nc.textPrimary : context.nc.textSecondary,
                                ),
                              ),
                              if (count > 0)
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                                  child: Text(
                                    '$count',
                                    style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // ── RIGHT COLUMN SEARCH + LIST ──
                Expanded(
                  child: Container(
                    color: context.nc.isDark ? const Color(0xFF0F172A) : Colors.white,
                    child: Column(
                      children: [
                        // Option Search Field
                        if (['Size', 'Brand', 'Category', 'Color'].contains(_activeTab))
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: TextField(
                              decoration: InputDecoration(
                                prefixIcon: const Icon(LucideIcons.search, size: 16),
                                hintText: 'Search in $_activeTab',
                                hintStyle: const TextStyle(fontSize: 12),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                              ),
                              onChanged: (val) => setState(() => _optionSearch = val),
                            ),
                          ),

                        // Options Checkbox List
                        Expanded(
                          child: ListView.builder(
                            itemCount: options.length,
                            itemBuilder: (ctx, idx) {
                              final opt = options[idx];
                              final isSelected = _isOptionSelected(opt);
                              
                              // Mock option occurrence count
                              final count = (opt.length * 3) % 40 + 1;

                              return InkWell(
                                onTap: () => _toggleOption(opt),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            isSelected ? LucideIcons.checkSquare : LucideIcons.square,
                                            size: 18,
                                            color: isSelected ? Colors.blue : context.nc.textSecondary,
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            opt,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                              color: isSelected ? Colors.blue : context.nc.textPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        '$count',
                                        style: TextStyle(color: context.nc.textTertiary, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Sticky bottom footer dialog action bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: context.nc.divider, width: 0.5)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onApply(_localSizes, _localBrands, _localCategories, _localColors);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    child: const Text('Apply filters', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
