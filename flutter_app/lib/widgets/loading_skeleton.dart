import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../config/theme.dart';
import 'tc025/tc025_widgets.dart';

/// Shimmer colours from the Zyndio tokens (light and dark).
Color _base(BuildContext context) => context.zc.borderSubtle;
Color _highlight(BuildContext context) => context.zc.bgSunken;

/// Enhanced Skeleton card widget with better gradients and structure
class SkeletonCard extends StatelessWidget {
  final double height;
  final double? width;
  final BorderRadius? borderRadius;
  final Widget? child;

  const SkeletonCard({
    super.key,
    required this.height,
    this.width,
    this.borderRadius,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: _base(context),
      highlightColor: _highlight(context),
      period: const Duration(milliseconds: 1500),
      child: Container(
        height: height,
        width: width ?? double.infinity,
        decoration: BoxDecoration(
          color: _base(context),
          borderRadius: borderRadius ?? BorderRadius.circular(24),
          border: Border.all(color: context.zc.borderSubtle, width: 1),
        ),
        child: child,
      ),
    );
  }
}

/// Circular skeleton for icons or profile pics
class SkeletonCircle extends StatelessWidget {
  final double size;

  const SkeletonCircle({super.key, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: _base(context),
      highlightColor: _highlight(context),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: _base(context),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// Skeleton line for text placeholders
class SkeletonLine extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonLine({
    super.key,
    required this.width,
    this.height = 12,
    this.borderRadius = 6,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: _base(context),
      highlightColor: _highlight(context),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: _base(context),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

/// Specialized skeleton for a Task Row
class SkeletonTaskRow extends StatelessWidget {
  const SkeletonTaskRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: zyndioCard(context, radius: 16),
      child: Row(
        children: [
          const SkeletonCard(height: 24, width: 24, borderRadius: BorderRadius.all(Radius.circular(8))),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonLine(width: 120, height: 14),
                const SizedBox(height: 6),
                const SkeletonLine(width: 180, height: 10),
              ],
            ),
          ),
          const SizedBox(width: 16),
          const SkeletonLine(width: 40, height: 18, borderRadius: 8),
        ],
      ),
    );
  }
}

/// Specialized skeleton for Category Cards
class SkeletonCategoryCard extends StatelessWidget {
  const SkeletonCategoryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: zyndioCard(context, radius: 20),
      child: Row(
        children: [
          const SkeletonCircle(size: 48),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonLine(width: 100, height: 16),
                const SizedBox(height: 6),
                const SkeletonLine(width: 140, height: 12),
              ],
            ),
          ),
          const SkeletonCircle(size: 24),
        ],
      ),
    );
  }
}

/// Loading skeleton for dashboard stats
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(flex: 5, child: const SkeletonCard(height: 180)),
              const SizedBox(width: 16),
              Expanded(flex: 3, child: const SkeletonCard(height: 180)),
            ],
          ),
          const SizedBox(height: 16),
          const SkeletonCard(height: 160),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(flex: 2, child: const SkeletonCard(height: 280)),
              const SizedBox(width: 16),
              Expanded(flex: 1, child: const SkeletonCard(height: 280)),
            ],
          ),
          const SizedBox(height: 16),
          const SkeletonCard(height: 200),
        ],
      ),
    );
  }
}
