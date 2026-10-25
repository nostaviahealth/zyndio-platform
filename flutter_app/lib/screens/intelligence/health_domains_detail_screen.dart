import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../config/theme.dart';
import '../../providers/intelligence_provider.dart';
import '../../models/intelligence_data.dart';

class HealthDomainsDetailScreen extends ConsumerStatefulWidget {
  const HealthDomainsDetailScreen({super.key});

  @override
  ConsumerState<HealthDomainsDetailScreen> createState() => _HealthDomainsDetailScreenState();
}

class _HealthDomainsDetailScreenState extends ConsumerState<HealthDomainsDetailScreen> {
  // Map to track expanded state
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
          "Health Domains", 
          style: TextStyle(color: context.nc.textPrimary, fontWeight: FontWeight.w600, fontSize: 17)
        ),
      ),
      body: intelligenceAsync.when(
        data: (data) {
          if (data == null || data.healthDomains.isEmpty) {
            return const Center(child: Text('No health domain data available.'));
          }
          final domains = data.healthDomains;
          
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                 child: Padding(
                   padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                   child: Text(
                     "Physiological Systems",
                     style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: context.nc.textPrimary, letterSpacing: -0.4),
                   ),
                 ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final domain = domains[index];
                      final isExpanded = _expandedItems[domain.name] ?? false;
                      return _buildDomainCard(domain, isExpanded);
                    },
                    childCount: domains.length,
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

  Color _getColor(String grade) {
    if (grade.startsWith('A')) return const Color(0xFF34C759); // iOS Green
    if (grade.startsWith('B')) return const Color(0xFF007AFF); // iOS Blue
    if (grade.startsWith('C')) return const Color(0xFFFF9500); // iOS Orange
    if (grade.startsWith('D')) return const Color(0xFFFF3B30); // iOS Red
    return const Color(0xFF8E8E93); // iOS Gray
  }

  String _getEffectiveGrade(int score, String? backendGrade) {
    if (backendGrade != null && backendGrade.isNotEmpty && backendGrade != '-') return backendGrade;
    if (score >= 90) return 'A';
    if (score >= 80) return 'B';
    if (score >= 70) return 'C';
    if (score >= 60) return 'D';
    return 'F';
  }

  Widget _buildDomainCard(HealthDomain domain, bool isExpanded) {
    // 1. Determine Colors
    final grade = _getEffectiveGrade(domain.score, domain.grade);
    final color = _getColor(grade);
    
    // 2. Determine Icon
    IconData iconData = LucideIcons.activity;
    final name = domain.name.toLowerCase();
    if (name.contains('heart') || name.contains('cardio')) {
      iconData = LucideIcons.heart;
    } else if (name.contains('metabolic')) iconData = LucideIcons.flame;
    else if (name.contains('immune')) iconData = LucideIcons.zap;
    else if (name.contains('hormonal')) iconData = LucideIcons.activity;
    else if (name.contains('longevity')) iconData = LucideIcons.hourglass; 
    else if (name.contains('liver')) iconData = LucideIcons.droplet;
    else if (name.contains('kidney')) iconData = LucideIcons.droplet;

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
          // Header Row
          InkWell(
            onTap: () {
              setState(() {
                _expandedItems[domain.name] = !isExpanded;
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                   // Icon Circle
                   Container(
                     width: 40,
                     height: 40,
                     decoration: BoxDecoration(
                       shape: BoxShape.circle,
                       color: color,
                     ),
                     child: Icon(iconData, color: Colors.white, size: 20),
                   ),
                   const SizedBox(width: 14),
                   
                   // Title & Status
                   Expanded(
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Text(
                           domain.name,
                           style: TextStyle(
                             fontSize: 17,
                             fontWeight: FontWeight.w600,
                             color: context.nc.textPrimary,
                             letterSpacing: -0.4,
                           ),
                         ),
                         const SizedBox(height: 2),
                         Text(
                           'Target: Grade ${domain.targetGrade ?? "B+"}',
                           style: TextStyle(
                             fontSize: 13,
                             color: context.nc.textTertiary,
                           ),
                         ),
                       ],
                     ),
                   ),

                   // Grade Badge
                   Container(
                     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                     decoration: BoxDecoration(
                       color: color.withOpacity(0.15),
                       borderRadius: BorderRadius.circular(8),
                     ),
                     child: Text(
                       grade,
                       style: TextStyle(
                         fontSize: 16,
                         fontWeight: FontWeight.bold,
                         color: color,
                       ),
                     ),
                   ),
                   const SizedBox(width: 8),
                   Icon(
                      isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: context.nc.textTertiary,
                      size: 20,
                    ),
                ],
              ),
            ),
          ),
          
          // Expanded Content (Description)
          if (isExpanded && domain.description != null) ...[
             Padding(
               padding: const EdgeInsets.symmetric(horizontal: 16),
               child: Divider(height: 1, color: context.nc.divider),
             ),
             Padding(
               padding: const EdgeInsets.all(20),
               child: Row(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Expanded(
                     child: Text(
                       domain.description!,
                       style: TextStyle(
                         fontSize: 15,
                         color: context.nc.textSecondary,
                         height: 1.5,
                       ),
                     ),
                   ),
                 ],
               ),
             ),
          ]
        ],
      ),
    );
  }
}
