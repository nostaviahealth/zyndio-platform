import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../config/theme.dart';
import '../../providers/nutrition_goals_provider.dart';
import '../../providers/patient_provider.dart';
import '../../providers/protocol_provider.dart';
import '../../services/azure_openai_service.dart';

class NutritionGoalsScreen extends ConsumerStatefulWidget {
  const NutritionGoalsScreen({super.key});

  @override
  ConsumerState<NutritionGoalsScreen> createState() => _NutritionGoalsScreenState();
}

class _NutritionGoalsScreenState extends ConsumerState<NutritionGoalsScreen> {
  late TextEditingController _calController;
  late TextEditingController _proController;
  late TextEditingController _carbController;
  late TextEditingController _fatController;
  bool _isLoadingAI = false;

  @override
  void initState() {
    super.initState();
    final goals = ref.read(nutritionGoalsProvider);
    _calController = TextEditingController(text: goals.calorieGoal.round().toString());
    _proController = TextEditingController(text: goals.proteinGoal.round().toString());
    _carbController = TextEditingController(text: goals.carbGoal.round().toString());
    _fatController = TextEditingController(text: goals.fatGoal.round().toString());
  }

  @override
  void dispose() {
    _calController.dispose();
    _proController.dispose();
    _carbController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  Future<void> _askAI() async {
    final profile = ref.read(patientProfileProvider).value;
    final protocol = ref.read(protocolProvider).selectedProtocol;
    
    if (profile == null) return;

    setState(() => _isLoadingAI = true);

    try {
      final aiService = AzureOpenAIService();
      final recommendation = await aiService.recommendNutritionGoals(
        profile: profile,
        protocol: protocol,
      );

      if (recommendation != null && mounted) {
        _animateToValues(
          recommendation['calories']!,
          recommendation['protein']!,
          recommendation['carbs']!,
          recommendation['fat']!,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI optimized your daily targets based on your protocol.'),
            backgroundColor: BrandColors.emerald500,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI Recommendation failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingAI = false);
    }
  }

  void _animateToValues(int cal, int pro, int carb, int fat) {
    // Simple population for now, could be animated later with a dedicated helper
    _calController.text = cal.toString();
    _proController.text = pro.toString();
    _carbController.text = carb.toString();
    _fatController.text = fat.toString();
  }

  Future<void> _save() async {
    final cal = double.tryParse(_calController.text) ?? 2000;
    final pro = double.tryParse(_proController.text) ?? 150;
    final carb = double.tryParse(_carbController.text) ?? 200;
    final fat = double.tryParse(_fatController.text) ?? 70;

    await ref.read(nutritionGoalsProvider.notifier).updateGoals(
      calories: cal,
      protein: pro,
      carbs: carb,
      fat: fat,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nutrition goals updated')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.nc.scaffoldBg,
      appBar: AppBar(
        title: Text('Nutrition Goals', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: context.nc.scaffoldBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold, color: BrandColors.emerald500, fontSize: 16)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily Targets',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: context.nc.textPrimary, letterSpacing: -0.5),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Configure your nutritional baseline.',
                        style: TextStyle(color: BrandColors.slate500, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _buildAIButton(),
              ],
            ),
            const SizedBox(height: 32),
            _GoalInput(
              label: 'Energy Goal',
              unit: 'kcal',
              controller: _calController,
              icon: LucideIcons.flame,
              color: BrandColors.orange500,
            ),
            const SizedBox(height: 16),
            _GoalInput(
              label: 'Protein Goal',
              unit: 'grams',
              controller: _proController,
              icon: LucideIcons.beef,
              color: BrandColors.red500,
            ),
            const SizedBox(height: 16),
            _GoalInput(
              label: 'Carbs Goal',
              unit: 'grams',
              controller: _carbController,
              icon: LucideIcons.wheat,
              color: const Color(0xFFD97706),
            ),
            const SizedBox(height: 16),
            _GoalInput(
              label: 'Fat Goal',
              unit: 'grams',
              controller: _fatController,
              icon: LucideIcons.droplet,
              color: BrandColors.blue500,
            ),
            const SizedBox(height: 32),
            _buildInfoCard(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildAIButton() {
    return GestureDetector(
      onTap: _isLoadingAI ? null : _askAI,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _isLoadingAI 
              ? (context.nc.isDark ? context.nc.cardSurface : BrandColors.slate200) 
              : context.nc.cardSurface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: BrandColors.emerald500.withOpacity(_isLoadingAI ? 0.1 : 0.3)),
          boxShadow: [
            if (!_isLoadingAI)
              BoxShadow(
                color: BrandColors.emerald500.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isLoadingAI) ...[
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: BrandColors.emerald500),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              _isLoadingAI ? 'Optimizing...' : 'Ask AI',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: _isLoadingAI ? BrandColors.slate500 : BrandColors.emerald500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.nc.isDark 
            ? context.nc.primary.withOpacity(0.15) 
            : BrandColors.emerald50.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BrandColors.emerald500.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: BrandColors.emerald500.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(LucideIcons.info, color: BrandColors.emerald500, size: 18),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'These goals serve as your baseline for calculating performance and metabolic recovery metrics.',
              style: TextStyle(fontSize: 13, color: BrandColors.emerald600, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalInput extends StatelessWidget {
  final String label;
  final String unit;
  final TextEditingController controller;
  final IconData icon;
  final Color color;

  const _GoalInput({
    required this.label,
    required this.unit,
    required this.controller,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.nc.cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.nc.cardBorder),
        boxShadow: [
          BoxShadow(
            color: BrandColors.dark.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: BrandColors.slate400,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: context.nc.textPrimary,
                          letterSpacing: -0.5,
                        ),
                        decoration: const InputDecoration(
                          hintText: '0',
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      unit,
                      style: TextStyle(
                        fontSize: 14,
                        color: BrandColors.slate400.withOpacity(0.8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
