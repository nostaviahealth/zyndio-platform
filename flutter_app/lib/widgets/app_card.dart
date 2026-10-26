import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Zyndio styled card widget
/// Matches the React card designs with rounded corners and subtle shadows
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final Color? borderColor;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.borderColor,
    this.onTap,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final nc = context.nc;
    final radius = borderRadius ?? BorderRadius.circular(24);
    
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: nc.shadowColor,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(
            sigmaX: nc.isDark ? 20 : 0, 
            sigmaY: nc.isDark ? 20 : 0,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: backgroundColor ?? nc.cardSurface,
              borderRadius: radius,
              border: Border.all(
                color: borderColor ?? nc.cardBorder,
                width: 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: onTap != null
                  ? InkWell(
                      onTap: onTap,
                      child: Padding(
                        padding: padding ?? const EdgeInsets.all(20),
                        child: child,
                      ),
                    )
                  : Padding(
                      padding: padding ?? const EdgeInsets.all(20),
                      child: child,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Colored accent card (like the rhythm cards in Home)
class AccentCard extends StatelessWidget {
  final Widget child;
  final Color backgroundColor;
  final Color borderColor;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  const AccentCard({
    super.key,
    required this.child,
    required this.backgroundColor,
    required this.borderColor,
    this.onTap,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      backgroundColor: backgroundColor,
      borderColor: borderColor,
      onTap: onTap,
      padding: padding ?? const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(16),
      child: child,
    );
  }
}

/// Dark themed card (like the Daily Wisdom card)
class DarkCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  const DarkCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: BrandColors.dark,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: BrandColors.dark.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: onTap != null
              ? InkWell(
                  onTap: onTap,
                  child: Padding(
                    padding: padding ?? const EdgeInsets.all(20),
                    child: child,
                  ),
                )
              : Padding(
                  padding: padding ?? const EdgeInsets.all(20),
                  child: child,
                ),
        ),
      ),
    );
  }
}
