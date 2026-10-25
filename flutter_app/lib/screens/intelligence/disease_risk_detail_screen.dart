import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../config/theme.dart';
import '../../providers/intelligence_provider.dart';
import '../../models/intelligence_data.dart';
import '../../widgets/health_disclaimer_banner.dart';

class DiseaseRiskDetailScreen extends ConsumerStatefulWidget {
  const DiseaseRiskDetailScreen({super.key});

  @override
  ConsumerState<DiseaseRiskDetailScreen> createState() => _DiseaseRiskDetailScreenState();
}

class _DiseaseRiskDetailScreenState extends ConsumerState<DiseaseRiskDetailScreen> {
  // Map to track expanded state of each item by condition name
  final Map<String, bool> _expandedItems = {};

  @override
  Widget build(BuildContext context) {
    final intelligenceAsync = ref.watch(intelligenceDataProvider);

    return Scaffold(
      backgroundColor: context.nc.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.nc.scaffoldBg,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: context.nc.primary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          "Disease Risk Analysis", 
          style: TextStyle(color: context.nc.textPrimary, fontWeight: FontWeight.w600, fontSize: 17)
        ),
      ),
      body: intelligenceAsync.when(
        data: (data) {
          if (data == null || data.diseaseRisks.isEmpty) {
            return const Center(child: Text('No disease risk data available.'));
          }
          final risks = data.diseaseRisks;
          
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                 child: Padding(
                   padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                   child: Text(
                     "Risk Assessment",
                     style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: context.nc.textPrimary, letterSpacing: -0.4),
                   ),
                 ),
              ),
              SliverToBoxAdapter(
                 child: Padding(
                   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                   child: HealthDisclaimerBanner(message: DisclaimerMessages.diseaseRisk),
                 ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final risk = risks[index];
                      final isExpanded = _expandedItems[risk.condition] ?? false;
                      return _buildExpandableRiskCard(risk, isExpanded);
                    },
                    childCount: risks.length,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildExpandableRiskCard(DiseaseRisk risk, bool isExpanded) {
    Color levelColor;

    switch (risk.level.toLowerCase()) {
      case 'low':
        levelColor = const Color(0xFF34C759); // iOS Green
        break;
      case 'moderate':
        levelColor = const Color(0xFFFF9500); // iOS Orange
        break;
      case 'high':
        levelColor = const Color(0xFFFF3B30); // iOS Red
        break;
      default:
        levelColor = const Color(0xFF8E8E93); // iOS Gray
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: context.nc.cardSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
           BoxShadow(
            color: context.nc.shadowColor,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ]
      ),
      child: Column(
        children: [
          // Header Row (Always Visible)
          InkWell(
            onTap: () {
              setState(() {
                _expandedItems[risk.condition] = !isExpanded;
              });
            },
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(16),
              bottom: isExpanded ? Radius.zero : const Radius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Circular Percentage Indication
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: CircularProgressIndicator(
                          value: risk.probability / 100,
                          backgroundColor: context.nc.inputFill,
                          valueColor: AlwaysStoppedAnimation(levelColor),
                          strokeWidth: 4,
                        ),
                      ),
                      Text(
                        '${risk.probability}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: levelColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  
                  // Title & Level
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          risk.condition,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: context.nc.textPrimary,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${risk.level} Risk',
                          style: TextStyle(
                            fontSize: 13,
                            color: levelColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Expand Icon
                 Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: context.nc.textTertiary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // Expanded Content
          if (isExpanded) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Divider(height: 1, color: context.nc.divider),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Description
                  if (risk.smartDescription != null) 
                     Text(
                        risk.smartDescription!,
                        style: TextStyle(
                          fontSize: 15,
                          color: context.nc.textSecondary,
                          height: 1.5,
                        ),
                     ),
                  
                  const SizedBox(height: 24),

                  // Inset Grouped Style Lists
                  _buildSectionHeader("RISK DRIVERS"),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: context.nc.inputFill,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: risk.drivers.map((driver) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Icon(Icons.circle, size: 6, color: context.nc.textTertiary),
                            const SizedBox(width: 8),
                            Expanded(child: Text(driver, style: TextStyle(fontSize: 14, color: context.nc.textSecondary))),
                          ],
                        ),
                      )).toList(),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  _buildSectionHeader("MITIGATION STRATEGY"),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: context.nc.inputFill,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      risk.mitigationStrategy ?? 'Consult your Zyndio protocol for specific recommendations.',
                      style: TextStyle(fontSize: 14, color: context.nc.textSecondary, height: 1.4),
                    ),
                  ),

                  const SizedBox(height: 24),
                  
                  // Verification (Small text)
                  Row(
                    children: [
                      Icon(LucideIcons.shieldCheck, size: 14, color: context.nc.textTertiary),
                      const SizedBox(width: 6),
                      Text(
                        'Verified via ${risk.primaryValidation ?? "Expert Wellness Standards"}',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.nc.textTertiary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title, 
        style: TextStyle(
          fontSize: 12, 
          fontWeight: FontWeight.w600, 
          color: context.nc.textTertiary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

}
