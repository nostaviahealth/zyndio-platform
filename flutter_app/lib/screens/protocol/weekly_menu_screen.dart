import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/patient_provider.dart';
import '../../data/meal_repository.dart';
import '../../data/free_meal_plans.dart';
import '../../models/meal_plan.dart';
import '../../widgets/weekly_menu_card.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/tc025/tc025_widgets.dart';
import '../../config/theme.dart';

class WeeklyMenuScreen extends ConsumerWidget {
  const WeeklyMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientAsync = ref.watch(patientProfileProvider);
    final profile = patientAsync.value;
    final profileId = profile?.id;
    final isFreeUser = profile == null ||
        (!profile.isPremium && profile.subscriptionPlan == 'free');

    return ZyndioDetailScaffold(
      title: 'Weekly Menu',
      onBack: () => Navigator.pop(context),
      children: [
        isFreeUser
            ? _buildFreePlan(context)
            : _buildPaidPlan(context, profileId),
      ],
    );
  }

  // ── Free users: show local Indian vegetarian plan ──
  Widget _buildFreePlan(BuildContext context) {
    final plan = getFreeMealPlan();
    return Column(
      children: [
        WeeklyMenuCard(plan: plan),
      ],
    );
  }

  // ── Paid users: fetch admin-curated plan from Supabase ──
  Widget _buildPaidPlan(BuildContext context, String? profileId) {
    return FutureBuilder<MealPlan?>(
      future: MealRepository.fetchApprovedPlan(profileId),
      builder: (context, snapshot) {
        final c = context.zc;
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SkeletonCard(height: 400, borderRadius: BorderRadius.circular(20));
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              "Error: ${snapshot.error}",
              textAlign: TextAlign.center,
              style: ZyndioType.subhead.copyWith(color: c.textSecondary),
            ),
          );
        }

        final plan = snapshot.data;

        if (plan != null) {
          return WeeklyMenuCard(plan: plan);
        }

        return Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 100),
            child: Column(
              children: [
                Icon(Icons.restaurant_menu, size: 48, color: c.textTertiary),
                const SizedBox(height: 16),
                Text(
                  "Your personalised menu is being prepared by our nutritionist.",
                  textAlign: TextAlign.center,
                  style: ZyndioType.subhead.copyWith(color: c.textSecondary),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
