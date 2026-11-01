
import 'package:flutter/material.dart';
import '../config/supabase_config.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

// --- MODELS ---

class ProtocolData {
  final String id;
  final String title;
  final String subtitle;
  final String description; // Long description from Supabase goal
  final String currentPhase; 
  final List<String> availablePhases; // For Toggle e.g. ["Phase 1", "Phase 2"]
  final bool isPremium; // New Field
  final DietBlueprint diet;
  final List<ProtocolTask> lifestyle;
  final List<ProtocolTask> fitness;
  final List<ProtocolTask> supplements;
  final Map<String, dynamic> debugGoal;
  final List<String> targetMetrics;

  const ProtocolData({
    required this.id,
    required this.title,
    required this.subtitle,
    this.description = '',
    required this.currentPhase,
    required this.availablePhases,
    this.isPremium = false,
    required this.diet,
    required this.lifestyle,
    required this.fitness,
    required this.supplements,
    this.debugGoal = const {},
    this.targetMetrics = const [],
  });

  static ProtocolData get mock => ProtocolData(
    id: 'mock-1',
    title: 'Reduce Cardiovascular Disease Risk',
    subtitle: '12 weeks • disease risk_reduction',
    currentPhase: 'Phase 1',
    availablePhases: ['Phase 1', 'Phase 2'],
    isPremium: false,
    diet: DietBlueprint(
      macros: [
        MacroItem(label: 'Protein', value: '25%'),
        MacroItem(label: 'Fats', value: '35%'),
        MacroItem(label: 'Carbs', value: '40%'),
      ],
      features: [
        'Mediterranean Diet',
        'Low Sodium',
        'Heart-Healthy Fats',
      ],
      targets: [
        TargetItem(label: 'Calories', value: '2000'),
        TargetItem(label: 'Protein', value: '25%'),
        TargetItem(label: 'Fats', value: '35%'),
        TargetItem(label: 'Carbs', value: '40%'),
      ],
      avoid: [
        'Trans Fats',
        'Processed Foods',
      ],
    ),
    lifestyle: [
      ProtocolTask(title: 'Sunlight Exposure', detail: '10 min morning', time: 'Morning', icon: LucideIcons.sun),
      ProtocolTask(title: 'Evening Wind Down', detail: 'No screens 1h before bed', time: 'Night', icon: LucideIcons.moon),
    ],
    fitness: [
       ProtocolTask(title: 'Zone 2 Cardio', detail: '45 mins', time: 'Daily', frequency: '5X/WEEK', icon: LucideIcons.dumbbell),
    ],
    supplements: [
       ProtocolTask(title: 'Omega-3', detail: '1000mg', time: 'Lunch', buyLink: 'https://example.com', icon: LucideIcons.pill),
    ],
    debugGoal: const {},
    targetMetrics: ['LDL Cholesterol', 'Triglycerides'],
  );
}

// ... DietBlueprint, MacroItem, TargetItem, ProtocolTask (same as before) ...
class DietBlueprint {
  final List<MacroItem> macros;
  final List<String> features;
  final List<TargetItem> targets;
  final List<String> avoid;

  const DietBlueprint({
    required this.macros,
    required this.features,
    required this.targets,
    required this.avoid,
  });
}

class MacroItem { final String label; final String value; const MacroItem({required this.label, required this.value}); }
class TargetItem { final String label; final String value; const TargetItem({required this.label, required this.value}); }
class ProtocolTask {
  final String title;
  final String detail;
  final String time;
  final String? frequency;
  final String? buyLink;
  final IconData? icon;
  final String? category;

  const ProtocolTask({
    required this.title,
    required this.detail,
    required this.time,
    this.frequency,
    this.buyLink,
    this.icon,
    this.category,
  });
}


// --- REPOSITORY ---

class ProtocolRepository {
  static List<ProtocolTask> get lifestyle => _currentFetch?.lifestyle ?? ProtocolData.mock.lifestyle;
  static List<ProtocolTask> get fitness => _currentFetch?.fitness ?? ProtocolData.mock.fitness;
  static List<ProtocolTask> get dietTasks => []; // Legacy unused
  static List<ProtocolTask> get supplements => _currentFetch?.supplements ?? ProtocolData.mock.supplements;

  static ProtocolData? _currentFetch;
  
  // Active Library Protocols (In-Memory for now, should be persisted)
  static final Set<String> _activeProtocolIds = {};

  static bool isProtocolActive(String id) => _activeProtocolIds.contains(id);

  static void toggleProtocol(String id) {
    if (_activeProtocolIds.contains(id)) {
      _activeProtocolIds.remove(id);
    } else {
      _activeProtocolIds.add(id);
    }
  }

  /// Set current protocol for legacy compatibility
  static void setCurrentProtocol(ProtocolData protocol) {
    _currentFetch = protocol;
  }

  /// Fetch ALL protocol phases from Supabase admin panel
  static Future<List<ProtocolData>> fetchAllAdminProtocols({String? profileId}) async {
    final List<ProtocolData> adminProtocols = [];
    
    try {
      final client = SupabaseConfig.client;
      if (client == null) return adminProtocols;

      // Patient identity IS their auth user id - no profiles lookup needed.
      final String? targetProfileId = profileId ?? client.auth.currentUser?.id;

      if (targetProfileId == null) return adminProtocols;

      // Fetch the health journey
      final response = await client
          .from('health_journeys')
          .select('*')
          .eq('profile_id', targetProfileId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        final phases = response['phases'] as List? ?? [];
        print('DEBUG fetchAllAdminProtocols: Found ${phases.length} phases');
        
        // Map each phase to a ProtocolData
        for (int i = 0; i < phases.length; i++) {
          final phaseData = phases[i];
          final protocol = _mapJsonToProtocolForPhase(response, phaseData, i);
          adminProtocols.add(protocol);
        }
      }
    } catch (e) {
      print('fetchAllAdminProtocols Error: $e');
    }

    return adminProtocols;
  }

  /// Map a specific phase from JSON to ProtocolData
  static ProtocolData _mapJsonToProtocolForPhase(Map<String, dynamic> json, Map<String, dynamic> phaseData, int phaseIndex) {
    final protocol = phaseData['protocol'] ?? {};

    List<ProtocolTask> mapTasks(dynamic section, String defaultIcon) {
      if (section == null) return [];
      final items = (section['items'] as List?) ?? (section['habits'] as List?) ?? (section['pillars'] as List?) ?? [];
      
      return items.map<ProtocolTask>((item) {
        return ProtocolTask(
          title: item['name'] ?? item['title'] ?? 'Task',
          detail: item['desc'] ?? item['purpose'] ?? item['description'] ?? '',
          time: item['time'] ?? item['timing'] ?? '',
          frequency: item['tag'],
          buyLink: null,
          icon: _getIcon(item['name'] ?? '', defaultIcon), 
        );
      }).toList();
    }

    // Diet Mapping
    final dietData = protocol['diet'] ?? {};
    final macros = dietData['macros'] ?? {};
    final dietBlueprint = DietBlueprint(
      macros: [
        MacroItem(label: 'Protein', value: macros['protein'] ?? '0%'),
        MacroItem(label: 'Fats', value: macros['fats'] ?? '0%'),
        MacroItem(label: 'Carbs', value: macros['carbs'] ?? '0%'),
      ],
      features: (dietData['principles'] as List?)?.map((e) => e.toString()).toList() ?? [],
      targets: [
        TargetItem(label: 'Calories', value: '${dietData['calories'] ?? 2000}'),
        TargetItem(label: 'Protein', value: macros['protein'] ?? '0%'),
        TargetItem(label: 'Fats', value: macros['fats'] ?? '0%'),
        TargetItem(label: 'Carbs', value: macros['carbs'] ?? '0%'),
      ],
      avoid: (dietData['exclusions'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );

    final goalData = phaseData['goal'] ?? {};
    final goalType = goalData['type']?.toString().replaceAll('_', ' ') ?? 'Optimization';
    final phaseNum = phaseData['phaseNumber'] ?? phaseIndex + 1;
    
    // Debug: Log all goal keys to find correct title field
    print('DEBUG Goal data keys: ${goalData.keys.toList()}');
    print('DEBUG goalData: $goalData');
    
    // Look for title in these priority fields: 'title', 'name', or fallback
    final goalTitle = goalData['title'] ?? goalData['name'] ?? goalData['heading'];
    final goalDescription = goalData['description'] as String? ?? '';
    
    // Use the short title if available, otherwise fall back to phase + goal type
    final title = goalTitle?.toString().isNotEmpty == true 
        ? goalTitle.toString()
        : 'Phase $phaseNum: ${_toTitleCase(goalType)}';
    
    return ProtocolData(
      id: 'admin-phase-$phaseIndex-${json['id']}',
      title: title,
      subtitle: '${phaseData['durationWeeks'] ?? '?'} WEEKS • ${goalType.toUpperCase()}',
      description: goalDescription, // Long description from Supabase
      currentPhase: 'Phase $phaseNum',
      availablePhases: ['Phase $phaseNum'],
      isPremium: false, // Admin protocols are always included
      diet: dietBlueprint,
      lifestyle: mapTasks(protocol['lifestyle'], 'sun'),
      fitness: mapTasks(protocol['fitness'], 'dumbbell'),
      supplements: mapTasks(protocol['supplements'], 'pill'),
      debugGoal: goalData,
      targetMetrics: (goalData['targetMetrics'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  // HARDCODED ADD-ON PROTOCOL LIBRARY (Free + Premium Extras)
  static final List<ProtocolData> addonLibrary = [
    // FREE: The Longevity Engine
    ProtocolData(
      id: 'longevity-engine',
      title: 'The Longevity Engine',
      subtitle: 'VO2 Max Optimization • LIFE EXTENSION',
      currentPhase: 'Phase 1',
      availablePhases: ['Phase 1', 'Phase 2', 'Phase 3'],
      isPremium: false, // Free
      description: "Reinventing the human lifespan, one breath at a time.\n\n"
          "THE METRIC THAT MATTERS\n"
          "Most people treat exercise like a chore. That is a mistake. Exercise is the most potent longevity drug in existence, and VO2 Max is the dosage.\n\n"
          "Think of your body as a machine. Your VO2 Max is the horsepower of your engine. It is the maximum amount of oxygen your body can utilize during intense effort.\n\n"
          "• Low VO2 Max: You have a lawnmower engine inside a Ferrari. You are inefficient. You age rapidly.\n"
          "• High VO2 Max: You have a jet engine. You burn fuel cleanly. You have 'Whole-Body Intelligence.'\n\n"
          "At Zyndio, we don't guess. We measure. And increasing this single number is the most effective way to add quality years to your life.\n\n"
          "THE SCIENCE: WHY WE DO THIS\n"
          "The data is undeniable. Moving from 'low fitness' to 'above average fitness' reduces your risk of death more than quitting smoking.\n\n"
          "The Benefits of a High Engine:\n"
          "• Cellular Youth: High VO2 max is correlated with longer telomeres.\n"
          "• Metabolic Shield: Dramatically improves insulin sensitivity.\n"
          "• Real-World Energy: The ability to hike with grandchildren, carry luggage, and climb stairs at age 80 without gasping.\n\n"
          "While others just tell you to 'run,' we combine this with Ayurvedic wisdom regarding breath control (Pranayama) and recovery.\n\n"
          "HEALTH DISCLAIMER\n"
          "This guide is for educational purposes only. Consult a physician before starting, especially if over 40 or with a history of heart disease.",
      diet: const DietBlueprint(
        macros: [
           MacroItem(label: 'Carbs', value: 'High (Zone 5)'),
           MacroItem(label: 'Carbs', value: 'Low (Zone 2)'),
        ],
        features: [
          'Fuel Zone 5 with Carbs',
          'Fast/Low Carb for Zone 2',
        ],
        targets: [],
        avoid: [],
      ),
      lifestyle: [
        const ProtocolTask(
          title: 'Pranayama Breathwork', 
          detail: 'Ayurvedic breath control & recovery optimization.', 
          time: 'Daily', 
          icon: LucideIcons.wind
        ),
        const ProtocolTask(
          title: 'Sleep Focus', 
          detail: 'Prioritize sleep quality heavily the night after Zone 5 sessions.', 
          time: 'Night (Post-Training)', 
          icon: LucideIcons.bed
        ),
      ],
      fitness: [
        const ProtocolTask(
          title: 'Foundational Zone 2', 
          detail: '45-60 min brisk incline walk, light cycle, or jog. Talk Test: Must be able to hold a conversation.', 
          time: '3-4X/WEEK', 
          frequency: '3-4X/WEEK',
          icon: LucideIcons.heartPulse
        ),
         const ProtocolTask(
          title: 'The Peak (Zone 5)', 
          detail: 'Norwegian 4x4: 4 mins HARD (drowning in air), 3 mins active recovery. Repeat 4 times.', 
          time: '1X/WEEK', 
          frequency: '1X/WEEK',
          icon: LucideIcons.flame
        ),
         const ProtocolTask(
          title: 'Low Impact Option', 
          detail: 'Use Bike, Rower, or Swim to save joints while spiking heart rate.', 
          time: 'As Needed', 
          frequency: 'OPTIONAL',
          icon: LucideIcons.bike
        ),
      ],
      supplements: [], // Left blank as requested
    ),
    // PREMIUM: Deep Sleep Mastery
    ProtocolData(
      id: 'sleep-mastery',
      title: 'Deep Sleep Mastery',
      subtitle: 'ONGOING • RECOVERY',
      currentPhase: 'Maintenance',
      availablePhases: [],
      isPremium: true, // Premium
      diet: const DietBlueprint(macros: [], features: [], targets: [], avoid: []),
      lifestyle: [
        const ProtocolTask(title: 'No Blue Light', detail: 'Wear blockers 2h before bed', time: 'Night', icon: LucideIcons.glasses),
        const ProtocolTask(title: 'Room Temp 68°F', detail: 'Optimize sleep environment', time: 'Night', icon: LucideIcons.thermometer),
      ],
      fitness: [],
      supplements: [
        const ProtocolTask(title: 'Magnesium Glycinate', detail: '400mg', time: 'Before Bed', icon: LucideIcons.moon),
        const ProtocolTask(title: 'L-Theanine', detail: '200mg', time: 'Before Bed', icon: LucideIcons.coffee),
      ],
    ),
    // PREMIUM: Cognitive Drive
    ProtocolData(
      id: 'cognitive-drive',
      title: 'Cognitive Drive',
      subtitle: '6 WEEKS • PERFORMANCE',
      currentPhase: 'Phase 1',
      availablePhases: [],
      isPremium: true,
      diet: const DietBlueprint(macros: [], features: [], targets: [], avoid: []),
      lifestyle: [
        const ProtocolTask(title: 'Deep Work Block', detail: '90m uninterrupted focus', time: 'Morning', icon: LucideIcons.brainCircuit),
        const ProtocolTask(title: 'NSDR', detail: '20min Non-Sleep Deep Rest', time: 'Afternoon', icon: LucideIcons.batteryCharging),
      ],
      fitness: [],
      supplements: [
        const ProtocolTask(title: 'Alpha GPC', detail: '300mg', time: 'Pre-Work', icon: LucideIcons.zap),
      ],
    ),
  ];

  // Fetch logic connecting to Supabase 'health_journeys' and Merging with Active Library
  static Future<ProtocolData> fetchProtocol({int phaseIndex = 0, String? profileId}) async {
    try {
      // 1. Fetch Base Protocol (Supabase)
      ProtocolData baseProtocol = ProtocolData.mock;
      
      final client = SupabaseConfig.client;
      if (client != null) {
        // Patient identity IS their auth user id - no profiles lookup needed.
        final String? targetProfileId = profileId ?? client.auth.currentUser?.id;

        if (targetProfileId != null) {
          final response = await client
              .from('health_journeys')
              .select('*')
              .eq('profile_id', targetProfileId)
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();

          if (response != null) {
            baseProtocol = _mapJsonToProtocol(response, phaseIndex);
          }
        }
      }

      // 2. Fetch Active Library Protocols
      final activeLibraryProtocols = addonLibrary.where((p) => _activeProtocolIds.contains(p.id)).toList();

      // 3. Merge
      if (activeLibraryProtocols.isEmpty) {
        _currentFetch = baseProtocol;
        return baseProtocol;
      }

      return _mergeProtocols(baseProtocol, activeLibraryProtocols);

    } catch (e) {
      print('Protocol Fetch Error: $e');
    }
    _currentFetch = ProtocolData.mock;
    return ProtocolData.mock;
  }

  static ProtocolData _mergeProtocols(ProtocolData base, List<ProtocolData> others) {
     List<ProtocolTask> mergedLifestyle = [...base.lifestyle];
     List<ProtocolTask> mergedFitness = [...base.fitness];
     List<ProtocolTask> mergedSupplements = [...base.supplements];
     
     // Simple text merge for titles suitable for UI
     String mergedTitle = base.title;
     String mergedSubtitle = base.subtitle;

     if (others.isNotEmpty) {
       mergedTitle = "$mergedTitle + ${others.length} Active";
     }

     for (var other in others) {
        mergedLifestyle.addAll(other.lifestyle);
        mergedFitness.addAll(other.fitness);
        mergedSupplements.addAll(other.supplements);
     }

     final merged = ProtocolData(
        id: base.id,
        title: mergedTitle,
        subtitle: mergedSubtitle,
        currentPhase: base.currentPhase,
        availablePhases: base.availablePhases,
        isPremium: base.isPremium,
        diet: base.diet, // Keep base diet for now, aggregating diets is complex
        lifestyle: mergedLifestyle,
        fitness: mergedFitness,
        supplements: mergedSupplements,
        targetMetrics: base.targetMetrics,
        debugGoal: base.debugGoal,
     );
     
     _currentFetch = merged;
     return merged;
  }

  static ProtocolData _mapJsonToProtocol(Map<String, dynamic> json, int phaseIndex) {
      final phases = json['phases'] as List? ?? [];
      if (phases.isEmpty) return ProtocolData.mock;
      
      final currentPhaseData = phases[phaseIndex < phases.length ? phaseIndex : 0];
      final protocol = currentPhaseData['protocol'] ?? {};

      // Helper to map tasks
      List<ProtocolTask> mapTasks(dynamic section, String defaultIcon) {
          if (section == null) return [];
          final items = (section['items'] as List?) ?? (section['habits'] as List?) ?? (section['pillars'] as List?) ?? [];
          
          return items.map<ProtocolTask>((item) {
              return ProtocolTask(
                  title: item['name'] ?? item['title'] ?? 'Task',
                  detail: item['desc'] ?? item['purpose'] ?? item['description'] ?? '',
                  time: item['time'] ?? item['timing'] ?? '',
                  frequency: item['tag'], // e.g. 5X/WEEK
                  buyLink: null, // Not in standard JSON yet, or maybe 'link'
                  icon: _getIcon(item['name'] ?? '', defaultIcon), 
              );
          }).toList();
      }

      // Diet Mapping
      final dietData = protocol['diet'] ?? {};
      final macros = dietData['macros'] ?? {};
      final dietBlueprint = DietBlueprint(
        macros: [
            MacroItem(label: 'Protein', value: macros['protein'] ?? '0%'),
            MacroItem(label: 'Fats', value: macros['fats'] ?? '0%'),
            MacroItem(label: 'Carbs', value: macros['carbs'] ?? '0%'),
        ],
        features: (dietData['principles'] as List?)?.map((e) => e.toString()).toList() ?? [],
        targets: [
             TargetItem(label: 'Calories', value: '${dietData['calories'] ?? 2000}'),
             TargetItem(label: 'Protein', value: macros['protein'] ?? '0%'),
             TargetItem(label: 'Fats', value: macros['fats'] ?? '0%'),
             TargetItem(label: 'Carbs', value: macros['carbs'] ?? '0%'),
        ],
        avoid: (dietData['exclusions'] as List?)?.map((e) => e.toString()).toList() ?? [],
      );


      final goalData = currentPhaseData['goal'] ?? {};
      final goalTitle = goalData['title'] ?? goalData['name'] ?? goalData['heading'];
      final goalType = goalData['type']?.toString().replaceAll('_', ' ') ?? 'Protocol';
      final phaseNum = currentPhaseData['phaseNumber'];

      final title = goalTitle?.toString().isNotEmpty == true 
        ? goalTitle.toString()
        : 'Phase $phaseNum: ${_toTitleCase(goalType)}';

      final data = ProtocolData(
          id: json['id'],
          title: title,
          subtitle: '${currentPhaseData['durationWeeks'] ?? '?'} WEEKS • ${goalType.toUpperCase()}',
          currentPhase: 'Phase $phaseNum',
          availablePhases: phases.map((p) => 'Phase ${p['phaseNumber']}').toList().cast<String>(),
          isPremium: false,
          diet: dietBlueprint,
          lifestyle: mapTasks(protocol['lifestyle'], 'sun'),
          fitness: mapTasks(protocol['fitness'], 'dumbbell'),
          supplements: mapTasks(protocol['supplements'], 'pill'),
          debugGoal: currentPhaseData['goal'] ?? {},
          targetMetrics: (currentPhaseData['goal']?['targetMetrics'] as List?)
              ?.map((e) => e.toString())
              .toList() ?? [],
      );
      
      // Don't set _currentFetch here, as this is just a mapper now
      return data;
  }

  static IconData _getIcon(String name, String defaultType) {
      final lower = name.toLowerCase();
      if (lower.contains('sun')) return LucideIcons.sun;
      if (lower.contains('sleep') || lower.contains('bed')) return LucideIcons.moon;
      if (lower.contains('meditation')) return LucideIcons.brain;
      if (lower.contains('cardio')) return LucideIcons.heartPulse;
      if (lower.contains('resistance') || lower.contains('weight')) return LucideIcons.dumbbell;
      if (lower.contains('omega') || lower.contains('fish')) return LucideIcons.fish;
      return defaultType == 'sun' ? LucideIcons.sun : (defaultType == 'dumbbell' ? LucideIcons.dumbbell : LucideIcons.pill);
  }

  /// Title case helper
  static String _toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }
}
