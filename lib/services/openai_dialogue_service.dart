import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../models/game_state.dart';
import '../models/simulation_step.dart';
import '../models/scenario_config.dart';
import '../models/scenario_models.dart';
import '../core/config/app_config.dart';
import 'realistic_tts_service.dart';
import 'menu_service.dart';

// Enhanced conversation context for tracking state
class ConversationContext {
  final List<ConversationMessage> messages;
  final bool allergiesDisclosed;
  final bool confirmedDish;
  final List<String> disclosedAllergies;
  final String? selectedDish;
  final int turnCount;
  final Map<String, bool> topicsCovered;

  // NEW: Order tracking after safety warnings
  final List<String> cancelledOrdersAfterWarning;
  final List<String> keptUnsafeOrdersAfterWarning;
  final List<String> reorderedItemsAfterCancellation;
  final bool safetyWarningGiven;

  const ConversationContext({
    this.messages = const [],
    this.allergiesDisclosed = false,
    this.confirmedDish = false,
    this.disclosedAllergies = const [],
    this.selectedDish,
    this.turnCount = 0,
    this.topicsCovered = const {},
    this.cancelledOrdersAfterWarning = const [],
    this.keptUnsafeOrdersAfterWarning = const [],
    this.reorderedItemsAfterCancellation = const [],
    this.safetyWarningGiven = false,
  });

  ConversationContext copyWith({
    List<ConversationMessage>? messages,
    bool? allergiesDisclosed,
    bool? confirmedDish,
    List<String>? disclosedAllergies,
    String? selectedDish,
    int? turnCount,
    Map<String, bool>? topicsCovered,
    List<String>? cancelledOrdersAfterWarning,
    List<String>? keptUnsafeOrdersAfterWarning,
    List<String>? reorderedItemsAfterCancellation,
    bool? safetyWarningGiven,
  }) {
    return ConversationContext(
      messages: messages ?? this.messages,
      allergiesDisclosed: allergiesDisclosed ?? this.allergiesDisclosed,
      confirmedDish: confirmedDish ?? this.confirmedDish,
      disclosedAllergies: disclosedAllergies ?? this.disclosedAllergies,
      selectedDish: selectedDish ?? this.selectedDish,
      turnCount: turnCount ?? this.turnCount,
      topicsCovered: topicsCovered ?? this.topicsCovered,
      cancelledOrdersAfterWarning:
          cancelledOrdersAfterWarning ?? this.cancelledOrdersAfterWarning,
      keptUnsafeOrdersAfterWarning:
          keptUnsafeOrdersAfterWarning ?? this.keptUnsafeOrdersAfterWarning,
      reorderedItemsAfterCancellation:
          reorderedItemsAfterCancellation ??
          this.reorderedItemsAfterCancellation,
      safetyWarningGiven: safetyWarningGiven ?? this.safetyWarningGiven,
    );
  }

  // Helper to get recent messages for context (last 6 messages)
  List<ConversationMessage> get recentMessages {
    if (messages.length <= 6) return messages;
    return messages.sublist(messages.length - 6);
  }
}

class ConversationMessage {
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;

  const ConversationMessage({
    required this.role,
    required this.content,
    required this.timestamp,
  });

  Map<String, String> toOpenAIMessage() {
    return {'role': role, 'content': content};
  }
}

// Enhanced menu item structure
class MenuItem {
  final String name;
  final String description;
  final List<String> allergens;
  final bool isSafe; // Based on user's allergies

  const MenuItem({
    required this.name,
    required this.description,
    required this.allergens,
    required this.isSafe,
  });
}

// Enhanced NPC response structure
class NPCDialogueResponse {
  final String npcDialogue;
  final bool isPositiveFeedback;
  final int confidencePoints;
  final List<String> detectedAllergies;
  final String followUpPrompt;
  final ConversationContext updatedContext;
  final bool shouldEndConversation;

  const NPCDialogueResponse({
    required this.npcDialogue,
    required this.isPositiveFeedback,
    required this.confidencePoints,
    required this.detectedAllergies,
    required this.followUpPrompt,
    required this.updatedContext,
    this.shouldEndConversation = false,
  });
}

// Separate scoring response for enhanced evaluation
class ConfidenceScoreResponse {
  final int confidenceScore;
  final String detailedFeedback;
  final List<String> strengthsObserved;
  final List<String> areasForImprovement;
  final bool overallSafetyRating;

  const ConfidenceScoreResponse({
    required this.confidenceScore,
    required this.detailedFeedback,
    required this.strengthsObserved,
    required this.areasForImprovement,
    required this.overallSafetyRating,
  });
}

class OpenAIDialogueService {
  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';

  final SpeechToText _speechToText = SpeechToText();
  final RealisticTTSService _realisticTts = RealisticTTSService();
  bool _speechEnabled = false;
  bool _isListening = false;
  String _lastWords = '';

  // Current conversation context
  ConversationContext _currentContext = const ConversationContext();

  // Callbacks for UI updates
  Function(String)? onTranscriptionUpdate;
  Function(String, bool)? onNPCResponse; // response text, isPositive
  Function(bool)? onListeningStateChange;
  Function(String)? onError;
  Function(bool)? onSpeechEnabledChange;
  Function(ConversationContext)? onContextUpdate;

  // TTS callbacks for animation synchronization
  Function()? onTTSStarted;
  Function()? onTTSCompleted;

  OpenAIDialogueService() {
    // Initialize services asynchronously to prevent crashes
    initializeServices();
  }

  Future<void> initializeServices() async {
    try {
      await _initSpeech();
      await _initTts();
    } catch (e) {
      debugPrint('Error initializing services: $e');
      onError?.call('Failed to initialize AI services: $e');
    }
  }

  Future<void> _initSpeech() async {
    try {
      // Log platform info for debugging
      debugPrint(
        'OpenAIDialogueService: Initializing speech on platform: ${Platform.operatingSystem}',
      );
      if (Platform.isIOS) {
        debugPrint(
          'OpenAIDialogueService: iOS detected - simulator may have slower speech recognition',
        );
      }

      _speechEnabled = await _speechToText.initialize(
        onError: (error) {
          debugPrint('[SPEECH] Speech recognition error: ${error.errorMsg}');
          String userFriendlyMessage = _getUserFriendlyErrorMessage(
            error.errorMsg,
          );
          onError?.call(userFriendlyMessage);

          // Handle specific error types
          if (error.errorMsg.contains('timeout') ||
              error.errorMsg.contains('no_match')) {
            debugPrint(
              '[SPEECH] Timeout/no match error - user must manually restart',
            );
          }
        },
        onStatus: (status) {
          // Handle status changes that might indicate problems
          if (status == 'notListening' && _isListening) {
            debugPrint(
              '[SPEECH] Speech stopped unexpectedly - status: $status',
            );
            _isListening = false;
            onListeningStateChange?.call(false);
          }
        },
        debugLogging: kDebugMode,
      );

      onSpeechEnabledChange?.call(_speechEnabled);
    } catch (e) {
      debugPrint('Error initializing speech to text: $e');
      onError?.call('Failed to initialize speech recognition');
      _speechEnabled = false;
      onSpeechEnabledChange?.call(false);
    }
  }

  Future<void> _initTts() async {
    try {
      // Set to male voice explicitly
      _realisticTts.setMaleVoice(preferredVoice: 'echo');

      // Set up callbacks for animation synchronization
      _realisticTts.onTTSCompleted = () {
        debugPrint('TTS completed - triggering animation stop');
        onTTSCompleted?.call();
      };

      _realisticTts.onTTSStarted = () {
        debugPrint('TTS started - triggering animation start');

        if (_isListening) {
          debugPrint('[SPEECH] Stopping speech recognition for TTS playback');
          stopListening();
        }

        onTTSStarted?.call();
      };

      _realisticTts.onError = (error) {
        debugPrint('TTS error: $error');
        onError?.call(error);
      };

      debugPrint(
        'RealisticTTSService initialized successfully with voice: ${_realisticTts.getCurrentVoice()}',
      );
    } catch (e) {
      debugPrint('Error initializing TTS: $e');
      onError?.call('Failed to initialize text-to-speech');
    }
  }

  Future<void> startListening() async {
    if (!_speechEnabled) {
      onError?.call('Speech recognition not available');
      return;
    }

    if (_isListening) {
      await stopListening();
      return;
    }

    if (_realisticTts.isPlaying) {
      debugPrint('[SPEECH] TTS is playing - delaying speech recognition start');
      onError?.call('Please wait for the waiter to finish speaking');
      return;
    }

    try {
      await Future.delayed(const Duration(milliseconds: 500));

      await _speechToText.listen(
        onResult: (result) {
          _lastWords = result.recognizedWords;

          final cleanedInput = _cleanSpeechInput(_lastWords);

          // Only update if the cleaned input is substantially different and valid
          if (cleanedInput.isNotEmpty && cleanedInput != _lastWords) {
            debugPrint('🎤 [SPEECH] Raw input: "$_lastWords"');
            debugPrint('🎤 [SPEECH] Cleaned input: "$cleanedInput"');
            _lastWords = cleanedInput;
          }

          onTranscriptionUpdate?.call(_lastWords);
          debugPrint(
            '[SPEECH] Speech result: $_lastWords (confidence: ${result.confidence}, hasConfidenceRating: ${result.hasConfidenceRating})',
          );
        },
        listenFor: const Duration(
          seconds: 45, // Increased to allow for longer complete sentences
        ),
        pauseFor: const Duration(
          seconds:
              12, // Increased to 12 seconds to allow for natural pauses and complete thoughts
        ),
        listenOptions: SpeechListenOptions(
          partialResults: true, // Re-enabled for real-time text display
          cancelOnError: false,
          listenMode: ListenMode
              .dictation, // Changed to dictation mode for better handling of longer sentences
          enableHapticFeedback: false,
          autoPunctuation: true,
        ),
      );

      _isListening = true;
      onListeningStateChange?.call(true);
    } catch (e) {
      await _handleSpeechError(e.toString());
    }
  }

  String _cleanSpeechInput(String input) {
    if (input.trim().isEmpty) return input;

    final ttsPatterns = [
      'welcome',
      'let me know whenever you\'re ready to order',
      'come, let me know',
      'of course, are you ready to order',
      'would you like a few more minutes to decide',
      'what can i get for you',
      'our menu features',
      'i\'d be happy to help',
    ];

    String cleaned = input.toLowerCase().trim();

    if (cleaned.contains('allergic') || cleaned.contains('allergy')) {
      for (final pattern in ttsPatterns) {
        cleaned = cleaned.replaceAll(pattern, '').trim();
      }
      return cleaned.isEmpty ? input.trim() : cleaned;
    }

    for (final pattern in ttsPatterns) {
      cleaned = cleaned.replaceAll(pattern, '').trim();
    }

    // Remove excessive repetition - if the same phrase appears 3+ times, keep only one
    final words = cleaned.split(' ');
    final cleanedWords = <String>[];
    String? lastPhrase;
    int repeatCount = 0;

    for (int i = 0; i < words.length; i++) {
      // Look for repeating 3-word phrases
      if (i + 2 < words.length) {
        final phrase = '${words[i]} ${words[i + 1]} ${words[i + 2]}';
        if (phrase == lastPhrase) {
          repeatCount++;
          if (repeatCount >= 2) {
            // Skip this repetition
            i += 2; // Skip the next 2 words too
            continue;
          }
        } else {
          lastPhrase = phrase;
          repeatCount = 0;
        }
      }
      cleanedWords.add(words[i]);
    }

    cleaned = cleanedWords.join(' ').trim();

    // Extract the most recent/relevant user input - look for question words or ordering phrases
    final userIndicators = [
      'hi',
      'what\'s',
      'whats',
      'can i',
      'i want',
      'i\'d like',
      'menu',
      'order',
      'allergic',
      'allergy',
      'i am',
      'what are',
      'what',
      'safe',
      'options',
    ];
    final sentences = cleaned
        .split(RegExp(r'[.!?]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    // Find the sentence that contains user indicators
    for (final sentence in sentences.reversed) {
      if (userIndicators.any((indicator) => sentence.contains(indicator))) {
        // Found a likely user input
        if (sentence.length > 3 && sentence.length < 100) {
          return sentence.trim();
        }
      }
    }

    // If no clear user input found, return the last short sentence
    if (sentences.isNotEmpty) {
      final lastSentence = sentences.last;
      if (lastSentence.length > 3 && lastSentence.length < 50) {
        return lastSentence.trim();
      }
    }

    // If all else fails, look for the shortest meaningful part
    final shortParts = cleaned
        .split(' ')
        .where((part) => part.length > 2)
        .toList();
    if (shortParts.length <= 6 && shortParts.isNotEmpty) {
      return shortParts.join(' ').trim();
    }

    // Return original if we can't clean it effectively
    return input.trim();
  }

  Future<void> stopListening() async {
    if (_isListening) {
      await _speechToText.stop();
      _isListening = false;
      onListeningStateChange?.call(false);
    }
  }

  /// Enhanced error handling and recovery for speech recognition
  Future<void> _handleSpeechError(String error) async {
    // Stop current listening session
    _isListening = false;
    onListeningStateChange?.call(false);

    // Check if it's a timeout or pause-related error that we can recover from
    if (error.contains('timeout') ||
        error.contains('pause') ||
        error.contains('no_match')) {
      debugPrint(
        '[SPEECH] Detected timeout/pause error - attempting automatic restart',
      );

      // Wait a moment before restarting
      await Future.delayed(const Duration(milliseconds: 500));

      // Try to restart listening if speech is still enabled
      if (_speechEnabled) {
        await startListening();
        return;
      }
    }

    // For other errors, provide user-friendly feedback
    final userFriendlyMessage = _getUserFriendlyErrorMessage(error);
    onError?.call(userFriendlyMessage);
  }

  /// Restart speech recognition when it gets stuck or times out
  Future<void> restartSpeechRecognition() async {
    // Stop current session
    if (_isListening) {
      await stopListening();
    }

    // Wait a moment
    await Future.delayed(const Duration(milliseconds: 500));

    // Start listening again
    if (_speechEnabled) {
      await startListening();
    }
  }

  // Reset conversation context for new simulation
  void resetConversation() {
    _currentContext = const ConversationContext();
    onContextUpdate?.call(_currentContext);
  }

  // Main method for getting AI response with enhanced context
  Future<NPCDialogueResponse> getOpenAIResponse({
    required String userInput,
    required SimulationStep currentStep,
    required PlayerProfile playerProfile,
    required String npcRole,
    required String scenarioContext,
    ConversationContext? context,
    String? systemPrompt,
    ScenarioConfig? scenarioConfig,
  }) async {
    try {
      // Use provided context or current context
      final workingContext = context ?? _currentContext;

      // Add user message to conversation history
      final userMessage = ConversationMessage(
        role: 'user',
        content: userInput,
        timestamp: DateTime.now(),
      );

      final updatedMessages = [...workingContext.messages, userMessage];

      // Load menu from scenario config or default file
      if (scenarioConfig?.menuData != null) {
        await MenuService.instance.loadMenu(menuData: scenarioConfig!.menuData);
      } else {
        // Fallback to default menu
        await MenuService.instance.loadMenu();
      }
      final menuForAI = MenuService.instance.formatMenuForAI(
        playerProfile.allergies,
      );

      debugPrint(
        '[MENU] Formatted menu for AI (first 500 chars): ${menuForAI.substring(0, menuForAI.length > 500 ? 500 : menuForAI.length)}...',
      );
      if (menuForAI.isEmpty) {
        debugPrint(
          '[MENU] ERROR: Menu is empty! AI will give generic responses.',
        );
      }

      final analysisResponse = await _analyzeUserIntent(
        userInput,
        playerProfile,
        workingContext,
      );

      final waiterResponse = await _generateWaiterResponse(
        userInput,
        systemPrompt,
        workingContext,
        menuForAI,
        scenarioConfig: scenarioConfig,
        playerProfile: playerProfile,
      );

      // Update context based on AI analysis (not phrase matching)
      final updatedContext = _updateContextFromAnalysis(
        workingContext.copyWith(messages: updatedMessages),
        analysisResponse,
        waiterResponse,
        userInput, // Add user input parameter
      );

      return NPCDialogueResponse(
        npcDialogue: waiterResponse,
        isPositiveFeedback: true,
        confidencePoints: 0,
        detectedAllergies:
            (analysisResponse['mentioned_allergies'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .where((e) => e.isNotEmpty)
                .toList() ??
            <String>[],
        followUpPrompt: '',
        updatedContext: updatedContext,
        shouldEndConversation:
            analysisResponse['conversation_should_end'] ?? false,
      );
    } catch (e) {
      debugPrint('Error in NPC response generation: $e');
      return NPCDialogueResponse(
        npcDialogue:
            "I apologize, but I'm having trouble understanding. Could you please repeat that?",
        isPositiveFeedback: false,
        confidencePoints: 0,
        detectedAllergies: <String>[],
        followUpPrompt: '',
        updatedContext: context ?? _currentContext,
        shouldEndConversation: false,
      );
    }
  }

  // Enhanced system prompt template with dynamic context
  String _buildEnhancedSystemPrompt({
    required String npcRole,
    required String scenarioContext,
    required PlayerProfile playerProfile,
    required ConversationContext context,
    required String menuForAI,
  }) {
    final hasDisclosedAllergies = context.allergiesDisclosed;
    final previousAllergies = context.disclosedAllergies.join(', ');
    final selectedDish = context.selectedDish;
    final recentMessages = context.recentMessages
        .take(4)
        .map((m) => '${m.role}: ${m.content}')
        .join('\n');

    // Check if customer ordered unsafe food by checking with MenuService
    if (selectedDish != null) {
      final menuItem = MenuService.instance.findItemByName(selectedDish);
      if (menuItem != null) {
        final orderedUnsafeFood = !MenuService.instance.isItemSafeForUser(
          menuItem,
          playerProfile.allergies,
        );
        // This safety check is used in the system prompt generation
        debugPrint(
          '[SAFETY] Selected dish "$selectedDish" is ${orderedUnsafeFood ? "UNSAFE" : "SAFE"} for user allergies',
        );
      }
    }

    return '''
You are a restaurant waiter serving a customer. Be natural and conversational.

CUSTOMER STATUS: ${hasDisclosedAllergies ? 'Mentioned allergies: $previousAllergies' : 'No allergies mentioned yet'}
${selectedDish != null ? 'Current order: $selectedDish' : 'No order placed yet'}

🍽️ YOUR MENU (ONLY mention these exact dishes):
$menuForAI

BE A NATURAL WAITER:
- Sound like a real person, not a robot
- Use short, natural responses: "Great", "Perfect", "That's okay", "Yeah no problem"
- Vary your greetings: "Hi there!", "Hello, ready to order?", "Welcome!"
- When customers mention allergies: "That's okay, I'll make sure to let the chef know"
- Keep responses conversational and human

MENU RULE: ONLY mention dishes from the menu above - never invent food items.

NATURAL WAITER RESPONSES:
- When customer mentions allergies: "No problem at all, I'll let the kitchen know"
- Order confirmations: "Perfect, I'll get that started", "Coming right up"
- Safety concerns: "I need to let you know that [dish] contains [allergen]"
- Recommendations: Only suggest actual menu items marked as safe

CRITICAL: If customer orders unsafe food, warn them naturally before confirming the order.

Recent conversation:
$recentMessages

HOW TO RESPOND NATURALLY:
- If customer asks for menu: List a few actual dishes from above
- If customer mentions allergies: "That's okay, I'll make sure to let the chef know"
- If customer orders: "Great" or "Perfect, I'll get that started"
- If customer asks about ingredients: Give honest info about what's in the dish
- If customer orders unsafe food: "I need to let you know that [dish] contains [allergen]"

CRITICAL: You MUST respond with ONLY valid JSON. No other text before or after.

CRITICAL: ORDER CONFIRMATION & CONVERSATION ENDING:

When customer says "thank you" or seems finished:
→ ASK: "Is that everything? You've ordered the [SPECIFIC DISH NAME] - is that correct?"

When customer asks "repeat my order" or "what did I order":
→ ALWAYS say the EXACT DISH NAME: "You ordered the [SPECIFIC DISH NAME]"
→ NEVER say generic things like "a dish that needs preparation"

When customer confirms with "yes" / "that's grand" / "correct":
→ RESPOND: "Perfect! I'll get that started for you" → Natural ending

Format: {
  "npc_dialogue": "Your natural waiter response here - be natural, not meta", 
  "detected_allergies": ["allergy1"],
  "reasoning": "Customer asked about X, they have Y allergy, I classified this as Z intent and responded accordingly"
}

CRITICAL FORMATTING RULES: 
- "npc_dialogue" = What you SAY as a waiter (natural speech)
- "reasoning" = Your detailed analysis: "Customer ordered [SPECIFIC DISH], then said they have [allergy] and asked 'will it be safe?' - this means they're asking about the safety of [THAT SPECIFIC DISH] for their [allergy]. I should respond about [THAT DISH] specifically with [level-appropriate response]"
- ALWAYS show you understand WHICH DISH they're asking about
- NEVER treat "will it be safe?" as generic allergy disclosure
- ALWAYS connect safety questions to the specific food they ordered''';
  }

  List<Map<String, String>> _buildConversationMessages({
    required String userInput,
    required SimulationStep currentStep,
    required PlayerProfile playerProfile,
    required String npcRole,
    required String scenarioContext,
    required ConversationContext context,
    required String menuForAI,
  }) {
    final systemPrompt = _buildEnhancedSystemPrompt(
      npcRole: npcRole,
      scenarioContext: scenarioContext,
      playerProfile: playerProfile,
      context: context,
      menuForAI: menuForAI,
    );

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
    ];

    // Add recent conversation history (max 4 recent exchanges to stay within token limits)
    final recentMessages = context.recentMessages;
    for (final message in recentMessages) {
      messages.add(message.toOpenAIMessage());
    }

    return messages;
  }

  Future<String> _sendOpenAIRequest(List<Map<String, String>> messages) async {
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${OpenAIConfig.apiKey}',
    };

    final body = json.encode({
      'model': 'gpt-3.5-turbo',
      'messages': messages,
      'max_tokens': 300,
      'temperature': 0.2,
    });

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: headers,
      body: body,
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['choices'][0]['message']['content'];
    } else {
      throw Exception(
        'OpenAI API request failed: ${response.statusCode} - ${response.body}',
      );
    }
  }

  ConversationContext _updateConversationContext(
    ConversationContext context,
    String userInput,
    String npcResponse,
    List<String> detectedAllergies,
    List<String> actualAllergies,
  ) {
    // Add NPC response to message history
    final npcMessage = ConversationMessage(
      role: 'assistant',
      content: npcResponse,
      timestamp: DateTime.now(),
    );

    final updatedMessages = [...context.messages, npcMessage];

    // Update allergy disclosure status - FIXED: Only count as allergy disclosure if user is actually mentioning allergies
    final newlyDisclosed = <String>[];

    // Check if user is actually disclosing allergies vs ordering food
    final isDisclosingAllergies = _isActuallyDisclosingAllergies(
      userInput.toLowerCase(),
      actualAllergies,
    );

    if (isDisclosingAllergies) {
      // Only count detected allergies if user is actually disclosing them
      for (final detected in detectedAllergies) {
        for (final actual in actualAllergies) {
          // Simple case-insensitive comparison for allergy matching
          if (detected.toLowerCase().trim() == actual.toLowerCase().trim() ||
              detected.toLowerCase().contains(actual.toLowerCase()) ||
              actual.toLowerCase().contains(detected.toLowerCase())) {
            newlyDisclosed.add(detected);
          }
        }
      }
    }

    final allDisclosed = [
      ...context.disclosedAllergies,
      ...newlyDisclosed,
    ].toSet().toList();
    final allergiesDisclosed =
        context.allergiesDisclosed || newlyDisclosed.isNotEmpty;

    // Detect dish selection - start with current selection but allow updates
    String? selectedDish = context.selectedDish;
    final lowerInput = userInput.toLowerCase();

    final orderingPhrases = [
      'i\'ll have',
      'i will have',
      'i want',
      'i\'d like',
      'i would like',
      'i choose',
      'i\'ll take',
      'i\'ll get',
      'can i have',
      'can i get',
      'give me',
      'i\'ll order',
    ];

    bool isOrdering = orderingPhrases.any(
      (phrase) => lowerInput.contains(phrase),
    );

    if (isOrdering && !_isJustAskingAboutMenu(lowerInput)) {
      // Extract the dish name from the input - be flexible
      String dishName = '';

      // Common food words to look for
      final foodWords = [
        'pasta',
        'pizza',
        'salad',
        'soup',
        'chicken',
        'fish',
        'beef',
        'pork',
        'vegetarian',
        'veggie',
        'burger',
        'sandwich',
        'rice',
        'noodles',
        'curry',
        'steak',
        'salmon',
        'tuna',
        'caesar',
        'tomato',
        'mushroom',
        'cheese',
        'bread',
        'fries',
        'chips',
        'brownie',
        'cake',
        'ice cream',
      ];

      for (final food in foodWords) {
        if (lowerInput.contains(food)) {
          // Build a reasonable dish name
          if (lowerInput.contains('vegetarian') &&
              lowerInput.contains('pasta')) {
            dishName = 'Vegetarian Pasta';
          } else if (lowerInput.contains('caesar') &&
              lowerInput.contains('salad')) {
            dishName = 'Caesar Salad';
          } else if (lowerInput.contains('fish') &&
              lowerInput.contains('chips')) {
            dishName = 'Fish & Chips';
          } else if (lowerInput.contains('chicken')) {
            dishName = 'Chicken Dish';
          } else {
            dishName = food.substring(0, 1).toUpperCase() + food.substring(1);
          }
          break;
        }
      }

      if (dishName.isNotEmpty) {
        selectedDish = dishName;
        debugPrint(
          '[DISH ORDERED] User ordered: $dishName from input: "$userInput"',
        );
      }
    }

    bool confirmedDish = context.confirmedDish;

    // Check if AI response contains order confirmation phrases
    final lowerNpcResponse = npcResponse.toLowerCase();

    // Only confirm dish if there's a selected dish AND AI confirms it
    if (selectedDish != null && !confirmedDish) {
      bool isQuestion = npcResponse.contains('?');
      bool isWarning =
          lowerNpcResponse.contains('contains') ||
          lowerNpcResponse.contains('allergic') ||
          lowerNpcResponse.contains('not safe') ||
          lowerNpcResponse.contains('wouldn\'t recommend');

      if (!isQuestion && !isWarning) {
        confirmedDish = true;
        debugPrint(
          '[ORDER CONFIRMED] AI confirmed order: "$selectedDish" with response: "$npcResponse"',
        );
      }
    }

    // Update topics covered
    final newTopics = Map<String, bool>.from(context.topicsCovered);
    if (allergiesDisclosed) newTopics['allergies_disclosed'] = true;
    if (selectedDish != null) newTopics['dish_selected'] = true;
    if (userInput.toLowerCase().contains('ingredient'))
      newTopics['ingredients_asked'] = true;

    final updatedContext = context.copyWith(
      messages: updatedMessages,
      allergiesDisclosed: allergiesDisclosed,
      disclosedAllergies: allDisclosed,
      selectedDish: selectedDish,
      confirmedDish: confirmedDish,
      turnCount: context.turnCount + 1,
      topicsCovered: newTopics,
    );

    return updatedContext;
  }

  /// Check if user is just asking about a dish rather than ordering it
  bool _isJustAskingAboutDish(String lowerInput) {
    // Patterns that indicate asking about a dish, not ordering
    final questionPatterns = [
      'what ingredients',
      'what\'s in',
      'what is in',
      'does it contain',
      'does it have',
      'ingredients are',
      'ingredients in',
      'tell me about',
      'more about',
      'allergens in',
      'allergens are',
      'what allergens',
      'how is',
      'how\'s',
      'describe',
      'what about',
      'is there',
      'are there',
      'nutritional',
      'calories',
      'preparation',
      'prepared',
      'cooked',
      'made',
      'seasoned',
      'spiced',
      'allergen-free',
      'safe for',
      'suitable for',
      'okay for',
      'can you tell',
      'information about',
      'details about',
    ];

    return questionPatterns.any((pattern) => lowerInput.contains(pattern));
  }

  /// Check if user is just asking about the menu in general, not ordering
  bool _isJustAskingAboutMenu(String lowerInput) {
    // Patterns that indicate asking about the menu in general
    final menuQuestionPatterns = [
      'what can i have',
      'what can i eat',
      'what\'s on the menu',
      'what is on the menu',
      'what do you have',
      'what\'s available',
      'what is available',
      'what options',
      'what choices',
      'menu',
      'show me',
      'tell me about',
      'what\'s good',
      'what is good',
      'recommend',
      'suggest',
      'options',
      'choices',
      'safe for me',
      'safe to eat',
      'what\'s safe',
      'what is safe',
      'can i eat',
      'can i have',
      'what about',
      'how about',
      'any',
      'anything',
      'something',
    ];

    return menuQuestionPatterns.any((pattern) => lowerInput.contains(pattern));
  }

  /// Check if user is actually disclosing allergies vs ordering food
  bool _isActuallyDisclosingAllergies(
    String lowerInput, [
    List<String>? userAllergies,
  ]) {
    // Patterns that indicate allergy disclosure
    final allergyDisclosurePatterns = [
      'i\'m allergic',
      'i am allergic',
      'i have allerg',
      'i have allergies',
      'i have allergy',
      'my allerg',
      'i can\'t eat',
      'i cannot eat',
      'i\'m intolerant',
      'i am intolerant',
      'i have an allergy',
      'i\'ve got allerg',
      'i have a sensitivity',
      'i react to',
      'i\'m sensitive to',
      'i am sensitive to',
      'allergic to',
      'allergy to',
      'intolerant to',
      'sensitive to',
      'reaction to',
      'can\'t have',
      'cannot have',
      'avoid',
      'stay away from',
      'bad reaction',
      'makes me sick',
      'i don\'t eat',
      'i won\'t eat',
      'i shouldn\'t eat',
      'i mustn\'t eat',
      'doctor said',
      'medically',
      'prescribed',
      'advised not to',
      'told not to',
      'not supposed to',
      'shouldn\'t have',
      'mustn\'t have',
      'can\'t consume',
      'cannot consume',
      'restricted from',
      'forbidden from',
      'prohibited from',
      'not allowed',
      'no ', // As in "no nuts", "no dairy", etc.
    ];

    // Check for actual allergy disclosure patterns
    bool hasAllergyDisclosure = allergyDisclosurePatterns.any(
      (pattern) => lowerInput.contains(pattern),
    );

    // Additional check for specific allergen mentions with "i have" pattern
    // This catches cases like "i have fish, egg and milk allergies"
    if (!hasAllergyDisclosure &&
        userAllergies != null &&
        lowerInput.contains('i have')) {
      for (final allergy in userAllergies) {
        if (lowerInput.contains('i have ${allergy.toLowerCase()}') ||
            lowerInput.contains('i have ${allergy.toLowerCase()},') ||
            lowerInput.contains('i have ${allergy.toLowerCase()} and') ||
            lowerInput.contains('i have ${allergy.toLowerCase()} allerg')) {
          hasAllergyDisclosure = true;
          break;
        }
      }
    }

    // Also check for responses to allergy questions like "Yes, I have fish allergy"
    if (!hasAllergyDisclosure &&
        userAllergies != null &&
        (lowerInput.startsWith('yes') ||
            lowerInput.startsWith('yeah') ||
            lowerInput.startsWith('yep'))) {
      // Check if it contains allergy disclosure after the "yes"
      final afterYes = lowerInput.replaceFirst(
        RegExp(r'^(yes|yeah|yep)[,\s]*'),
        '',
      );
      if (allergyDisclosurePatterns.any(
        (pattern) => afterYes.contains(pattern),
      )) {
        hasAllergyDisclosure = true;
      }
      // Also check for specific allergen mentions after "yes"
      for (final allergy in userAllergies) {
        if (afterYes.contains('i have ${allergy.toLowerCase()}') ||
            afterYes.contains('${allergy.toLowerCase()} allerg') ||
            afterYes.contains('allergic to ${allergy.toLowerCase()}')) {
          hasAllergyDisclosure = true;
          break;
        }
      }
    }

    // Note: We prioritize allergy disclosure over ordering patterns

    // FIXED: If user mentions allergies, always consider it allergy disclosure regardless of other patterns
    return hasAllergyDisclosure;
  }

  /// Check if AI response indicates the conversation should end
  bool _shouldEndConversationFromAI(
    String npcDialogue,
    ConversationContext context,
  ) {
    // Only end if AI explicitly says something like "enjoy your meal" or "have a great day"
    final lowerDialogue = npcDialogue.toLowerCase();

    final naturalEndingPhrases = [
      'enjoy your meal',
      'have a great day',
      'have a wonderful day',
      'take care',
      'see you later',
    ];

    bool hasNaturalEnding = naturalEndingPhrases.any(
      (phrase) => lowerDialogue.contains(phrase),
    );

    if (hasNaturalEnding) {
      debugPrint(
        '[AI NATURAL END] AI naturally ended conversation: "$npcDialogue"',
      );
    }

    return hasNaturalEnding;
  }

  NPCDialogueResponse _performErrorRecovery(
    String openaiResponse,
    String userInput,
    PlayerProfile playerProfile,
    ConversationContext context,
  ) {
    // Try to extract dialogue from broken response
    String npcDialogue = openaiResponse.trim();

    // Try to extract dialogue from common patterns
    final dialoguePatterns = [
      RegExp(r'"npc_dialogue":\s*"([^"]*)"'),
      RegExp(r'npc_dialogue.*?:\s*"([^"]*)"'),
      RegExp(r'dialogue.*?:\s*"([^"]*)"'),
    ];

    for (final pattern in dialoguePatterns) {
      final match = pattern.firstMatch(openaiResponse);
      if (match != null && match.group(1) != null) {
        npcDialogue = match.group(1)!;

        break;
      }
    }

    // If we couldn't extract from JSON patterns, use the raw response if it looks reasonable
    if (npcDialogue == openaiResponse.trim()) {
      // If the response is too long, truncate it
      if (npcDialogue.length > 200) {
        npcDialogue = npcDialogue.substring(0, 200) + '...';
      }

      // If it's completely unusable, provide a contextual fallback
      if (npcDialogue.isEmpty ||
          npcDialogue.length < 10 ||
          npcDialogue.contains('Error') ||
          npcDialogue.contains('API') ||
          npcDialogue.startsWith('{') ||
          npcDialogue.startsWith('[')) {
        npcDialogue = _generateContextualFallback(
          userInput,
          context,
          playerProfile.allergies,
        );
      }
    }

    // Perform basic allergy detection
    final detectedAllergies = <String>[];
    final lowerInput = userInput.toLowerCase();

    for (final allergy in playerProfile.allergies) {
      final allergyLower = allergy.toLowerCase();
      if (lowerInput.contains(allergyLower) ||
          lowerInput.contains('${allergyLower}s') ||
          (lowerInput.contains('allerg') &&
              lowerInput.contains(
                allergyLower.substring(0, math.min(3, allergyLower.length)),
              ))) {
        detectedAllergies.add(allergyLower);
      }
    }

    final updatedContext = _updateConversationContext(
      context,
      userInput,
      npcDialogue,
      detectedAllergies,
      playerProfile.allergies,
    );

    // Update internal context
    _currentContext = updatedContext;
    onContextUpdate?.call(_currentContext);

    // Check if AI response indicates conversation should end
    final shouldEndConversation = _shouldEndConversationFromAI(
      npcDialogue,
      updatedContext,
    );

    return NPCDialogueResponse(
      npcDialogue: npcDialogue,
      isPositiveFeedback: true,
      confidencePoints: 0,
      detectedAllergies: detectedAllergies,
      followUpPrompt: '',
      updatedContext: updatedContext,
      shouldEndConversation: shouldEndConversation,
    );
  }

  String _generateContextualFallback(
    String userInput,
    ConversationContext context,
    List<String> allergies,
  ) {
    final lowerInput = userInput.toLowerCase();
    final hasDisclosedAllergies = context.allergiesDisclosed;

    // Generate varied responses based on context
    if (lowerInput.contains('allerg')) {
      final encouragingResponses = [
        'Thanks for telling me about your allergies! That\'s really important.',
        'Good job letting me know about your allergies! I\'ll help you find safe options.',
        'I appreciate you sharing that with me. Let me suggest some safe dishes.',
      ];
      return encouragingResponses[DateTime.now().millisecond %
          encouragingResponses.length];
    }

    if (lowerInput.contains('contain') || lowerInput.contains('ingredient')) {
      if (hasDisclosedAllergies) {
        final safetyResponses = [
          'Great question! That dish is safe for your allergies.',
          'Good thinking to ask! Yes, that\'s a safe choice for you.',
          'Smart to check! That one doesn\'t have any of your allergens.',
        ];
        return safetyResponses[DateTime.now().millisecond %
            safetyResponses.length];
      }
    }

    if (lowerInput.contains('order') ||
        lowerInput.contains('have') ||
        lowerInput.contains('want')) {
      if (!hasDisclosedAllergies) {
        return 'Sounds good! Before I put in your order, do you have any food allergies I should know about?';
      } else {
        return 'Perfect choice! That\'s a safe option for you. Anything else you\'d like?';
      }
    }

    if (lowerInput.contains('recommend') ||
        lowerInput.contains('suggest') ||
        lowerInput.contains('else')) {
      if (hasDisclosedAllergies) {
        final recommendResponses = [
          'How about trying something different? The soup is really popular!',
          'If you\'re looking for variety, the salad is fresh and tasty!',
          'For something different, maybe the pasta? It\'s one of our favorites!',
        ];
        return recommendResponses[DateTime.now().millisecond %
            recommendResponses.length];
      }
    }

    // Default friendly responses
    final defaultResponses = [
      'I\'m here to help you find something delicious and safe!',
      'What sounds good to you today?',
      'Let me know what you\'re in the mood for!',
    ];
    return defaultResponses[DateTime.now().millisecond %
        defaultResponses.length];
  }

  // Optional: Separate confidence scoring API call for detailed evaluation
  Future<ConfidenceScoreResponse> getDetailedConfidenceScore({
    required ConversationContext context,
    required PlayerProfile playerProfile,
  }) async {
    try {
      final scoringPrompt = _buildConfidenceScorePrompt(context, playerProfile);

      final messages = [
        {'role': 'system', 'content': scoringPrompt},
        {
          'role': 'user',
          'content':
              'Please evaluate this conversation for allergy communication skills.',
        },
      ];

      final response = await _sendOpenAIRequest(messages);
      return _parseConfidenceScoreResponse(response);
    } catch (e) {
      debugPrint('Error getting confidence score: $e');

      // Return fallback score
      return ConfidenceScoreResponse(
        confidenceScore: context.allergiesDisclosed ? 7 : 3,
        detailedFeedback: context.allergiesDisclosed
            ? 'Good job communicating about your allergies!'
            : 'Remember to always mention your food allergies when ordering.',
        strengthsObserved: context.allergiesDisclosed
            ? ['Disclosed allergies']
            : [],
        areasForImprovement: context.allergiesDisclosed
            ? []
            : ['Mention allergies earlier'],
        overallSafetyRating: context.allergiesDisclosed,
      );
    }
  }

  String _buildConfidenceScorePrompt(
    ConversationContext context,
    PlayerProfile playerProfile,
  ) {
    return '''
You are evaluating a teenager's allergy communication skills in a restaurant scenario.

PLAYER'S ACTUAL ALLERGIES: ${playerProfile.allergies.join(', ')}

CONVERSATION HISTORY:
${context.messages.map((m) => '${m.role.toUpperCase()}: ${m.content}').join('\n')}

EVALUATION CRITERIA:
- Clarity of allergy disclosure (0-3 points)
- Proactiveness in mentioning allergies (0-2 points)
- Asking about ingredients/safety (0-2 points)
- Overall safety awareness (0-3 points)

Respond with JSON only:
{
  "confidence_score": [0-10],
  "detailed_feedback": "Specific feedback on communication",
  "strengths_observed": ["list", "of", "strengths"],
  "areas_for_improvement": ["list", "of", "areas"],
  "overall_safety_rating": true/false
}''';
  }

  ConfidenceScoreResponse _parseConfidenceScoreResponse(String response) {
    try {
      final json = jsonDecode(response.trim()) as Map<String, dynamic>;

      return ConfidenceScoreResponse(
        confidenceScore: (json['confidence_score'] as int? ?? 5).clamp(0, 10),
        detailedFeedback:
            json['detailed_feedback']?.toString() ?? 'Communication assessed',
        strengthsObserved:
            (json['strengths_observed'] as List?)?.cast<String>() ?? [],
        areasForImprovement:
            (json['areas_for_improvement'] as List?)?.cast<String>() ?? [],
        overallSafetyRating: json['overall_safety_rating'] as bool? ?? false,
      );
    } catch (e) {
      debugPrint('Error parsing confidence score: $e');
      return ConfidenceScoreResponse(
        confidenceScore: 5,
        detailedFeedback: 'Unable to evaluate conversation',
        strengthsObserved: [],
        areasForImprovement: ['Continue practicing clear communication'],
        overallSafetyRating: false,
      );
    }
  }

  Future<void> speakNPCResponse(String text) async {
    try {
      // Use the realistic TTS service with natural voice
      await _realisticTts.speakWithNaturalVoice(text);
    } catch (e) {
      onError?.call('Failed to play speech');
      onTTSCompleted?.call(); // Trigger completion on error
    }
  }

  Future<void> stopSpeaking() async {
    try {
      await _realisticTts.stopSpeaking();
    } catch (e) {}
  }

  String _extractDialogueFromResponse(String response) {
    String cleaned = response.trim();

    // Pattern 1: Try to extract from JSON structure
    try {
      final jsonResponse = jsonDecode(cleaned) as Map<String, dynamic>;
      final dialogue = jsonResponse['npc_dialogue']?.toString();
      final reasoning = jsonResponse['reasoning']?.toString();

      // Log reasoning for dev debugging if present
      if (reasoning != null && reasoning.isNotEmpty) {
        debugPrint('[AI REASONING] $reasoning');
      }

      if (dialogue != null && dialogue.isNotEmpty) {
        return dialogue.trim();
      }
    } catch (_) {
      // Not pure JSON, continue with other patterns
    }

    // Pattern 2: Extract dialogue from mixed text+JSON response
    final jsonPattern = RegExp(r'"npc_dialogue":\s*"([^"]*)"');
    final reasoningPattern = RegExp(r'"reasoning":\s*"([^"]*)"');

    final match = jsonPattern.firstMatch(cleaned);
    final reasoningMatch = reasoningPattern.firstMatch(cleaned);

    // Log reasoning for dev debugging if present
    if (reasoningMatch != null && reasoningMatch.group(1) != null) {
      debugPrint('[AI REASONING] ${reasoningMatch.group(1)}');
    }

    if (match != null && match.group(1) != null) {
      return match.group(1)!.trim();
    }

    // Pattern 3: Handle responses where dialogue comes before JSON
    final lines = cleaned.split('\n');
    String potentialDialogue = '';

    for (final line in lines) {
      final trimmedLine = line.trim();
      // Skip empty lines and JSON-looking lines
      if (trimmedLine.isEmpty ||
          trimmedLine.startsWith('{') ||
          trimmedLine.startsWith('"') ||
          trimmedLine.contains('npc_dialogue') ||
          trimmedLine.contains('detected_allergies') ||
          trimmedLine.contains('reasoning')) {
        continue;
      }

      // Found a line that looks like natural dialogue
      if (trimmedLine.length > 10 && !trimmedLine.contains('Error')) {
        potentialDialogue = trimmedLine;
        break;
      }
    }

    if (potentialDialogue.isNotEmpty) {
      return potentialDialogue;
    }

    // Pattern 4: Extract the first sentence if it looks like dialogue
    final sentences = cleaned.split(RegExp(r'[.!?]\s*'));
    for (final sentence in sentences) {
      final trimmed = sentence.trim();
      if (trimmed.length > 5 &&
          !trimmed.startsWith('{') &&
          !trimmed.contains('npc_dialogue') &&
          !trimmed.contains('detected_allergies') &&
          !trimmed.contains('reasoning') &&
          !trimmed.contains('Error')) {
        return trimmed +
            (sentence.endsWith('.') ||
                    sentence.endsWith('!') ||
                    sentence.endsWith('?')
                ? ''
                : '.');
      }
    }

    // Fallback: Return a safe default
    return "Sorry, I didn't catch that.";
  }

  bool get isListening => _isListening;
  ConversationContext get currentContext => _currentContext;

  Future<Map<String, dynamic>> _analyzeUserIntent(
    String userInput,
    PlayerProfile playerProfile,
    ConversationContext context,
  ) async {
    final analysisPrompt =
        '''
You are analyzing a restaurant customer's message to understand their PRIMARY intent. Be very precise.

CUSTOMER SAID: "$userInput"

CONTEXT:
- Has disclosed allergies: ${context.allergiesDisclosed}
- Previously disclosed allergies: ${context.disclosedAllergies.join(', ')}
- Previously ordered: ${context.selectedDish ?? 'none'}  
- Turn: ${context.turnCount}

CRITICAL: Only detect allergies if they are EXPLICITLY mentioned with clear allergy indicators in THIS specific message. Do NOT infer allergies from context or assume anything.

INTENT PRIORITY RULES (in order of importance):
1. If customer is placing/ordering food → "food_ordering" (even if they also mention allergies)
2. If customer is ONLY telling about allergies → "allergy_disclosure"
3. If customer is asking questions → "question"
4. If customer is giving simple responses → "general_response"
5. If customer is greeting → "greeting"

INTENT DEFINITIONS:
- "food_ordering": Customer is placing an order, choosing food, or saying what they want to eat (PRIMARY if ordering)
- "allergy_disclosure": Customer is ONLY telling you about their food allergies, restrictions, or what they can't eat
- "question": Customer is asking about menu, ingredients, recommendations, or seeking information
- "general_response": Simple responses like "yes", "no", "thank you", "okay"
- "greeting": Initial hello, hi, or greeting

CRITICAL EXAMPLES FOR COMPOUND STATEMENTS (ORDERING + ALLERGIES):
- "Hi, I want to order Satay chicken skewers, but I have peanut allergy" → intent: "food_ordering", ordered_food: "Satay chicken skewers", mentioned_allergies: ["peanut"]
- "I'll have the pasta and I'm allergic to nuts" → intent: "food_ordering", ordered_food: "pasta", mentioned_allergies: ["nuts"]
- "I want the burger but I'm allergic to dairy" → intent: "food_ordering", ordered_food: "burger", mentioned_allergies: ["dairy"]

CRITICAL EXAMPLES FOR QUESTIONS + ALLERGIES:
- "Hi, before ordering, I'd like to tell you that I am allergic to peanuts, so what are the best options that I can have?" → intent: "question", ordered_food: null, mentioned_allergies: ["peanuts"]
- "I'm allergic to shellfish, what would you recommend?" → intent: "question", ordered_food: null, mentioned_allergies: ["shellfish"]
- "I can't eat dairy, what's safe for me?" → intent: "question", ordered_food: null, mentioned_allergies: ["dairy"]

CRITICAL EXAMPLES FOR PURE ALLERGY DISCLOSURE:
- "I should mention I'm allergic to peanuts" → intent: "allergy_disclosure", ordered_food: null, mentioned_allergies: ["peanuts"]
- "I have a nut allergy" → intent: "allergy_disclosure", ordered_food: null, mentioned_allergies: ["nuts"]

CRITICAL: When someone mentions allergies in ANY intent, ALWAYS extract them:
- Even if asking questions: "I'm allergic to X, what can I eat?" → mentioned_allergies: ["X"]
- Even if ordering: "I'll have Y, but I'm allergic to X" → mentioned_allergies: ["X"]
- Even if just disclosing: "I'm allergic to X" → mentioned_allergies: ["X"]

CRITICAL EXAMPLES FOR NON-ALLERGY STATEMENTS:
- "Can I get some peanuts?" → intent: "food_ordering", ordered_food: "peanuts", mentioned_allergies: []
- "What do you have in chicken?" → intent: "question", ordered_food: null, mentioned_allergies: []
- "What's the menu?" → intent: "question", ordered_food: null, mentioned_allergies: []
- "Hi" → intent: "greeting", ordered_food: null, mentioned_allergies: []

ABSOLUTE RULE FOR mentioned_allergies:
ALWAYS extract allergies when these phrases appear:
  * "I'm allergic to X" → ["X"]
  * "I can't eat X" → ["X"]
  * "I have an allergy to X" → ["X"]
  * "I'm intolerant to X" → ["X"]
  * "I have X allergy" → ["X"]
  * "I am allergic to X" → ["X"]
  * "allergic to X" → ["X"]

NEVER extract allergies for these:
  * Ordering food: "Can I get peanuts?" → []
  * Asking about ingredients: "What's in the chicken?" → []
  * General conversation: "Hi", "Thank you" → []

CRITICAL: If you see "allergic to" or "I'm allergic" ANYWHERE in the message, extract the allergen even if they're also asking questions or ordering food!

ABSOLUTE RULE FOR ordered_food:
- Extract ANY food item mentioned with ordering phrases:
  * "I want to order X"
  * "I'll have X"
  * "I want X"
  * "Can I get X"
  * "I'd like X"
- Even if they also mention allergies in the same sentence

ABSOLUTE RULE FOR intent:
- If they're ordering food (even with allergy mention) → "food_ordering"
- If they're ONLY asking questions → "question"  
- If they're ONLY disclosing allergies (no food order) → "allergy_disclosure"
- If they're greeting → "greeting"
- Otherwise → "general_response"

Respond with JSON only:
{
  "intent": "food_ordering|allergy_disclosure|question|general_response|greeting",
  "mentioned_allergies": ["specific", "allergens", "mentioned"],
  "ordered_food": "exact food name if ordering, otherwise null",
  "is_asking_question": true/false,
  "conversation_should_end": false,
  "confidence": 0.0-1.0
}
''';

    try {
      final response = await _sendOpenAIRequest([
        {'role': 'user', 'content': analysisPrompt},
      ]);

      final analysis = jsonDecode(response) as Map<String, dynamic>;

      debugPrint(
        '[AI ANALYSIS] Intent: ${analysis['intent']}, Allergies: ${analysis['mentioned_allergies']}, Food: ${analysis['ordered_food']}',
      );

      // Validate allergy detection
      if (analysis['mentioned_allergies'] != null &&
          (analysis['mentioned_allergies'] as List).isNotEmpty) {
        debugPrint(
          '[AI ANALYSIS] ✅ Allergies correctly detected: ${analysis['mentioned_allergies']}',
        );
      }

      return analysis;
    } catch (e) {
      debugPrint('Error in AI intent analysis: $e');
      // Fallback analysis based on keywords
      return {
        'intent': 'general_response',
        'mentioned_allergies': <String>[],
        'ordered_food': null,
        'is_asking_question': false,
        'conversation_should_end': false,
        'confidence': 0.5,
      };
    }
  }

  Future<String> _generateWaiterResponse(
    String userInput,
    String? systemPrompt,
    ConversationContext context,
    String menuForAI, {
    ScenarioConfig? scenarioConfig,
    PlayerProfile? playerProfile,
  }) async {
    try {
      final messages = <Map<String, String>>[];

      if (systemPrompt != null && systemPrompt.isNotEmpty) {
        // Enhance the provided system prompt with scenario-specific behavior
        String enhancedPrompt = systemPrompt;
        if (scenarioConfig != null) {
          enhancedPrompt += _addScenarioBehaviorContext(
            scenarioConfig,
            playerProfile,
            context,
          );
        }
        messages.add({'role': 'system', 'content': enhancedPrompt});
      } else {
        final fallbackPrompt = _generateEnhancedFallbackPrompt(
          menuForAI,
          scenarioConfig,
          playerProfile,
          context,
        );
        messages.add({'role': 'system', 'content': fallbackPrompt});
      }

      // Add conversation history
      for (final m in context.recentMessages) {
        messages.add({'role': m.role, 'content': m.content});
      }

      // Add current user message
      messages.add({'role': 'user', 'content': userInput});

      final response = await _sendOpenAIRequest(messages);

      String waiterResponse = response;

      // Extract just the dialogue from JSON response if needed
      waiterResponse = _extractDialogueFromResponse(response);

      final forbiddenTerms = [
        'grilled chicken salad', // Common AI hallucination
        'house salad', // Too generic
        'green salad', // Too generic
        'caesar salad', // Common hallucination
        'chicken salad', // Common hallucination
        'pasta salad', // Common hallucination
        'our special', // Too vague
        'chef\'s special', // Too vague
        'today\'s special', // Too vague
        'signature dish', // Too vague
        'generic',
      ];

      final lowerResponse = waiterResponse.toLowerCase();
      for (final term in forbiddenTerms) {
        if (lowerResponse.contains(term)) {
          debugPrint(
            '[AI] FAILED! Mentioned non-menu item "$term" in: "$waiterResponse"',
          );
          debugPrint('[AI] Using menu-based fallback instead');
          return _generateMenuBasedFallback(userInput, menuForAI);
        }
      }

      debugPrint('[AI WAITER SAYS]: "$waiterResponse"');
      return waiterResponse;
    } catch (e) {
      debugPrint('Error generating waiter response: $e');

      return _generateMenuBasedFallback(userInput, menuForAI);
    }
  }

  String _addScenarioBehaviorContext(
    ScenarioConfig scenarioConfig,
    PlayerProfile? playerProfile,
    ConversationContext context,
  ) {
    final behaviorRules = scenarioConfig.behaviorRules;
    final level = scenarioConfig.level;

    final buffer = StringBuffer();
    buffer.writeln('\n\n=== SCENARIO-SPECIFIC BEHAVIOR ===');
    buffer.writeln('Level: ${level.toString().split('.').last.toUpperCase()}');
    buffer.writeln(
      'Guidance Level: ${(behaviorRules.guidanceLevel * 100).round()}%',
    );
    buffer.writeln('Patience Level: ${behaviorRules.patienceLevel}/5');

    // Level-specific behavioral adjustments
    switch (level) {
      case DifficultyLevel.beginner:
        buffer.writeln('\nBEGINNER BEHAVIOR:');

        // Add conversation memory for beginner level
        buffer.writeln('\nCONVERSATION MEMORY (Beginner):');
        buffer.writeln(
          '- You have access to full conversation history through the message chain',
        );
        buffer.writeln(
          '- Remember what customer has asked, ordered, cancelled, or changed',
        );
        buffer.writeln('- Track ingredient questions vs actual food orders');
        buffer.writeln('- Note any safety decisions (cancelling unsafe items)');
        buffer.writeln(
          '- Be supportive when customer makes good safety choices',
        );
        buffer.writeln('');

        buffer.writeln('CONTEXTUAL THINKING (BEGINNER):');
        buffer.writeln(
          'UNDERSTAND the conversation flow - What does customer ACTUALLY mean?',
        );
        buffer.writeln('');
        buffer.writeln('THINK STEP BY STEP:');
        buffer.writeln('1. What food have they ordered/discussed?');
        buffer.writeln('2. What allergy did they mention?');
        buffer.writeln('3. What are they asking about NOW?');
        buffer.writeln('');
        buffer.writeln('BEGINNER CRITICAL EXAMPLES:');
        buffer.writeln('');
        buffer.writeln('EXACT SCENARIO THAT KEEPS FAILING:');
        buffer.writeln('Customer: "I\'ll have the goat cheese tart"');
        buffer.writeln('AI: "Great choice! I\'ll put that in for you."');
        buffer.writeln(
          'Customer: "Actually, I am allergic to fish, so will it be safe?"',
        );
        buffer.writeln(
          '→ CONTEXT: Customer is asking about THE GOAT CHEESE TART safety for fish allergy',
        );
        buffer.writeln(
          '→ RESPOND SUPPORTIVELY: "Let me check that for you! The goat cheese tart should be perfectly safe for a fish allergy since it doesn\'t contain any fish ingredients. I\'ll just make sure there\'s no cross-contact in our preparation"',
        );
        buffer.writeln('');
        buffer.writeln(
          'Customer says "I have a nut allergy" (no food context)',
        );
        buffer.writeln('→ CONTEXT: Just disclosing allergy');
        buffer.writeln(
          '→ RESPOND: "Thank you for letting me know! I\'ll make sure the kitchen is aware"',
        );
        buffer.writeln('');
        buffer.writeln('Customer says "Thank you" (after allergy discussion):');
        buffer.writeln('→ CONTEXT: Seems ready to finish');
        buffer.writeln(
          '→ RESPOND: "Is that everything? You\'ve ordered the [DISH NAME] - is that correct?"',
        );
        buffer.writeln('');
        buffer.writeln(
          'CRITICAL: When someone asks "will it be safe?" they mean the CURRENT FOOD!',
        );
        buffer.writeln('');

        buffer.writeln('EXAMPLES WITH CONTEXT TRACKING:');
        buffer.writeln(
          '- User: "what does irish lamb stew contain?" → INGREDIENT QUESTION → Answer factually',
        );
        buffer.writeln(
          '- User: "I have fish allergy, so is it safe for me?" (after asking about stew) → SAFETY QUESTION → Be supportive about the stew safety',
        );
        buffer.writeln(
          '- User: "I have a nut allergy" (alone) → ALLERGY DISCLOSURE → Follow supportive beginner pattern',
        );
        buffer.writeln(
          '- User: "I\'ll have the stew" → FOOD ORDER → Process order',
        );
        buffer.writeln(
          '- "Actually, I don\'t want that" → ORDER CANCELLATION → Remove from order',
        );
        buffer.writeln(
          '- "I\'ll have X instead" → ORDER CHANGE → Replace previous order',
        );
        buffer.writeln(
          '- End of conversation → CONFIRM ORDER: "So to confirm, you\'re having the [dishes]"',
        );
        buffer.writeln('');
        buffer.writeln('CRITICAL SAFETY QUESTION RECOGNITION:');
        buffer.writeln(
          '- If user asks about dish ingredients, then asks "I have X allergy, is it safe?" → This is asking about THAT DISH!',
        );
        buffer.writeln(
          '- Be supportive about the specific dish they asked about, not generic responses',
        );
        buffer.writeln('');
        buffer.writeln('ORDER TRACKING (BEGINNER - SUPPORTIVE):');
        buffer.writeln(
          '- When customer wants to cancel after safety concern → "Of course! Let me help you find something safer"',
        );
        buffer.writeln(
          '- When customer reorders safe item → "Excellent choice! That\'s much safer for you"',
        );
        buffer.writeln(
          '- When customer keeps unsafe order → "Are you sure? I\'m a bit worried about that choice"',
        );
        buffer.writeln('');

        buffer.writeln('- Be extra patient and encouraging');
        buffer.writeln('- Offer gentle prompts if customer seems uncertain');
        buffer.writeln(
          '- Use simple, natural responses like "That\'s okay, I\'ll make sure to let the chef know"',
        );
        buffer.writeln(
          '- Use positive, supportive language but avoid corporate phrases',
        );
        buffer.writeln(
          '- NEVER say "Your safety is our priority" or other formal corporate language',
        );
        buffer.writeln(
          '- Before conversation ends, confirm final order: "So to confirm, you\'re having [dishes and drinks]"',
        );
        buffer.writeln(
          '- Track multiple orders if customer orders several items',
        );
        buffer.writeln(
          '- Note if customer cancels unsafe food (praise good safety decision)',
        );
        break;

      case DifficultyLevel.intermediate:
        buffer.writeln('\nINTERMEDIATE BEHAVIOR:');

        // Add conversation memory for intermediate level
        buffer.writeln('\nCONVERSATION MEMORY (Intermediate):');
        buffer.writeln(
          '- You have access to full conversation history through the message chain',
        );
        buffer.writeln(
          '- Remember what customer has asked, ordered, cancelled, or changed',
        );
        buffer.writeln('- Track ingredient questions vs actual food orders');
        buffer.writeln('- Note any safety decisions (cancelling unsafe items)');
        buffer.writeln('- Be balanced when customer makes safety choices');
        buffer.writeln('');

        buffer.writeln('CONTEXTUAL THINKING (INTERMEDIATE):');
        buffer.writeln(
          'UNDERSTAND the conversation flow - What does customer ACTUALLY mean?',
        );
        buffer.writeln('');
        buffer.writeln('THINK STEP BY STEP:');
        buffer.writeln('1. What food have they ordered/discussed?');
        buffer.writeln('2. What allergy did they mention?');
        buffer.writeln('3. What are they asking about NOW?');
        buffer.writeln('');
        buffer.writeln('INTERMEDIATE CRITICAL EXAMPLES:');
        buffer.writeln('');
        buffer.writeln('EXACT SCENARIO THAT KEEPS FAILING:');
        buffer.writeln('Customer: "I\'ll have the goat cheese tart"');
        buffer.writeln('AI: "Great choice! I\'ll put that in for you."');
        buffer.writeln(
          'Customer: "Actually, I am allergic to fish, so will it be safe?"',
        );
        buffer.writeln(
          '→ CONTEXT: Customer is asking about THE GOAT CHEESE TART safety for fish allergy',
        );
        buffer.writeln(
          '→ RESPOND PROFESSIONALLY: "The goat cheese tart should be fine for a fish allergy since it doesn\'t contain fish, but let me check with the kitchen about our preparation methods to be certain"',
        );
        buffer.writeln('');
        buffer.writeln(
          'Customer says "I have a nut allergy" (no food context)',
        );
        buffer.writeln('→ CONTEXT: Just disclosing allergy');
        buffer.writeln(
          '→ RESPOND: "I\'ll note that for the kitchen. What can I get for you today?"',
        );
        buffer.writeln('');
        buffer.writeln('Customer says "Thank you" (after allergy discussion):');
        buffer.writeln('→ CONTEXT: Seems ready to finish');
        buffer.writeln(
          '→ RESPOND: "Is that everything? You\'ve ordered the [DISH NAME] - is that correct?"',
        );
        buffer.writeln('');
        buffer.writeln(
          'CRITICAL: "will it be safe?" = asking about THE SPECIFIC DISH THEY ORDERED!!!',
        );
        buffer.writeln('');

        buffer.writeln('EXAMPLES WITH CONTEXT TRACKING:');
        buffer.writeln(
          '- User: "what does irish lamb stew contain?" → INGREDIENT QUESTION → Answer factually',
        );
        buffer.writeln(
          '- User: "I have fish allergy, so is it safe for me?" (after asking about stew) → SAFETY QUESTION → Be professional about the stew safety',
        );
        buffer.writeln(
          '- User: "I have a nut allergy" (alone) → ALLERGY DISCLOSURE → Follow professional intermediate pattern',
        );
        buffer.writeln(
          '- User: "I\'ll have the stew" → FOOD ORDER → Process order',
        );
        buffer.writeln(
          '- "Actually, I don\'t want that" → ORDER CANCELLATION → Remove from order',
        );
        buffer.writeln(
          '- "I\'ll have X instead" → ORDER CHANGE → Replace previous order',
        );
        buffer.writeln(
          '- End of conversation → CONFIRM ORDER: "So to confirm, you\'re having the [dishes]"',
        );
        buffer.writeln('');
        buffer.writeln('CRITICAL SAFETY QUESTION RECOGNITION:');
        buffer.writeln(
          '- If user asks about dish ingredients, then asks "I have X allergy, is it safe?" → This is asking about THAT DISH!',
        );
        buffer.writeln(
          '- Be professional about the specific dish they asked about, not generic responses',
        );
        buffer.writeln('');
        buffer.writeln('ORDER TRACKING (INTERMEDIATE - PROFESSIONAL):');
        buffer.writeln(
          '- When customer wants to cancel after safety concern → "That\'s understandable, what would you prefer instead?"',
        );
        buffer.writeln(
          '- When customer reorders safe item → "Good choice, that should work better for you"',
        );
        buffer.writeln(
          '- When customer keeps unsafe order → "Alright, I\'ll put that through"',
        );
        buffer.writeln('');

        buffer.writeln('- Be professional but helpful');
        buffer.writeln('- Provide information when asked');
        buffer.writeln('- Don\'t over-guide - let customer take initiative');
        buffer.writeln('- Maintain neutral, service-oriented tone');
        buffer.writeln(
          '- Before conversation ends, confirm final order: "So to confirm, you\'re having [dishes and drinks]"',
        );
        buffer.writeln(
          '- Track multiple orders if customer orders several items',
        );
        buffer.writeln(
          '- Note if customer cancels unsafe food (acknowledge good decision)',
        );
        break;

      case DifficultyLevel.advanced:
        buffer.writeln('\nADVANCED BEHAVIOR:');

        // CRITICAL: Advanced mode natural responses
        buffer.writeln('\nADVANCED MODE - BE CHALLENGING BUT NATURAL:');
        buffer.writeln(
          'You are a busy waiter who presents realistic kitchen challenges.',
        );
        buffer.writeln('');
        buffer.writeln('WHEN CUSTOMER ASKS ABOUT CROSS-CONTACT:');
        buffer.writeln(
          '- "I\'ve spoken to the chef, and we fry everything in the one fryer"',
        );
        buffer.writeln(
          '- "So I spoke with the chef, and he said that he\'s too busy now to clean down all the equipment"',
        );
        buffer.writeln(
          '- "The kitchen staff is pretty busy today, so there could be some traces"',
        );
        buffer.writeln(
          '- "We prepare many dishes using the same equipment, so there could be traces"',
        );
        buffer.writeln('');
        buffer.writeln('FORCE THEM TO DECIDE:');
        buffer.writeln(
          '- "But you should be fine with just maybe some traces"',
        );
        buffer.writeln(
          '- "It\'s hard to say if there\'ll be cross-contamination"',
        );
        buffer.writeln(
          '- "The chef can\'t guarantee anything with how busy we are"',
        );
        buffer.writeln('');

        // Add conversation memory instructions for advanced level
        buffer.writeln('\n🧠 CONVERSATION MEMORY:');
        buffer.writeln(
          '- You have access to full conversation history through the message chain',
        );
        buffer.writeln(
          '- Remember what customer has asked, ordered, cancelled, or changed',
        );
        buffer.writeln('- Track ingredient questions vs actual food orders');
        buffer.writeln('- Note any safety decisions (cancelling unsafe items)');
        buffer.writeln('');

        buffer.writeln('CONTEXTUAL THINKING (ADVANCED):');
        buffer.writeln(
          'THINK ABOUT THE CONVERSATION FLOW - What does customer ACTUALLY mean?',
        );
        buffer.writeln('');
        buffer.writeln('STEP 1: What food have they ordered/discussed?');
        buffer.writeln('STEP 2: What allergy did they mention?');
        buffer.writeln('STEP 3: What are they asking about NOW?');
        buffer.writeln('');
        buffer.writeln('CRITICAL FAILING EXAMPLES - MUST FOLLOW:');
        buffer.writeln('');
        buffer.writeln('EXACT SCENARIO THAT KEEPS FAILING:');
        buffer.writeln('Customer: "I\'ll have the goat cheese tart"');
        buffer.writeln('AI: "Great choice! I\'ll put that in for you."');
        buffer.writeln(
          'Customer: "Actually, I am allergic to fish, so will it be safe?"',
        );
        buffer.writeln(
          '→ CONTEXT: Customer is asking about THE GOAT CHEESE TART safety for fish allergy',
        );
        buffer.writeln(
          '→ WRONG RESPONSE: "I\'ll mention it, but we\'re quite busy today"',
        );
        buffer.writeln(
          '→ CORRECT RESPONSE: "I spoke to the chef about the goat cheese tart - since fish isn\'t in the ingredients, we just need to check about cross-contamination in our prep areas"',
        );
        buffer.writeln('');
        buffer.writeln('ANOTHER EXAMPLE:');
        buffer.writeln('Customer: "I\'ll have calamari"');
        buffer.writeln('Customer: "I\'m allergic to fish, will it be safe?"');
        buffer.writeln(
          '→ CONTEXT: They\'re asking about THE CALAMARI safety for fish allergy',
        );
        buffer.writeln(
          '→ RESPOND: "I spoke to the chef about the calamari, and we prepare many dishes using the same equipment, so there could be traces from other orders"',
        );
        buffer.writeln('');
        buffer.writeln(
          'CRITICAL: "will it be safe?" = asking about THE SPECIFIC DISH THEY ORDERED!!!',
        );
        buffer.writeln('');
        buffer.writeln('Customer says "Thank you" (after allergy discussion):');
        buffer.writeln('→ CONTEXT: Seems ready to finish');
        buffer.writeln(
          '→ RESPOND: "Is that everything? You\'ve ordered the [DISH NAME] - is that correct?"',
        );
        buffer.writeln('');
        buffer.writeln(
          '- Cross-contact question → Present kitchen challenges (see examples above)',
        );
        buffer.writeln('- Food order → Process normally');
        buffer.writeln(
          '- Safety concerns → Give realistic constraints, not accommodation',
        );
        buffer.writeln('');
        buffer.writeln('');
        buffer.writeln('ADVANCED MODE EXAMPLES - WHAT TO ACTUALLY SAY:');
        buffer.writeln('');
        buffer.writeln('User: "I have a fish allergy"');
        buffer.writeln('→ SAY: "That\'s grand, I\'ll tell them. Any drinks?"');
        buffer.writeln('');
        buffer.writeln(
          'User: "I am allergic to fish, so is it safe for me to have the calamari?"',
        );
        buffer.writeln(
          '→ SAY: "I spoke to the chef about the calamari, and we prepare many dishes using the same equipment, so there could be traces from other orders. It\'s hard to say."',
        );
        buffer.writeln('');
        buffer.writeln(
          'User: "Can you ask the kitchen that there is no cross contact?"',
        );
        buffer.writeln(
          '→ SAY: "I\'ve spoken to the chef, and we fry everything in the one fryer, including our battered fish. So the oil could have fish traces in it, it\'s hard to say"',
        );
        buffer.writeln('');
        buffer.writeln('User: "Can you make sure no cross-contamination?"');
        buffer.writeln(
          '→ SAY: "So I spoke with the chef, and he said that he\'s too busy now to clean down all the equipment. But you should be fine with just maybe some traces"',
        );
        buffer.writeln('');
        buffer.writeln('User: "Is the stew safe for my fish allergy?"');
        buffer.writeln(
          '→ SAY: "I spoke to the chef about the stew, and we prepare many dishes using the same equipment, so there could be fish traces from other orders"',
        );
        buffer.writeln('');
        buffer.writeln('CRITICAL ORDER TRACKING:');
        buffer.writeln('- When you give safety warnings, note it in reasoning');
        buffer.writeln(
          '- Track if customer cancels after warning (good decision)',
        );
        buffer.writeln(
          '- Track if customer keeps unsafe order after warning (bad decision)',
        );
        buffer.writeln(
          '- Track if customer reorders something else (check if new item is safe)',
        );
        buffer.writeln('');
        buffer.writeln('CANCELLATION & REORDER EXAMPLES:');
        buffer.writeln('User: "Actually, I don\'t want the stew anymore"');
        buffer.writeln('→ SAY: "No problem, what would you like instead?"');
        buffer.writeln('');
        buffer.writeln('User: "I\'ll have the salad instead"');
        buffer.writeln(
          '→ SAY: "Good choice, the salad should be safe for you"',
        );
        buffer.writeln('');
        buffer.writeln('User: "I\'ll keep the stew" (after safety warning)');
        buffer.writeln('→ SAY: "Alright, I\'ll put that through for you"');
        buffer.writeln('');
        buffer.writeln('');
        buffer.writeln('INGREDIENT QUESTION RESPONSES:');
        buffer.writeln(
          '- "The stew has herbs and spices that might contain traces of various allergens"',
        );
        buffer.writeln(
          '- "There could be some allergen traces from the seasonings and preparation"',
        );
        buffer.writeln(
          '- "The kitchen uses various ingredients - there might be traces of common allergens"',
        );
        buffer.writeln('');
        buffer.writeln(
          '- CRITICAL: NEVER ask about allergies - only respond when customer mentions them',
        );
        buffer.writeln(
          '- NEVER say "who had the allergy again?" or assume allergies exist',
        );
        buffer.writeln(
          '- THINK about what customer actually said - don\'t make assumptions',
        );
        buffer.writeln(
          '- IF customer mentions allergies, follow TWO-STEP pattern:',
        );
        buffer.writeln(
          '- STEP 1: Initially respond with mild business constraints: "Okay, I\'ll mention it, but we\'re quite busy today. Any drinks?" or "Right, I\'ll let them know, though the kitchen\'s pretty hectic"',
        );
        buffer.writeln(
          '- STEP 1 must be SHORT and NOT include chef information or challenges',
        );
        buffer.writeln(
          '- STEP 2: ONLY on LATER turns, present challenges claiming to speak with chef:',
        );
        // Generate dynamic cross-contamination example based on user's allergies
        final allergen = playerProfile?.allergies.isNotEmpty == true
            ? playerProfile!.allergies.first.toLowerCase()
            : 'allergens';

        if (allergen == 'egg') {
          buffer.writeln(
            '  "I\'ve spoken to the chef, and she said that we use eggs in our batter for other dishes, and the same equipment gets used throughout the kitchen. So there could be some egg traces from other preparations."',
          );
        } else if (allergen.contains('nut')) {
          buffer.writeln(
            '  "So I spoke with the chef, and he said that he\'s too busy now to clean down all the equipment to make your order, and other people do get nuts on French toast, so they are in our kitchen. It\'s a really busy time now with brunch on a Sunday. But you should be fine with just maybe some traces"',
          );
        } else if (allergen == 'fish' || allergen == 'seafood') {
          buffer.writeln(
            '  "I\'ve spoken to the chef, and she said that we fry everything in the one fryer, including our battered fish. So the oil could have some fish traces in it, it\'s hard to say"',
          );
        } else {
          buffer.writeln(
            '  "I\'ve spoken to the chef, and she said that we prepare many different dishes using the same equipment, so there could be some $allergen traces from other orders."',
          );
        }
        buffer.writeln(
          '- NEVER combine casual acceptance with challenges in one response',
        );
        buffer.writeln(
          '- Challenges should be presented as denials/problems, not solutions',
        );
        buffer.writeln(
          '- Give inappropriate advice that forces customer decisions',
        );
        buffer.writeln(
          '- Present realistic kitchen constraints and business pressures',
        );
        buffer.writeln('- Use casual language but create safety challenges');
        buffer.writeln(
          '- Be accommodating only when customer explicitly pushes back',
        );
        buffer.writeln(
          '- NEVER be overly helpful or accommodating - make customers work for safety assurance',
        );
        buffer.writeln(
          '- Emphasize business priorities: "It\'s a really busy time", "The chef\'s too busy", "We don\'t have time to..."',
        );
        buffer.writeln(
          '- Before conversation ends, confirm final order: "So to confirm, you\'re having [dishes and drinks]"',
        );
        buffer.writeln(
          '- Track multiple orders if customer orders several items',
        );
        buffer.writeln(
          '- Note if customer cancels unsafe food (good safety decision)',
        );
        if (behaviorRules.includeHiddenAllergens) {
          buffer.writeln(
            '- Only reveal hidden allergens if directly asked - no volunteering information',
          );
        }
        break;
    }

    // Behavioral flags
    if (behaviorRules.allowProbing && level == DifficultyLevel.advanced) {
      buffer.writeln(
        '\n- May ask follow-up questions to test customer knowledge',
      );
    }

    if (behaviorRules.includeHiddenAllergens) {
      buffer.writeln('- Hidden allergens are present in menu items');
      buffer.writeln(
        '- Only reveal hidden allergens when customer asks specifically',
      );
    }

    // Trigger words
    if (behaviorRules.triggerWords.isNotEmpty) {
      buffer.writeln(
        '\nTrigger words that should prompt responses: ${behaviorRules.triggerWords.join(", ")}',
      );
    }

    return buffer.toString();
  }

  String _generateEnhancedFallbackPrompt(
    String menuForAI,
    ScenarioConfig? scenarioConfig,
    PlayerProfile? playerProfile,
    ConversationContext context,
  ) {
    final buffer = StringBuffer();

    buffer.writeln('You are a restaurant waiter.');

    if (scenarioConfig != null) {
      buffer.writeln(
        'Restaurant: ${scenarioConfig.menuData?['restaurant_name'] ?? 'Unknown Restaurant'}',
      );
      buffer.writeln('Scenario: ${scenarioConfig.name}');
      buffer.writeln(scenarioConfig.scenarioContext);

      // Add behavior context
      buffer.write(
        _addScenarioBehaviorContext(scenarioConfig, playerProfile, context),
      );
    }

    buffer.writeln('\n$menuForAI');

    buffer.writeln('\n ABSOLUTE MANDATORY RULES ');
    buffer.writeln(' SIMPLE GUIDELINES:');
    buffer.writeln('- Ingredient question? → Give factual info');
    buffer.writeln('- Allergy disclosure? → Follow level protocols');
    buffer.writeln('- Food order? → Process order');
    buffer.writeln(
      '- Cross-contact question? → Follow level behavior (supportive vs challenging)',
    );
    buffer.writeln('- Conversation ending? → Confirm final order');
    buffer.writeln('');
    buffer.writeln(
      '1. NEVER ASK ABOUT ALLERGIES - only respond if customer mentions them first',
    );
    buffer.writeln(
      '2. YOU CAN ONLY MENTION FOOD ITEMS THAT ARE LISTED ABOVE IN THE MENU',
    );
    buffer.writeln('3. USE THE EXACT DISH NAMES - COPY THEM WORD FOR WORD');
    buffer.writeln(
      '4. NEVER MENTION: "garlic bread", "bruschetta", "calamari", generic food names',
    );
    buffer.writeln(
      '5. ONLY suggest items marked "SAFE" for customers with allergies',
    );
    buffer.writeln(
      '6. THINK about what customer actually said - don\'t assume or make up context',
    );

    return buffer.toString();
  }

  String _generateMenuBasedFallback(String userInput, String menuForAI) {
    final lowerInput = userInput.toLowerCase();

    if (lowerInput.trim() == 'yes' ||
        lowerInput.trim() == 'sure' ||
        lowerInput.trim() == 'ok' ||
        lowerInput.trim() == 'okay' ||
        lowerInput.contains('yes please') ||
        lowerInput.contains('that would be great')) {
      // User is agreeing to suggestions - provide actual safe menu items
      final menuLines = menuForAI.split('\n');
      final safeItems = <String>[];

      for (int i = 0; i < menuLines.length; i++) {
        final line = menuLines[i];
        if (line.contains('SAFE')) {
          // Look backward for the item name
          for (int j = i - 1; j >= math.max(0, i - 5); j--) {
            final itemLine = menuLines[j];
            if (itemLine.startsWith('• ')) {
              safeItems.add(itemLine.substring(2).split(' - ')[0]);
              break;
            }
          }
          if (safeItems.length >= 3) break;
        }
      }

      if (safeItems.isNotEmpty) {
        return "Perfect! Based on your allergies, I'd recommend ${safeItems.take(2).join(' or ')}. Both are completely safe for you. Which one sounds good?";
      } else {
        // Fallback to first available item if no safety info
        for (final line in menuLines) {
          if (line.startsWith('• ')) {
            final firstItem = line.substring(2).split(' - ')[0];
            return "Perfect! How about our $firstItem? Or would you prefer to see other options from our menu?";
          }
        }
      }
    }

    if (lowerInput.contains('what') &&
        (lowerInput.contains('have') || lowerInput.contains('got')) &&
        (lowerInput.contains('in ') || lowerInput.contains('with '))) {
      // Extract the food type they're asking about
      String? foodType;
      final foodTypes = [
        'chicken',
        'fish',
        'beef',
        'pork',
        'seafood',
        'prawn',
        'shrimp',
        'lamb',
        'duck',
        'vegetarian',
        'vegan',
        'curry',
        'pasta',
        'soup',
        'dessert',
      ];

      for (final type in foodTypes) {
        if (lowerInput.contains(type)) {
          foodType = type;
          break;
        }
      }

      if (foodType != null) {
        return _findItemsByFoodType(foodType, menuForAI);
      }
    }

    if (lowerInput.contains('menu')) {
      // ✅ Use actual menu items from the formatted menuForAI string
      if (menuForAI.isNotEmpty) {
        // Extract some starter items from the menuForAI string
        final menuLines = menuForAI.split('\n');
        final starterItems = <String>[];
        bool inStarters = false;

        for (final line in menuLines) {
          if (line.contains('--- STARTERS ---')) {
            inStarters = true;
            continue;
          }
          if (line.contains('--- MAINS ---') ||
              line.contains('--- DESSERTS ---')) {
            inStarters = false;
          }
          if (inStarters && line.startsWith('• ')) {
            starterItems.add(
              line.substring(2).split(' - ')[0],
            ); // Extract just the name
            if (starterItems.length >= 3) break;
          }
        }

        if (starterItems.isNotEmpty) {
          return "Of course! For starters we have ${starterItems.join(', ')}. We also have mains, desserts, and drinks. What would you like to know more about?";
        }
      }
      // Fallback to dynamic menu extraction
      final menuLines = menuForAI.split('\n');
      final availableItems = <String>[];

      for (final line in menuLines) {
        if (line.startsWith('• ')) {
          availableItems.add(line.substring(2).split(' - ')[0]);
          if (availableItems.length >= 5) break;
        }
      }

      if (availableItems.isNotEmpty) {
        return "Of course! We have ${availableItems.take(3).join(', ')}, and more. What would you like to know about?";
      }
      return "What can I get for you today?";
    } else if (lowerInput.contains('recommend')) {
      // Extract first item from menu for recommendation
      final menuLines = menuForAI.split('\n');
      String? firstItem;
      for (final line in menuLines) {
        if (line.startsWith('• ')) {
          firstItem = line.substring(2).split(' - ')[0];
          break;
        }
      }
      if (firstItem != null) {
        return "I'd recommend our $firstItem - it's very popular! What are you in the mood for?";
      }
      return "What are you in the mood for today?";
    } else if (lowerInput.contains('safe') || lowerInput.contains('allerg')) {
      final menuLines = menuForAI.split('\n');
      final safeItems = <String>[];

      for (int i = 0; i < menuLines.length; i++) {
        final line = menuLines[i];
        if (line.contains('SAFE')) {
          // Look backward for the item name (should be a few lines above)
          for (int j = i - 1; j >= math.max(0, i - 5); j--) {
            final itemLine = menuLines[j];
            if (itemLine.startsWith('• ')) {
              safeItems.add(itemLine.substring(2).split(' - ')[0]);
              break;
            }
          }
          if (safeItems.length >= 3) break;
        }
      }

      if (safeItems.isNotEmpty) {
        final allergyType = lowerInput.contains('peanut')
            ? 'peanut allergy'
            : 'allergies';
        return "Thanks for telling me about your $allergyType! Safe options for you include ${safeItems.join(', ')}. What sounds good?";
      } else {
        return "Absolutely! I can help you find something that works for you. Could you tell me about your specific allergies so I can recommend the best options from our menu?";
      }
    } else {
      return "What can I get for you today?";
    }
  }

  String _findItemsByFoodType(String foodType, String menuForAI) {
    final menuLines = menuForAI.split('\n');
    final matchingItems = <String>[];

    for (final line in menuLines) {
      if (line.startsWith('• ')) {
        final itemName = line.substring(2).split(' - ')[0];
        final itemNameLower = itemName.toLowerCase();
        final foodTypeLower = foodType.toLowerCase();

        bool matches = false;

        // Direct name matches
        if (itemNameLower.contains(foodTypeLower)) {
          matches = true;
        }

        // Special food type mappings based on our actual menu
        switch (foodTypeLower) {
          case 'chicken':
            // Our chicken dishes: Satay Chicken Skewers, Butter Chicken, Thai Green Curry (Chicken/Tofu), Pesto Pasta with Grilled Chicken
            if (itemNameLower.contains('chicken')) {
              matches = true;
            }
            break;
          case 'fish':
          case 'seafood':
          case 'prawn':
          case 'shrimp':
            // Our seafood dishes: Prawn Tempura, Seafood Linguine, Sushi Platter
            if (itemNameLower.contains('prawn') ||
                itemNameLower.contains('seafood') ||
                itemNameLower.contains('sushi') ||
                itemNameLower.contains('linguine')) {
              matches = true;
            }
            break;
          case 'beef':
            // Our beef dishes: Beef Burger with Brioche Bun
            if (itemNameLower.contains('beef') ||
                itemNameLower.contains('burger')) {
              matches = true;
            }
            break;
          case 'vegetarian':
          case 'vegan':
            // Our vegetarian/vegan options: Vegan Lentil Shepherd's Pie, Hummus & Pitta, Buffalo Mozzarella & Pesto, Tomato & Basil Soup, etc.
            if (itemNameLower.contains('vegan') ||
                itemNameLower.contains('lentil') ||
                itemNameLower.contains('hummus') ||
                itemNameLower.contains('mozzarella') ||
                itemNameLower.contains('tomato') ||
                itemNameLower.contains('falafel') ||
                itemNameLower.contains('meringue')) {
              matches = true;
            }
            break;
          case 'pork':
            // Our pork dishes: BBQ Ribs
            if (itemNameLower.contains('ribs') ||
                itemNameLower.contains('bbq')) {
              matches = true;
            }
            break;
          case 'curry':
            // Our curry dishes: Butter Chicken, Thai Green Curry
            if (itemNameLower.contains('curry') ||
                itemNameLower.contains('butter chicken')) {
              matches = true;
            }
            break;
          case 'pasta':
            // Our pasta dishes: Pesto Pasta with Grilled Chicken
            if (itemNameLower.contains('pasta') ||
                itemNameLower.contains('linguine')) {
              matches = true;
            }
            break;
          case 'soup':
            // Our soup dishes: Tomato & Basil Soup
            if (itemNameLower.contains('soup')) {
              matches = true;
            }
            break;
          case 'dessert':
            // Our dessert dishes: Chocolate Brownie, Almond Frangipane Tart, Pistachio Gelato, Meringue with Berries
            if (itemNameLower.contains('brownie') ||
                itemNameLower.contains('tart') ||
                itemNameLower.contains('gelato') ||
                itemNameLower.contains('meringue')) {
              matches = true;
            }
            break;
        }

        if (matches) {
          matchingItems.add(itemName);
        }
      }
    }

    if (matchingItems.isNotEmpty) {
      if (matchingItems.length == 1) {
        return "We have ${matchingItems[0]} with $foodType. Would you like to know more about it?";
      } else {
        return "For $foodType dishes, we have ${matchingItems.join(', ')}. What sounds good to you?";
      }
    } else {
      return "I'm sorry, we don't currently have any $foodType dishes on our menu. Would you like me to suggest some other options?";
    }
  }

  /// ✅ NEW: Update context based on AI analysis
  ConversationContext _updateContextFromAnalysis(
    ConversationContext context,
    Map<String, dynamic> analysis,
    String waiterResponse,
    String userInput, // Add user input parameter
  ) {
    // Add waiter response to messages
    final waiterMessage = ConversationMessage(
      role: 'assistant',
      content: waiterResponse,
      timestamp: DateTime.now(),
    );
    final updatedMessages = [...context.messages, waiterMessage];

    // Update based on AI analysis
    bool allergiesDisclosed = context.allergiesDisclosed;
    List<String> disclosedAllergies = [...context.disclosedAllergies];
    String? selectedDish = context.selectedDish;
    bool confirmedDish = context.confirmedDish;

    if (analysis['mentioned_allergies'] is List &&
        (analysis['mentioned_allergies'] as List).isNotEmpty) {
      final newAllergies = (analysis['mentioned_allergies'] as List<dynamic>)
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList();

      if (newAllergies.isNotEmpty) {
        allergiesDisclosed = true;
        disclosedAllergies = [
          ...disclosedAllergies,
          ...newAllergies,
        ].toSet().toList();
        debugPrint(
          '[CONTEXT UPDATE] All disclosed allergies: $disclosedAllergies',
        );
      }
    }

    if (analysis['ordered_food'] != null &&
        analysis['ordered_food'].toString().isNotEmpty &&
        analysis['ordered_food'].toString() != 'null') {
      final rawDish = analysis['ordered_food'].toString();
      final normalizedDish = _normalizeDishName(rawDish);

      final lowerInput = userInput.toLowerCase();
      final isConfirmation =
          lowerInput.startsWith('yes') ||
          lowerInput.startsWith('sure') ||
          lowerInput.startsWith('okay') ||
          lowerInput.contains('with that') ||
          lowerInput.contains('sounds good') ||
          lowerInput.contains('that sounds') ||
          lowerInput.contains('that\'s good') ||
          lowerInput.contains('that works');

      // Don't overwrite existing main dish selection with confirmations or side items
      if (selectedDish != null && isConfirmation) {
        debugPrint(
          '[CONTEXT SKIP] User confirming existing order: $selectedDish, ignoring additional item: $rawDish',
        );
      } else if (selectedDish == null || normalizedDish != selectedDish) {
        // Check if it's a real main dish menu item (not just bread/water/sides)
        final isSideItem = [
          'bread',
          'water',
          'drink',
          'soda',
          'juice',
          'roll',
          'croutons',
        ].contains(normalizedDish?.toLowerCase());
        final isRealMenuItem =
            normalizedDish != null && normalizedDish.length > 3 && !isSideItem;

        if (isRealMenuItem) {
          selectedDish = normalizedDish;
          debugPrint(
            '[CONTEXT UPDATE] Food ordered: $selectedDish (normalized from: $rawDish) from intent: ${analysis['intent']}',
          );
        } else {
          debugPrint(
            '[CONTEXT SKIP] Ignoring side item/beverage: $rawDish (normalized: $normalizedDish)',
          );
        }
      } else {
        debugPrint('[CONTEXT SKIP] Same dish already selected: $selectedDish');
      }
    }

    // NEW: Track safety warnings and order changes
    List<String> cancelledAfterWarning = [
      ...context.cancelledOrdersAfterWarning,
    ];
    List<String> keptUnsafeAfterWarning = [
      ...context.keptUnsafeOrdersAfterWarning,
    ];
    List<String> reorderedAfterCancellation = [
      ...context.reorderedItemsAfterCancellation,
    ];
    bool safetyWarningGiven = context.safetyWarningGiven;

    // Detect safety warnings in waiter response
    final lowerResponse = waiterResponse.toLowerCase();
    bool containsSafetyWarning =
        lowerResponse.contains('traces') ||
        lowerResponse.contains('cross') ||
        lowerResponse.contains('contamination') ||
        lowerResponse.contains('shared equipment') ||
        lowerResponse.contains('same fryer') ||
        lowerResponse.contains('too busy') ||
        lowerResponse.contains('can\'t guarantee') ||
        lowerResponse.contains('might contain');

    if (containsSafetyWarning && !safetyWarningGiven) {
      safetyWarningGiven = true;
      debugPrint('[CONTEXT UPDATE] Safety warning detected in waiter response');
    }

    // Detect order cancellations after safety warnings
    final lowerInput = userInput.toLowerCase();
    bool isCancellation =
        lowerInput.contains('don\'t want') ||
        lowerInput.contains('cancel') ||
        lowerInput.contains('change my order') ||
        lowerInput.contains('something else') ||
        lowerInput.contains('different') ||
        lowerInput.contains('instead');

    if (isCancellation &&
        context.safetyWarningGiven &&
        context.selectedDish != null) {
      cancelledAfterWarning.add(context.selectedDish!);
      debugPrint(
        '[CONTEXT UPDATE] Order cancelled after safety warning: ${context.selectedDish}',
      );
      selectedDish = null; // Clear current selection
      confirmedDish = false;
    }

    // Detect when user keeps order despite safety warnings
    bool isKeepingOrder =
        (lowerInput.contains('keep') && lowerInput.contains('order')) ||
        (lowerInput.contains('i\'ll have') && context.safetyWarningGiven) ||
        (lowerInput.contains('still want') || lowerInput.contains('anyway'));

    if (isKeepingOrder &&
        context.safetyWarningGiven &&
        context.selectedDish != null) {
      keptUnsafeAfterWarning.add(context.selectedDish!);
      debugPrint(
        '[CONTEXT UPDATE] Kept unsafe order after safety warning: ${context.selectedDish}',
      );
    }

    // Detect reorders after cancellation
    if (selectedDish != null &&
        cancelledAfterWarning.isNotEmpty &&
        !context.reorderedItemsAfterCancellation.contains(selectedDish!)) {
      reorderedAfterCancellation.add(selectedDish!);
      debugPrint(
        '[CONTEXT UPDATE] Reordered after cancellation: $selectedDish',
      );
    }

    // Handle order confirmation (waiter confirms the order)
    if (selectedDish != null && !confirmedDish) {
      // Simple check: if waiter response is positive and not a question/warning
      bool isQuestion = waiterResponse.contains('?');
      bool isWarning = containsSafetyWarning;

      if (!isQuestion && !isWarning && lowerResponse.length > 10) {
        confirmedDish = true;
        debugPrint('[CONTEXT UPDATE] Order confirmed by waiter');
      }
    }

    // Debug: Print complete context state
    debugPrint(
      '[CONTEXT STATE] allergiesDisclosed=$allergiesDisclosed, selectedDish=$selectedDish, confirmedDish=$confirmedDish',
    );

    // Update topics covered
    final newTopics = Map<String, bool>.from(context.topicsCovered);
    if (allergiesDisclosed) newTopics['allergies_disclosed'] = true;
    if (selectedDish != null) newTopics['dish_selected'] = true;
    if (analysis['is_asking_question'] == true)
      newTopics['asked_questions'] = true;

    final updatedContext = context.copyWith(
      messages: updatedMessages,
      allergiesDisclosed: allergiesDisclosed,
      disclosedAllergies: disclosedAllergies,
      selectedDish: selectedDish,
      confirmedDish: confirmedDish,
      turnCount: context.turnCount + 1,
      topicsCovered: newTopics,
      cancelledOrdersAfterWarning: cancelledAfterWarning,
      keptUnsafeOrdersAfterWarning: keptUnsafeAfterWarning,
      reorderedItemsAfterCancellation: reorderedAfterCancellation,
      safetyWarningGiven: safetyWarningGiven,
    );

    // Update internal context
    _currentContext = updatedContext;
    onContextUpdate?.call(_currentContext);

    return updatedContext;
  }

  String _getUserFriendlyErrorMessage(String errorMsg) {
    if (errorMsg.contains('err_no_match') || errorMsg.contains('no_match')) {
      return 'No speech detected. Speak clearly and take your time - pauses are okay!';
    } else if (errorMsg.contains('err_speech_timeout') ||
        errorMsg.contains('timeout')) {
      return 'Speech recognition is listening. You can speak longer sentences with natural pauses.';
    } else if (errorMsg.contains('err_audio') || errorMsg.contains('audio')) {
      return 'Audio issue detected. Please check your microphone.';
    } else if (errorMsg.contains('err_network') ||
        errorMsg.contains('network')) {
      return 'Network error. Please check your connection.';
    } else if (errorMsg.contains('err_client') || errorMsg.contains('client')) {
      return 'Speech recognition temporarily unavailable. Please try again.';
    } else if (errorMsg.contains('err_insufficient_permissions') ||
        errorMsg.contains('permission')) {
      return 'Microphone permission required. Please enable in settings.';
    } else {
      return 'Speech recognition error. Please try again.';
    }
  }

  void dispose() {
    _speechToText.cancel();
    _realisticTts.dispose();
  }

  /// Normalize dish names to match menu items
  String? _normalizeDishName(String? dishName) {
    if (dishName == null || dishName.isEmpty) return null;

    final normalized = dishName.toLowerCase().trim();

    // Common dish name mappings to match menu exactly
    final dishMappings = {
      'tomato basil soup': 'Tomato & Basil Soup',
      'tomato and basil soup': 'Tomato & Basil Soup',
      'satay chicken skewers': 'Satay Chicken Skewers',
      'satay chicken': 'Satay Chicken Skewers',
      'chicken satay': 'Satay Chicken Skewers',
      'prawn tempura': 'Prawn Tempura',
      'tempura prawns': 'Prawn Tempura',
      'hummus pitta': 'Hummus & Pitta',
      'hummus and pitta': 'Hummus & Pitta',
      'buffalo mozzarella pesto': 'Buffalo Mozzarella & Pesto',
      'mozzarella and pesto': 'Buffalo Mozzarella & Pesto',
      'butter chicken': 'Butter Chicken',
      'thai green curry': 'Thai Green Curry',
      'green curry': 'Thai Green Curry',
      'seafood linguine': 'Seafood Linguine',
      'sushi platter': 'Sushi Platter',
      'sticky toffee pudding': 'Sticky Toffee Pudding',
      'chocolate brownies': 'Chocolate Brownies',
      'chocolate brownie': 'Chocolate Brownies',
      'vegan lentil pie': 'Vegan Lentil Shepherd\'s Pie',
      'vegan shepherds pie': 'Vegan Lentil Shepherd\'s Pie',
      'lentil shepherds pie': 'Vegan Lentil Shepherd\'s Pie',
    };

    // Check for exact match first
    if (dishMappings.containsKey(normalized)) {
      return dishMappings[normalized]!;
    }

    // Partial matching for variations
    for (final mapping in dishMappings.entries) {
      if (normalized.contains(mapping.key) ||
          mapping.key.contains(normalized)) {
        return mapping.value;
      }
    }

    // If no mapping found, return original with proper capitalization
    return dishName
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? word
              : word[0].toUpperCase() + word.substring(1).toLowerCase(),
        )
        .join(' ');
  }
}
