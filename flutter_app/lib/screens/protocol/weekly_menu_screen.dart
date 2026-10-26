import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../providers/patient_provider.dart';
import '../../data/meal_repository.dart';
import '../../data/free_meal_plans.dart';
import '../../models/meal_plan.dart';
import '../../widgets/weekly_menu_card.dart';
import '../../widgets/loading_skeleton.dart';
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

    return Scaffold(
      backgroundColor: context.nc.scaffoldBg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120.0,
            floating: false,
            pinned: true,
            backgroundColor: context.nc.scaffoldBg,
            elevation: 0,
            leading: IconButton(
              icon: Icon(LucideIcons.chevronLeft, color: context.nc.textPrimary),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: Text(
                'Weekly Menu',
                style: TextStyle(
                  color: context.nc.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: isFreeUser
                  ? _buildFreePlan(context)
                  : _buildPaidPlan(context, profileId),
            ),
          ),
        ],
      ),
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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SkeletonCard(height: 400, borderRadius: BorderRadius.circular(20));
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        final plan = snapshot.data;

        if (plan != null) {
          return WeeklyMenuCard(plan: plan);
        }

        return const Center(
          child: Padding(
            padding: EdgeInsets.only(top: 100),
            child: Column(
              children: [
                Icon(Icons.restaurant_menu, size: 48, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  "Your personalised menu is being prepared by our nutritionist.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
