import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:convert';
import '../data/protocol_repository.dart';
import '../models/health_protocol.dart';
import 'rhythm_provider.dart';
import '../config/supabase_config.dart';

/// State for the Protocol Library
class ProtocolState {
  final List<ProtocolData> allProtocols; // Care-team phases only
  final String? selectedProtocolId;
  final bool isLoading;
  final bool loadFailed;

  const ProtocolState({
    this.allProtocols = const [],
    this.selectedProtocolId,
    this.isLoading = false,
    this.loadFailed = false,
  });

  ProtocolState copyWith({
    List<ProtocolData>? allProtocols,
    String? selectedProtocolId,
    bool? isLoading,
    bool? loadFailed,
    bool clearSelection = false,
  }) {
    return ProtocolState(
      allProtocols: allProtocols ?? this.allProtocols,
      selectedProtocolId: clearSelection
          ? null
          : (selectedProtocolId ?? this.selectedProtocolId),
      isLoading: isLoading ?? this.isLoading,
      loadFailed: loadFailed ?? this.loadFailed,
    );
  }

  /// Get the currently selected protocol data
  ProtocolData? get selectedProtocol {
    if (selectedProtocolId == null) return null;
    try {
      return allProtocols.firstWhere((p) => p.id == selectedProtocolId);
    } catch (_) {
      return null;
    }
  }

  /// Get admin protocols (those with id starting with 'admin-')
  List<ProtocolData> get adminProtocols =>
      allProtocols.where((p) => p.id.startsWith('admin-')).toList();

  /// Get add-on protocols (free or premium extras)
  List<ProtocolData> get addonProtocols =>
      allProtocols.where((p) => !p.id.startsWith('admin-')).toList();
}

/// Protocol Notifier - manages protocol selection and library
class ProtocolNotifier extends Notifier<ProtocolState> {
  String? _profileId;
  static const String _storageKey = 'selected_protocol_id';
  static const String _savedProtocolsKey = 'saved_custom_protocols';
  List<ProtocolData> _savedCustomProtocols = [];

  bool _hasInitialized = false;

  @override
  ProtocolState build() {
    // Guard against re-initialization on every rebuild —
    // _init() only needs to run once; selectProtocol() and fetchLibrary()
    // handle subsequent updates explicitly.
    if (!_hasInitialized) {
      _hasInitialized = true;
      _init();
      return const ProtocolState(isLoading: true);
    }
    
    // Safety check: Avoid reading 'state' if for some reason it's not yet set
    // but the flag is true (extremely rare, but possible in complex circularities)
    try {
      return state;
    } catch (_) {
      return const ProtocolState(isLoading: true);
    }
  }

  Future<void> _init() async {
    try {
      // Load persisted selection
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString(_storageKey);
      
      // Temporarily set saved ID in state (will be validated in fetchLibrary)
      if (savedId != null) {
        state = state.copyWith(selectedProtocolId: savedId);
      }
      
      await fetchLibrary();
      
      // Cloud Migration: Move any locally saved protocols to Supabase
      await _migrateLocalProtocolsToCloud(prefs);
    } catch (_) {
      state = state.copyWith(isLoading: false, loadFailed: true);
    }
  }

  Future<void> _migrateLocalProtocolsToCloud(SharedPreferences prefs) async {
    final client = SupabaseConfig.client;
    if (client == null || client.auth.currentUser == null) return;

    final savedJson = prefs.getStringList(_savedProtocolsKey) ?? [];
    if (savedJson.isEmpty) return; // Nothing to migrate

    try {
      // Patient identity IS their auth user id - no profiles lookup needed.
      final profileId = client.auth.currentUser!.id;

      print("Migrating ${savedJson.length} local custom protocols to cloud...");

      for (String jsonStr in savedJson) {
        final Map<String, dynamic> map = jsonDecode(jsonStr);
        final protocolData = _mapSavedJsonToProtocolData(map);
        
        // Ensure ID is unique and doesn't conflict
        String safeId = protocolData.id;
        if (!safeId.startsWith('custom-')) safeId = 'custom-$safeId';

        await client.from('custom_protocols').upsert({
            'profile_id': profileId,
            'protocol_data': _mapProtocolDataToJson(protocolData),
        });
      }

      // Clear local storage after successful migration
      await prefs.remove(_savedProtocolsKey);
      print("Local custom protocols migrated and cleared.");
      
      // Refresh to grab the newly uploaded ones
      await fetchLibrary();
    } catch (e) {
      print('Error during custom protocols cloud migration: $e');
    }
  }

  /// Set profile ID for fetching user-specific protocols
  void setProfileId(String? profileId) {
    if (_profileId != profileId) {
      _profileId = profileId;
      fetchLibrary();
    }
  }

  /// Fetch all protocols: Admin phases from Supabase + hardcoded add-ons
  Future<void> fetchLibrary() async {
    state = state.copyWith(isLoading: true);

    try {
      final client = SupabaseConfig.client;
      // Patient identity IS their auth user id - no profiles lookup needed.
      final String? targetProfileId = _profileId ?? client?.auth.currentUser?.id;

      // 1. Fetch admin protocols (all phases)
      final adminProtocols = await ProtocolRepository.fetchAllAdminProtocols(
        profileId: targetProfileId,
      );

      // 2. Fetch custom AI protocols from cloud
      final List<ProtocolData> cloudCustomProtocols = [];
      if (client != null && targetProfileId != null) {
          try {
            final cloudRes = await client
                .from('custom_protocols')
                .select('protocol_data')
                .eq('profile_id', targetProfileId)
                .order('created_at', ascending: false);
            
            for (var row in cloudRes) {
                if (row['protocol_data'] != null) {
                    cloudCustomProtocols.add(_mapSavedJsonToProtocolData(row['protocol_data'] as Map<String, dynamic>));
                }
            }
          } catch (_) {
            // A missing custom-protocol table must not invent a plan.
          }
      }
      _savedCustomProtocols = cloudCustomProtocols;

      // Care-team phases only. The in-repo sample library is not a plan.
      final allProtocols = [...adminProtocols, ..._savedCustomProtocols];

      // 5. Auto-select logic
      String? selectedId = state.selectedProtocolId;
      
      // Verify if saved ID still exists in the fetched list
      if (selectedId != null) {
          final exists = allProtocols.any((p) => p.id == selectedId);
          if (!exists) selectedId = null; // Invalid/Old ID
      }

      if (selectedId == null && adminProtocols.isNotEmpty) {
        selectedId = adminProtocols.first.id;
      }

      state = ProtocolState(
        allProtocols: allProtocols,
        selectedProtocolId: selectedId,
        isLoading: false,
        loadFailed: false,
      );

      // Also update the repository's current fetch for legacy compatibility
      if (state.selectedProtocol != null) {
        ProtocolRepository.setCurrentProtocol(state.selectedProtocol!);
      }
    } catch (_) {
      state = state.copyWith(isLoading: false, loadFailed: true);
    }
  }

  /// Select a protocol and trigger rhythm refresh
  Future<void> selectProtocol(String id) async {
    if (state.selectedProtocolId == id) return; // No change

    state = state.copyWith(selectedProtocolId: id);

    // Persist selection
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, id);

    // Update repository for legacy compatibility
    if (state.selectedProtocol != null) {
      ProtocolRepository.setCurrentProtocol(state.selectedProtocol!);
    }

    // Trigger Today's Rhythm refresh
    ref.read(dailyRhythmProvider.notifier).refresh();
  }

  /// Save a generated HealthProtocol (from Chat) to the library
  Future<void> saveGeneratedProtocol(HealthProtocol generated) async {
    final newData = _mapHealthProtocolToData(generated);
    await _saveProtocolDataToCloud(newData);

    // Refresh library and auto-select
    await fetchLibrary();
    selectProtocol(newData.id);
  }



  Future<void> _saveProtocolDataToCloud(ProtocolData protocolData) async {
    final client = SupabaseConfig.client;
    if (client == null || client.auth.currentUser == null) {
        print("Cannot save protocol: Supabase client or user not found.");
        return;
    }

    try {
        // Patient identity IS their auth user id - no profiles lookup needed.
        final profileId = client.auth.currentUser!.id;

        await client.from('custom_protocols').upsert({
            'profile_id': profileId,
            'protocol_data': _mapProtocolDataToJson(protocolData),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
    } catch (e) {
        print('Error saving custom protocol to cloud: $e');
    }
  }

  // --- HELPERS for Persistence ---

  ProtocolData _mapHealthProtocolToData(HealthProtocol h) {
    // Helper to map section to tasks
    List<ProtocolTask> mapSection(ProtocolSection section, IconData defaultIcon) {
        List<ProtocolTask> tasks = [];
        // 1. Content as main task
        if (section.content.isNotEmpty) {
           tasks.add(ProtocolTask(
             title: 'Overview', // Or section title
             detail: section.content,
             time: 'Anytime',
             icon: defaultIcon,
             frequency: 'Daily',
           ));
        }
        // 2. Action items
        for (var item in section.actionItems) {
           tasks.add(ProtocolTask(
             title: item,
             detail: 'Action Step',
             time: 'Flexible',
             icon: defaultIcon,
           ));
        }
        return tasks;
    }

    return ProtocolData(
      id: 'custom-${h.id}',
      title: h.title,
      subtitle: '${h.type.toUpperCase()} • CUSTOM',
      description: h.summary,
      currentPhase: 'Phase 1',
      availablePhases: ['Phase 1'],
      isPremium: true, // Treat customized as premium feature
      diet: DietBlueprint(
        macros: [], // Chat doesn't generate structured macros yet
        features: h.diet.actionItems,
        targets: [],
        avoid: [],
      ),
      lifestyle: mapSection(h.lifestyle, LucideIcons.sun),
      fitness: mapSection(h.fitness, LucideIcons.dumbbell),
      supplements: mapSection(h.supplements, LucideIcons.pill),
    );
  }

  Map<String, dynamic> _mapProtocolDataToJson(ProtocolData p) {
    // Used for Supabase JSONB storage — preserve all task metadata
    Map<String, dynamic> taskToJson(ProtocolTask t) => {
      'title': t.title,
      'detail': t.detail,
      'time': t.time,
      if (t.frequency != null) 'frequency': t.frequency,
      if (t.buyLink != null) 'buyLink': t.buyLink,
      if (t.category != null) 'category': t.category,
    };
    
    return {
      'id': p.id,
      'title': p.title,
      'subtitle': p.subtitle,
      'description': p.description,
      'lifestyle': p.lifestyle.map(taskToJson).toList(),
      'fitness': p.fitness.map(taskToJson).toList(),
      'supplements': p.supplements.map(taskToJson).toList(),
      'diet_features': p.diet.features,
    };
  }

  ProtocolData _mapSavedJsonToProtocolData(Map<String, dynamic> json) {
     List<ProtocolTask> mapTasks(List<dynamic>? list, IconData icon) {
       return (list ?? []).map((m) => ProtocolTask(
         title: m['title'] ?? '',
         detail: m['detail'] ?? '',
         time: m['time'] ?? 'Anytime',
         frequency: m['frequency'],
         buyLink: m['buyLink'],
         category: m['category'],
         icon: icon,
       )).toList();
     }

     return ProtocolData(
       id: json['id']?.toString() ?? 'unknown',
       title: json['title']?.toString() ?? 'Untitled Protocol',
       subtitle: json['subtitle']?.toString() ?? 'CUSTOM',
       description: json['description']?.toString() ?? '',
       currentPhase: 'Phase 1',
       availablePhases: const ['Phase 1'],
       isPremium: true,
       diet: DietBlueprint(
         macros: const [], 
         features: (json['diet_features'] as List?)?.map((e) => e.toString()).toList() ?? [], 
         targets: const [], 
         avoid: const []
       ),
       lifestyle: mapTasks(json['lifestyle'], LucideIcons.sun),
       fitness: mapTasks(json['fitness'], LucideIcons.dumbbell),
       supplements: mapTasks(json['supplements'], LucideIcons.pill),
     );
  }
}

/// Main provider for protocol state
final protocolProvider =
    NotifierProvider<ProtocolNotifier, ProtocolState>(() {
  return ProtocolNotifier();
});
