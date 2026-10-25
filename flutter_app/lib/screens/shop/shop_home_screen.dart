import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../config/theme.dart';
import '../../../providers/shop_provider.dart';
import '../../../providers/patient_provider.dart';
import 'shop_cart_sheet.dart';

// ═══════════════════════════════════════════════════════════════
// SHOP HOME SCREEN — Premium Nykaa Man-level dark e-commerce UI
// ═══════════════════════════════════════════════════════════════

class ShopHomeScreen extends ConsumerStatefulWidget {
  const ShopHomeScreen({super.key});

  @override
  ConsumerState<ShopHomeScreen> createState() => _ShopHomeScreenState();
}

class _ShopHomeScreenState extends ConsumerState<ShopHomeScreen> {
  final List<String> _tabs = ['ALL', 'GROOMING', 'FASHION', 'LUXE', 'CLINICAL'];
  String _activeTab = 'ALL';

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _currentNavbarIndex = 0;

  // ── Dark theme palette ──
  static const Color _bgDark = Color(0xFF2C3039);
  static const Color _bgDarker = Color(0xFF1F2228);
  static const Color _bgSection = Color(0xFF3A3F4A);
  static const Color _textWhite = Colors.white;
  static const Color _textGrey = Color(0xFFA0A5AE);
  static const Color _textMuted = Color(0xFF7A7F88);
  static const Color _goldAccent = Color(0xFFD4A857);

  // ── Category circle data ──
  final List<Map<String, String>> _circleCategories = [
    {
      'title': 'Health &\nWellness',
      'image': 'https://images.unsplash.com/photo-1576073719676-aa95576db207?w=300&auto=format&fit=crop&q=80',
    },
    {
      'title': 'Skin Care',
      'image': 'https://images.unsplash.com/photo-1556228578-0d85b1a4d571?w=300&auto=format&fit=crop&q=80',
    },
    {
      'title': 'Luxe',
      'image': 'https://images.unsplash.com/photo-1594035910387-fea47794261f?w=300&auto=format&fit=crop&q=80',
    },
    {
      'title': 'Hair Care',
      'image': 'https://images.unsplash.com/photo-1596755389378-c31d21fd1273?w=300&auto=format&fit=crop&q=80',
    },
    {
      'title': 'Fragrance',
      'image': 'https://images.unsplash.com/photo-1595425970377-c9703c48657a?w=300&auto=format&fit=crop&q=80',
    },
    {
      'title': 'Grooming',
      'image': 'https://images.unsplash.com/photo-1517832606299-7ae9b720a186?w=300&auto=format&fit=crop&q=80',
    },
    {
      'title': 'Clinical',
      'image': 'https://images.unsplash.com/photo-1582750433449-64c8e3e3e402?w=300&auto=format&fit=crop&q=80',
    },
  ];

  // ── Most Wanted Brands data ──
  final List<Map<String, String>> _mostWantedBrands = [
    {
      'brand': 'Dot & Key',
      'subtitle': 'Healthy Plum &\nHydrated Skin',
      'image': 'https://images.unsplash.com/photo-1571781926291-c477ebfd024b?w=400&auto=format&fit=crop&q=80',
    },
    {
      'brand': 'Plum',
      'subtitle': 'Up To 25% OFF',
      'image': 'https://images.unsplash.com/photo-1611930022073-b7a4ba5fcccd?w=400&auto=format&fit=crop&q=80',
    },
    {
      'brand': 'Cetaphil',
      'subtitle': 'Up To 10% OFF',
      'image': 'https://images.unsplash.com/photo-1556228578-0d85b1a4d571?w=400&auto=format&fit=crop&q=80',
    },
    {
      'brand': 'Bioderma',
      'subtitle': 'Up To 10% OFF',
      'image': 'https://images.unsplash.com/photo-1631729371254-42c2892f0e6e?w=400&auto=format&fit=crop&q=80',
    },
    {
      'brand': 'Puma',
      'subtitle': 'Active Life Up To 40%',
      'image': 'https://images.unsplash.com/photo-1517838277536-f5f99be501cd?w=400&auto=format&fit=crop&q=80',
    },
    {
      'brand': 'The Derma Co',
      'subtitle': 'Up To 20% OFF',
      'image': 'https://images.unsplash.com/photo-1522337360788-8b13dee7a37e?w=400&auto=format&fit=crop&q=80',
    },
  ];

  // ── Spotlight Picks data ──
  final List<Map<String, String>> _spotlightPicks = [
    {
      'brand': 'CeraVe',
      'tagline': 'Developed with\ndermatologists',
      'price': 'Starting At ₹315',
      'image': 'https://images.unsplash.com/photo-1556228578-0d85b1a4d571?w=600&auto=format&fit=crop&q=80',
      'color': '0xFF2563EB',
    },
    {
      'brand': 'Rare Rabbit',
      'tagline': 'Aesthetics With\nComfort',
      'price': 'Starting At ₹999',
      'image': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=600&auto=format&fit=crop&q=80',
      'color': '0xFF1E293B',
    },
    {
      'brand': 'Forest Essentials',
      'tagline': 'Ayurvedic Luxury &\nTimeless Beauty',
      'price': 'Starting At ₹1,250',
      'image': 'https://images.unsplash.com/photo-1608248597279-f99d160bfcbc?w=600&auto=format&fit=crop&q=80',
      'color': '0xFF155E37',
    },
    {
      'brand': 'Tom Ford',
      'tagline': 'Bold Fragrances &\nLuxury Aesthetics',
      'price': 'Starting At ₹3,499',
      'image': 'https://images.unsplash.com/photo-1541643600914-78b084683601?w=600&auto=format&fit=crop&q=80',
      'color': '0xFF451A03',
    },
  ];

  // ── Outfits data ──
  final List<Map<String, String>> _outfitCards = [
    {
      'title': 'Wedding\nSale',
      'image': 'https://images.unsplash.com/photo-1594938298603-c8148c4dae35?w=400&auto=format&fit=crop&q=80',
    },
    {
      'title': 'Work-\nReady Fits',
      'image': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&auto=format&fit=crop&q=80',
    },
    {
      'title': 'Sporty\nTraining',
      'image': 'https://images.unsplash.com/photo-1483721310020-03333e577078?w=400&auto=format&fit=crop&q=80',
    },
    {
      'title': 'Casual\nOutings',
      'image': 'https://images.unsplash.com/photo-1617137968427-85924c800a22?w=400&auto=format&fit=crop&q=80',
    },
    {
      'title': 'Winter\nElegance',
      'image': 'https://images.unsplash.com/photo-1610384024014-a3f6b9b390f1?w=400&auto=format&fit=crop&q=80',
    },
  ];

  // ── Brand pills for Luxe section ──
  final List<String> _luxeBrands = [
    'ALDO',
    'CLINIQUE',
    'FOREST ESSENTIALS',
    'BVLGARI',
    'TOM FORD',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(shopProductsActiveDefaultProvider);
    final profile = ref.watch(patientProfileProvider).value;
    final totalCartItems = ref.watch(cartTotalItemsProvider);
    final totalCartPrice = ref.watch(cartTotalPriceProvider);

    Widget activeBody;
    if (_currentNavbarIndex == 0) {
      activeBody = CustomScrollView(
        slivers: [
          // ─── 1. HEADER ───
          SliverToBoxAdapter(child: _buildHeader(profile)),

          // ─── 2. TABS ───
          SliverToBoxAdapter(child: _buildTabs()),

          // ─── ALL TAB CONTENT ───
          if (_activeTab == 'ALL' && _searchQuery.isEmpty) ...[
            // 3. Category circles
            SliverToBoxAdapter(child: _buildCategoryCircles()),

            // 4. Hero banner
            SliverToBoxAdapter(child: _buildHeroBanner()),

            // 5. "Look Sharp, Feel Fresh" — horizontal promo cards
            SliverToBoxAdapter(child: _buildLookSharpSection()),

            // 6. "ZYNDIO MAN LUXE" — brand pills + large banner
            SliverToBoxAdapter(child: _buildLuxeSection()),

            // 7. "Most Wanted Brands" — 2x2 grid
            SliverToBoxAdapter(child: _buildMostWantedBrands()),

            // 8. Category lifestyle circles (Running, Sportswear…)
            SliverToBoxAdapter(child: _buildLifestyleCategories()),

            // 9. "Spotlight Picks" — brand promo cards
            SliverToBoxAdapter(child: _buildSpotlightPicks()),

            // 10. "Bestsellers" — horizontal product scroll
            SliverToBoxAdapter(
              child: _buildBestsellersSection(products),
            ),

            // 11. "Outfits For All Your Plans"
            SliverToBoxAdapter(child: _buildOutfitsSection()),
          ],

          // ─── FILTERED TAB CONTENT (non-ALL tabs or search) ───
          if (_activeTab != 'ALL' || _searchQuery.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _buildFilteredProductsGrid(products),
            ),
          ],

          // Bottom padding for cart bar
          SliverToBoxAdapter(
            child: SizedBox(height: totalCartItems > 0 ? 120 : 60),
          ),
        ],
      );
    } else if (_currentNavbarIndex == 1) {
      activeBody = _buildSearchTab(products);
    } else if (_currentNavbarIndex == 2) {
      activeBody = _buildWishlistTab(products);
    } else {
      activeBody = _buildAccountTab(profile);
    }

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
          bottomNavigationBar: _buildShopBottomNavigationBar(),
          body: Stack(
            children: [
              SafeArea(
                bottom: false,
                child: activeBody,
              ),

              // ─── FLOATING CART BAR ───
              if (totalCartItems > 0)
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: _buildCartBar(totalCartItems, totalCartPrice),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // SECTION BUILDERS
  // ═══════════════════════════════════════════════════════════════

  // ─── HEADER ───
  Widget _buildHeader(dynamic profile) {
    return Container(
      color: _bgDark,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: [
          // Top row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: const Icon(LucideIcons.chevronLeft, color: _textWhite, size: 24),
                  ),
                  const SizedBox(width: 8),
                  const Icon(LucideIcons.mapPin, color: _textWhite, size: 16),
                  const SizedBox(width: 6),
                  const Text(
                    'Add Pincode / Address',
                    style: TextStyle(color: _textGrey, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 4),
                  const Icon(LucideIcons.chevronDown, color: _textGrey, size: 14),
                ],
              ),
              const Row(
                children: [
                  Icon(LucideIcons.bell, color: _textWhite, size: 22),
                  SizedBox(width: 16),
                  Icon(LucideIcons.heart, color: _textWhite, size: 22),
                  SizedBox(width: 16),
                  Icon(LucideIcons.shoppingBag, color: _textWhite, size: 22),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Search bar
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(LucideIcons.search, color: Colors.black45, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: const TextStyle(color: Colors.black, fontSize: 14),
                    decoration: const InputDecoration(
                      filled: false,
                      fillColor: Colors.transparent,
                      hintText: 'Search for supplements, brands, products...',
                      hintStyle: TextStyle(color: Colors.black38, fontSize: 14),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                    child: const Icon(LucideIcons.x, color: Colors.black45, size: 20),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── TABS ───
  Widget _buildTabs() {
    return Container(
      color: _bgDark,
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        children: [
          SizedBox(
            height: 34,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _tabs.length,
              itemBuilder: (context, index) {
                final tab = _tabs[index];
                final isSelected = tab == _activeTab;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _activeTab = tab);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tab,
                          style: TextStyle(
                            color: isSelected ? _textWhite : _textMuted,
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: 2,
                          width: 36,
                          color: isSelected ? _textWhite : Colors.transparent,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(height: 0.5, color: Colors.white.withOpacity(0.08)),
        ],
      ),
    );
  }

  // ─── CATEGORY CIRCLES ───
  Widget _buildCategoryCircles() {
    return Container(
      color: _bgDark,
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 8),
      child: SizedBox(
        height: 110,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _circleCategories.length,
          itemBuilder: (context, index) {
            final cat = _circleCategories[index];
            final cleanCategoryName = cat['title']!.replaceAll('\n', ' ');
            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                context.push('/shop/products/$cleanCategoryName');
              },
              child: Padding(
                padding: const EdgeInsets.only(right: 20),
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.5),
                        image: DecorationImage(
                          image: NetworkImage(cat['image']!),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 76,
                      child: Text(
                        cat['title']!,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: const TextStyle(
                          color: _textWhite,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ─── HERO BANNER ───
  Widget _buildHeroBanner() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        context.push('/shop/products/all');
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        height: 300,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          image: const DecorationImage(
            image: NetworkImage(
              'https://images.unsplash.com/photo-1596462502278-27bfdc403348?w=800&auto=format&fit=crop&q=80',
            ),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withOpacity(0.85),
              ],
              stops: const [0.35, 1.0],
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text(
                'ZYNDIO®',
                style: TextStyle(color: _textWhite, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 2),
              ),
              const SizedBox(height: 2),
              Text('#SimplifySelfcare', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
              const SizedBox(height: 20),
              const Text(
                'Give Your Body',
                style: TextStyle(color: _textWhite, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5),
              ),
              Text('The Love It Deserves', style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 15)),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white38, width: 1),
                  ),
                  child: const Icon(LucideIcons.chevronRight, color: _textWhite, size: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── LOOK SHARP, FEEL FRESH — horizontal promo cards ───
  Widget _buildLookSharpSection() {
    final promos = [
      {
        'title': 'FRESH &\nCOOL ALL DAY',
        'subtitle': 'Perfect for those who want to\nstay sweat-free and refreshed.',
        'discount': 'UP TO 60% OFF',
        'image': 'https://images.unsplash.com/photo-1571781926291-c477ebfd024b?w=500&auto=format&fit=crop&q=80',
        'bg': const Color(0xFF87CEEB),
      },
      {
        'title': 'SUMMER\nESSENTIALS',
        'subtitle': 'Beat the heat with\nour curated picks.',
        'discount': 'UP TO 40% OFF',
        'image': 'https://images.unsplash.com/photo-1556228578-0d85b1a4d571?w=500&auto=format&fit=crop&q=80',
        'bg': const Color(0xFFFFD699),
      },
      {
        'title': 'NIGHTTIME\nRESTORATION',
        'subtitle': 'Deep skin healing and cellular\nrecovery while you rest.',
        'discount': 'UP TO 50% OFF',
        'image': 'https://images.unsplash.com/photo-1590439471364-192aa70c0c53?w=500&auto=format&fit=crop&q=80',
        'bg': const Color(0xFFB8C8D4),
      },
      {
        'title': 'METABOLIC\nOPTIMIZATION',
        'subtitle': 'Understand your biochemistry\nwith tailored diagnostics.',
        'discount': 'UP TO 30% OFF',
        'image': 'https://images.unsplash.com/photo-1576091160550-2173dba999ef?w=500&auto=format&fit=crop&q=80',
        'bg': const Color(0xFFE2F0D9),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Look Sharp, Feel Fresh'),
        SizedBox(
          height: 280,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: promos.length,
            itemBuilder: (context, index) {
              final p = promos[index];
              final cleanTitleName = (p['title'] as String).replaceAll('\n', ' ');
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push('/shop/products/$cleanTitleName');
                },
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.82,
                  margin: const EdgeInsets.only(right: 12),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: p['bg'] as Color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    children: [
                      // Background product image
                      Positioned.fill(
                        child: Opacity(
                          opacity: 0.3,
                          child: Image.network(
                            p['image'] as String,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      // Content
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p['title'] as String,
                              style: const TextStyle(
                                color: Color(0xFF1A1D24),
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              p['subtitle'] as String,
                              style: TextStyle(color: Colors.black.withOpacity(0.65), fontSize: 12, height: 1.4),
                            ),
                            const Spacer(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  p['discount'] as String,
                                  style: const TextStyle(
                                    color: Color(0xFF1A1D24),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.black26),
                                  ),
                                  child: const Icon(LucideIcons.chevronRight, size: 16, color: Colors.black54),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ─── ZYNDIO MAN LUXE — brand pills + hero banner ───
  Widget _buildLuxeSection() {
    return Container(
      color: _bgDarker,
      padding: const EdgeInsets.fromLTRB(0, 28, 0, 48),
      child: Column(
        children: [
          // Title
          RichText(
            text: const TextSpan(
              children: [
                TextSpan(
                  text: 'ZYNDIO',
                  style: TextStyle(
                    color: _textWhite,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    letterSpacing: -0.5,
                  ),
                ),
                TextSpan(
                  text: 'MAN ',
                  style: TextStyle(color: _textGrey, fontSize: 20, fontWeight: FontWeight.w400),
                ),
                TextSpan(
                  text: 'LUXE',
                  style: TextStyle(color: _goldAccent, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Brand pills
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _luxeBrands.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.push('/shop/products/${_luxeBrands[index]}');
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Center(
                      child: Text(
                        _luxeBrands[index],
                        style: const TextStyle(
                          color: _textWhite,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          // Large Luxe banner
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              context.push('/shop/products/Bvlgari');
            },
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              height: 280,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                image: const DecorationImage(
                  image: NetworkImage(
                    'https://images.unsplash.com/photo-1523293182086-7651a899d37f?w=800&auto=format&fit=crop&q=80',
                  ),
                  fit: BoxFit.cover,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.85),
                    ],
                    stops: const [0.4, 1.0],
                  ),
                ),
                padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text(
                    'B V L G A R I',
                    style: TextStyle(
                      color: _textWhite,
                      fontSize: 28,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Get 2 Free Gifts',
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14, fontWeight: FontWeight.w500),
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

  // ─── MOST WANTED BRANDS — 2x2 grid ───
  Widget _buildMostWantedBrands() {
    return Container(
      color: _bgSection,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      child: Column(
        children: [
          const Text(
            'Most Wanted Brands',
            style: TextStyle(color: _textWhite, fontSize: 22, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            'Add Before It\'s Gone',
            style: TextStyle(color: _textGrey, fontSize: 13),
          ),
          const SizedBox(height: 20),
          // 2x2 Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.8,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemCount: _mostWantedBrands.length,
            itemBuilder: (context, index) {
              final brand = _mostWantedBrands[index];
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push('/shop/products/${brand['brand']}');
                },
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(
                      image: NetworkImage(brand['image']!),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                        stops: const [0.4, 1.0],
                      ),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          brand['brand']!,
                          style: const TextStyle(
                          color: _textWhite,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        brand['subtitle']!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          ),
        ],
      ),
    );
  }

  // ─── LIFESTYLE CATEGORIES (Running, Sportswear) ───
  Widget _buildLifestyleCategories() {
    final items = [
      {
        'title': 'Running',
        'image': 'https://images.unsplash.com/photo-1476480862126-209bfaa8edc8?w=300&auto=format&fit=crop&q=80',
      },
      {
        'title': 'Sportswear',
        'image': 'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?w=300&auto=format&fit=crop&q=80',
      },
      {
        'title': 'Training',
        'image': 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=300&auto=format&fit=crop&q=80',
      },
      {
        'title': 'Outdoor',
        'image': 'https://images.unsplash.com/photo-1551698618-1dfe5d97d256?w=300&auto=format&fit=crop&q=80',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Shop By Activity'),
        Container(
          color: _bgDark,
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
          child: SizedBox(
            height: 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.push('/shop/products/${item['title']}');
                  },
                  child: Container(
                    width: 130,
                    margin: const EdgeInsets.only(right: 14),
                    child: Column(
                      children: [
                        Container(
                          height: 120,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            image: DecorationImage(
                              image: NetworkImage(item['image']!),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item['title']!,
                          style: const TextStyle(color: _textWhite, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // ─── SPOTLIGHT PICKS ───
  Widget _buildSpotlightPicks() {
    return Container(
      color: _bgSection,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      child: Column(
        children: [
          const Text(
            'Spotlight Picks',
            style: TextStyle(color: _textWhite, fontSize: 22, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            'Handpicked For You',
            style: TextStyle(color: _textGrey, fontSize: 13),
          ),
          const SizedBox(height: 20),
          ..._spotlightPicks.map((pick) {
            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                context.push('/shop/products/${pick['brand']}');
              },
              child: Container(
                height: 180,
                margin: const EdgeInsets.only(bottom: 14),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Color(int.parse(pick['color']!)),
                ),
                child: Row(
                  children: [
                  // Left text content
                  Expanded(
                    flex: 60,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            pick['brand']!,
                            style: const TextStyle(
                              color: _textWhite,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            pick['tagline']!,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.75),
                              fontSize: 11,
                              height: 1.3,
                            ),
                          ),
                          const Spacer(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  pick['price']!,
                                  style: const TextStyle(
                                    color: _textWhite,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Shop Now',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Right image
                  Expanded(
                    flex: 40,
                    child: Image.network(
                      pick['image']!,
                      fit: BoxFit.cover,
                      height: double.infinity,
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
  }

  // ─── BESTSELLERS — horizontal product cards ───
  Widget _buildBestsellersSection(List<ShopProduct> products) {
    return Container(
      color: _bgDark,
      padding: const EdgeInsets.fromLTRB(0, 28, 0, 36),
      child: Column(
        children: [
          const Text(
            'Bestsellers',
            style: TextStyle(color: _textWhite, fontSize: 22, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 340,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final prod = products[products.length - 1 - index];
                return _buildDarkProductCard(prod);
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── DARK-THEMED PRODUCT CARD (inline, no external widget) ───
  Widget _buildDarkProductCard(ShopProduct product) {
    final hasDiscount = product.originalPrice != null && product.originalPrice! > product.price;
    final discountPercent = hasDiscount
        ? (((product.originalPrice! - product.price) / product.originalPrice!) * 100).round()
        : 0;

    return GestureDetector(
      onTap: () => context.push('/shop/product/${product.id}'),
      child: Container(
        width: 170,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: _bgDarker,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image area
            Expanded(
              flex: 60,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    child: Container(
                      color: const Color(0xFF2A2D35),
                      width: double.infinity,
                      child: Image.network(
                        product.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(LucideIcons.packageOpen, size: 32, color: _textMuted),
                        ),
                      ),
                    ),
                  ),
                  // Badge
                  if (hasDiscount)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$discountPercent% OFF',
                          style: const TextStyle(color: _textWhite, fontSize: 9, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  // Wishlist
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(LucideIcons.heart, size: 14, color: _textGrey),
                    ),
                  ),
                ],
              ),
            ),
            // Details
            Expanded(
              flex: 40,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Rating
                    Row(
                      children: [
                        const Icon(Icons.star, size: 12, color: _goldAccent),
                        const SizedBox(width: 3),
                        Text(
                          '${product.longevityScore}',
                          style: const TextStyle(color: _textWhite, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Title
                    Text(
                      product.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _textWhite, fontSize: 12, fontWeight: FontWeight.w600, height: 1.25),
                    ),
                    const Spacer(),
                    // Price row
                    Row(
                      children: [
                        Text(
                          '₹${product.price.toStringAsFixed(0)}',
                          style: const TextStyle(color: _textWhite, fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                        if (hasDiscount) ...[
                          const SizedBox(width: 6),
                          Text(
                            '₹${product.originalPrice!.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: _textMuted,
                              fontSize: 11,
                              decoration: TextDecoration.lineThrough,
                              decorationColor: _textMuted,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$discountPercent%',
                            style: const TextStyle(color: Color(0xFF22C55E), fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Select Size / ADD button
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Center(
                        child: Text(
                          'ADD TO CART',
                          style: TextStyle(color: _textWhite, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5),
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

  // ─── OUTFITS FOR ALL YOUR PLANS ───
  Widget _buildOutfitsSection() {
    return Container(
      color: _bgSection,
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          const Text(
            'Outfits For All Your Plans',
            style: TextStyle(
              color: _textWhite,
              fontSize: 22,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _outfitCards.length,
              itemBuilder: (context, index) {
                final outfit = _outfitCards[index];
                final cleanTitleName = outfit['title']!.replaceAll('\n', ' ');
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.push('/shop/products/$cleanTitleName');
                  },
                  child: Container(
                    width: 160,
                    margin: const EdgeInsets.only(right: 12),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(
                        image: NetworkImage(outfit['image']!),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.65),
                          ],
                        ),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: Text(
                          outfit['title']!,
                          style: const TextStyle(
                            color: _textWhite,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            fontStyle: FontStyle.italic,
                            height: 1.15,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── FILTERED PRODUCTS (for non-ALL tabs or search mode) ───
  Widget _buildFilteredProductsGrid(List<ShopProduct> allProducts) {
    final filtered = allProducts.where((prod) {
      final matchesSearch = _searchQuery.isEmpty ||
          prod.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          prod.description.toLowerCase().contains(_searchQuery.toLowerCase());

      bool matchesTab = _activeTab == 'ALL';
      if (_activeTab == 'GROOMING') matchesTab = prod.category == 'Supplements';
      if (_activeTab == 'CLINICAL') matchesTab = prod.category == 'Diagnostics';
      if (_activeTab == 'LUXE') matchesTab = prod.category == 'Wearables';
      if (_activeTab == 'FASHION') matchesTab = true;

      return matchesSearch && matchesTab;
    }).toList();

    if (filtered.isEmpty) {
      return Container(
        height: 300,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.searchX, color: _textMuted, size: 48),
            const SizedBox(height: 16),
            const Text('No products found', style: TextStyle(color: _textWhite, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Text('Try a different search or category', style: TextStyle(color: _textGrey, fontSize: 13)),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _activeTab == 'ALL' ? 'Search Results' : _activeTab,
            style: const TextStyle(color: _textWhite, fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.58,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
            ),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              return _buildDarkProductCard(filtered[index]);
            },
          ),
        ],
      ),
    );
  }

  // ─── SECTION TITLE HELPER ───
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 16),
      child: Text(
        title,
        style: const TextStyle(
          color: _textWhite,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  // ─── FLOATING CART BAR ───
  Widget _buildCartBar(int totalItems, double totalPrice) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => const ShopCartSheet(),
        );
      },
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$totalItems ITEM${totalItems > 1 ? 'S' : ''}',
                  style: const TextStyle(color: Colors.black54, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                ),
                const SizedBox(height: 1),
                Text(
                  '₹${totalPrice.toStringAsFixed(0)}',
                  style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'VIEW CART',
                  style: TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                ),
                const SizedBox(width: 8),
                Icon(LucideIcons.arrowRight, color: Colors.black.withOpacity(0.9), size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShopBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: _bgDarker,
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.08),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavbarItem(0, LucideIcons.store, 'Shop'),
              _buildNavbarItem(1, LucideIcons.search, 'Search'),
              _buildNavbarItem(2, LucideIcons.heart, 'Wishlist'),
              _buildNavbarItem(3, LucideIcons.user, 'Account'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavbarItem(int index, IconData icon, String label) {
    final isSelected = _currentNavbarIndex == index;
    final activeColor = _goldAccent;
    final inactiveColor = _textMuted;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _currentNavbarIndex = index;
        });
      },
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? activeColor : inactiveColor,
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? activeColor : inactiveColor,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchTab(List<ShopProduct> products) {
    return Column(
      children: [
        // Dedicated header search pill
        Container(
          padding: const EdgeInsets.all(16),
          color: _bgDark,
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(LucideIcons.search, color: Colors.black45, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: const TextStyle(color: Colors.black, fontSize: 14),
                    decoration: const InputDecoration(
                      filled: false,
                      fillColor: Colors.transparent,
                      hintText: 'Search for supplements, diagnostics...',
                      hintStyle: TextStyle(color: Colors.black38, fontSize: 14),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                    child: const Icon(LucideIcons.x, color: Colors.black45, size: 20),
                  ),
              ],
            ),
          ),
        ),
        
        Expanded(
          child: _searchQuery.isNotEmpty
              ? SingleChildScrollView(child: _buildFilteredProductsGrid(products))
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    const SizedBox(height: 10),
                    const Text(
                      'Trending Searches',
                      style: TextStyle(color: _textWhite, fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        'NMN NAD+',
                        'Glucose Monitor',
                        'Resveratrol',
                        'Cortisol Test',
                        'Bio-Age DNA',
                      ].map((tag) => GestureDetector(
                        onTap: () {
                          _searchController.text = tag;
                          setState(() => _searchQuery = tag);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            tag,
                            style: const TextStyle(color: _textWhite, fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ),
                      )).toList(),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Popular Departments',
                      style: TextStyle(color: _textWhite, fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 16),
                    _buildPopularCategoryCard(
                      'Supplements & Cell Longevity',
                      'https://images.unsplash.com/photo-1576073719676-aa95576db207?w=500&auto=format&fit=crop&q=80',
                      'Supplements',
                    ),
                    const SizedBox(height: 12),
                    _buildPopularCategoryCard(
                      'Advanced Health Diagnostics',
                      'https://images.unsplash.com/photo-1582750433449-64c8e3e3e402?w=500&auto=format&fit=crop&q=80',
                      'Diagnostics',
                    ),
                    const SizedBox(height: 12),
                    _buildPopularCategoryCard(
                      'Biocompatible Wearables',
                      'https://images.unsplash.com/photo-1576671081837-49000212a370?w=500&auto=format&fit=crop&q=80',
                      'Wearables',
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildPopularCategoryCard(String name, String imgUrl, String tabFilter) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeTab = tabFilter.toUpperCase();
          _currentNavbarIndex = 0; // Switch to home tab with filter applied!
        });
      },
      child: Container(
        height: 100,
        margin: const EdgeInsets.only(bottom: 12),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          image: DecorationImage(
            image: NetworkImage(imgUrl),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          color: Colors.black.withOpacity(0.6),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                name,
                style: const TextStyle(color: _textWhite, fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const Icon(LucideIcons.chevronRight, color: _textWhite, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWishlistTab(List<ShopProduct> products) {
    // Pre-populate with a few premium items
    final wishlistItems = products.take(3).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const Text(
            'My Wishlist',
            style: TextStyle(color: _textWhite, fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            '${wishlistItems.length} items saved',
            style: const TextStyle(color: _textGrey, fontSize: 13),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: GridView.builder(
              itemCount: wishlistItems.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.58,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
              ),
              itemBuilder: (context, index) {
                return _buildDarkProductCard(wishlistItems[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountTab(dynamic profile) {
    final userName = profile?.name ?? 'Test User';
    final userEmail = profile?.email ?? 'support@zyndio.example';

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        const SizedBox(height: 24),
        // User Profile Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _bgDarker,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _goldAccent.withOpacity(0.15),
                  border: Border.all(color: _goldAccent, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                    style: const TextStyle(color: _goldAccent, fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userName,
                    style: const TextStyle(color: _textWhite, fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    userEmail,
                    style: const TextStyle(color: _textGrey, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          'Personal Dashboard',
          style: TextStyle(color: _textWhite, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
        const SizedBox(height: 12),
        // Action List
        _buildAccountOption(LucideIcons.package, 'My Orders', 'Track shipment & history'),
        _buildAccountOption(LucideIcons.wallet, 'Zyndio Luxe Wallet', 'Manage credits & refund balances'),
        _buildAccountOption(LucideIcons.microscope, 'Diagnostic Reports', 'Epigenetic DNA & blood panels'),
        _buildAccountOption(LucideIcons.helpCircle, 'Biotech Support', 'Direct link to longevity concierge'),
        _buildAccountOption(LucideIcons.settings, 'Store Preferences', 'Address, details & currencies'),
        const SizedBox(height: 24),
        // Sign out button
        GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            context.pop(); // Pop back out of the Shop module entirely!
          },
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.red.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                'Exit Shop Module',
                style: TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.5),
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildAccountOption(IconData icon, String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _bgDarker.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: () {
          HapticFeedback.lightImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$title is a premium demo feature.', style: const TextStyle(color: Colors.white)),
              backgroundColor: _bgSection,
              duration: const Duration(seconds: 2),
            ),
          );
        },
        leading: Icon(icon, color: _goldAccent, size: 22),
        title: Text(title, style: const TextStyle(color: _textWhite, fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(color: _textGrey, fontSize: 11)),
        trailing: const Icon(LucideIcons.chevronRight, color: _textMuted, size: 16),
      ),
    );
  }
}
