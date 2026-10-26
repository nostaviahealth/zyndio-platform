import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../config/theme.dart';
import '../../data/protocol_repository.dart';
import '../wearables/widgets/dashboard_card_style.dart';
import '../../providers/protocol_provider.dart';
import '../../providers/patient_provider.dart';
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
    final protocolState = ref.watch(protocolProvider);
    final advancedProtocols = protocolState.adminProtocols;
    final miniProtocols = protocolState.addonProtocols.where((p) => !p.isPremium && !p.id.startsWith('custom-')).toList();
    final customProtocols = protocolState.addonProtocols.where((p) => p.id.startsWith('custom-')).toList();
    final userPlan = ref.watch(patientProfileProvider).value?.subscriptionPlan ?? 'free';

    return Scaffold(
      backgroundColor: context.nc.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: context.nc.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Protocol Library',
          style: TextStyle(
            color: context.nc.textPrimary, 
            fontWeight: FontWeight.w800, 
            fontSize: 18,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: protocolState.isLoading
          ? Center(child: CircularProgressIndicator(color: context.nc.textPrimary))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Advanced Protocols",
                    style: TextStyle(
                      fontSize: 16, 
                      fontWeight: FontWeight.w700, 
                      color: context.nc.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Personalized by your physician",
                    style: TextStyle(fontSize: 13, color: context.nc.textSecondary),
                  ),
                  const SizedBox(height: 16),

                  if (advancedProtocols.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: DashboardCardStyle.decorationOf(context),
                      child: Row(
                        children: [
                          Icon(LucideIcons.info, color: context.nc.textSecondary, size: 18),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "No protocol yet. Complete onboarding.",
                              style: TextStyle(color: context.nc.textSecondary, fontSize: 13),
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

                  const SizedBox(height: 32),

                  // CUSTOM AI PROTOCOLS Section
                  if (customProtocols.isNotEmpty) ...[
                    Row(
                      children: [
                        Text(
                          "Custom AI Protocols",
                          style: TextStyle(
                            fontSize: 16, 
                            fontWeight: FontWeight.w700, 
                            color: context.nc.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
                          ),
                          child: const Text(
                            'AI',
                            style: TextStyle(
                              fontSize: 10, 
                              fontWeight: FontWeight.w900, 
                              color: Color(0xFF818CF8),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Generated from your Intelligence chats",
                      style: TextStyle(fontSize: 13, color: context.nc.textSecondary),
                    ),
                    const SizedBox(height: 16),

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
                    const SizedBox(height: 32),
                  ],

                  // MINI PROTOCOLS Section
                  Text(
                    "Mini Protocols",
                    style: TextStyle(
                      fontSize: 16, 
                      fontWeight: FontWeight.w700, 
                      color: context.nc.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Simple routines for specific goals",
                    style: TextStyle(fontSize: 13, color: context.nc.textSecondary),
                  ),
                  const SizedBox(height: 16),

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

                  const SizedBox(height: 80),
                ],
              ),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onSelect,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: DashboardCardStyle.decorationOf(context).copyWith(
            border: isActive 
                ? Border.all(color: BrandColors.emerald500, width: 2)
                : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      protocol.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isLocked ? context.nc.textTertiary : context.nc.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      protocol.subtitle.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11, 
                        fontWeight: FontWeight.w700,
                        color: context.nc.textSecondary,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (isLocked)
                Icon(LucideIcons.lock, color: context.nc.textTertiary, size: 18)
              else if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: BrandColors.emerald500,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: BrandColors.emerald500.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Text(
                    'Active',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                )
              else
                Icon(LucideIcons.chevronRight, color: context.nc.textTertiary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

