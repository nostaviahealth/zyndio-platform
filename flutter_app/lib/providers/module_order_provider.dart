import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../main.dart'; // Import for sharedPrefs

enum IntelligenceModule {
  protocol,
  food,
  cardio,
  performance,
}

extension IntelligenceModuleExt on IntelligenceModule {
  String get displayName {
    switch (this) {
      case IntelligenceModule.protocol:
        return 'Protocol Group (Timeline & Blueprint)';
      case IntelligenceModule.food:
        return 'Food Intelligence';
      case IntelligenceModule.cardio:
        return 'Cardiovascular Intelligence';
      case IntelligenceModule.performance:
        return 'Performance Intelligence';
    }
  }
}

const _kModuleOrderPrefsKey = 'intelligence_module_order';

class ModuleOrderNotifier extends Notifier<List<IntelligenceModule>> {
  @override
  List<IntelligenceModule> build() {
    return _loadFromPrefsSync();
  }

  List<IntelligenceModule> _loadFromPrefsSync() {
    try {
      final savedList = sharedPrefs.getStringList(_kModuleOrderPrefsKey);
      
      if (savedList != null && savedList.isNotEmpty) {
        final List<IntelligenceModule> loaded = [];
        for (final name in savedList) {
          final module = IntelligenceModule.values.firstWhere(
            (e) => e.name == name,
            orElse: () => IntelligenceModule.protocol,
          );
          if (!loaded.contains(module)) {
            loaded.add(module);
          }
        }
        
        for (final module in IntelligenceModule.values) {
          if (!loaded.contains(module)) {
            loaded.add(module);
          }
        }
        
        return loaded;
      }
    } catch (e) {
      // Fallback
    }
    
    return [
      IntelligenceModule.protocol,
      IntelligenceModule.food,
      IntelligenceModule.cardio,
      IntelligenceModule.performance,
    ];
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    
    final List<IntelligenceModule> current = List.from(state);
    final IntelligenceModule item = current.removeAt(oldIndex);
    current.insert(newIndex, item);
    
    state = current;
    
    try {
      sharedPrefs.setStringList(_kModuleOrderPrefsKey, current.map((e) => e.name).toList());
    } catch (e) {
      // Ignore
    }
  }
}

final moduleOrderProvider = NotifierProvider<ModuleOrderNotifier, List<IntelligenceModule>>(() {
  return ModuleOrderNotifier();
});
