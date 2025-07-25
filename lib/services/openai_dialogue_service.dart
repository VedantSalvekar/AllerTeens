import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/game_state.dart';
import '../models/simulation_step.dart';
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

  const ConversationContext({
    this.messages = const [],
    this.allergiesDisclosed = false,
    this.confirmedDish = false,
    this.disclosedAllergies = const [],
    this.selectedDish,
    this.turnCount = 0,
    this.topicsCovered = const {},
  });

  ConversationContext copyWith({
    List<ConversationMessage>? messages,
    bool? allergiesDisclosed,
    bool? confirmedDish,
    List<String>? disclosedAllergies,
    String? selectedDish,
    int? turnCount,
    Map<String, bool>? topicsCovered,
  }) {
    return ConversationContext(
      messages: messages ?? this.messages,
      allergiesDisclosed: allergiesDisclosed ?? this.allergiesDisclosed,
      confirmedDish: confirmedDish ?? this.confirmedDish,
      disclosedAllergies: disclosedAllergies ?? this.disclosedAllergies,
      selectedDish: selectedDish ?? this.selectedDish,
      turnCount: turnCount ?? this.turnCount,
      topicsCovered: topicsCovered ?? this.topicsCovered,
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
          debugPrint('🎤 [SPEECH] Speech recognition error: ${error.errorMsg}');
          String userFriendlyMessage = _getUserFriendlyErrorMessage(
            error.errorMsg,
          );
          onError?.call(userFriendlyMessage);

          // Handle specific error types
          if (error.errorMsg.contains('timeout') ||
              error.errorMsg.contains('no_match')) {
            debugPrint(
              '🔄 [SPEECH] Timeout/no match error - user must manually restart',
            );
            // ✅ REMOVED: No automatic restart - user must manually press microphone
          }
        },
        onStatus: (status) {
          // Handle status changes that might indicate problems
          if (status == 'notListening' && _isListening) {
            debugPrint(
              '🔄 [SPEECH] Speech stopped unexpectedly - status: $status',
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

        // ✅ REMOVED: No automatic speech restart - user must manually press microphone
      };

      _realisticTts.onTTSStarted = () {
        debugPrint('TTS started - triggering animation start');

        // ✅ CRITICAL FIX: Stop speech recognition when TTS starts to prevent audio interference
        if (_isListening) {
          debugPrint(
            '🎤 [SPEECH] Stopping speech recognition for TTS playback',
          );
          stopListening();
        }

        onTTSStarted?.call();
      };

      _realisticTts.onError = (error) {
        debugPrint('TTS error: $error');
        onError?.call(error);

        // ✅ REMOVED: No automatic restart - user must manually press microphone
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

    // ✅ CRITICAL FIX: Don't start listening if TTS is currently playing
    if (_realisticTts.isPlaying) {
      debugPrint(
        '🎤 [SPEECH] TTS is playing - delaying speech recognition start',
      );
      onError?.call('Please wait for the waiter to finish speaking');
      return;
    }

    try {
      // ✅ Add a small delay to ensure TTS audio has stopped completely
      await Future.delayed(const Duration(milliseconds: 500));

      await _speechToText.listen(
        onResult: (result) {
          _lastWords = result.recognizedWords;

          // ✅ CRITICAL FIX: Clean up the speech input to remove TTS interference
          final cleanedInput = _cleanSpeechInput(_lastWords);

          // Only update if the cleaned input is substantially different and valid
          if (cleanedInput.isNotEmpty && cleanedInput != _lastWords) {
            debugPrint('🎤 [SPEECH] Raw input: "$_lastWords"');
            debugPrint('🎤 [SPEECH] Cleaned input: "$cleanedInput"');
            _lastWords = cleanedInput;
          }

          onTranscriptionUpdate?.call(_lastWords);
          debugPrint(
            '🎤 [SPEECH] Speech result: $_lastWords (confidence: ${result.confidence}, hasConfidenceRating: ${result.hasConfidenceRating})',
          );
        },
        listenFor: const Duration(
          seconds: 30, // Reduced from 60 to 30 seconds for better control
        ),
        pauseFor: const Duration(
          seconds:
              3, // Reduced from 10 to 3 seconds for more responsive interaction
        ),
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: false,
          listenMode: ListenMode
              .confirmation, // Changed back from dictation to confirmation for cleaner input
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

  /// ✅ NEW: Clean speech input to remove TTS interference and repeated content
  String _cleanSpeechInput(String input) {
    if (input.trim().isEmpty) return input;

    // Remove common TTS phrases that might get picked up
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

    // Remove TTS interference patterns
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
        '🔄 [SPEECH] Detected timeout/pause error - attempting automatic restart',
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

      // Load menu from JSON and get formatted version for AI
      await MenuService.instance.loadMenu();
      final menuForAI = MenuService.instance.formatMenuForAI(
        playerProfile.allergies,
      );

      // ✅ DEBUG: Log the formatted menu to see what AI is receiving
      debugPrint(
        '🍽️ [MENU] Formatted menu for AI (first 500 chars): ${menuForAI.substring(0, menuForAI.length > 500 ? 500 : menuForAI.length)}...',
      );
      if (menuForAI.isEmpty) {
        debugPrint(
          '❌ [MENU] ERROR: Menu is empty! AI will give generic responses.',
        );
      }

      // ✅ NEW: Use AI to analyze user intent semantically
      final analysisResponse = await _analyzeUserIntent(
        userInput,
        playerProfile,
        workingContext,
      );

      // Build waiter response using the provided systemPrompt
      final waiterResponse = await _generateWaiterResponse(
        userInput,
        systemPrompt,
        workingContext,
        menuForAI,
      );

      // Update context based on AI analysis (not phrase matching)
      final updatedContext = _updateContextFromAnalysis(
        workingContext.copyWith(messages: updatedMessages),
        analysisResponse,
        waiterResponse,
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
      debugPrint('Error getting OpenAI response: $e');
      debugPrint('Error details: ${e.toString()}');
      debugPrint('User input was: $userInput');
      onError?.call('Failed to get AI response');

      // Generate contextual fallback response based on user input
      String fallbackResponse;
      final lowerInput = userInput.toLowerCase();

      if (lowerInput.contains('menu')) {
        fallbackResponse =
            "Of course! We have pasta, pizza, salads, grilled chicken, fish & chips, and vegetarian options. What sounds good to you?";
      } else if (lowerInput.contains('recommend')) {
        fallbackResponse =
            "I'd recommend our grilled chicken or pasta - they're very popular! What are you in the mood for?";
      } else if (lowerInput.contains('allerg') || lowerInput.contains('safe')) {
        fallbackResponse = "I understand. What would you like to order today?";
      } else if (lowerInput.contains('order') ||
          lowerInput.contains('have') ||
          lowerInput.contains('want')) {
        fallbackResponse = "Great! What can I get for you?";
      } else {
        fallbackResponse = "What can I help you with today?";
      }

      // Update context manually for fallback
      final fallbackContext = _currentContext.copyWith(
        messages: [
          ..._currentContext.messages,
          ConversationMessage(
            role: 'user',
            content: userInput,
            timestamp: DateTime.now(),
          ),
          ConversationMessage(
            role: 'assistant',
            content: fallbackResponse,
            timestamp: DateTime.now(),
          ),
        ],
        turnCount: _currentContext.turnCount + 1,
      );

      return NPCDialogueResponse(
        npcDialogue: fallbackResponse,
        isPositiveFeedback: true,
        confidencePoints: 0,
        detectedAllergies: <String>[],
        followUpPrompt: '',
        updatedContext: fallbackContext,
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
    bool orderedUnsafeFood = false;
    if (selectedDish != null) {
      final menuItem = MenuService.instance.findItemByName(selectedDish);
      if (menuItem != null) {
        orderedUnsafeFood = !MenuService.instance.isItemSafeForUser(
          menuItem,
          playerProfile.allergies,
        );
      }
    }

    return '''
You are a friendly, professional waiter at a restaurant. This is ALLERGY SAFETY TRAINING.

ALLERGY DISCLOSURE STATUS: ${hasDisclosedAllergies ? 'YES - They told you about: $previousAllergies' : 'NO - They haven\'t mentioned allergies yet'}
${selectedDish != null ? 'ORDERED DISH: $selectedDish' : 'NO ORDER YET'}

🚨 CRITICAL: You must ONLY mention the specific dishes listed in this menu. DO NOT invent or mention any other foods.

$menuForAI

⚠️ FORBIDDEN WORDS: Never use these generic terms: "grilled chicken", "pasta", "fish & chips", "salads", "pizza". Use ONLY our actual menu item names listed above.

WAITER SAFETY PROTOCOLS:
1. If customer orders food containing their disclosed allergies → IMMEDIATELY warn them
2. If customer orders food but hasn't disclosed allergies → Ask about allergies first  
3. If customer asks about ingredients → Be specific about allergens and hidden allergens
4. Always prioritize customer safety over sales

EXAMPLE SAFETY RESPONSES:
- "I need to let you know that the [dish] contains [allergen], which you mentioned you're allergic to. Would you like me to suggest something safer?"
- "Before I take your order, do you have any food allergies I should know about?"
- "That dish contains [allergen] and also has hidden [hidden allergen] in the [component]. Given your allergies, I'd recommend [safe alternative] instead."

CRITICAL: If customer orders unsafe food, you MUST warn them before confirming the order.

CRITICAL MENU RULES:
1. ONLY mention dishes from the menu listed above - NEVER invent or suggest generic foods
2. When showing menu, use EXACT dish names only: "Satay Chicken Skewers", "Tomato & Basil Soup", etc.
3. ONLY provide prices/descriptions when customer specifically asks for them
4. When suggesting safe options, check allergens and ONLY recommend safe dishes from our actual menu
5. NEVER say "grilled chicken", "pasta", "fish & chips" - these are NOT on our menu

FOOD TYPE QUERIES:
When customer asks "what do you have in chicken" or "what fish dishes do you have":
- Search the menu above for items containing that food type
- ONLY mention items that are actually on our menu
- For chicken: "Satay Chicken Skewers", "Butter Chicken", "Thai Green Curry (Chicken/Tofu)"
- For fish/seafood: "Prawn Tempura", "Seafood Linguine", "Sushi Platter"
- For beef: "Beef Burger with Brioche Bun"
- If we don't have that food type, say "We don't currently have any [food type] dishes"

REALISTIC TRAINING SCENARIOS:

  1. **If customer asks for menu WITHOUT mentioning allergies:**
     - List ACTUAL menu items with exact names only (no prices unless asked)
     - Example: "For starters we have Satay Chicken Skewers, Tomato & Basil Soup, Prawn Tempura, Hummus & Pitta, and Buffalo Mozzarella & Pesto. For mains we have Butter Chicken, Thai Green Curry..."
     - NEVER mention foods not on our menu
     - Don't mention allergies unless they do first

  1.5 **If customer asks about specific food types (e.g., "what chicken dishes do you have"):**
     - Search our actual menu above for items containing that food type
     - ONLY mention items that exist on our menu
     - Examples: "For chicken, we have Satay Chicken Skewers and Butter Chicken" or "For seafood, we have Prawn Tempura, Seafood Linguine, and Sushi Platter"
     - If we don't have that food type: "We don't currently have any [food type] dishes. Would you like me to suggest something else?"

  2. **If customer mentions allergies FIRST:**
     - Thank them for sharing
     - Check the allergen list for each menu item above
     - ONLY suggest safe dishes from our actual menu (names only, no prices unless asked)
     - Example for peanut allergy: "Safe options for you include Tomato & Basil Soup, Hummus & Pitta, Butter Chicken, and Thai Green Curry" 
     - NEVER suggest generic items like "grilled chicken" - use our specific menu names

3. **If customer orders food without mentioning allergies:**
   - Ask gently: "Before I put in your order, do you have any food allergies I should know about?"
   - Wait for their response

4. **If customer mentions allergies AFTER ordering:**
   - Check if their order contains any of the allergens they mentioned
   - If it does, warn them: "I need to let you know that [dish] contains [allergen] which you mentioned you're allergic to. That wouldn't be safe for you."
   - Suggest safe alternatives instead

5. **If customer asks about ingredients:**
   - Give honest, accurate information from the menu allergen information
   - Don't assume they have specific allergies unless they tell you

6. **If customer asks for prices or descriptions:**
   - Provide exact prices and descriptions from the menu above
   - Example: "The Butter Chicken is £16.95 and it's a creamy tomato-based chicken curry"

IMPORTANT: You should ONLY know about allergies that the customer has explicitly told you about. Do NOT assume they have allergies they haven't mentioned.

Recent conversation:
$recentMessages

CRITICAL: You MUST respond with ONLY valid JSON. No other text before or after.
Format: {"npc_dialogue": "Your response here", "detected_allergies": ["allergy1"]}''';
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
      'max_tokens':
          300, // ✅ Increased from 200 to 300 to allow listing more menu items
      'temperature':
          0.2, // ✅ Reduced temperature for more consistent menu responses
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

    // ✅ REALISTIC: Detect any food ordering like a real restaurant
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

    // ✅ FIXED: Only set confirmedDish when AI waiter actually confirms the order
    bool confirmedDish = context.confirmedDish;

    // Check if AI response contains order confirmation phrases
    final lowerNpcResponse = npcResponse.toLowerCase();

    // Only confirm dish if there's a selected dish AND AI confirms it
    if (selectedDish != null && !confirmedDish) {
      // ✅ REALISTIC: Any positive response after ordering = confirmation
      // Exclude questions and warnings
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
      confirmedDish: confirmedDish, // ✅ Now only true when AI actually confirms
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

    // Patterns that indicate ordering food (not disclosing allergies)
    final orderingPatterns = [
      'i\'ll have',
      'i\'ll take',
      'i want',
      'i\'d like',
      'i choose',
      'i\'ll order',
      'i\'ll get',
      'give me',
      'have the',
      'take the',
      'get the',
      'that one',
      'this one',
      'sounds good',
      'sounds great',
      'perfect',
      'sure',
      'okay',
      'fine',
      'yep',
      'yup',
      'alright',
      'right',
      'exactly',
      'that\'s it',
      'that\'s right',
      'that\'s what i want',
      'that\'s good',
      'that works',
      'that\'s fine',
      'that\'s perfect',
      'let\'s do that',
      'let\'s go with',
      'i\'ll do',
      'i\'ll go with',
      'i\'ll pick',
      'i\'ll select',
      'i\'ll choose',
      'bring me',
      'make me',
      'prepare',
      'cook',
      'fix me',
      'serve me',
      'deliver',
    ];

    // Check if user is ordering food - but exclude questions
    final isOrdering =
        orderingPatterns.any((pattern) => lowerInput.contains(pattern)) &&
        !lowerInput.startsWith('what') &&
        !lowerInput.startsWith('so what') &&
        !hasAllergyDisclosure; // CRITICAL FIX: Don't consider it ordering if they're disclosing allergies

    // FIXED: If user mentions allergies, always consider it allergy disclosure regardless of other patterns
    return hasAllergyDisclosure;
  }

  /// Check if AI response indicates the conversation should end
  bool _shouldEndConversationFromAI(
    String npcDialogue,
    ConversationContext context,
  ) {
    // ✅ REALISTIC: Let conversations flow naturally
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
        '🔚 [AI NATURAL END] AI naturally ended conversation: "$npcDialogue"',
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
                allergyLower.substring(0, min(3, allergyLower.length)),
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

  bool get isListening => _isListening;
  ConversationContext get currentContext => _currentContext;

  /// ✅ NEW: Use AI to semantically analyze user intent
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
✅ ALWAYS extract allergies when these phrases appear:
  * "I'm allergic to X" → ["X"]
  * "I can't eat X" → ["X"]
  * "I have an allergy to X" → ["X"]
  * "I'm intolerant to X" → ["X"]
  * "I have X allergy" → ["X"]
  * "I am allergic to X" → ["X"]
  * "allergic to X" → ["X"]

❌ NEVER extract allergies for these:
  * Ordering food: "Can I get peanuts?" → []
  * Asking about ingredients: "What's in the chicken?" → []
  * General conversation: "Hi", "Thank you" → []

🔥 CRITICAL: If you see "allergic to" or "I'm allergic" ANYWHERE in the message, extract the allergen even if they're also asking questions or ordering food!

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
      final messages = [
        {'role': 'system', 'content': analysisPrompt},
        {'role': 'user', 'content': 'Analyze this message.'},
      ];

      final response = await _sendOpenAIRequest(messages);
      final analysis = jsonDecode(response) as Map<String, dynamic>;

      debugPrint('[AI ANALYSIS] Raw response: $response');
      debugPrint(
        '[AI ANALYSIS] Intent: ${analysis['intent']}, Allergies: ${analysis['mentioned_allergies']}, Food: ${analysis['ordered_food']}',
      );
      debugPrint('[AI ANALYSIS] User input was: "$userInput"');

      // ✅ CRITICAL FIX: Validate analysis results against expected patterns
      if (userInput.toLowerCase().contains('menu') ||
          userInput.toLowerCase().contains('what\'s')) {
        if (analysis['intent'] != 'question') {
          debugPrint(
            '[AI ANALYSIS] ❌ ERROR: Menu question should have intent "question" but got "${analysis['intent']}"',
          );
          // Force correct analysis for menu questions
          analysis['intent'] = 'question';
          analysis['is_asking_question'] = true;
          analysis['ordered_food'] = null;
          analysis['mentioned_allergies'] = [];
        }
      }

      // ✅ CRITICAL FIX: Validate allergy detection
      final lowerInput = userInput.toLowerCase();
      final hasAllergyPhrase =
          lowerInput.contains('allergic to') ||
          lowerInput.contains('i\'m allergic') ||
          lowerInput.contains('i am allergic') ||
          lowerInput.contains('can\'t eat') ||
          lowerInput.contains('cannot eat') ||
          lowerInput.contains('have an allergy') ||
          lowerInput.contains('allergy to');

      if (hasAllergyPhrase) {
        final detectedAllergies =
            analysis['mentioned_allergies'] as List? ?? [];
        if (detectedAllergies.isEmpty) {
          debugPrint(
            '[AI ANALYSIS] ❌ CRITICAL ERROR: User mentioned allergies but AI missed them!',
          );
          debugPrint('[AI ANALYSIS] Input: "$userInput"');
          debugPrint('[AI ANALYSIS] AI Response: $analysis');

          // Emergency fallback: manual extraction
          final allergens = <String>[];
          if (lowerInput.contains('allergic to peanut'))
            allergens.add('peanuts');
          if (lowerInput.contains('allergic to nut')) allergens.add('nuts');
          if (lowerInput.contains('allergic to dairy')) allergens.add('dairy');
          if (lowerInput.contains('allergic to milk')) allergens.add('milk');
          if (lowerInput.contains('allergic to shellfish'))
            allergens.add('shellfish');
          if (lowerInput.contains('allergic to fish')) allergens.add('fish');
          if (lowerInput.contains('allergic to egg')) allergens.add('eggs');
          if (lowerInput.contains('allergic to wheat')) allergens.add('wheat');
          if (lowerInput.contains('allergic to gluten'))
            allergens.add('gluten');

          if (allergens.isNotEmpty) {
            analysis['mentioned_allergies'] = allergens;
            debugPrint(
              '[AI ANALYSIS] ✅ FIXED: Manually extracted allergies: $allergens',
            );
          }
        } else {
          debugPrint(
            '[AI ANALYSIS] ✅ Allergies correctly detected: $detectedAllergies',
          );
        }
      }

      return analysis;
    } catch (e) {
      debugPrint('Error in AI analysis: $e');
      // Fallback analysis
      return {
        'intent': 'general_response',
        'mentioned_allergies': <String>[],
        'ordered_food': null,
        'is_asking_question': userInput.contains('?'),
        'conversation_should_end': false,
        'confidence': 0.5,
      };
    }
  }

  /// ✅ NEW: Generate natural waiter response
  Future<String> _generateWaiterResponse(
    String userInput,
    String? systemPrompt,
    ConversationContext context,
    String menuForAI,
  ) async {
    try {
      final messages = <Map<String, String>>[];

      // ✅ FIXED: Always use system prompt with menu data
      if (systemPrompt != null && systemPrompt.isNotEmpty) {
        messages.add({'role': 'system', 'content': systemPrompt});
      } else {
        // ✅ FALLBACK: Create basic system prompt with menu if none provided
        final fallbackPrompt =
            '''
You are a friendly restaurant waiter. Here's our menu:

$menuForAI

When customers ask about the menu, tell them about these specific items with names and prices.
Always be helpful and answer questions about ingredients and allergens.
        ''';
        messages.add({'role': 'system', 'content': fallbackPrompt});
      }

      // Add conversation history
      for (final m in context.recentMessages) {
        messages.add({'role': m.role, 'content': m.content});
      }

      // Add current user message
      messages.add({'role': 'user', 'content': userInput});

      final response = await _sendOpenAIRequest(messages);

      // ✅ CRITICAL FIX: Validate AI response doesn't use forbidden generic terms
      String waiterResponse = response;

      // Extract just the dialogue from JSON response if needed
      try {
        final jsonResponse = jsonDecode(response) as Map<String, dynamic>;
        waiterResponse = jsonResponse['npc_dialogue']?.toString() ?? response;
      } catch (_) {
        // If not JSON, use response as-is
        waiterResponse = response;
      }

      // ✅ Validate response doesn't contain forbidden generic foods
      final forbiddenTerms = [
        'grilled chicken',
        'fried chicken',
        'chicken breast',
        'chicken tenders',
        'roasted chicken',
        'chicken parmesan',
        'chicken stir-fry',
        'pasta',
        'fish & chips',
        'fish and chips',
        'pizza',
        'salads',
        'generic',
      ];
      final lowerResponse = waiterResponse.toLowerCase();

      for (final term in forbiddenTerms) {
        if (lowerResponse.contains(term)) {
          debugPrint(
            '❌ [AI RESPONSE] Found forbidden term "$term" in response: "$waiterResponse"',
          );
          // Force fallback with actual menu items
          return _generateMenuBasedFallback(userInput, menuForAI);
        }
      }

      return waiterResponse;
    } catch (e) {
      debugPrint('Error generating waiter response: $e');
      // ✅ FIXED: Use actual menu data in fallback responses
      return _generateMenuBasedFallback(userInput, menuForAI);
    }
  }

  /// ✅ NEW: Generate fallback responses using actual menu data
  String _generateMenuBasedFallback(String userInput, String menuForAI) {
    final lowerInput = userInput.toLowerCase();

    // ✅ NEW: Handle food type queries (e.g., "what do you have in chicken")
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
      return "Of course! For starters we have Satay Chicken Skewers, Tomato & Basil Soup, Prawn Tempura, Hummus & Pitta, and Buffalo Mozzarella & Pesto. For mains we have Butter Chicken, Thai Green Curry, and more. What sounds good to you?";
    } else if (lowerInput.contains('recommend')) {
      return "I'd recommend our Satay Chicken Skewers for starters, or if you prefer something lighter, our Tomato & Basil Soup is very popular! What are you in the mood for?";
    } else if (lowerInput.contains('safe') || lowerInput.contains('allerg')) {
      // ✅ Handle allergy-specific safe options
      if (lowerInput.contains('peanut')) {
        return "Thanks for telling me about your peanut allergy! Safe options for you include Tomato & Basil Soup, Hummus & Pitta, Butter Chicken, and Thai Green Curry. All of these are peanut-free. What sounds good?";
      } else {
        return "Absolutely! I can help you find something that works for you. Could you tell me about your specific allergies so I can recommend the best options from our menu?";
      }
    } else {
      return "What can I get for you today?";
    }
  }

  /// ✅ NEW: Find menu items by food type
  String _findItemsByFoodType(String foodType, String menuForAI) {
    final menuLines = menuForAI.split('\n');
    final matchingItems = <String>[];

    for (final line in menuLines) {
      if (line.startsWith('• ')) {
        final itemName = line.substring(2).split(' - ')[0];
        final itemNameLower = itemName.toLowerCase();
        final foodTypeLower = foodType.toLowerCase();

        // Check if the item name or description contains the food type
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

    // ✅ FIXED: Handle allergies mentioned in ANY intent (not just allergy_disclosure)
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
          '[CONTEXT UPDATE] Allergies mentioned in ${analysis['intent']}: $newAllergies',
        );
        debugPrint(
          '[CONTEXT UPDATE] All disclosed allergies: $disclosedAllergies',
        );
      }
    }

    // ✅ FIXED: Handle food ordering from ANY intent that contains ordered_food
    if (analysis['ordered_food'] != null &&
        analysis['ordered_food'].toString().isNotEmpty &&
        analysis['ordered_food'].toString() != 'null') {
      selectedDish = analysis['ordered_food'].toString();
      debugPrint(
        '[CONTEXT UPDATE] Food ordered: $selectedDish from intent: ${analysis['intent']}',
      );
    }

    // Handle order confirmation (waiter confirms the order)
    if (selectedDish != null && !confirmedDish) {
      // Simple check: if waiter response is positive and not a question/warning
      final lowerResponse = waiterResponse.toLowerCase();
      bool isQuestion = waiterResponse.contains('?');
      bool isWarning =
          lowerResponse.contains('contains') ||
          lowerResponse.contains('allergic') ||
          lowerResponse.contains('not safe');

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
}
