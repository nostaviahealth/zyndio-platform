import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../config/theme.dart';
import '../../widgets/app_card.dart';

/// Tools screen matching React Tools.tsx
class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Health Tools',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Calculate and track your health metrics',
            style: TextStyle(color: BrandColors.slate500, fontSize: 14),
          ),
          const SizedBox(height: 24),

          // Calculators Section
          Text(
            'Calculators',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          _ToolCard(
            icon: LucideIcons.calculator,
            title: 'BMI Calculator',
            description: 'Calculate your Body Mass Index',
            color: BrandColors.blue500,
          ),
          _ToolCard(
            icon: LucideIcons.flame,
            title: 'Calorie Calculator',
            description: 'Estimate your daily calorie needs',
            color: BrandColors.orange500,
          ),
          _ToolCard(
            icon: LucideIcons.heart,
            title: 'Heart Rate Zones',
            description: 'Calculate your training heart rate zones',
            color: BrandColors.red500,
          ),
          _ToolCard(
            icon: LucideIcons.droplet,
            title: 'Water Intake',
            description: 'Calculate your daily hydration needs',
            color: BrandColors.blue400,
          ),
          const SizedBox(height: 24),

          // Trackers Section
          Text(
            'Trackers',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          _ToolCard(
            icon: LucideIcons.moon,
            title: 'Sleep Tracker',
            description: 'Log and analyze your sleep patterns',
            color: BrandColors.indigo500,
          ),
          _ToolCard(
            icon: LucideIcons.utensils,
            title: 'Food Journal',
            description: 'Track your meals and nutrition',
            color: BrandColors.emerald500,
          ),
          _ToolCard(
            icon: LucideIcons.activity,
            title: 'Workout Log',
            description: 'Record your exercise sessions',
            color: BrandColors.purple500,
          ),
          const SizedBox(height: 24),

          const SizedBox(height: 120),
        ],
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _ToolCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$title is coming soon!'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: BrandColors.slate800,
            ),
          );
        },
        padding: const EdgeInsets.all(16),
        borderRadius: BorderRadius.circular(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 24, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: BrandColors.dark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: BrandColors.slate500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              LucideIcons.chevronRight,
              size: 20,
              color: BrandColors.slate400,
            ),
          ],
        ),
      ),
    );
  }
}
