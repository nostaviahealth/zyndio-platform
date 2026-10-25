import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../../../config/theme.dart';

class DashboardCardStyle {
  /// Static fallback (light mode only) — kept for backward compatibility
  static BoxDecoration get decoration => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(28),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.06),
        blurRadius: 24,
        offset: const Offset(0, 4),
      ),
      BoxShadow(
        color: Colors.black.withOpacity(0.03),
        blurRadius: 40,
        offset: const Offset(0, 12),
      ),
    ],
    border: Border.all(color: const Color(0xFFF1F5F9)),
  );

  /// Theme-aware decoration — use this in widgets with access to BuildContext
  static BoxDecoration decorationOf(BuildContext context) {
    final nc = context.nc;
    return BoxDecoration(
      color: nc.cardSurface,
      borderRadius: BorderRadius.circular(28),
      boxShadow: [
        BoxShadow(
          color: nc.shadowColor,
          blurRadius: 24,
          offset: const Offset(0, 4),
        ),
      ],
      border: Border.all(color: nc.cardBorder),
    );
  }
  
  static const EdgeInsets padding = EdgeInsets.all(24);
}

class DashboardCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final BoxDecoration? decoration;
  
  const DashboardCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.decoration,
  });

  @override
  Widget build(BuildContext context) {
    final defaultDeco = decoration ?? DashboardCardStyle.decorationOf(context);
    
    // In dark mode, apply true liquid glass blur
    if (context.nc.isDark) {
      return Padding(
        padding: margin ?? EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(
              width: width,
              height: height,
              padding: padding ?? DashboardCardStyle.padding,
              decoration: defaultDeco,
              child: child,
            ),
          ),
        ),
      );
    }
    
    // Light mode fallback
    return Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding ?? DashboardCardStyle.padding,
      decoration: defaultDeco,
      child: child,
    );
  }
}
