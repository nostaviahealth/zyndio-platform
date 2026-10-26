import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../providers/questionnaire_provider.dart';
import '../../models/longevity_questionnaire.dart';
import '../../config/theme.dart';
import '../../widgets/app_card.dart';

class QuestionnaireScreen extends ConsumerStatefulWidget {
  const QuestionnaireScreen({super.key});

  @override
  ConsumerState<QuestionnaireScreen> createState() => _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends ConsumerState<QuestionnaireScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late LongevityQuestionnaire _answers;
  late TextEditingController _weightController;
  late TextEditingController _heightController;
  late TextEditingController _waistController;
  late TextEditingController _hipController;

  @override
  void initState() {
    super.initState();
    final existing = ref.read(questionnaireProvider);
    _answers = LongevityQuestionnaire.fromJson(existing.toJson());
    _weightController = TextEditingController(text: _answers.weightKg?.toString() ?? '');
    _heightController = TextEditingController(text: _answers.heightCm?.toString() ?? '');
    _waistController = TextEditingController(text: _answers.waistCm?.toString() ?? '');
    _hipController = TextEditingController(text: _answers.hipCm?.toString() ?? '');
  }

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    _waistController.dispose();
    _hipController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    FocusScope.of(context).unfocus();
    _pageController.nextPage(
        duration: const Duration(milliseconds: 500), curve: Curves.easeInOutCubic);
  }

  void _prevPage() {
    FocusScope.of(context).unfocus();
    _pageController.previousPage(
        duration: const Duration(milliseconds: 500), curve: Curves.easeInOutCubic);
  }

  void _saveAndExit() {
    _answers.isComplete = true;
    ref.read(questionnaireProvider.notifier).save(_answers);
    context.pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Longevity Profile Updated! Protocol Engine Unlocked."),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final questions = _getQuestions();
    final totalSteps = questions.length + 1;
    
    return Scaffold(
      backgroundColor: context.nc.scaffoldBg,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                context.nc.isDark ? const Color(0xFF0F172A) : context.nc.scaffoldBg,
                context.nc.scaffoldBg,
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(totalSteps),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (p) => setState(() => _currentPage = p),
                    itemCount: totalSteps + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) return _buildBodyCompositionPage();
                      if (index <= questions.length) return _buildQuestionPage(questions[index - 1]);
                      return _buildSummaryPage();
                    },
                  ),
                ),
                _buildFooter(totalSteps),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(int totalSteps) {
    final progress = _currentPage / totalSteps;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(LucideIcons.x, color: context.nc.textSecondary, size: 20),
                onPressed: () => context.pop(),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    "Longevity Assessment",
                    style: TextStyle(
                      color: context.nc.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: context.nc.divider.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(context.nc.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(int totalSteps) {
    final isFirst = _currentPage == 0;
    final isLast = _currentPage == totalSteps;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (!isFirst)
            GestureDetector(
              onTap: _prevPage,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: context.nc.cardBorder),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.chevronLeft, size: 18, color: context.nc.textSecondary),
                    const SizedBox(width: 4),
                    Text("Back", style: TextStyle(color: context.nc.textSecondary, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            )
          else
            const SizedBox.shrink(),
          
          if (isLast)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: ElevatedButton(
                  onPressed: _saveAndExit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.nc.textPrimary,
                    foregroundColor: context.nc.scaffoldBg,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 0,
                  ),
                  child: const Text("Unlock Longevity Protocol", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                ),
              ),
            )
          else if (_currentPage == 0)
             ElevatedButton(
                onPressed: _nextPage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.nc.textPrimary,
                  foregroundColor: context.nc.scaffoldBg,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 0,
                ),
                child: const Row(
                  children: [
                    Text("Continue", style: TextStyle(fontWeight: FontWeight.w800)),
                    SizedBox(width: 8),
                    Icon(LucideIcons.chevronRight, size: 18),
                  ],
                ),
              )
        ],
      ),
    );
  }

  Widget _buildBodyCompositionPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildQuestionHeader("⚖️", "Body Composition", "Foundation metrics for biological age calculation."),
          const SizedBox(height: 24),
          AppCard(
            child: Column(
              children: [
                _buildGenderPicker(),
                const SizedBox(height: 24),
                _buildDOBPicker(),
                const SizedBox(height: 24),
                _buildMeasurementInputs(),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildCalculatedPanel(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildQuestionPage(Map<String, dynamic> q) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildQuestionHeader(q['emoji'], q['section'], q['subtitle']),
          const SizedBox(height: 24),
          Text(
            q['question'],
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: context.nc.textPrimary,
              height: 1.3,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 32),
          if (q['type'] == 'choice')
            ...((q['options'] as List).map((opt) => _buildOptionCard(opt, q['field'], false)))
          else if (q['type'] == 'multi')
            ...((q['options'] as List).map((opt) => _buildOptionCard(opt, q['field'], true)))
          else if (q['type'] == 'slider')
             _buildSliderInput(q['field'], q['min'], q['max']),
          const SizedBox(height: 40),
          if (q['type'] == 'multi')
            ElevatedButton(
              onPressed: _nextPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: context.nc.textPrimary,
                foregroundColor: context.nc.scaffoldBg,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text("Confirm Selection", style: TextStyle(fontWeight: FontWeight.w800)),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: BrandColors.emerald500.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.checkCircle2, size: 80, color: BrandColors.emerald500),
          ),
          const SizedBox(height: 32),
          Text(
            "Assessment Complete",
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: context.nc.textPrimary, letterSpacing: -1),
          ),
          const SizedBox(height: 12),
          Text(
            "Our Protocol Engine is now ready to generate your longevity blueprint based on your 29 biomarkers.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: context.nc.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 40),
          AppCard(
            child: Column(
              children: [
                _buildSummaryRow("Body Composition", "Synced ⚖️"),
                _buildSummaryRow("Lifestyle & Habits", "Analyzed 🏃"),
                _buildSummaryRow("Stress Resilience", "Mapped 🧠"),
                _buildSummaryRow("Environmental Load", "Calculated 🌍"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String status) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: context.nc.textSecondary, fontWeight: FontWeight.w500)),
          Text(status, style: const TextStyle(color: BrandColors.emerald500, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildQuestionHeader(String emoji, String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 12),
            Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: context.nc.textTertiary,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(fontSize: 14, color: context.nc.textTertiary, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildOptionCard(String label, String field, bool isMulti) {
    final current = _getFieldValue(field);
    final isSelected = isMulti ? (current as List).contains(label) : current == label;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        HapticFeedback.lightImpact();
        setState(() {
          if (isMulti) {
            final list = List<String>.from(current as List);
            if (isSelected) list.remove(label); else list.add(label);
            _setFieldValue(field, list);
          } else {
            _setFieldValue(field, label);
            Future.delayed(const Duration(milliseconds: 400), _nextPage);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color: isSelected ? context.nc.textPrimary : context.nc.cardSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? context.nc.textPrimary : context.nc.cardBorder,
            width: 1.5,
          ),
          boxShadow: isSelected ? [
            BoxShadow(color: context.nc.textPrimary.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 4))
          ] : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? context.nc.scaffoldBg : context.nc.textPrimary,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
            if (isSelected)
              Icon(LucideIcons.checkCircle2, size: 20, color: context.nc.scaffoldBg)
            else
              Icon(LucideIcons.circle, size: 20, color: context.nc.cardBorder),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderInput(String field, int min, int max) {
    final value = _getFieldValue(field) as int;
    return Column(
      children: [
        Text(
          "$value",
          style: TextStyle(fontSize: 64, fontWeight: FontWeight.w900, color: context.nc.textPrimary, letterSpacing: -2),
        ),
        const SizedBox(height: 24),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: context.nc.textPrimary,
            inactiveTrackColor: context.nc.divider.withOpacity(0.1),
            thumbColor: context.nc.textPrimary,
            overlayColor: context.nc.textPrimary.withOpacity(0.1),
            trackHeight: 8,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
          ),
          child: Slider(
            value: value.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max - min,
            onChanged: (v) => setState(() => _setFieldValue(field, v.toInt())),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Minimum", style: TextStyle(color: context.nc.textTertiary, fontWeight: FontWeight.w600)),
            Text("Maximum", style: TextStyle(color: context.nc.textTertiary, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 40),
        ElevatedButton(
          onPressed: _nextPage,
          style: ElevatedButton.styleFrom(
            backgroundColor: context.nc.textPrimary,
            foregroundColor: context.nc.scaffoldBg,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: const Text("Next Question", style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }

  Widget _buildGenderPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("GENDER", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: context.nc.textTertiary, letterSpacing: 1)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildGenderButton("Male")),
            const SizedBox(width: 12),
            Expanded(child: _buildGenderButton("Female")),
          ],
        ),
      ],
    );
  }

  Widget _buildGenderButton(String label) {
    final isSelected = _answers.gender == label;
    return GestureDetector(
      onTap: () => setState(() => _answers.gender = label),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? context.nc.textPrimary : context.nc.inputFill,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? context.nc.scaffoldBg : context.nc.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDOBPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("DATE OF BIRTH", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: context.nc.textTertiary, letterSpacing: 1)),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime(1990),
              firstDate: DateTime(1920),
              lastDate: DateTime.now(),
            );
            if (picked != null) {
              setState(() => _answers.dateOfBirth = picked.toIso8601String().split('T').first);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.nc.inputFill,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.calendar, size: 18, color: context.nc.textTertiary),
                const SizedBox(width: 12),
                Text(
                  _answers.dateOfBirth.isNotEmpty ? _answers.dateOfBirth : "Select Date",
                  style: TextStyle(color: context.nc.textPrimary, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMeasurementInputs() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildFieldInput("Weight", "kg", _weightController, (v) => _answers.weightKg = double.tryParse(v))),
            const SizedBox(width: 12),
            Expanded(child: _buildFieldInput("Height", "cm", _heightController, (v) => _answers.heightCm = double.tryParse(v))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildFieldInput("Waist", "cm", _waistController, (v) => _answers.waistCm = double.tryParse(v))),
            const SizedBox(width: 12),
            Expanded(child: _buildFieldInput("Hip", "cm", _hipController, (v) => _answers.hipCm = double.tryParse(v))),
          ],
        ),
      ],
    );
  }

  Widget _buildFieldInput(String label, String unit, TextEditingController controller, Function(String) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: context.nc.textTertiary, letterSpacing: 1)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          onChanged: (v) {
            onChanged(v);
            setState(() {});
          },
          style: TextStyle(color: context.nc.textPrimary, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            filled: true,
            fillColor: context.nc.inputFill,
            suffixText: unit,
            suffixStyle: TextStyle(color: context.nc.textTertiary, fontSize: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildCalculatedPanel() {
    final bmi = _answers.bmi;
    final whr = _answers.waistToHipRatio;
    if (bmi == null && whr == null) return const SizedBox.shrink();

    return AppCard(
      backgroundColor: context.nc.isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              if (bmi != null) _buildMetric("BMI", bmi.toStringAsFixed(1), _getBmiColor(bmi)),
              if (whr != null) _buildMetric("WAIST:HIP", whr.toStringAsFixed(2), whr > 0.9 ? Colors.orange : BrandColors.emerald500),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color)),
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: context.nc.textTertiary)),
      ],
    );
  }

  Color _getBmiColor(double bmi) {
    if (bmi < 18.5) return Colors.orange;
    if (bmi < 25) return BrandColors.emerald500;
    if (bmi < 30) return Colors.orange;
    return Colors.red;
  }

  dynamic _getFieldValue(String field) {
    final map = _answers.toJson();
    return map[field];
  }

  void _setFieldValue(String field, dynamic value) {
    final map = _answers.toJson();
    map[field] = value;
    _answers = LongevityQuestionnaire.fromJson(map);
  }

  List<Map<String, dynamic>> _getQuestions() {
    return [
      {
        'section': 'Health Baseline',
        'emoji': '❤️',
        'subtitle': 'Understand your current starting point.',
        'question': 'How would you describe your current health?',
        'field': 'currentHealth',
        'type': 'choice',
        'options': ['Excellent', 'Good', 'Average', 'Fair', 'Poor'],
      },
      {
        'section': 'Health Baseline',
        'emoji': '⚡',
        'subtitle': 'Vitality and energy management.',
        'question': 'How is your energy throughout the day?',
        'field': 'energyLevel',
        'type': 'choice',
        'options': ['Consistently high', 'High in morning, dips later', 'Afternoon crash', 'Low most of the day', 'Unpredictable'],
      },
      {
        'section': 'Health Baseline',
        'emoji': '😴',
        'subtitle': 'Sleep architecture.',
        'question': 'How many hours do you sleep on average?',
        'field': 'sleepHours',
        'type': 'choice',
        'options': ['<5', '5–6', '6–7', '7–8', '8+'],
      },
      {
        'section': 'Lifestyle',
        'emoji': '🏃',
        'subtitle': 'Physical activity and habits.',
        'question': 'How active is your typical week?',
        'field': 'weeklyActivity',
        'type': 'choice',
        'options': ['Sedentary', 'Light (1-2 sessions)', 'Moderate (3-4 sessions)', 'Very Active (5+)', 'Elite/Athlete'],
      },
      {
        'section': 'Stress',
        'emoji': '🧠',
        'subtitle': 'Mental resilience and psychology.',
        'question': 'On a scale of 1–10, how stressed do you feel?',
        'field': 'stressScale',
        'type': 'slider',
        'min': 1,
        'max': 10,
      },
      {
        'section': 'Stress',
        'emoji': '🤯',
        'subtitle': 'Stress response patterns.',
        'question': 'How do you typically respond to stress?',
        'field': 'stressResponse',
        'type': 'multi',
        'options': ['Eat more', 'Eat less', 'Skip workouts', 'Overwork', 'Sleep more', 'Sleep less'],
      },
      {
        'section': 'Environment',
        'emoji': '🌍',
        'subtitle': 'External biological stressors.',
        'question': 'Primary drinking water source?',
        'field': 'waterSource',
        'type': 'choice',
        'options': ['RO', 'Tap', 'Bottled', 'Unsure'],
      },
      {
        'section': 'Goals',
        'emoji': '🎯',
        'subtitle': 'Defining your longevity target.',
        'question': 'What are your top 3 priorities?',
        'field': 'topPriorities',
        'type': 'multi',
        'options': ['Longevity', 'Reverse a condition', 'Fat loss', 'Muscle gain', 'Energy', 'Cognitive sharpness', 'Stress resilience'],
      },
      {
        'section': 'Identity',
        'emoji': '🛡️',
        'subtitle': 'Internal beliefs.',
        'question': 'Do you believe aging is:',
        'field': 'agingBelief',
        'type': 'choice',
        'options': ['Mostly genetic', 'Highly modifiable', 'Unsure'],
      },
    ];
  }
}
