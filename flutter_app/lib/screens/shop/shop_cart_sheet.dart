import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../providers/shop_provider.dart';

class ShopCartSheet extends ConsumerStatefulWidget {
  const ShopCartSheet({super.key});

  @override
  ConsumerState<ShopCartSheet> createState() => _ShopCartSheetState();
}

class _ShopCartSheetState extends ConsumerState<ShopCartSheet>
    with TickerProviderStateMixin {
  bool _orderPlaced = false;
  late AnimationController _successController;
  late Animation<double> _successScale;
  late Animation<double> _successFade;

  // Premium Luxury Dark-Themed Color System (Matched exactly with Shop Home Screen)
  static const Color _bgDark = Color(0xFF2C3039);
  static const Color _bgDarker = Color(0xFF1F2228);
  static const Color _borderDark = Color(0xFF3A3F4A);
  static const Color _textWhite = Colors.white;
  static const Color _textMuted = Color(0xFFA0A5AE);
  static const Color _textGrey = Color(0xFF7A7F88);
  static const Color _emerald = Color(0xFF10B981);
  static const Color _emeraldDark = Color(0xFF059669);
  static const Color _emeraldGlow = Color(0xFF34D399);

  @override
  void initState() {
    super.initState();
    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _successScale = CurvedAnimation(
      parent: _successController,
      curve: Curves.elasticOut,
    );
    _successFade = CurvedAnimation(
      parent: _successController,
      curve: Curves.easeIn,
    );
  }

  @override
  void dispose() {
    _successController.dispose();
    super.dispose();
  }

  void _placeOrder() {
    HapticFeedback.heavyImpact();
    setState(() => _orderPlaced = true);
    _successController.forward();
  }

  // ── Helpers ──

  double _calcMrpTotal(List<CartItem> cart) {
    return cart.fold(0.0, (sum, item) {
      final mrp = item.product.originalPrice ?? item.product.price;
      return sum + (mrp * item.quantity);
    });
  }

  double _calcDiscount(List<CartItem> cart) {
    return cart.fold(0.0, (sum, item) {
      final mrp = item.product.originalPrice ?? item.product.price;
      return sum + ((mrp - item.product.price) * item.quantity);
    });
  }

  double _calcDeliveryFee(double totalPrice) {
    return totalPrice >= 150.0 ? 0.0 : 9.0;
  }

  static const double _handlingFeeOriginal = 4.0;

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final totalPrice = ref.watch(cartTotalPriceProvider);
    final totalItems = ref.watch(cartTotalItemsProvider);

    final mrpTotal = _calcMrpTotal(cart);
    final discount = _calcDiscount(cart);
    final deliveryFee = _calcDeliveryFee(totalPrice);
    final toPay = totalPrice + deliveryFee;
    final totalSaved = discount + _handlingFeeOriginal;

    if (_orderPlaced) {
      return _buildSuccessScreen(context);
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: _bgDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag Handle
          _buildDragHandle(context),

          // Scrollable Content
          Expanded(
            child: cart.isEmpty
                ? _buildEmptyCart(context)
                : ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      // Savings Banner (Translucent emerald pill)
                      if (totalSaved > 0) _buildSavingsBanner(context, totalSaved),

                      // Delivery Info Card (Sleek dark theme)
                      _buildDeliveryInfoCard(context, totalItems),

                      // Cart Items
                      _buildCartItemsList(context, cart),

                      // Bill Summary
                      _buildBillSummary(
                        context,
                        mrpTotal: mrpTotal,
                        totalPrice: totalPrice,
                        deliveryFee: deliveryFee,
                        toPay: toPay,
                      ),

                      // Savings Summary Card
                      if (totalSaved > 0)
                        _buildSavingsSummary(context, totalSaved, discount),

                      const SizedBox(height: 100),
                    ],
                  ),
          ),

          // Sticky Bottom Pay Bar
          if (cart.isNotEmpty) _buildStickyBottom(context, toPay),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // DRAG HANDLE
  // ═══════════════════════════════════════════════════════════

  Widget _buildDragHandle(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Center(
          child: Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // SAVINGS BANNER (Luxe Emerald Translucent Pill)
  // ═══════════════════════════════════════════════════════════

  Widget _buildSavingsBanner(BuildContext context, double totalSaved) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: _emerald.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _emerald.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            LucideIcons.badgeCheck,
            color: _emeraldGlow,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Yay! You saved ₹${totalSaved.toStringAsFixed(0)} on this order',
              style: const TextStyle(
                color: _emeraldGlow,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Icon(
            LucideIcons.chevronDown,
            color: _emeraldGlow,
            size: 16,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // DELIVERY INFO CARD
  // ═══════════════════════════════════════════════════════════

  Widget _buildDeliveryInfoCard(BuildContext context, int totalItems) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _bgDarker,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: _emerald.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.clock,
              color: _emeraldGlow,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Delivering in 10 mins',
                  style: TextStyle(
                    color: _textWhite,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$totalItems item${totalItems > 1 ? 's' : ''}',
                  style: const TextStyle(
                    color: _textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => HapticFeedback.lightImpact(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    LucideIcons.calendarDays,
                    color: _textMuted,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Schedule',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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

  // ═══════════════════════════════════════════════════════════
  // CART ITEMS LIST
  // ═══════════════════════════════════════════════════════════

  Widget _buildCartItemsList(BuildContext context, List<CartItem> cart) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _bgDarker,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          for (int i = 0; i < cart.length; i++) ...[
            _buildCartItem(context, cart[i]),
            if (i < cart.length - 1)
              Divider(
                height: 1,
                indent: 14,
                endIndent: 14,
                color: Colors.white.withOpacity(0.04),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildCartItem(BuildContext context, CartItem item) {
    final hasDiscount = item.product.originalPrice != null &&
        item.product.originalPrice! > item.product.price;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Image
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              item.product.imageUrl,
              width: 54,
              height: 54,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFF22252E),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  LucideIcons.package,
                  color: _textMuted,
                  size: 24,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Title + Description + Price
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.title,
                  style: const TextStyle(
                    color: _textWhite,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  item.product.details.isNotEmpty
                      ? item.product.details.first
                      : item.product.category,
                  style: const TextStyle(
                    color: _textMuted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (hasDiscount) ...[
                      Text(
                        '₹${item.product.originalPrice!.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: _textGrey,
                          fontSize: 12,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: _textGrey,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      '₹${item.product.price.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: _emeraldGlow,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Quantity Controls + Remove
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Remove button
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  for (int i = 0; i < item.quantity; i++) {
                    ref.read(cartProvider.notifier).removeFromCart(item.product);
                  }
                },
                child: Icon(
                  LucideIcons.trash2,
                  color: Colors.white.withOpacity(0.3),
                  size: 15,
                ),
              ),
              const SizedBox(height: 14),
              // Qty controls
              Container(
                height: 28,
                decoration: BoxDecoration(
                  color: _bgDark,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _qtyButton(
                      context,
                      icon: LucideIcons.minus,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        ref
                            .read(cartProvider.notifier)
                            .removeFromCart(item.product);
                      },
                    ),
                    Container(
                      width: 24,
                      alignment: Alignment.center,
                      child: Text(
                        '${item.quantity}',
                        style: const TextStyle(
                          color: _emeraldGlow,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _qtyButton(
                      context,
                      icon: LucideIcons.plus,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        ref
                            .read(cartProvider.notifier)
                            .addToCart(item.product);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _qtyButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 28,
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 12,
          color: Colors.white.withOpacity(0.6),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // BILL SUMMARY
  // ═══════════════════════════════════════════════════════════

  Widget _buildBillSummary(
    BuildContext context, {
    required double mrpTotal,
    required double totalPrice,
    required double deliveryFee,
    required double toPay,
  }) {
    final isFreeDelivery = deliveryFee == 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _bgDarker,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                LucideIcons.receipt,
                color: Colors.white.withOpacity(0.8),
                size: 16,
              ),
              const SizedBox(width: 8),
              const Text(
                'Bill Summary',
                style: TextStyle(
                  color: _textWhite,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Item Total
          _billRow(
            context,
            label: 'Item Total',
            trailingWidget: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (mrpTotal != totalPrice) ...[
                  Text(
                    '₹${mrpTotal.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: _textGrey,
                      fontSize: 13,
                      decoration: TextDecoration.lineThrough,
                      decorationColor: _textGrey,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  '₹${totalPrice.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: _textWhite,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          _dashedDivider(context),

          // Delivery Fee
          _billRow(
            context,
            label: 'Delivery Fee',
            trailingWidget: isFreeDelivery
                ? const Text(
                    'FREE',
                    style: TextStyle(
                      color: _emeraldGlow,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : Text(
                    '₹${deliveryFee.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: _textWhite,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),

          _dashedDivider(context),

          // Handling Fee
          _billRow(
            context,
            label: 'Handling Fee',
            trailingWidget: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '₹4',
                  style: TextStyle(
                    color: _textGrey,
                    fontSize: 13,
                    decoration: TextDecoration.lineThrough,
                    decorationColor: _textGrey,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'FREE',
                  style: TextStyle(
                    color: _emeraldGlow,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          // Thick separator
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              height: 1,
              color: Colors.white.withOpacity(0.06),
            ),
          ),

          // To Pay
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'To Pay',
                style: TextStyle(
                  color: _textWhite,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '₹${toPay.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: _textWhite,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _billRow(
    BuildContext context, {
    required String label,
    required Widget trailingWidget,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _textMuted,
              fontSize: 13,
            ),
          ),
          trailingWidget,
        ],
      ),
    );
  }

  Widget _dashedDivider(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const dashWidth = 4.0;
          const dashSpace = 3.0;
          final dashCount =
              (constraints.maxWidth / (dashWidth + dashSpace)).floor();
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(dashCount, (_) {
              return SizedBox(
                width: dashWidth,
                height: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // SAVINGS SUMMARY CARD
  // ═══════════════════════════════════════════════════════════

  Widget _buildSavingsSummary(
    BuildContext context,
    double totalSaved,
    double discountOnMrp,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _emerald.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _emerald.withOpacity(0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    LucideIcons.piggyBank,
                    color: _emeraldGlow,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Savings on this order',
                    style: TextStyle(
                      color: _emeraldGlow,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _emerald.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '₹${totalSaved.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (discountOnMrp > 0)
            _savingsLine('Discount on MRP', discountOnMrp),
          _savingsLine('Savings on Handling fee', _handlingFeeOriginal),
        ],
      ),
    );
  }

  Widget _savingsLine(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _emeraldGlow,
              fontSize: 12,
            ),
          ),
          Text(
            '- ₹${amount.toStringAsFixed(0)}',
            style: const TextStyle(
              color: _emeraldGlow,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // STICKY BOTTOM PAY BAR
  // ═══════════════════════════════════════════════════════════

  Widget _buildStickyBottom(BuildContext context, double toPay) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        16,
        MediaQuery.of(context).padding.bottom + 14,
      ),
      decoration: BoxDecoration(
        color: _bgDarker,
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Instant order hint
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  LucideIcons.zap,
                  color: Colors.white.withOpacity(0.35),
                  size: 13,
                ),
                const SizedBox(width: 4),
                Text(
                  'Instant Order – Pay while we deliver',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.35),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              // To Pay amount
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '₹${toPay.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: _textWhite,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Text(
                    'TOTAL',
                    style: TextStyle(
                      color: _textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Pay Now Button (Radiant luxury green gradient with high-end glow)
              GestureDetector(
                onTap: _placeOrder,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        _emerald,
                        _emeraldDark,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: _emerald.withOpacity(0.24),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Pay Now',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(
                        LucideIcons.arrowRight,
                        color: Colors.white,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // EMPTY CART
  // ═══════════════════════════════════════════════════════════

  Widget _buildEmptyCart(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.shoppingCart,
            color: Colors.white.withOpacity(0.15),
            size: 56,
          ),
          const SizedBox(height: 16),
          const Text(
            'Your cart is empty',
            style: TextStyle(
              color: _textWhite,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Add items from the shop to get started',
            style: TextStyle(
              color: _textMuted,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // SUCCESS SCREEN
  // ═══════════════════════════════════════════════════════════

  Widget _buildSuccessScreen(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: const BoxDecoration(
        color: _bgDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
      child: AnimatedBuilder(
        animation: _successController,
        builder: (context, _) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated check circle
              ScaleTransition(
                scale: _successScale,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: _emerald,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _emerald.withOpacity(0.35),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(
                    LucideIcons.check,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              FadeTransition(
                opacity: _successFade,
                child: Column(
                  children: [
                    const Text(
                      'Order Placed! 🎉',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _textWhite,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Your longevity essentials are on the way.\nEstimated delivery in 10 minutes.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _textMuted,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: _emerald.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _emerald.withOpacity(0.2)),
                      ),
                      child: const Text(
                        '🧬 Longevity markers will update automatically',
                        style: TextStyle(
                          color: _emeraldGlow,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          ref.read(cartProvider.notifier).clearCart();
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _emerald,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Continue Shopping',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
