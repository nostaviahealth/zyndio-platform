import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../config/theme.dart';

class MedicalConciergeSection extends StatelessWidget {
  const MedicalConciergeSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.0),
          child: Text(
            "Wellness Concierge",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: BrandColors.dark,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ConciergeCard(
                title: "Health\nConsultant",
                subtitle: "20 min consultation",
                limit: "1 session / month",
                icon: LucideIcons.stethoscope,
                color: BrandColors.blue600,
                onTap: () {
                  _showBookingDialog(context, "Health Consultant");
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ConciergeCard(
                title: "Wellness\nNutritionist",
                subtitle: "20 min optimization",
                limit: "2 sessions / month",
                icon: LucideIcons.apple, // or Leaf
                color: BrandColors.emerald600,
                onTap: () {
                   _showBookingDialog(context, "Nutritionist");
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showBookingDialog(BuildContext context, String serviceName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Book $serviceName'),
        content: const Text('In-app booking is coming soon. Please contact your health coach or support to schedule a session.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _ConciergeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String limit;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ConciergeCard({
    required this.title,
    required this.subtitle,
    required this.limit,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: BrandColors.slate200),
          boxShadow: [
            BoxShadow(
              color: BrandColors.slate400.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon Badge
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 16),
              
              // Title
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: BrandColors.dark,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              
              // Subtitle (Duration)
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: BrandColors.slate500,
                ),
              ),
              const SizedBox(height: 12),
              
              // Limit Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: BrandColors.slate100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  limit,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: BrandColors.slate600,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Button
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Text(
                  "Book Now",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
