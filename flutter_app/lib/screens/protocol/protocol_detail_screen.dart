import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../config/theme.dart';
import '../../data/protocol_repository.dart';
import '../../providers/protocol_provider.dart';
import '../../widgets/tc025/tc025_widgets.dart';

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
    final c = Theme.of(context).extension<ZyndioColors>()!;

    return ZyndioDetailScaffold(
      title: 'Protocol Details',
      onBack: () => context.pop(),
      // Bottom Activate Button
      bottomBar: isActive
          ? Container(
              width: double.infinity,
              height: 54,
              decoration: BoxDecoration(
                color: c.statusSuccessSubtle,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.check, color: c.statusSuccess, size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Actively Personalized',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: ZyndioType.family,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: c.statusSuccess,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : ZyndioGradientButton(
              label: 'Activate Protocol',
              trailingArrow: false,
              onTap: () {
                HapticFeedback.lightImpact();
                ref.read(protocolProvider.notifier).selectProtocol(protocol.id);
                context.pop();
              },
            ),
      children: [
        // ── Header Section ──
        ZyndioCard(
          radius: 24,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ZyndioPill(
                isAdvanced ? 'ADVANCED PROTOCOL' : 'MINI PROTOCOL',
                tone: isAdvanced ? ZyndioPillTone.success : ZyndioPillTone.brand,
              ),
              const SizedBox(height: 14),
              Text(
                protocol.title,
                style: ZyndioType.title1.copyWith(color: c.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                protocol.subtitle.toUpperCase(),
                style: TextStyle(
                  fontFamily: ZyndioType.family,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: c.textTertiary,
                  letterSpacing: 1.3,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // ── Description ──
        const ZyndioSectionLabel('The Blueprint'),
        ZyndioCard(
          child: Text(
            protocol.description.isNotEmpty
                ? protocol.description
                : 'A highly optimized regimen focusing on ${protocol.title.toLowerCase()} through precise habits.',
            style: TextStyle(
              fontFamily: ZyndioType.family,
              fontSize: 15,
              height: 22 / 15,
              color: c.textSecondary,
            ),
          ),
        ),

        // ── Target Metrics ──
        if (protocol.targetMetrics.isNotEmpty) ...[
          const SizedBox(height: 28),
          const ZyndioSectionLabel('Optimization Goals'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: protocol.targetMetrics.map((metric) {
              return ZyndioPill(metric);
            }).toList(),
          ),
        ],

        // ── What's Included ──
        const SizedBox(height: 28),
        const ZyndioSectionLabel('Protocol Pillars'),
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

        const SizedBox(height: 28),

        // ── Health Disclaimer ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: c.bgSunken,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            children: [
              Text(
                'HEALTH DISCLAIMER',
                style: TextStyle(
                  fontFamily: ZyndioType.family,
                  color: c.textTertiary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Consult a physician before starting any intense protocol, especially if you have a history of heart disease.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: ZyndioType.family,
                  color: c.textSecondary,
                  fontSize: 13,
                  height: 18 / 13,
                ),
              ),
            ],
          ),
        ),
      ],

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
    final c = Theme.of(context).extension<ZyndioColors>()!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: zyndioCard(context, radius: 22),
        child: Column(
          children: [
            GestureDetector(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                color: Colors.transparent,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: TextStyle(
                          fontFamily: ZyndioType.family,
                          fontSize: 16,
                          height: 22 / 16,
                          fontWeight: FontWeight.w600,
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                    ZyndioPill('${widget.items.length}'),
                    const SizedBox(width: 12),
                    Icon(
                      _isExpanded ? LucideIcons.minus : LucideIcons.plus,
                      color: c.textTertiary,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
            if (_isExpanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                child: Column(
                  children: widget.items.map((item) {
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: c.bgSunken,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: TextStyle(
                              fontFamily: ZyndioType.family,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: c.textPrimary,
                            ),
                          ),
                          if (item.detail.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              item.detail,
                              style: TextStyle(
                                fontFamily: ZyndioType.family,
                                fontSize: 13,
                                height: 18 / 13,
                                color: c.textSecondary,
                              ),
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
