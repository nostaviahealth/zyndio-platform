import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/shopify_service.dart';

/// Shop Product Model matching longevity categories
class ShopProduct {
  final String id;
  final String title;
  final String description;
  final double price;
  final double? originalPrice; // For Blinkit-style discounts
  final String category;
  final String imageUrl;
  final double longevityScore; // Scientific impact score out of 10
  final String scientificBenefit;
  final List<String> details;

  ShopProduct({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    this.originalPrice,
    required this.category,
    required this.imageUrl,
    required this.longevityScore,
    required this.scientificBenefit,
    required this.details,
  });
}

/// Cart Item Model
class CartItem {
  final ShopProduct product;
  final int quantity;

  CartItem({
    required this.product,
    required this.quantity,
  });

  CartItem copyWith({
    ShopProduct? product,
    int? quantity,
  }) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
    );
  }
}

/// Static Mock Products Data (Longevity & Biotech theme)
final shopProducts = [
  // Supplements
  ShopProduct(
    id: 'supp_nmn_1000',
    title: 'NMN Platinum Cell-Boost',
    description: '1000mg pure Nicotinamide Mononucleotide to increase NAD+ levels, boosting cellular energy & DNA repair.',
    price: 69.00,
    originalPrice: 89.00,
    category: 'Supplements',
    imageUrl: 'https://images.unsplash.com/photo-1576073719676-aa95576db207?w=500&auto=format&fit=crop&q=80',
    longevityScore: 9.4,
    scientificBenefit: 'Improves mitochondrial efficiency and activates sirtuin longevity pathways.',
    details: ['60 capsules', 'Vegan', 'Size: Free Size', '99.8% high purity'],
  ),
  ShopProduct(
    id: 'supp_resv_500',
    title: 'Trans-Resveratrol Bio-Soma',
    description: '500mg premium Trans-Resveratrol paired with Piperine for 15x bioavailability. Activates cellular defenses.',
    price: 45.00,
    originalPrice: 55.00,
    category: 'Supplements',
    imageUrl: 'https://images.unsplash.com/photo-1556228578-0d85b1a4d571?w=500&auto=format&fit=crop&q=80',
    longevityScore: 8.8,
    scientificBenefit: 'Mimics caloric restriction pathways and supports cardiovascular longevity.',
    details: ['30 capsules', 'Gluten-free', 'Size: Free Size', 'Synergistic cellular activation formula'],
  ),
  ShopProduct(
    id: 'food_matcha_cer',
    title: 'Ceremonial Matcha Uji-Grade',
    description: 'Shade-ground organic green tea stone-ground in Kyoto. Mega-dose of EGCG catechins for cognitive longevity.',
    price: 32.00,
    category: 'Diagnostics',
    imageUrl: 'https://images.unsplash.com/photo-1563729784474-d77dbb933a9e?w=500&auto=format&fit=crop&q=80',
    longevityScore: 8.5,
    scientificBenefit: 'Suppresses inflammatory cytokines and optimizes metabolic parameters.',
    details: ['30g tin', '100% Organic', 'Size: Free Size', 'Supercharged with L-theanine'],
  ),
  ShopProduct(
    id: 'wear_cgm_patch',
    title: 'Continuous Glucose Monitor',
    description: 'Biocompatible 14-day continuous interstitial glucose tracker. Integrates with Zyndio to map metabolism.',
    price: 120.00,
    originalPrice: 150.00,
    category: 'Wearables',
    imageUrl: 'https://images.unsplash.com/photo-1576671081837-49000212a370?w=500&auto=format&fit=crop&q=80',
    longevityScore: 9.6,
    scientificBenefit: 'Helps prevent insulin resistance, glycemic spikes, and advanced glycation endproducts.',
    details: ['1x Sensor', 'Size: Free Size', 'Waterproof IP68', 'Includes application patch'],
  ),
  ShopProduct(
    id: 'diag_age_kit',
    title: 'Bio-Age DNA Methylation Kit',
    description: 'Clinical epigenetic test calculating biological age, rate of aging, and immune cellular senescence.',
    price: 199.00,
    originalPrice: 249.00,
    category: 'Diagnostics',
    imageUrl: 'https://images.unsplash.com/photo-1599643478518-a784e5dc4c8f?w=500&auto=format&fit=crop&q=80',
    longevityScore: 9.8,
    scientificBenefit: 'Empirically measures biological cellular decay and tracks overall therapy compliance.',
    details: ['Saliva collector kit', 'Size: Free Size', 'Comprehensive 40+ page diagnostic profile', 'Doctor approved review'],
  ),
  ShopProduct(
    id: 'supp_ashwa_pro',
    title: 'Ashwagandha KSM-66',
    description: 'Highly concentrated root extract designed to manage elevated cortisol, reducing stress and optimizing cognitive clarity.',
    price: 28.00,
    originalPrice: 35.00,
    category: 'Supplements',
    imageUrl: 'https://images.unsplash.com/photo-1611930022073-b7a4ba5fcccd?w=500&auto=format&fit=crop&q=80',
    longevityScore: 8.7,
    scientificBenefit: 'Acts as a natural adaptogen that lowers chronic inflammation and supports neuroprotection.',
    details: ['60 capsules', 'Size: Free Size', 'Third-party heavy metal tested', 'Made in a GMP certified facility'],
  ),
  ShopProduct(
    id: 'wear_smart_ring',
    title: 'Zyndio Smart Ring',
    description: 'Elegant biocompatible titanium ring tracking HRV, sleep cycles, and daily metabolic strain markers.',
    price: 299.00,
    originalPrice: 349.00,
    category: 'Wearables',
    imageUrl: 'https://images.unsplash.com/photo-1599643478518-a784e5dc4c8f?w=500&auto=format&fit=crop&q=80',
    longevityScore: 9.5,
    scientificBenefit: 'Passively maps circadian rhythm anomalies and autonomous nervous system responses.',
    details: ['Hypoallergenic titanium shell', 'Size: M', 'Water resistant to 100m', 'Integrated health dashboard'],
  ),
  ShopProduct(
    id: 'supp_omega_3',
    title: 'Omega-3 Marine Elite',
    description: 'High-potency purified fish oil supplying 1200mg EPA and 900mg DHA to boost cellular membrane flexibility.',
    price: 39.00,
    originalPrice: 49.00,
    category: 'Supplements',
    imageUrl: 'https://images.unsplash.com/photo-1556228578-0d85b1a4d571?w=500&auto=format&fit=crop&q=80',
    longevityScore: 9.1,
    scientificBenefit: 'Protects the cardiovascular system, improves neuro-longevity, and reduces metabolic distress.',
    details: ['120 softgels', 'Size: Free Size', 'Wild-caught sustainable sources', 'Zero fishy aftertaste'],
  ),

  // Skin Care
  ShopProduct(
    id: 'skincare_cerave_cleanser',
    title: 'CeraVe Hydrating Cleanser',
    description: 'Developed with dermatologists, non-foaming hydrating lotion cleanses skin and restores barrier.',
    price: 315.00,
    originalPrice: 350.00,
    category: 'Skin Care',
    imageUrl: 'https://images.unsplash.com/photo-1556228578-0d85b1a4d571?w=500&auto=format&fit=crop&q=80',
    longevityScore: 9.2,
    scientificBenefit: 'Contains 3 essential ceramides to protect and soothe sensitive skin.',
    details: ['236ml', 'Size: Free Size', 'Hyaluronic Acid'],
  ),
  ShopProduct(
    id: 'skincare_dotkey_moisturizer',
    title: 'Dot & Key Vitamin C Moisturizer',
    description: 'Healthy plum & hydrated skin restoration gel cream with botanical vitamin C.',
    price: 495.00,
    originalPrice: 595.00,
    category: 'Skin Care',
    imageUrl: 'https://images.unsplash.com/photo-1571781926291-c477ebfd024b?w=500&auto=format&fit=crop&q=80',
    longevityScore: 8.9,
    scientificBenefit: 'Improves skin luminosity and fights oxidative photo-aging.',
    details: ['50ml', 'Size: Free Size', 'Paraben-free'],
  ),
  ShopProduct(
    id: 'skincare_plum_serum',
    title: 'Plum 10% Niacinamide Serum',
    description: 'Clarifying skin serum for blemishes, dark spots control, and hyperpigmentation.',
    price: 590.00,
    originalPrice: 790.00,
    category: 'Skin Care',
    imageUrl: 'https://images.unsplash.com/photo-1611930022073-b7a4ba5fcccd?w=500&auto=format&fit=crop&q=80',
    longevityScore: 9.1,
    scientificBenefit: 'Strengthens outer epidermic layers and regulates lipid secretion.',
    details: ['30ml', 'Size: Free Size', '100% Vegan'],
  ),
  ShopProduct(
    id: 'skincare_cetaphil_lotion',
    title: 'Cetaphil Gentle Skin Cleanser',
    description: 'Clinically proven to hydrate skin while cleansing away impurities without drying.',
    price: 299.00,
    originalPrice: 350.00,
    category: 'Skin Care',
    imageUrl: 'https://images.unsplash.com/photo-1556228578-0d85b1a4d571?w=500&auto=format&fit=crop&q=80',
    longevityScore: 9.3,
    scientificBenefit: 'Hypoallergenic micellar formulation protects natural moisture barrier.',
    details: ['250ml', 'Size: Free Size', 'Dermatologist Recommended'],
  ),
  ShopProduct(
    id: 'skincare_bioderma_micellar',
    title: 'Bioderma Sensibio H2O Micellar',
    description: 'Dermatological cleansing water that respects sensitive skin vulnerability.',
    price: 399.00,
    originalPrice: 450.00,
    category: 'Skin Care',
    imageUrl: 'https://images.unsplash.com/photo-1631729371254-42c2892f0e6e?w=500&auto=format&fit=crop&q=80',
    longevityScore: 9.0,
    scientificBenefit: 'Captures micro-impurities while retaining physiological pH balance.',
    details: ['100ml', 'Size: Free Size', 'Soap-free'],
  ),
  ShopProduct(
    id: 'skincare_derma_peel',
    title: 'The Derma Co Peeling Solution',
    description: '15% AHA + 1% BHA multi-acid exfoliating peel solution for radiant complexion.',
    price: 559.00,
    originalPrice: 699.00,
    category: 'Skin Care',
    imageUrl: 'https://images.unsplash.com/photo-1522337360788-8b13dee7a37e?w=500&auto=format&fit=crop&q=80',
    longevityScore: 8.8,
    scientificBenefit: 'Accelerates cell turnover and gently clears clogged pores.',
    details: ['30ml', 'Size: Free Size', 'Salicylic & Glycolic acid'],
  ),

  // Luxe Brands
  ShopProduct(
    id: 'luxe_forest_cream',
    title: 'Forest Essentials Soundarya Cream',
    description: 'Ayurvedic luxury radiance cream infused with pure 24k gold bhasma powder.',
    price: 1250.00,
    originalPrice: 1550.00,
    category: 'Luxe',
    imageUrl: 'https://images.unsplash.com/photo-1608248597279-f99d160bfcbc?w=500&auto=format&fit=crop&q=80',
    longevityScore: 9.5,
    scientificBenefit: 'Gold dust particles stimulate collagen production and combat free radicals.',
    details: ['50g', 'Size: Free Size', '24k Gold Bhasma'],
  ),
  ShopProduct(
    id: 'luxe_tomford_oud',
    title: 'Tom Ford Oud Wood Parfum',
    description: 'Bold, exotic, and luxury woody fragrance reflecting absolute masculinity.',
    price: 3499.00,
    originalPrice: 3999.00,
    category: 'Luxe',
    imageUrl: 'https://images.unsplash.com/photo-1541643600914-78b084683601?w=500&auto=format&fit=crop&q=80',
    longevityScore: 9.6,
    scientificBenefit: 'Luxury aromatic therapy triggers deep neurological relaxation.',
    details: ['50ml', 'Size: Free Size', 'Eau de Parfum'],
  ),
  ShopProduct(
    id: 'luxe_bvlgari_man',
    title: 'Bvlgari Man In Black',
    description: 'An intense composition of amber, leather, spices and woods. Bold fragrance.',
    price: 5200.00,
    originalPrice: 6000.00,
    category: 'Luxe',
    imageUrl: 'https://images.unsplash.com/photo-1523293182086-7651a899d37f?w=500&auto=format&fit=crop&q=80',
    longevityScore: 9.7,
    scientificBenefit: 'High grade natural spices provide signature stress relief aromas.',
    details: ['100ml', 'Size: Free Size', 'Genuine Import'],
  ),
  ShopProduct(
    id: 'luxe_clinique_shave',
    title: 'Clinique Post-Shave Soother',
    description: 'Soothing aloe-rich formula comforts and cools just-shaven facial skin.',
    price: 1800.00,
    originalPrice: 2200.00,
    category: 'Luxe',
    imageUrl: 'https://images.unsplash.com/photo-1517832606299-7ae9b720a186?w=500&auto=format&fit=crop&q=80',
    longevityScore: 9.3,
    scientificBenefit: 'Actively minimizes shaving inflammation and redness.',
    details: ['75ml', 'Size: Free Size', 'Allergy Tested'],
  ),
  ShopProduct(
    id: 'luxe_aldo_loafers',
    title: 'ALDO Luxe Leather Loafers',
    description: 'Handcrafted premium Italian dress slip-on leather shoes.',
    price: 4999.00,
    originalPrice: 6999.00,
    category: 'Luxe',
    imageUrl: 'https://images.unsplash.com/photo-1594938298603-c8148c4dae35?w=500&auto=format&fit=crop&q=80',
    longevityScore: 9.4,
    scientificBenefit: 'Ergonomic shape supports foot arch structure and dynamic balance.',
    details: ['Size: 42', 'Genuine Leather', 'Memory Foam Insole'],
  ),

  // Grooming & Hair Care
  ShopProduct(
    id: 'hair_rosemary_oil',
    title: 'Zyndio Rosemary Growth Oil',
    description: 'Pure rosemary leaf extract blended with organic carrier oils for thicker hair.',
    price: 350.00,
    originalPrice: 450.00,
    category: 'Hair Care',
    imageUrl: 'https://images.unsplash.com/photo-1596755389378-c31d21fd1273?w=500&auto=format&fit=crop&q=80',
    longevityScore: 9.0,
    scientificBenefit: ' Rosemary extract blocks DHT hormones associated with cellular hair loss.',
    details: ['150ml', 'Size: Free Size', 'Sulfates-free'],
  ),
  ShopProduct(
    id: 'grooming_beard_oil',
    title: 'Zyndio Advanced Beard Oil',
    description: 'Natural jojoba, argan, and cedarwood blend to soften and nourish coarse beard hair.',
    price: 450.00,
    originalPrice: 599.00,
    category: 'Grooming',
    imageUrl: 'https://images.unsplash.com/photo-1517832606299-7ae9b720a186?w=500&auto=format&fit=crop&q=80',
    longevityScore: 8.6,
    scientificBenefit: 'Nourishes the hair follicles underneath to avoid dry skin flakes.',
    details: ['30ml', 'Size: Free Size', 'Organic cold-pressed'],
  ),

  // Fashion / Outfits
  ShopProduct(
    id: 'fashion_rare_rabbit_shirt',
    title: 'Rare Rabbit White Linen Shirt',
    description: 'Pure white breathable premium linen shirt designed for ultimate comfort.',
    price: 1999.00,
    originalPrice: 2499.00,
    category: 'Fashion',
    imageUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=500&auto=format&fit=crop&q=80',
    longevityScore: 9.2,
    scientificBenefit: '100% organic linen fibers reduce skin sweat accumulation.',
    details: ['Size: M', 'Slim Fit', '100% Linen'],
  ),
  ShopProduct(
    id: 'fashion_snitch_jacket',
    title: 'Snitch Black Denim Jacket',
    description: 'Rugged urban solid denim button-up utility jacket.',
    price: 1699.00,
    originalPrice: 1999.00,
    category: 'Fashion',
    imageUrl: 'https://images.unsplash.com/photo-1617137968427-85924c800a22?w=500&auto=format&fit=crop&q=80',
    longevityScore: 8.9,
    scientificBenefit: 'Structured heavy-weight denim protects against cold winds.',
    details: ['Size: L', '100% Denim Cotton'],
  ),
  ShopProduct(
    id: 'fashion_levi_jeans',
    title: 'Levi\'s 511 Slim Jeans',
    description: 'Classic high-durability dark blue stretch denim jeans.',
    price: 1935.00,
    originalPrice: 4299.00,
    category: 'Fashion',
    imageUrl: 'https://images.unsplash.com/photo-1594938298603-c8148c4dae35?w=500&auto=format&fit=crop&q=80',
    longevityScore: 9.4,
    scientificBenefit: 'Durable construction with 2% elastane for dynamic flexibility.',
    details: ['Size: 32', 'Stretch Denim'],
  ),
  ShopProduct(
    id: 'fashion_puma_hoodie',
    title: 'Puma Active Training Hoodie',
    description: 'Breathable dry-fit polyester performance training pullover hoodie.',
    price: 1499.00,
    originalPrice: 2499.00,
    category: 'Fashion',
    imageUrl: 'https://images.unsplash.com/photo-1483721310020-03333e577078?w=500&auto=format&fit=crop&q=80',
    longevityScore: 9.0,
    scientificBenefit: 'DryCELL technology absorbs heat and sweat efficiently during tasks.',
    details: ['Size: L', 'Athletic Fit'],
  ),
  ShopProduct(
    id: 'fashion_american_eagle_polo',
    title: 'American Eagle Classic Polo',
    description: 'Preppy smart-casual cotton polo shirt for clean work-ready fits.',
    price: 1299.00,
    originalPrice: 1799.00,
    category: 'Fashion',
    imageUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=500&auto=format&fit=crop&q=80',
    longevityScore: 8.8,
    scientificBenefit: 'Soft pique knit texture ensures consistent airflow.',
    details: ['Size: M', 'Regular fit'],
  ),
  ShopProduct(
    id: 'fashion_arrow_suit',
    title: 'Arrow Work-Ready Blazer',
    description: 'Formal double-vented corporate executive tailored blazer coat.',
    price: 3499.00,
    originalPrice: 4999.00,
    category: 'Fashion',
    imageUrl: 'https://images.unsplash.com/photo-1594938298603-c8148c4dae35?w=500&auto=format&fit=crop&q=80',
    longevityScore: 9.1,
    scientificBenefit: 'Crease-resistant fabric keeps you looking sharp all day.',
    details: ['Size: 40', 'Premium wool blend'],
  ),
  ShopProduct(
    id: 'fashion_wedding_sherwani',
    title: 'Rare Rabbit Wedding Coat',
    description: 'Royal wedding sale special traditional raw silk embroidered sherwani coat.',
    price: 8999.00,
    originalPrice: 12999.00,
    category: 'Fashion',
    imageUrl: 'https://images.unsplash.com/photo-1617137968427-85924c800a22?w=500&auto=format&fit=crop&q=80',
    longevityScore: 9.5,
    scientificBenefit: 'Handwoven raw silk offers supreme thermal regulation.',
    details: ['Size: L', 'Raw Silk Fabric'],
  ),
  ShopProduct(
    id: 'fashion_winter_sweater',
    title: 'The Indian Garage Co Sweater',
    description: 'Cozy knitted thermal winter sweater for lifestyle protection.',
    price: 1064.00,
    originalPrice: 2799.00,
    category: 'Fashion',
    imageUrl: 'https://images.unsplash.com/photo-1610384024014-a3f6b9b390f1?w=500&auto=format&fit=crop&q=80',
    longevityScore: 8.7,
    scientificBenefit: 'Acryli-wool weave locks body heat efficiently.',
    details: ['Size: M', 'Acrylic blend'],
  ),
  ShopProduct(
    id: 'fashion_casual_shaket',
    title: 'WROGN Casual Outer Shaket',
    description: 'Trendy casual check zip-up flannel shaket with hoodie details.',
    price: 1221.00,
    originalPrice: 2799.00,
    category: 'Fashion',
    imageUrl: 'https://images.unsplash.com/photo-1617137968427-85924c800a22?w=500&auto=format&fit=crop&q=80',
    longevityScore: 8.6,
    scientificBenefit: 'Heavy weight flannel provides durable layer insulation.',
    details: ['Size: L', '100% cotton'],
  ),
];

/// Providers
final shopProductsProvider = Provider<List<ShopProduct>>((ref) {
  return shopProducts;
});

final shopifyProductsProvider = FutureProvider.family<List<ShopProduct>, String?>((ref, query) async {
  final shopifyService = ShopifyService();
  return await shopifyService.fetchProducts(query: query);
});

final shopProductsActiveProvider = Provider.family<List<ShopProduct>, String?>((ref, query) {
  final shopifyAsync = ref.watch(shopifyProductsProvider(query));
  return shopifyAsync.maybeWhen(
    data: (products) => products.isNotEmpty ? products : ref.read(shopProductsProvider),
    orElse: () => ref.read(shopProductsProvider),
  );
});

final shopProductsActiveDefaultProvider = Provider<List<ShopProduct>>((ref) {
  return ref.watch(shopProductsActiveProvider(null));
});

final selectedCategoryProvider = NotifierProvider<SelectedCategoryNotifier, String>(() {
  return SelectedCategoryNotifier();
});

class SelectedCategoryNotifier extends Notifier<String> {
  @override
  String build() {
    return 'All';
  }

  void setCategory(String category) {
    state = category;
  }
}

final cartProvider = NotifierProvider<CartNotifier, List<CartItem>>(() {
  return CartNotifier();
});

class CartNotifier extends Notifier<List<CartItem>> {
  @override
  List<CartItem> build() {
    _loadCart();
    return [];
  }

  Future<void> _loadCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('zyndio_shop_cart');
      if (saved != null) {
        final List<dynamic> decoded = jsonDecode(saved);
        final items = decoded.map((item) {
          final prod = shopProducts.firstWhere(
            (p) => p.id == item['prodId'],
            orElse: () => shopProducts.first,
          );
          return CartItem(product: prod, quantity: item['quantity'] as int);
        }).toList();
        state = items;
      }
    } catch (_) {}
  }

  Future<void> _saveCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final items = state.map((item) => {
        'prodId': item.product.id,
        'quantity': item.quantity,
      }).toList();
      await prefs.setString('zyndio_shop_cart', jsonEncode(items));
    } catch (_) {}
  }

  void addToCart(ShopProduct product) {
    final existingIndex = state.indexWhere((item) => item.product.id == product.id);
    if (existingIndex != -1) {
      final currentItem = state[existingIndex];
      state = [
        ...state.sublist(0, existingIndex),
        currentItem.copyWith(quantity: currentItem.quantity + 1),
        ...state.sublist(existingIndex + 1),
      ];
    } else {
      state = [...state, CartItem(product: product, quantity: 1)];
    }
    _saveCart();
  }

  void removeFromCart(ShopProduct product) {
    final existingIndex = state.indexWhere((item) => item.product.id == product.id);
    if (existingIndex == -1) return;

    final currentItem = state[existingIndex];
    if (currentItem.quantity > 1) {
      state = [
        ...state.sublist(0, existingIndex),
        currentItem.copyWith(quantity: currentItem.quantity - 1),
        ...state.sublist(existingIndex + 1),
      ];
    } else {
      state = [
        ...state.sublist(0, existingIndex),
        ...state.sublist(existingIndex + 1),
      ];
    }
    _saveCart();
  }

  void clearCart() {
    state = [];
    _saveCart();
  }
}

/// Calculated Cart Getters
final cartTotalItemsProvider = Provider<int>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.fold(0, (sum, item) => sum + item.quantity);
});

final cartTotalPriceProvider = Provider<double>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.fold(0.0, (sum, item) => sum + (item.product.price * item.quantity));
});
