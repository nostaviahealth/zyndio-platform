import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/meal_repository.dart';
import '../models/chat_session.dart';
import '../models/health_protocol.dart';
import '../models/meal_plan.dart';
import 'cycle_provider.dart';
import '../models/simulation_result.dart';
import '../models/menstrual_log.dart';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import '../data/chat_repository.dart';
import '../data/health_repository.dart';
import '../services/azure_openai_service.dart';
import '../services/wearable_context_service.dart';
import '../services/shared_health_cache.dart';
import 'patient_provider.dart';
import 'intelligence_provider.dart';
import 'lab_reports_provider.dart';
import 'questionnaire_provider.dart';
import 'protocol_provider.dart';
import '../services/agent_service.dart';
import '../services/agent_tools.dart';
import '../services/memory_service.dart';
import '../services/correlation_engine.dart';
import '../services/companion_boundaries.dart';
import '../services/food_context_service.dart';
import 'purchase_provider.dart';
import 'usage_limit_provider.dart';

// --- Existing Provider ---
final chatHistoryProvider = FutureProvider<List<ChatSession>>((ref) async {
  return ChatRepository.fetchHistory();
});

// --- New Chat Logic ---

// Model for AI-returned call-to-action buttons
class CtaAction {
  final String label;
  final String action;

  CtaAction({required this.label, required this.action});

  Map<String, dynamic> toJson() => {'label': label, 'action': action};
  factory CtaAction.fromJson(Map<String, dynamic> json) =>
      CtaAction(label: json['label'] ?? '', action: json['action'] ?? '');
}

// --- BLOCK-BASED MESSAGING ---
abstract class MessageBlock {
  final String type;
  MessageBlock(this.type);
  Map<String, dynamic> toJson();
  factory MessageBlock.fromJson(Map<String, dynamic> json) {
    switch (json['type']) {
      case 'text': return TextBlock.fromJson(json);
      case 'data_card': return DataCardBlock.fromJson(json);
      case 'simulation': return SimulationBlock.fromJson(json);
      case 'protocol': return ProtocolBlock.fromJson(json);
      case 'meal_plan': return MealPlanBlock.fromJson(json);
      case 'cta': return CtaBlock.fromJson(json);
      case 'metric_card': return MetricCardBlock.fromJson(json);
      default: return TextBlock(text: "[Unsupported block type: ${json['type']}]");
    }
  }
}

class TextBlock extends MessageBlock {
  final String text;
  TextBlock({required this.text}) : super('text');
  @override Map<String, dynamic> toJson() => {'type': 'text', 'text': text};
  factory TextBlock.fromJson(Map<String, dynamic> json) => TextBlock(text: json['text'] ?? '');
}

class DataCardBlock extends MessageBlock {
    final String title;
    final List<Map<String, dynamic>> rows;
    final String? verdict;
    DataCardBlock({required this.title, required this.rows, this.verdict}) : super('data_card');
    @override Map<String, dynamic> toJson() => {'type': 'data_card', 'title': title, 'rows': rows, 'verdict': verdict};
    factory DataCardBlock.fromJson(Map<String, dynamic> json) => DataCardBlock(
        title: json['title'] ?? '',
        rows: List<Map<String, dynamic>>.from(json['rows'] ?? []),
        verdict: json['verdict'],
    );
}

class SimulationBlock extends MessageBlock {
    final SimulationResult simulation;
    SimulationBlock({required this.simulation}) : super('simulation');
    @override Map<String, dynamic> toJson() => {'type': 'simulation', 'simulation': simulation.toJson()};
    factory SimulationBlock.fromJson(Map<String, dynamic> json) => SimulationBlock(simulation: SimulationResult.fromJson(json['simulation']));
}

class ProtocolBlock extends MessageBlock {
    final HealthProtocol protocol;
    ProtocolBlock({required this.protocol}) : super('protocol');
    @override Map<String, dynamic> toJson() => {'type': 'protocol', 'protocol': protocol.toJson()};
    factory ProtocolBlock.fromJson(Map<String, dynamic> json) => ProtocolBlock(protocol: HealthProtocol.fromJson(json['protocol']));
}

class MealPlanBlock extends MessageBlock {
    final MealPlan mealPlan;
    MealPlanBlock({required this.mealPlan}) : super('meal_plan');
    @override Map<String, dynamic> toJson() => {'type': 'meal_plan', 'mealPlan': mealPlan.toJson()};
    factory MealPlanBlock.fromJson(Map<String, dynamic> json) => MealPlanBlock(mealPlan: MealPlan.fromJson(json['mealPlan']));
}

class CtaBlock extends MessageBlock {
    final List<CtaAction> actions;
    CtaBlock({required this.actions}) : super('cta');
    @override Map<String, dynamic> toJson() => {'type': 'cta', 'actions': actions.map((a) => a.toJson()).toList()};
    factory CtaBlock.fromJson(Map<String, dynamic> json) => CtaBlock(actions: (json['actions'] as List).map((a) => CtaAction.fromJson(a)).toList());
}

class MetricCardBlock extends MessageBlock {
    final String label;
    final String value;
    final String? unit;
    final String? status;
    final List<double>? history;
    
    MetricCardBlock({
        required this.label,
        required this.value,
        this.unit,
        this.status,
        this.history,
    }) : super('metric_card');
    
    @override Map<String, dynamic> toJson() => {
        'type': 'metric_card',
        'label': label,
        'value': value,
        'unit': unit,
        'status': status,
        'history': history,
    };
    
    factory MetricCardBlock.fromJson(Map<String, dynamic> json) {
        return MetricCardBlock(
            label: json['label'] ?? '',
            value: json['value']?.toString() ?? '',
            unit: json['unit'],
            status: json['status'],
            history: (json['history'] as List?)?.map((e) => double.tryParse(e.toString()) ?? 0.0).toList(),
        );
    }
}

class ChatMessage {
  final bool isUser;
  final List<MessageBlock> blocks;
  final DateTime? timestamp;
  final String? imagePath; 
  final String? reaction; 

  // Helpers for legacy / top-level access
  String get text => blocks.whereType<TextBlock>().map((e) => e.text).join('\n\n');
  HealthProtocol? get attachment => blocks.whereType<ProtocolBlock>().firstOrNull?.protocol;
  SimulationResult? get simulation => blocks.whereType<SimulationBlock>().firstOrNull?.simulation;
  MealPlan? get mealPlan => blocks.whereType<MealPlanBlock>().firstOrNull?.mealPlan;
  List<CtaAction>? get ctaActions => blocks.whereType<CtaBlock>().firstOrNull?.actions;
  
  ChatMessage({
    required this.isUser, 
    List<MessageBlock>? blocks,
    String? text,
    HealthProtocol? attachment,
    SimulationResult? simulation,
    MealPlan? mealPlan,
    List<CtaAction>? ctaActions,
    this.timestamp,
    this.imagePath,
    this.reaction,
  }) : blocks = blocks ?? _migrateLegacy(text, attachment, simulation, mealPlan, ctaActions);

  static List<MessageBlock> _migrateLegacy(String? text, HealthProtocol? att, SimulationResult? sim, MealPlan? meal, List<CtaAction>? cta) {
      final List<MessageBlock> b = [];
      if (text != null && text.isNotEmpty) b.add(TextBlock(text: text));
      if (att != null) b.add(ProtocolBlock(protocol: att));
      if (sim != null) b.add(SimulationBlock(simulation: sim));
      if (meal != null) b.add(MealPlanBlock(mealPlan: meal));
      if (cta != null && cta.isNotEmpty) b.add(CtaBlock(actions: cta));
      return b;
  }

  ChatMessage copyWith({
    List<MessageBlock>? blocks,
    String? reaction,
  }) {
    return ChatMessage(
      isUser: isUser,
      blocks: blocks ?? this.blocks,
      timestamp: timestamp,
      imagePath: imagePath,
      reaction: reaction ?? this.reaction,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isUser': isUser,
      'blocks': blocks.map((b) => b.toJson()).toList(),
      'timestamp': timestamp?.toIso8601String() ?? DateTime.now().toIso8601String(),
      if (imagePath != null) 'imagePath': imagePath,
      if (reaction != null) 'reaction': reaction,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    List<MessageBlock> parsedBlocks = [];
    if (json['blocks'] != null) {
        parsedBlocks = (json['blocks'] as List).map((b) => MessageBlock.fromJson(b)).toList();
    } else {
        // Legacy Migration
        parsedBlocks = _migrateLegacy(
            json['text'], 
            json['attachment'] != null ? HealthProtocol.fromJson(json['attachment']) : null,
            json['simulation'] != null ? SimulationResult.fromJson(json['simulation']) : null,
            json['mealPlan'] != null ? MealPlan.fromJson(json['mealPlan']) : null,
            json['ctaActions'] != null ? (json['ctaActions'] as List).map((a) => CtaAction.fromJson(a)).toList() : null
        );
    }
    return ChatMessage(
      isUser: json['isUser'] ?? false,
      blocks: parsedBlocks,
      timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp']) : null,
      imagePath: json['imagePath'],
      reaction: json['reaction'],
    );
  }
}

class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? loadingStatus;
   final HealthProtocol? pendingProtocol;
   final String? lastUserMessageText;
   final int? swappingDayIndex;
   final int? swappingMealIndex;
   
   ChatState({
     required this.messages, 
     this.isLoading = false, 
     this.loadingStatus,
     this.pendingProtocol,
     this.lastUserMessageText,
     this.swappingDayIndex,
     this.swappingMealIndex,
   });
   
   ChatState copyWith({
     List<ChatMessage>? messages, 
     bool? isLoading, 
     String? loadingStatus,
     HealthProtocol? pendingProtocol,
     String? lastUserMessageText,
     int? swappingDayIndex,
     int? swappingMealIndex,
   }) {
     return ChatState(
       messages: messages ?? this.messages,
       isLoading: isLoading ?? this.isLoading,
       loadingStatus: loadingStatus,
       pendingProtocol: pendingProtocol ?? this.pendingProtocol,
       lastUserMessageText: lastUserMessageText ?? this.lastUserMessageText,
       swappingDayIndex: swappingDayIndex ?? this.swappingDayIndex,
       swappingMealIndex: swappingMealIndex ?? this.swappingMealIndex,
     );
   }
}

class ChatNotifier extends Notifier<ChatState> {
  @override
  ChatState build() {
    return ChatState(messages: [
      ChatMessage(text: "Hello! I'm your AI health assistant. How can I help you today?", isUser: false),
    ]);
  }

  AzureOpenAIService get _aiService => ref.read(azureOpenAIServiceProvider);
  AgentService get _agentService => ref.read(agentServiceProvider);
  MemoryService get _memoryService => ref.read(memoryServiceProvider);

  String? _currentSessionId;
  bool _isCancelled = false; // Stop/Cancel flag

  // Initialize with a new session ID or load one
  void startNewSession() {
    _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
    state = ChatState(messages: [
      ChatMessage(text: "Hello! I'm your AI health assistant. How can I help you today?", isUser: false),
    ]);
  }

  /// Cancels the current AI generation
  void cancelCurrentRequest() {
    _isCancelled = true;
    state = state.copyWith(isLoading: false, loadingStatus: null);
  }

  /// Regenerates the last AI response
  Future<void> regenerateLastResponse() async {
    final lastText = state.lastUserMessageText;
    if (lastText == null || lastText.isEmpty) return;
    // Remove last AI message
    final msgs = List<ChatMessage>.from(state.messages);
    if (msgs.isNotEmpty && !msgs.last.isUser) msgs.removeLast();
    // Also remove the last user message so sendMessage can re-add it cleanly
    if (msgs.isNotEmpty && msgs.last.isUser) msgs.removeLast();
    state = state.copyWith(messages: msgs);
    await sendMessage(lastText);
  }

  /// Regenerates a specific meal within a meal plan.
  Future<void> regenerateMeal(int dayIndex, int mealIndex, {MealPlan? currentPlan}) async {
    state = state.copyWith(
      swappingDayIndex: dayIndex,
      swappingMealIndex: mealIndex,
    );
    
    MealPlan? targetPlan = currentPlan;

    if (targetPlan == null) {
      try {
        final lastMsg = state.messages.lastWhere((m) => m.mealPlan != null);
        targetPlan = lastMsg.mealPlan;
      } catch (_) {
        print("[AI ERROR] No meal plan found in message history to swap from.");
        state = state.copyWith(
          isLoading: false,
          loadingStatus: null,
          messages: [
            ...state.messages,
            ChatMessage(text: "I couldn't find the original meal plan to swap from. Please try generating a new one.", isUser: false),
          ],
        );
        return;
      }
    }

    if (targetPlan == null) return;
    
    final mealToSwap = targetPlan.weeklyPlan[dayIndex].meals[mealIndex];
    final dayName = targetPlan.weeklyPlan[dayIndex].day;

    final swapPrompt = "I'd like to swap the meal '${mealToSwap.name}' (scheduled for ${mealToSwap.time}) on $dayName. "
        "STRICT CONSTRAINT: The new meal MUST respect the dietary category of the original (e.g., if it was Veg, the replacement MUST be Veg; if it contained meat, the replacement MUST be a high-quality protein alternative). "
        "Provide a high-fidelity alternative that matches the original caloric and macro targets closely while fitting my clinical profile. "
        "Include a valid 'clinical_rationale' for the new meal. "
        "Return the FULL updated 7-day 'meal_plan' JSON.";

    await sendMessage(swapPrompt);
  }

  /// Specialized "In-Place" swap that bypasses full chat flow for speed.
  /// Returns the updated MealPlan or null if it fails.
  Future<MealPlan?> swapMealInPlace({
    required int dayIndex,
    required int mealIndex,
    required MealPlan currentPlan,
    String? suggestion,
  }) async {
    state = state.copyWith(
      isLoading: true,
      loadingStatus: "Swapping meal...",
      swappingDayIndex: dayIndex,
      swappingMealIndex: mealIndex,
    );

    final mealToSwap = currentPlan.weeklyPlan[dayIndex].meals[mealIndex];
    final dayName = currentPlan.weeklyPlan[dayIndex].day;

    final buffer = StringBuffer();
    buffer.writeln("You are a clinical performance nutritionist.");
    buffer.writeln("TASK: Swap a single meal in an existing 7-day meal plan.");
    buffer.writeln("MEAL TO SWAP: '${mealToSwap.name}' at ${mealToSwap.time} on $dayName.");
    buffer.writeln("IMPORTANT: The new meal MUST be DISTINCT and DIFFERENT from the original. Do not return the same meal.");
    if (suggestion != null && suggestion.isNotEmpty) {
      buffer.writeln("USER PREFERENCE: \"$suggestion\"");
    }
    
    buffer.writeln("\nSTRICT CONSTRAINTS:");
    buffer.writeln("- Match the original calorie (${mealToSwap.calories}) and macro targets (P:${mealToSwap.protein}, C:${mealToSwap.carbs}, F:${mealToSwap.fats}) as closely as possible.");
    buffer.writeln("- Respect the dietary category (Veg/Non-Veg) of the original.");
    buffer.writeln("- Factor in the user's lab reports and wearable trends.");
    buffer.writeln("- Provide a CONCISE 'clinical_rationale' (max 2-3 sentences) citing why this is a good swap for their profile.");
    buffer.writeln("- RETURN ONLY the updated 7-day 'meal_plan' JSON. No conversational text.");

    // Build context messages for speed (using callAzureAPI directly)
    final profile = ref.read(patientProfileProvider).value;
    final intelligence = ref.read(intelligenceDataProvider).value;
    final labReports = ref.read(labReportsProvider).value;

    final systemPrompt = StringBuffer();
    systemPrompt.writeln("You are the Intelligence. You output valid JSON meal plans.");
    if (profile != null) systemPrompt.writeln("User: ${profile.name}, Age: ${profile.age}");
    if (intelligence != null) systemPrompt.writeln("Health Score: ${intelligence.overallScore}");
    if (labReports != null && labReports.isNotEmpty) {
      final latest = labReports.first;
      systemPrompt.writeln("Latest Labs: ${latest.markers.map((m) => '${m.name}:${m.value}').join(', ')}");
    }

    final messages = [
      {"role": "system", "content": systemPrompt.toString()},
      {"role": "user", "content": "${buffer.toString()}\n\nCURRENT FULL PLAN JSON:\n${jsonEncode(currentPlan.toJson())}"}
    ];

    try {
      final responseText = await _aiService.callAzureAPI(messages, jsonMode: true);
      if (responseText != null) {
        final Map<String, dynamic> jsonMap = jsonDecode(_aiService.cleanJson(responseText));
        // Some AIs wrap in a 'meal_plan' key, some return the plan directly
        final planJson = jsonMap.containsKey('meal_plan') ? jsonMap['meal_plan'] : jsonMap;
        final updatedPlan = MealPlan.fromJson(planJson);

        // Add to history so Canvas can see it
        final updatedMessages = [...state.messages];
        updatedMessages.add(ChatMessage(
          isUser: false,
          blocks: [
            TextBlock(text: "I've updated your meal plan based on your suggestion: \"${suggestion ?? 'Instant swap'}\""),
            MealPlanBlock(mealPlan: updatedPlan),
          ],
        ));

        state = state.copyWith(
          isLoading: false, 
          loadingStatus: null,
          messages: updatedMessages,
        );
        
        // Persist to DB if user is authenticated
        final profileId = profile?.id;
        if (profileId != null) {
          // We'll update the record in Supabase
          await _updatePlanInDatabase(profileId, updatedPlan);
        }

        return updatedPlan;
      }
    } catch (e) {
      print("Swap in-place failed: $e");
    }

    state = state.copyWith(isLoading: false, loadingStatus: null);
    return null;
  }

  Future<void> _updatePlanInDatabase(String profileId, MealPlan plan) async {
    try {
      // Find the latest approved plan and update it
      final client = Supabase.instance.client;
      final response = await client
          .from('meal_plans')
          .select('id')
          .eq('profile_id', profileId)
          .eq('approved', true)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        await client.from('meal_plans').update({
          'weekly_plan': plan.weeklyPlan.map((d) => d.toJson()).toList(),
        }).eq('id', response['id']);
      } else {
        // Fallback: save as new if none found (unlikely for a paid user)
        await MealRepository.saveGeneratedPlan(profileId, plan);
      }
    } catch (e) {
      print("Failed to persist swapped plan: $e");
    }
  }

  /// Applies a thumbs up/down reaction to a message
  void reactToMessage(int index, String reaction) {
    final msgs = List<ChatMessage>.from(state.messages);
    if (index < 0 || index >= msgs.length) return;
    final existing = msgs[index].reaction;
    // Toggle off if same reaction tapped again
    msgs[index] = msgs[index].copyWith(reaction: existing == reaction ? '' : reaction);
    state = state.copyWith(messages: msgs);
  }

  Future<void> loadSession(String sessionId) async {
    final session = await ChatRepository.getSession(sessionId);
    if (session != null) {
      _currentSessionId = sessionId;
      state = ChatState(messages: session.messages); // Load loaded messages
    }
  }

  Future<void> _saveCurrentSession() async {
    if (_currentSessionId == null) startNewSession();

    // Create a title based on the first user message
    String title = "New Conversation";
    final firstUserMsg = state.messages.firstWhere((m) => m.isUser, orElse: () => ChatMessage(text: "New Conversation", isUser: true));
    if (firstUserMsg.text.isNotEmpty) {
      title = firstUserMsg.text.length > 30 ? "${firstUserMsg.text.substring(0, 30)}..." : firstUserMsg.text;
    }
    
    // Get last message text
    final lastMsg = state.messages.lastOrNull?.text ?? "No messages";

    // Generate Summary if session has substance (> 2 messages) and no summary exists yet (or update it)
    String? summary;
    if (state.messages.length >= 2) {
       print("RAG DEBUG: Threshold met (${state.messages.length} msgs). Generating summary...");
       
       try {
         // Convert to map for service safely
         final List<Map<String, String>> history = state.messages.map((m) => {
            "role": m.isUser ? "user" : "model",
            "text": m.text
         }).toList();
         
         summary = await _aiService.generateChatSummary(history);
         print("RAG DEBUG: Generated summary: $summary");

         // === RAG: Store memories (fire-and-forget, non-blocking) ===
         if (summary.isNotEmpty) {
           print("RAG DEBUG: Calling memorizeConversation...");
           _memoryService.memorizeConversation(
             summary: summary,
             messages: history,
             sessionId: _currentSessionId!,
           ).catchError((e) => print('RAG ERROR: Memory store error: $e'));
         }
       } catch (e) {
         print("Failed to generate summary or memorize: $e");
       }
    }

    final session = ChatSession(
      id: _currentSessionId!,
      title: title,
      date: DateTime.now(),
      lastMessage: lastMsg,
      messages: state.messages,
      summary: summary,
    );

    try {
      await ChatRepository.saveSession(session);
      // Fire-and-forget: refresh history list without blocking
      // ignore: unawaited_futures
      Future(() => ref.refresh(chatHistoryProvider));
    } catch (e) {
      print("CRITICAL: Failed to save session to local repository: $e");
    }
  }

  Future<void> sendMessage(String text, {String? imagePath, bool isVoiceMode = false}) async {
    if (text.trim().isEmpty) return;

    // --- CLINICAL BOUNDARY LAYER (APP-09) ---
    // Emergencies and clinical questions never reach the AI: they go to the
    // care team as escalations (see companion_boundaries.dart).
    final route = routeCompanionMessage(text);
    if (route != CompanionRoute.companion) {
      final userMsg = ChatMessage(text: text, isUser: true, timestamp: DateTime.now());
      state = state.copyWith(messages: [...state.messages, userMsg]);
      final filed = await fileCompanionEscalation(route, text);
      final reply = route == CompanionRoute.emergency
          ? emergencyGuidance(text)
          : (filed ? careTeamHandoffReply : careTeamHandoffFailedReply);
      final replyMsg = ChatMessage(text: reply, isUser: false, timestamp: DateTime.now());
      state = state.copyWith(messages: [...state.messages, replyMsg]);
      return;
    }
    // ------------------------------------

    _isCancelled = false; // Reset cancel flag for each new message
    final stopwatch = Stopwatch()..start(); // Instrumentation

    if (_currentSessionId == null) startNewSession();

    // Add user message immediately
    final userMsg = ChatMessage(
      text: text, 
      isUser: true, 
      timestamp: DateTime.now(),
      imagePath: imagePath,
    );
    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isLoading: true,
      loadingStatus: "Reviewing your health data...",
      lastUserMessageText: text,
    );

    // Increment chat usage
    ref.read(usageLimitProvider.notifier).incrementChat();

    // Early Persistence: Save the user's message immediately
    await _saveCurrentSession();
    
    try {
      // 1. Context Building
      final profile = ref.read(patientProfileProvider).value;
      final intelligence = ref.read(intelligenceDataProvider).value;

      final buffer = StringBuffer();
      buffer.writeln("You are Zyndio Intelligence, an advanced AI wellness and longevity assistant. Tone: warm, empathetic, conversational.");
      buffer.writeln("\n🚨 CRITICAL MEDICAL BOUNDARIES:");
      buffer.writeln("1. You are an AI, NOT a doctor. You must NEVER diagnose medical conditions or prescribe medications.");
      buffer.writeln("2. If the user mentions serious symptoms, explicitly advise them to consult a physician immediately.");
      buffer.writeln("3. Restrict recommendations strictly to functional nutrition, lifestyle optimization, and OTC longevity supplements.");
      buffer.writeln("4. Frame all insights as educational wellness reference, not medical treatment.");
      buffer.writeln("If tools are needed (LOG FOOD, UPDATE RHYTHM), use them silently.");

      // === COMPRESSED RESPONSE ARCHITECTURE ===
      buffer.writeln("\nRESPONSE FORMAT:");
      if (isVoiceMode) {
        buffer.writeln("- STRICT RULE: This is a VOICE conversation. Your response will be spoken aloud to the user.");
        buffer.writeln("- Be EXTREMELY concise. 1 to 2 sentences MAX.");
        buffer.writeln("- NO MARKDOWN. NO headers (##). NO bold (**). NO lists.");
        buffer.writeln("- Respond exactly like a human talking in a fast-paced phone call.");
        buffer.writeln("- Do NOT generate meal plans, protocols, or complex tables in voice mode. Just give the quick answer.");
      } else {
        buffer.writeln("- Lead with **bold 1-2 sentence key insight**.");
        buffer.writeln("- Use ## headers for sections, ### for subsections. Structure like a Bento-grid.");
        buffer.writeln("- Use > blockquotes for wellness context or expertise notes.");
        buffer.writeln("- NEVER use Markdown tables. Use JSON cards instead (schemas below).");
        buffer.writeln("- End substantive responses with --- then ## Next Steps.");
        buffer.writeln("- Paragraphs: 2-3 sentences max. No emojis. No greeting openers. Start with the answer.");
        buffer.writeln("- PREMIUM feature gating: Digital Twin & Bio-Protocols are premium.");
      }

      // === CARD SCHEMAS (COMPACT) ===
      buffer.writeln("\nCARD SCHEMAS — Output inside \`\`\`json fences:");
      buffer.writeln('metric_card: {"type":"metric_card","label":str,"value":str,"unit":str?,"status":"Optimal|Warning|Alert","history":[num]?} — for single metrics');
      buffer.writeln('data_card: {"type":"data_card","title":str,"verdict":str?,"rows":[{"label":str,"value":str,"status":str?,"history":[num]?}]} — for multi-row tables');

      // === DIGITAL TWIN ENGINE (COMPACT) ===
      buffer.writeln("\nDIGITAL TWIN ENGINE:");
      buffer.writeln("TRIGGER: 'what happens if', 'impact of', 'simulate', any hypothetical.");
      buffer.writeln("Frame as PREDICTION. Timescales: 3h (metabolic/food), 7d (rhythm/weekly), 12m (seasonal), 20y (longevity).");
      buffer.writeln("Use real biomarkers + wearable data as causal drivers. For 3h: include mitigation_effects.");
      buffer.writeln("Provide 6-8 curve data points. glucose_curve = mg/dL, energy_curve = 0-100.");
      buffer.writeln("Brief 2-3 sentence text, then JSON.");
      buffer.writeln('simulation: {"type":"simulation","verdict":str,"risk_level":"low|moderate|high","summary":str,"timescale":"3h|7d|12m|20y","baseline_glucose":num,"primary_label":str,"causal_drivers":[{"label":str,"value":str,"impact":"positive|negative|neutral","source":"lab|wearable"}],"mitigation_effects":{str:num}?,"glucose":{"label":str,"prediction":str,"severity":str,"detail":str},"insulin":{...},"sleep":{...},"energy":{...},"inflammation":{...},"glucose_curve":[{"t":num,"v":num}],"energy_curve":[{"t":num,"v":num}],"compare_label":str?,"compare_glucose_curve":[...]?,"compare_energy_curve":[...]?,"recommendations":[str],"reasoning":str}');

      // === PROTOCOL ENGINE (COMPACT) ===
      buffer.writeln("\nPROTOCOL ENGINE:");
      buffer.writeln("TRIGGER: solution/plan/protocol/'how to fix'/'how to improve'.");
      buffer.writeln("GATEKEEPER: If LONGEVITY PROFILE below is INCOMPLETE, REFUSE. Ask user to complete it in Settings.");
      buffer.writeln("TWO-STEP flow: Step 1 = ask 2-3 clarifying questions (goal specificity, constraints, timeline). No JSON. Step 2 = after answers, generate full protocol JSON.");
      buffer.writeln("Philosophy: Functional Medicine + silent Ayurvedic logic. No Sanskrit terms unless asked. No emojis. Swiss-Design precision.");
      buffer.writeln('protocol: {"type":"protocol","title":str,"summary":str,"lifestyle":{"title":str,"content":str,"action_items":[str]},"diet":{...},"fitness":{...},"supplements":{...}}');

      // === MEAL PLAN ENGINE (COMPACT) ===
      buffer.writeln("\nMEAL PLAN ENGINE:");
      buffer.writeln("TRIGGER: 'meal plan'/'diet plan'/'weekly menu'.");
      buffer.writeln("Same gatekeeper + two-step flow as Protocol. Step 1: ask cuisine, calorie target, meals/day. Step 2: generate 7-day JSON.");
      buffer.writeln("HYPER-PERSONALIZATION: Cross-reference lab markers (especially glucose/inflammation) and wearable trends. If 'Metabolic Health' score < 60, prioritize low-GI and higher fiber. If 'Recovery' is warning, increase anti-inflammatory foods.");
      buffer.writeln("CLINICAL RATIONALE: Every meal MUST include a 'clinical_rationale' field citing a specific biomarker or trend (e.g., 'Targeting your high fasting glucose [110 mg/dL]' or 'Boosts recovery given your declining HRV trend').");
      buffer.writeln("Use active protocol diet constraints + lab data. Each meal needs realistic macros. Use actual week dates.");
      buffer.writeln('meal_plan: {"type":"meal_plan","name":str,"weekly_plan":[{"day":str,"date":str,"meals":[{"time":str,"name":str,"desc":str,"calories":num,"protein":str,"carbs":str,"fats":str,"clinical_rationale":str}]}]}');

      // === CTA (COMPACT) ===
      buffer.writeln("\nCTA ACTIONS: When directing user to an app action, append after text in \`\`\`cta fences. Max 2.");
      buffer.writeln('Actions: navigate_to_meal_log, navigate_to_upload, navigate_to_protocol, navigate_to_wearables, navigate_to_paywall');
      buffer.writeln('Format: [{"label":str,"action":str}]. Only in text responses, NOT in protocol/simulation/meal_plan.');

      // === SMART CONTEXT INJECTION ===
      buffer.writeln("\n=== CURRENT HEALTH KNOWLEDGE ===");
      
      if (profile != null) {
        buffer.writeln("USER: ${profile.name}, Age: ${profile.age}");
      }

      final isFemale = ref.read(isFemaleUserProvider);
      if (isFemale) {
        final cycleState = ref.read(cycleIntelligenceProvider);
        if (cycleState.currentPhase != CyclePhase.unknown) {
          buffer.writeln("\n=== MENSTRUAL CYCLE CONTEXT ===");
          buffer.writeln("Current Phase: ${cycleState.currentPhase.name.toUpperCase()} (Day ${cycleState.currentDayOfCycle})");
          buffer.writeln("Take this phase into account for all nutrition, metabolism, and fitness recommendations. (e.g., Luteal = higher basal temp, lower HRV, more calories needed. Follicular = higher strength/resilience).");
        }
      }

      // === IMAGE CONTEXT INJECTION ===
      if (imagePath != null) {
        buffer.writeln("\n=== VISION INPUT ===");
        buffer.writeln("The user has attached an image to this message. Analyze the image carefully in context of their health data.");
        buffer.writeln("If it is a FOOD image: provide a brief nutritional impact analysis, glucose effect, and whether it aligns with their active protocol.");
        buffer.writeln("If it is a LAB REPORT image: extract visible biomarkers and cross-reference with existing lab data.");
        buffer.writeln("If it is a SUPPLEMENT label: analyze ingredients for interactions, synergies, or concerns given the user's profile.");
      }

      if (intelligence != null) {
        buffer.writeln("INTELLIGENCE SCORE: ${intelligence.overallScore}");
        // Inject Intelligence Domain Scores
        if (intelligence.healthDomains.isNotEmpty) {
          buffer.writeln("\n=== HEALTH DOMAIN SCORES (from Zyndio Intelligence) ===");
          buffer.writeln("Reference these grades when making predictions. Worse grades = amplified metabolic risk.");
          for (final domain in intelligence.healthDomains) {
            buffer.writeln("- ${domain.name}: Score ${domain.score}/100 | Grade: ${domain.grade ?? 'N/A'} | Status: ${domain.status ?? 'N/A'}");
          }
        }
        // Inject Disease Risks
        if (intelligence.diseaseRisks.isNotEmpty) {
          buffer.writeln("\nDISEASE RISK PROFILE:");
          for (final risk in intelligence.diseaseRisks) {
            buffer.writeln("- ${risk.condition}: ${risk.probability}% (${risk.level}) — Drivers: ${risk.drivers.join(', ')}");
          }
        }
      }

      // === ACTIVE PROTOCOL INJECTION ===
      final protocolState = ref.read(protocolProvider);
      final activeProtocol = protocolState.selectedProtocol;
      if (activeProtocol != null) {
        buffer.writeln("\n=== USER'S ACTIVE PROTOCOL ===");
        buffer.writeln("Protocol: ${activeProtocol.title} (${activeProtocol.currentPhase})");
        buffer.writeln("IMPORTANT: Factor these into predictions. Supplements affect metabolic response. Diet principles constrain recommendations.");
        
        // Diet
        if (activeProtocol.diet.features.isNotEmpty) {
          buffer.writeln("Diet Principles: ${activeProtocol.diet.features.join(', ')}");
        }
        if (activeProtocol.diet.macros.isNotEmpty) {
          buffer.writeln("Macros: ${activeProtocol.diet.macros.map((m) => '${m.label}: ${m.value}').join(', ')}");
        }
        if (activeProtocol.diet.avoid.isNotEmpty) {
          buffer.writeln("Avoiding: ${activeProtocol.diet.avoid.join(', ')}");
        }
        
        // Supplements
        if (activeProtocol.supplements.isNotEmpty) {
          buffer.writeln("Active Supplements: ${activeProtocol.supplements.map((s) => '${s.title} (${s.detail}) at ${s.time}').join(', ')}");
          buffer.writeln("NOTE: Factor supplement effects into metabolic simulations. E.g., Berberine lowers glucose spike ~15-20%, Omega-3 reduces inflammation.");
        }
        
        // Fitness
        if (activeProtocol.fitness.isNotEmpty) {
          buffer.writeln("Fitness: ${activeProtocol.fitness.map((f) => '${f.title} (${f.detail}) ${f.frequency ?? f.time}').join(', ')}");
        }
        
        // Target Metrics
        if (activeProtocol.targetMetrics.isNotEmpty) {
          buffer.writeln("Target Biomarkers: ${activeProtocol.targetMetrics.join(', ')}");
        }
      }
      
      // Inject Longevity Profile (Questionnaire)
      final questionnaire = ref.read(questionnaireProvider);
      buffer.writeln("\n=== LONGEVITY PROFILE ===");
      buffer.writeln("Status: ${questionnaire.isComplete ? 'COMPLETE' : 'INCOMPLETE'}");
      if (questionnaire.isComplete) {
         buffer.writeln("1. Health Baseline: Health: ${questionnaire.currentHealth}, Energy: ${questionnaire.energyLevel}, Digestion: ${questionnaire.digestiveDiscomfort}");
         buffer.writeln("2. Lifestyle: Activity: ${questionnaire.weeklyActivity}, Alcohol: ${questionnaire.alcoholConsumption}, Sitting: ${questionnaire.dailySittingHours}");
         buffer.writeln("3. Stress & Psych: Stress: ${questionnaire.stressScale}/10, Response: ${questionnaire.stressResponse.join(', ')}");
         buffer.writeln("4. Environment: City: ${questionnaire.cityResidence}, Screen Exp: ${questionnaire.screenExposureSleep}");
         buffer.writeln("5. Goals: Priorities: ${questionnaire.topPriorities.join(', ')}, Commitment: ${questionnaire.commitmentLevel}");
         buffer.writeln("6. Sleep: Hours: ${questionnaire.sleepHours}, Refreshment: ${questionnaire.refreshmentWaking}/10");
      }

      // Inject Lab Reports (Latest Panel + Trends)
      final labReports = ref.read(labReportsProvider).value;
      if (labReports != null && labReports.isNotEmpty) {
          final latestReport = labReports.first;
          buffer.writeln("\nLATEST LAB RESULTS (${latestReport.date}):");
          for (var marker in latestReport.markers) {
              buffer.writeln("- ${marker.name}: ${marker.value} (Range: ${marker.range}) [${marker.status}]"); 
          }
      }

      // === PARALLEL CONTEXT INJECTION (wearable + correlation + food + memory) ===
      state = state.copyWith(loadingStatus: "Retrieving health history...");
      print('[AI PERF] Context assembly started at ${stopwatch.elapsedMilliseconds}ms');

      // Prepare correlation lab markers (synchronous — just reads from state)
      List<Map<String, dynamic>>? labMarkers;
      final labReportsForCorr = ref.read(labReportsProvider).value;
      if (labReportsForCorr != null && labReportsForCorr.isNotEmpty) {
        labMarkers = labReportsForCorr.first.markers.map((m) => {
          'name': m.name,
          'value': m.value,
          'range': m.range,
          'status': m.status,
        }).toList();
      }

      // === SHARED DATA FETCH (SINGLE PASS) ===
      // Fetch wearable history ONCE and share between WearableContextService & CorrelationEngine.
      // This eliminates 5-7 duplicate database calls.
      final repo = HealthRepository();
      final healthCache = await SharedHealthCache.fetch(repo);
      print('[AI PERF] Shared health cache fetched at ${stopwatch.elapsedMilliseconds}ms');

      state = state.copyWith(loadingStatus: "Analyzing health patterns...");

      // Fire all context tasks in parallel — both wearable & correlation use the SAME cache
      final contextResults = await Future.wait([
        // 0: Wearable context (uses shared cache)
        WearableContextService(repo).buildContext(cache: healthCache)
            .catchError((_) => ''),
        // 1: Correlation Engine (uses shared cache)
        CorrelationEngine.analyze(
          repo: repo,
          intelligence: intelligence,
          labMarkers: labMarkers,
          cache: healthCache,
        ).catchError((_) => <String>[]),
        // 2: Food context
        FoodContextService.buildContext()
            .catchError((_) => ''),
        // 3: Memory recall
        _memoryService.recallMemories(text, count: 5)
            .catchError((_) => <MemoryFragment>[]),
        // 4: Recent local summaries
        ChatRepository.fetchRecentSummaries(3)
            .catchError((_) => <String>[]),
      ]);
      print('[AI PERF] All context assembled at ${stopwatch.elapsedMilliseconds}ms');

      state = state.copyWith(loadingStatus: "Consulting intelligence...");

      // Assemble results into the prompt buffer
      final wearableContext = contextResults[0] as String;
      if (wearableContext.isNotEmpty) {
        buffer.writeln('');
        buffer.writeln(wearableContext);
        buffer.writeln('Cross-reference wearable data with lab results. Cite specific numbers from history for trends.');
      }

      final correlationInsights = contextResults[1] as List<String>;
      if (correlationInsights.isNotEmpty) {
        buffer.writeln('');
        buffer.writeln('=== CROSS-DOMAIN PATTERN INSIGHTS ===');
        for (var i = 0; i < correlationInsights.length; i++) {
          buffer.writeln('${i + 1}. ${correlationInsights[i]}');
        }
      }

      final foodContext = contextResults[2] as String;
      if (foodContext.isNotEmpty) {
        buffer.writeln('');
        buffer.writeln(foodContext);
        buffer.writeln('Cross-reference food logs with wearable data to explain patterns.');
      }

      final memories = contextResults[3] as List<MemoryFragment>;
      if (memories.isNotEmpty) {
        buffer.writeln("\n=== LONG-TERM MEMORY ===");
        for (var i = 0; i < memories.length; i++) {
          final m = memories[i];
          final dateStr = m.createdAt.toIso8601String().substring(0, 10);
          buffer.writeln("[${m.memoryType.toUpperCase()}] ($dateStr | ${(m.similarity * 100).toStringAsFixed(0)}%) ${m.content}");
        }
      }

      final recentSummaries = contextResults[4] as List<String>;
      if (recentSummaries.isNotEmpty) {
        buffer.writeln("\nRECENT MEMORY:");
        for (var s in recentSummaries) {
          buffer.writeln("- $s");
        }
      }
      
      buffer.writeln("\nBase analysis on the data above. Don't ask for data you already have. Reference memories naturally.");

      // 2. Build Message List with optional image in the last user turn
      final history = state.messages.sublist(0, state.messages.length - 1).map((m) => {
        "role": m.isUser ? "user" : "model",
        "text": m.text
      }).toList();

      final List<Map<String, dynamic>> apiMessages = [
          {"role": "system", "content": buffer.toString()},
          ...history.map((m) => {
              "role": m['role'] == 'model' ? 'assistant' : m['role']!,
              "content": m['text']!
          }),
      ];

      // Build last user turn (possibly multimodal with image)
      if (imagePath != null) {
        try {
          final bytes = await File(imagePath).readAsBytes();
          final base64Image = base64Encode(bytes);
          apiMessages.add({
            "role": "user",
            "content": [
              {"type": "text", "text": text},
              {"type": "image_url", "image_url": {"url": "data:image/jpeg;base64,$base64Image"}}
            ],
          });
        } catch (e) {
          print('Image encoding failed: $e');
          apiMessages.add({"role": "user", "content": text});
        }
      } else {
        apiMessages.add({"role": "user", "content": text});
      }


      // 3. Agent Loop
      bool finished = false;
      int turns = 0;
      final maxTurns = 5;

      while (!finished && turns < maxTurns) {
          turns++;
          
          print('[AI PERF] API call started at ${stopwatch.elapsedMilliseconds}ms');
          final stream = _aiService.getChatResponseStream(
              apiMessages, 
              tools: AgentTools.definitions
          );
          
          // --- STREAMING LOOP ---
          String accumulatedContent = "";
          List<ToolCall>? finalToolCalls;
          bool firstTokenReceived = false;
          int? aiMsgIndex; // Captured when first token arrives
          
          // --- SMOOTHNESS UPGRADE: Token Batching & Haptics ---
          DateTime lastUpdateTime = DateTime.now();
          const updateInterval = Duration(milliseconds: 40); 
          
          await for (var event in stream) {
              if (_isCancelled) { finished = true; break; }
              
              if (event.contentDelta != null && event.contentDelta!.isNotEmpty) {
                  accumulatedContent += event.contentDelta!;
                  
                  // 1. LAZY INSERTION: Add the message to state only when first token arrives
                  if (!firstTokenReceived) {
                    firstTokenReceived = true;
                    aiMsgIndex = state.messages.length;
                    final emptyAiMsg = ChatMessage(text: "", isUser: false);
                    state = state.copyWith(
                      messages: [...state.messages, emptyAiMsg], 
                      isLoading: true, 
                      loadingStatus: null
                    );
                    print('[AI PERF] ⚡ Time to First Token: ${stopwatch.elapsedMilliseconds}ms');
                  }
                  
                  final now = DateTime.now();
                  // Update UI every 40ms or for the first few tokens for snappiness
                  if (aiMsgIndex != null && (now.difference(lastUpdateTime) > updateInterval || accumulatedContent.length < 5)) {
                    lastUpdateTime = now;
                    
                    // Light haptic tick for typewriter feel (every 3-5 chars)
                    if (accumulatedContent.length % 4 == 0) {
                       HapticFeedback.selectionClick();
                    }

                    // STREAMING BLOCK HYGIENE: 
                    // Hide markdown cards only if they are the ONLY things being streamed,
                    // otherwise just let the markdown flow to avoid hiding key insights.
                    String displayContent = accumulatedContent;
                    if (displayContent.contains('```json')) {
                       final parts = displayContent.split('```json');
                       if (parts[0].trim().isEmpty) {
                         displayContent = "Generating digital analysis..."; 
                       } else {
                         displayContent = parts[0].trim();
                       }
                    } else if (displayContent.contains('```cta')) {
                       displayContent = displayContent.split('```cta')[0].trim();
                    }

                    final updatedMessages = List<ChatMessage>.from(state.messages);
                    updatedMessages[aiMsgIndex] = ChatMessage(
                        text: displayContent,
                        isUser: false,
                    );
                    state = state.copyWith(messages: updatedMessages);
                  }
              }
              
              if (event.toolCalls != null) {
                  finalToolCalls = event.toolCalls;
              }
              
              if (event.isDone) break;
          }
          
          if (_isCancelled) {
              if (aiMsgIndex != null) {
                final updatedMessages = List<ChatMessage>.from(state.messages);
                updatedMessages[aiMsgIndex] = ChatMessage(
                    text: accumulatedContent.isNotEmpty ? "$accumulatedContent [Cancelled]" : "Cancelled.",
                    isUser: false,
                );
                state = state.copyWith(messages: updatedMessages, isLoading: false, loadingStatus: null);
              } else {
                state = state.copyWith(isLoading: false, loadingStatus: null);
              }
              break;
          }

          if (finalToolCalls != null && finalToolCalls.isNotEmpty) {
              // Executing Tools
              final updatedMessages = List<ChatMessage>.from(state.messages);
              if (aiMsgIndex != null) updatedMessages.removeAt(aiMsgIndex); 
              state = state.copyWith(messages: updatedMessages, loadingStatus: "Performing actions...");
              
              if (accumulatedContent.isNotEmpty) {
                  apiMessages.add({"role": "assistant", "content": accumulatedContent});
              } else {
                  apiMessages.add({"role": "assistant", "content": "I will execute that for you."}); 
              }

              for (var tool in finalToolCalls) {
                  final toolOutput = await _agentService.executeTool(tool.name, tool.arguments);
                  
                  apiMessages.add({
                      "role": "user",
                      "content": "[SYSTEM] Tool '${tool.name}' output: $toolOutput\nNow generate a relevant, user-facing response detailing what you did."
                  });
              }
              state = state.copyWith(loadingStatus: "Finalizing response...");
          } else {
              // Final Response Processing
              if (accumulatedContent.isNotEmpty) {
                  final parsedBlocks = _parseBlocks(accumulatedContent, ref.read(purchaseProvider).isPlus, ref.read(canGenerateProtocolProvider));
                  final ChatMessage finalAiMsg = ChatMessage(isUser: false, blocks: parsedBlocks);

                  final updatedMessages = List<ChatMessage>.from(state.messages);
                  if (aiMsgIndex != null) {
                    updatedMessages[aiMsgIndex] = finalAiMsg;
                  } else {
                    updatedMessages.add(finalAiMsg);
                  }
                  state = state.copyWith(
                      messages: updatedMessages,
                      isLoading: false,
                      loadingStatus: null
                  );
                  
                  // Final Save
                  await _saveCurrentSession();
                  finished = true;
              } else {
                  // Fallback: No content and no tools means we are done
                  finished = true;
              }
          }

      }
    } catch (e) {
      print("[AI ERROR] sendMessage failed: $e");
      // Add error message to chat so user isn't left hanging
      final errorMsg = ChatMessage(text: "I encountered an error while processing that. Please try again.", isUser: false);
      state = state.copyWith(
        messages: [...state.messages, errorMsg],
        isLoading: false,
        loadingStatus: null
      );
    } finally {
      // GUARANTEE: Reset loading state regardless of outcome
      state = state.copyWith(
        isLoading: false, 
        loadingStatus: null,
        swappingDayIndex: null,
        swappingMealIndex: null,
      );
      print('[AI PERF] Total completion time: ${stopwatch.elapsedMilliseconds}ms');
    }
  }


  List<MessageBlock> _parseBlocks(String content, bool isPlus, bool canGenerate) {
    List<MessageBlock> blocks = [];
    final regex = RegExp(r'```(json|cta)(.*?)```', dotAll: true);
    
    int lastMatchEnd = 0;
    for (final match in regex.allMatches(content)) {
      // 1. Text before the JSON/CTA
      if (match.start > lastMatchEnd) {
        String textBlock = content.substring(lastMatchEnd, match.start).trim();
        if (textBlock.isNotEmpty) {
          // Remove Markdown horizontal rules typically used right before cards
          textBlock = textBlock.replaceAll(RegExp(r'\n[-_*]{3,}\s*$'), '').trim();
          if (textBlock.isNotEmpty) blocks.add(TextBlock(text: textBlock));
        }
      }

      // 2. The block itself
      String type = match.group(1)!;
      String payload = match.group(2)!.trim();

      if (type == 'cta') {
        try {
          final List<dynamic> ctaList = jsonDecode(payload);
          blocks.add(CtaBlock(actions: ctaList.map((a) => CtaAction.fromJson(a as Map<String, dynamic>)).toList()));
        } catch (e) {
          print('CTA Parse Error: $e');
        }
      } else if (type == 'json') {
        try {
          final Map<String, dynamic> data = jsonDecode(payload);
          if (data['type'] == 'data_card') {
            blocks.add(DataCardBlock.fromJson(data));
          } else if (data['type'] == 'simulation') {
            if (!isPlus) {
               blocks.add(CtaBlock(actions: [CtaAction(label: 'Unlock Simulation with Plus', action: 'navigate_to_paywall')]));
               blocks.add(TextBlock(text: "Feature Locked: AI Simulations require Zyndio Plus."));
            } else {
               blocks.add(SimulationBlock(simulation: SimulationResult.fromJson(data)));
            }
          } else if (data['type'] == 'protocol') {
            if (!canGenerate && !isPlus) {
               blocks.add(CtaBlock(actions: [CtaAction(label: 'Upgrade for Unlimited Protocols', action: 'navigate_to_paywall')]));
               blocks.add(TextBlock(text: "Feature Locked: Monthly protocol generation limit reached."));
            } else {
               blocks.add(ProtocolBlock(protocol: HealthProtocol.fromJson(data)));
               // Since ref is available here (via instance method), this works.
            }
          } else if (data['type'] == 'meal_plan') {
            if (!canGenerate && !isPlus) {
               blocks.add(CtaBlock(actions: [CtaAction(label: 'Upgrade for Unlimited Meal Plans', action: 'navigate_to_paywall')]));
               blocks.add(TextBlock(text: "Feature Locked: Monthly meal plan generation limit reached."));
            } else {
               blocks.add(MealPlanBlock(mealPlan: MealPlan.fromJson(data)));
            }
          }
        } catch (e) {
           print('JSON Parse Error: $e');
        }
      }
      
      lastMatchEnd = match.end;
    }

    // 3. Text after
    if (lastMatchEnd < content.length) {
      String remainingText = content.substring(lastMatchEnd).trim();
      if (remainingText.isNotEmpty) {
        blocks.add(TextBlock(text: remainingText));
      }
    }

    // Fallback if no blocks were matched
    if (blocks.isEmpty && content.trim().isNotEmpty) {
        blocks.add(TextBlock(text: content.trim()));
    }

    return blocks;
  }
}


final chatProvider = NotifierProvider<ChatNotifier, ChatState>(() {
  return ChatNotifier();
});
