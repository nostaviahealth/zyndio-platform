import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../config/theme.dart';
import '../../data/protocol_repository.dart';
import '../../providers/protocol_provider.dart';
import '../../providers/patient_provider.dart';
import '../../widgets/tc025/tc025_widgets.dart';
import 'protocol_detail_screen.dart';

class ProtocolsListScreen extends ConsumerStatefulWidget {
  const ProtocolsListScreen({super.key});

  @override
  ConsumerState<ProtocolsListScreen> createState() => _ProtocolsListScreenState();
}

class _ProtocolsListScreenState extends ConsumerState<ProtocolsListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = ref.read(patientProfileProvider).value;
      if (profile != null) {
        ref.read(protocolProvider.notifier).setProfileId(profile.id);
      }
    });
  }

  void _openProtocolDetail(ProtocolData protocol, bool isAdvanced, String userPlan) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProtocolDetailScreen(
          protocol: protocol,
          isAdvanced: isAdvanced,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.zc;
    final protocolState = ref.watch(protocolProvider);
    final advancedProtocols = protocolState.adminProtocols;
    final miniProtocols = protocolState.addonProtocols.where((p) => !p.isPremium && !p.id.startsWith('custom-')).toList();
    final customProtocols = protocolState.addonProtocols.where((p) => p.id.startsWith('custom-')).toList();
    final userPlan = ref.watch(patientProfileProvider).value?.subscriptionPlan ?? 'free';

    return ZyndioDetailScaffold(
      title: 'Protocol Library',
      onBack: () => context.pop(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
      children: protocolState.isLoading
          ? [
              Padding(
                padding: const EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator(color: c.brandPrimary)),
              ),
            ]
          : [
              const _SectionHeader(
                title: "Advanced Protocols",
                subtitle: "Personalized by your physician",
              ),

              if (advancedProtocols.isEmpty)
                ZyndioCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(LucideIcons.info, color: c.textSecondary, size: 18),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "No protocol yet. Complete onboarding.",
                          style: ZyndioType.subhead.copyWith(color: c.textSecondary),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...advancedProtocols.map((protocol) {
                  final isActive = protocolState.selectedProtocolId == protocol.id;
                  return _ProtocolCard(
                    protocol: protocol,
                    isActive: isActive,
                    isAdvanced: true,
                    isLocked: false,
                    onSelect: () => _openProtocolDetail(protocol, true, userPlan),
                  );
                }),

              const SizedBox(height: 28),

              // CUSTOM AI PROTOCOLS Section
              if (customProtocols.isNotEmpty) ...[
                const _SectionHeader(
                  title: "Custom AI Protocols",
                  subtitle: "Generated from your Intelligence chats",
                  badge: ZyndioPill('AI', tone: ZyndioPillTone.brand),
                ),

                ...customProtocols.map((protocol) {
                  final isActive = protocolState.selectedProtocolId == protocol.id;
                  return _ProtocolCard(
                    protocol: protocol,
                    isActive: isActive,
                    isAdvanced: false,
                    isLocked: false,
                    onSelect: () => _openProtocolDetail(protocol, false, userPlan),
                  );
                }),
                const SizedBox(height: 28),
              ],

              // MINI PROTOCOLS Section
              const _SectionHeader(
                title: "Mini Protocols",
                subtitle: "Simple routines for specific goals",
              ),

              ...miniProtocols.map((protocol) {
                final isActive = protocolState.selectedProtocolId == protocol.id;
                return _ProtocolCard(
                  protocol: protocol,
                  isActive: isActive,
                  isAdvanced: false,
                  isLocked: false,
                  onSelect: () => _openProtocolDetail(protocol, false, userPlan),
                );
              }),
            ],
    );
  }
}

/// Section title + one-line explainer, with an optional pill beside the title.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle, this.badge});

  final String title;
  final String subtitle;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final c = context.zc;
    final heading = Text(
      title,
      style: ZyndioType.headline.copyWith(color: c.textPrimary),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: badge == null
                ? heading
                : Row(
                    children: [
                      Flexible(child: heading),
                      const SizedBox(width: 8),
                      badge!,
                    ],
                  ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: ZyndioType.footnote.copyWith(color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ProtocolCard extends StatelessWidget {
  final ProtocolData protocol;
  final bool isActive;
  final bool isAdvanced;
  final bool isLocked;
  final VoidCallback onSelect;

  const _ProtocolCard({
    required this.protocol,
    required this.isActive,
    required this.isAdvanced,
    required this.isLocked,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.zc;
    final isCustom = protocol.id.startsWith('custom-');
    final (IconData icon, ZyndioTint tint) = isAdvanced
        ? (LucideIcons.clipboardList, ZyndioTint.violet)
        : isCustom
            ? (LucideIcons.sparkles, ZyndioTint.indigo)
            : (LucideIcons.listChecks, ZyndioTint.green);
    final base = zyndioCard(context, radius: 22);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onSelect,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: isActive
              ? base.copyWith(
                  border: Border.all(color: c.statusSuccess, width: 2))
              : base,
          child: Row(
            children: [
              ZyndioIconTile(icon: icon, tint: tint, size: 44),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      protocol.title,
                      style: ZyndioType.callout.copyWith(
                        height: 22 / 16,
                        fontWeight: FontWeight.w600,
                        color: isLocked ? c.textTertiary : c.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      protocol.subtitle.toUpperCase(),
                      style: TextStyle(
                        fontFamily: ZyndioType.family,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: c.textTertiary,
                        letterSpacing: 0.8,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (isLocked)
                Icon(LucideIcons.lock, color: c.textTertiary, size: 18)
              else if (isActive)
                ConstrainedBox(
                  constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width * 0.3),
                  child: const ZyndioPill('Active', tone: ZyndioPillTone.success),
                )
              else
                Icon(LucideIcons.chevronRight, color: c.textTertiary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
