import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../config/theme.dart';
import '../../data/protocol_repository.dart';
import '../../providers/protocol_provider.dart';

class ProtocolDetailScreen extends ConsumerWidget {
  final ProtocolData protocol;
  final bool isAdvanced;

  const ProtocolDetailScreen({
    super.key,
    required this.protocol,
    this.isAdvanced = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final protocolState = ref.watch(protocolProvider);
    final isActive = protocolState.selectedProtocolId == protocol.id;

    return Scaffold(
      backgroundColor: context.nc.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.nc.scaffoldBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        centerTitle: true,
        title: const Text(
          'Protocol Details',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: Stack(
        children: [
          // ── Siri-style Background Glows ──
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    BrandColors.indigo900.withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    BrandColors.emerald500.withOpacity(0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 120, 20, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header Section ──
                Center(
                  child: Column(
                    children: [
                      _GlassPill(
                        text: isAdvanced ? 'ADVANCED PROTOCOL' : 'MINI PROTOCOL',
                        color: isAdvanced ? BrandColors.emerald500 : Colors.white70,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        protocol.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -1.0,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        protocol.subtitle.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withOpacity(0.5),
                          letterSpacing: 2.0,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // ── Description ──
                const _SectionLabel(label: 'The Blueprint'),
                const SizedBox(height: 12),
                _GlassCard(
                  child: Text(
                    protocol.description.isNotEmpty
                        ? protocol.description
                        : 'A highly optimized regimen focusing on ${protocol.title.toLowerCase()} through precise habits.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: Colors.white.withOpacity(0.8),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),

                // ── Target Metrics ──
                if (protocol.targetMetrics.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  const _SectionLabel(label: 'Optimization Goals'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: protocol.targetMetrics.map((metric) {
                      return _GlassPill(
                        text: metric,
                        color: Colors.white,
                        fontSize: 11,
                      );
                    }).toList(),
                  ),
                ],

                // ── What's Included ──
                const SizedBox(height: 32),
                const _SectionLabel(label: 'Protocol Pillars'),
                const SizedBox(height: 12),
                _ExpandableSection(
                  title: 'Lifestyle Habits',
                  items: protocol.lifestyle.map((t) => _TaskPreview(title: t.title, detail: t.detail)).toList(),
                ),
                _ExpandableSection(
                  title: 'Dietary Directives',
                  items: protocol.diet.features.map((f) => _TaskPreview(title: f, detail: '')).toList(),
                ),
                _ExpandableSection(
                  title: 'Fitness Breakdown',
                  items: protocol.fitness.map((t) => _TaskPreview(title: t.title, detail: t.detail)).toList(),
                ),
                _ExpandableSection(
                  title: 'Key Supplementation',
                  items: protocol.supplements.map((t) => _TaskPreview(title: t.title, detail: t.detail)).toList(),
                ),

                const SizedBox(height: 40),
                
                // ── Health Disclaimer ──
                _GlassCard(
                  child: Column(
                    children: [
                      const Text(
                        'HEALTH DISCLAIMER',
                        style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.0),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Consult a physician before starting any intense protocol, especially if you have a history of heart disease.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      
      // Bottom Activate Button
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            color: BrandColors.dark.withOpacity(0.8),
            padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + MediaQuery.of(context).padding.bottom),
            child: isActive
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      color: BrandColors.emerald500.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: BrandColors.emerald500.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(LucideIcons.check, color: BrandColors.emerald500, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Actively Personalized',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: BrandColors.emerald500,
                          ),
                        ),
                      ],
                    ),
                  )
                : GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      ref.read(protocolProvider.notifier).selectProtocol(protocol.id);
                      context.pop();
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [BrandColors.emerald500, Color(0xFF0D9488)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: BrandColors.emerald500.withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Text(
                        'Activate Protocol',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ── ELEGANT GLASS UTILITIES ──

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});
  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        color: Colors.white.withOpacity(0.4),
        letterSpacing: 1.5,
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  const _GlassCard({required this.child, this.padding});
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: padding ?? const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            borderRadius: BorderRadius.circular(24),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _GlassPill extends StatelessWidget {
  final String text;
  final Color color;
  final double fontSize;
  const _GlassPill({required this.text, this.color = Colors.white, this.fontSize = 10});
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(100),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            border: Border.all(color: color.withOpacity(0.2)),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(
            text,
            style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5),
          ),
        ),
      ),
    );
  }
}

class _ExpandableSection extends StatefulWidget {
  final String title;
  final List<_TaskPreview> items;

  const _ExpandableSection({
    required this.title,
    required this.items,
  });

  @override
  State<_ExpandableSection> createState() => _ExpandableSectionState();
}

class _ExpandableSectionState extends State<_ExpandableSection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _GlassCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            GestureDetector(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                color: Colors.transparent,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${widget.items.length}',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white.withOpacity(0.5)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      _isExpanded ? LucideIcons.minus : LucideIcons.plus,
                      color: Colors.white38,
                      size: 14,
                    ),
                  ],
                ),
              ),
            ),
            if (_isExpanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  children: widget.items.map((item) {
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                          if (item.detail.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              item.detail,
                              style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5)),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TaskPreview {
  final String title;
  final String detail;
  _TaskPreview({required this.title, required this.detail});
}
