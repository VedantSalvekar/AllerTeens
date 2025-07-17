import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/game_state.dart';
import '../models/simulation_step.dart';
import '../core/config/app_config.dart';
import 'realistic_tts_service.dart';

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
              '🔄 [SPEECH] Timeout/no match error - restarting listening',
            );
            Future.delayed(const Duration(milliseconds: 1000), () {
              if (_speechEnabled && !_isListening) {
                startListening();
              }
            });
          }
        },
        onStatus: (status) {
          debugPrint('🎤 [SPEECH] Speech status: $status');

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
      debugPrint('🎤 [SPEECH] Speech to text initialized: $_speechEnabled');
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
      debugPrint('TTS voice set to male (echo)');

      // Set up callbacks for animation synchronization
      _realisticTts.onTTSCompleted = () {
        debugPrint('TTS completed - triggering animation stop');
        onTTSCompleted?.call();
      };

      _realisticTts.onTTSStarted = () {
        debugPrint('TTS started - triggering animation start');
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

    try {
      await _speechToText.listen(
        onResult: (result) {
          _lastWords = result.recognizedWords;
          onTranscriptionUpdate?.call(_lastWords);
          debugPrint(
            '🎤 [SPEECH] Speech result: $_lastWords (confidence: ${result.confidence}, hasConfidenceRating: ${result.hasConfidenceRating})',
          );
        },
        listenFor: const Duration(
          seconds: 60,
        ), // Increased from 30 to 60 seconds
        pauseFor: const Duration(
          seconds: 10, // Increased from 4 to 10 seconds for longer pauses
        ), // Much longer pause tolerance for natural speech patterns
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError:
              false, // Don't cancel immediately on error - let user retry
          listenMode: ListenMode
              .dictation, // Changed from confirmation to dictation for longer speech
          enableHapticFeedback:
              false, // Disable haptic feedback to avoid interruptions
          autoPunctuation:
              true, // Enable automatic punctuation for better transcription
        ),
      );

      _isListening = true;
      onListeningStateChange?.call(true);
      debugPrint(
        '🎤 [SPEECH] Started listening with extended timeout (60s) and pause tolerance (10s)',
      );
    } catch (e) {
      debugPrint('❌ [SPEECH] Error starting speech recognition: $e');
      await _handleSpeechError(e.toString());
    }
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
    debugPrint('🔄 [SPEECH] Handling speech error: $error');

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
        debugPrint('🔄 [SPEECH] Automatically restarting speech recognition');
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
    debugPrint('🔄 [SPEECH] Manually restarting speech recognition');

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

      // Generate menu items based on user's allergies
      final menuItems = _generateMenuItems(playerProfile.allergies);

      // Build messages for OpenAI API
      final messages = _buildConversationMessages(
        userInput: userInput,
        currentStep: currentStep,
        playerProfile: playerProfile,
        npcRole: npcRole,
        scenarioContext: scenarioContext,
        context: workingContext.copyWith(messages: updatedMessages),
        menuItems: menuItems,
      );

      final response = await _sendOpenAIRequest(messages);
      return _parseOpenAIResponse(
        response,
        userInput,
        playerProfile,
        workingContext.copyWith(messages: updatedMessages),
        menuItems,
      );
    } catch (e) {
      debugPrint('Error getting OpenAI response: $e');
      onError?.call('Failed to get AI response');

      // Return a fallback response
      return NPCDialogueResponse(
        npcDialogue:
            "I'm sorry, I didn't quite catch that. Could you tell me about any food allergies you might have?",
        isPositiveFeedback: false,
        confidencePoints: 0,
        detectedAllergies: [],
        followUpPrompt: "Please speak clearly about your dietary restrictions.",
        updatedContext: _currentContext,
      );
    }
  }

  // Enhanced system prompt template with dynamic context
  String _buildEnhancedSystemPrompt({
    required String npcRole,
    required String scenarioContext,
    required PlayerProfile playerProfile,
    required ConversationContext context,
    required List<MenuItem> menuItems,
  }) {
    final menuContext = _formatMenuContext(menuItems);
    final hasDisclosedAllergies = context.allergiesDisclosed;
    final previousAllergies = context.disclosedAllergies.join(', ');
    final selectedDish = context.selectedDish;
    final recentMessages = context.recentMessages
        .take(4)
        .map((m) => '${m.role}: ${m.content}')
        .join('\n');

    // Check if customer ordered unsafe food
    final orderedUnsafeFood =
        selectedDish != null &&
        menuItems.any((item) => item.name == selectedDish && !item.isSafe);

    return '''
You are a friendly, professional waiter at a restaurant. This is ALLERGY SAFETY TRAINING.

CUSTOMER'S ACTUAL ALLERGIES: ${playerProfile.allergies.join(', ')}
ALLERGY DISCLOSURE STATUS: ${hasDisclosedAllergies ? 'YES - They told you about: $previousAllergies' : 'NO - They haven\'t mentioned allergies yet'}
${selectedDish != null ? 'ORDERED DISH: $selectedDish' : 'NO ORDER YET'}

SAFE MENU ITEMS (for this customer):
${menuItems.where((item) => item.isSafe).map((item) => '✅ ${item.name}: ${item.description}').join('\n')}

UNSAFE MENU ITEMS (contain their allergens):
${menuItems.where((item) => !item.isSafe).map((item) => '⚠️ ${item.name}: ${item.description} (Contains: ${item.allergens.join(', ')})').join('\n')}

FULL MENU (all items):
${menuItems.map((item) => '- ${item.name}: ${item.description}').join('\n')}

REALISTIC TRAINING SCENARIOS:

1. **If customer asks for menu WITHOUT mentioning allergies:**
   - Give them the COMPLETE menu (all items)
   - Don't filter anything - let them choose
   - Don't mention allergies unless they do first

2. **If customer mentions allergies FIRST:**
   - Thank them for sharing
   - Only suggest SAFE items from the menu
   - Don't mention unsafe items at all

3. **If customer orders UNSAFE food without mentioning allergies:**
   - Ask gently: "Before I put in your order, do you have any food allergies I should know about?"
   - Wait for their response

4. **If customer mentions allergies AFTER ordering unsafe food:**
   - Immediately warn them: "I need to let you know that [dish] contains [allergen] which you mentioned you're allergic to. That wouldn't be safe for you."
   - Suggest safe alternatives instead

5. **If customer asks about ingredients:**
   - Give honest, accurate information
   - Don't volunteer allergy info unless they ask

${orderedUnsafeFood ? '\n🚨 SAFETY ALERT: Customer ordered unsafe food! You must warn them about the allergens!' : ''}

Recent conversation:
$recentMessages

CRITICAL: You MUST respond with ONLY valid JSON. No other text before or after.
Format: {"npc_dialogue": "Your response here", "detected_allergies": ["allergy1"]}''';
  }

  // Generate contextual menu items based on user allergies
  List<MenuItem> _generateMenuItems(List<String> userAllergies) {
    final baseMenu = [
      MenuItem(
        name: 'Chicken Satay Bowl',
        description: 'Grilled chicken with peanut sauce and vegetables',
        allergens: ['peanut', 'soy', 'sesame'],
        isSafe: !_containsUserAllergens([
          'peanut',
          'soy',
          'sesame',
        ], userAllergies),
      ),
      MenuItem(
        name: 'Caesar Salad',
        description: 'Romaine lettuce with caesar dressing and croutons',
        allergens: ['egg', 'dairy', 'gluten', 'anchovy'],
        isSafe: !_containsUserAllergens([
          'egg',
          'dairy',
          'gluten',
          'anchovy',
        ], userAllergies),
      ),
      MenuItem(
        name: 'Grilled Veggie Bowl',
        description: 'Fresh seasonal vegetables with quinoa',
        allergens: [],
        isSafe: true, // Always safe
      ),
      MenuItem(
        name: 'Tomato Basil Soup',
        description: 'Creamy tomato soup with fresh basil',
        allergens: ['dairy', 'gluten'],
        isSafe: !_containsUserAllergens(['dairy', 'gluten'], userAllergies),
      ),
      MenuItem(
        name: 'Fish & Chips',
        description: 'Beer-battered fish with crispy fries',
        allergens: ['fish', 'gluten', 'egg'],
        isSafe: !_containsUserAllergens([
          'fish',
          'gluten',
          'egg',
        ], userAllergies),
      ),
      MenuItem(
        name: 'Chocolate Brownie',
        description: 'Rich chocolate brownie with walnuts',
        allergens: ['dairy', 'egg', 'tree nuts', 'gluten'],
        isSafe: !_containsUserAllergens([
          'dairy',
          'egg',
          'tree nuts',
          'gluten',
        ], userAllergies),
      ),
      MenuItem(
        name: 'Fresh Fruit Salad',
        description: 'Seasonal fresh fruit medley',
        allergens: [],
        isSafe: true, // Always safe
      ),
      MenuItem(
        name: 'Thai Green Curry',
        description: 'Coconut curry with vegetables and rice',
        allergens: ['shellfish', 'fish sauce', 'coconut'],
        isSafe: !_containsUserAllergens([
          'shellfish',
          'fish sauce',
          'coconut',
        ], userAllergies),
      ),
    ];

    return baseMenu;
  }

  bool _containsUserAllergens(
    List<String> itemAllergens,
    List<String> userAllergies,
  ) {
    return itemAllergens.any(
      (allergen) => userAllergies.any(
        (userAllergy) =>
            _normalizeAllergen(allergen) == _normalizeAllergen(userAllergy),
      ),
    );
  }

  String _normalizeAllergen(String allergen) {
    final normalized = allergen.toLowerCase().trim();

    // Handle common allergen synonyms
    final synonymMap = {
      'dairy': 'milk',
      'milk': 'milk',
      'egg': 'eggs',
      'eggs': 'eggs',
      'fish': 'fish',
      'shellfish': 'shellfish',
      'tree nuts': 'tree nut',
      'tree nut': 'tree nut',
      'nuts': 'tree nut',
      'nut': 'tree nut',
      'peanut': 'peanut',
      'peanuts': 'peanut',
      'soy': 'soy',
      'gluten': 'gluten',
      'wheat': 'gluten',
      'sesame': 'sesame',
      'coconut': 'coconut',
      'anchovy': 'fish',
      'fish sauce': 'fish',
    };

    return synonymMap[normalized] ?? normalized;
  }

  String _formatMenuContext(List<MenuItem> menuItems) {
    final buffer = StringBuffer('RESTAURANT MENU & ALLERGENS:\n');
    for (final item in menuItems) {
      final allergenInfo = item.allergens.isEmpty
          ? 'none (safe option)'
          : item.allergens.join(', ');
      final safetyIndicator = item.isSafe
          ? '✓ SAFE'
          : '⚠ CONTAINS USER ALLERGENS';
      buffer.writeln('• ${item.name} - ${item.description}');
      buffer.writeln('  Allergens: $allergenInfo ($safetyIndicator)');
    }
    return buffer.toString();
  }

  List<Map<String, String>> _buildConversationMessages({
    required String userInput,
    required SimulationStep currentStep,
    required PlayerProfile playerProfile,
    required String npcRole,
    required String scenarioContext,
    required ConversationContext context,
    required List<MenuItem> menuItems,
  }) {
    final systemPrompt = _buildEnhancedSystemPrompt(
      npcRole: npcRole,
      scenarioContext: scenarioContext,
      playerProfile: playerProfile,
      context: context,
      menuItems: menuItems,
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
      'max_tokens': 200,
      'temperature': 0.3,
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

  NPCDialogueResponse _parseOpenAIResponse(
    String openaiResponse,
    String userInput,
    PlayerProfile playerProfile,
    ConversationContext context,
    List<MenuItem> menuItems,
  ) {
    try {
      debugPrint('Raw OpenAI response: $openaiResponse');

      // Clean the response - remove any text before/after JSON
      String cleanedResponse = openaiResponse.trim();

      // Remove markdown code blocks if present
      cleanedResponse = cleanedResponse
          .replaceAll('```json', '')
          .replaceAll('```', '');

      // Find JSON boundaries
      int jsonStart = cleanedResponse.indexOf('{');
      int jsonEnd = cleanedResponse.lastIndexOf('}');

      if (jsonStart != -1 && jsonEnd != -1 && jsonEnd > jsonStart) {
        cleanedResponse = cleanedResponse.substring(jsonStart, jsonEnd + 1);
      }

      debugPrint('Cleaned response for parsing: $cleanedResponse');

      final jsonResponse = json.decode(cleanedResponse) as Map<String, dynamic>;

      // Extract and validate fields with fallbacks
      final npcDialogue =
          jsonResponse['npc_dialogue']?.toString() ??
          "I'm here to help you order safely. What can I get for you today?";

      final detectedAllergies = <String>[];
      if (jsonResponse['detected_allergies'] is List) {
        for (final allergy in jsonResponse['detected_allergies']) {
          if (allergy != null) {
            detectedAllergies.add(allergy.toString().toLowerCase());
          }
        }
      }

      // Update conversation context
      final updatedContext = _updateConversationContext(
        context,
        userInput,
        npcDialogue,
        detectedAllergies,
        playerProfile.allergies,
      );

      // Update the service's internal context
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
    } catch (e) {
      debugPrint('JSON parsing failed, attempting error recovery: $e');
      return _performErrorRecovery(
        openaiResponse,
        userInput,
        playerProfile,
        context,
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
          if (_normalizeAllergen(detected) == _normalizeAllergen(actual)) {
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

    // Check if user is placing a new order - if so, reset selection to find new dish
    final isNewOrder =
        lowerInput.contains('i\'ll have') ||
        lowerInput.contains('i will have') ||
        lowerInput.contains('i want') ||
        lowerInput.contains('i\'d like') ||
        lowerInput.contains('i choose') ||
        lowerInput.contains('i\'ll order') ||
        lowerInput.contains('i\'ll get');

    if (isNewOrder) {
      selectedDish = null; // Reset to find new dish
    }

    // Look for actual dish ordering - be very specific to avoid false positives
    for (final item in _generateMenuItems(actualAllergies)) {
      final dishName = item.name.toLowerCase();

      // Check for flexible dish name matching (handle variations)
      bool dishMentioned = false;

      // Direct match
      if (lowerInput.contains(dishName)) {
        dishMentioned = true;
      }

      // Check for common variations and keywords
      if (dishName.contains('thai green curry') &&
          (lowerInput.contains('thai curry') ||
              lowerInput.contains('green curry') ||
              lowerInput.contains('thai green curry'))) {
        dishMentioned = true;
      }

      if (dishName.contains('chicken satay') &&
          (lowerInput.contains('satay') ||
              lowerInput.contains('chicken satay') ||
              lowerInput.contains('chicken say') ||
              lowerInput.contains('say table') ||
              lowerInput.contains('say bowl') ||
              lowerInput.contains('chicken city') ||
              lowerInput.contains('chicken table'))) {
        dishMentioned = true;
      }

      if (dishName.contains('caesar salad') &&
          (lowerInput.contains('caesar') ||
              lowerInput.contains('caesar salad'))) {
        dishMentioned = true;
      }

      if (dishName.contains('fish') && lowerInput.contains('fish')) {
        dishMentioned = true;
      }

      if (dishName.contains('veggie') &&
          (lowerInput.contains('veggie') || lowerInput.contains('vegetable'))) {
        dishMentioned = true;
      }

      // Only set selectedDish if user is actually ordering, not just asking about ingredients or menu
      if (dishMentioned &&
          !_isJustAskingAboutDish(lowerInput) &&
          !_isJustAskingAboutMenu(lowerInput)) {
        if (lowerInput.contains('i\'ll take') ||
            lowerInput.contains('i\'ll have') ||
            lowerInput.contains('i will have') ||
            lowerInput.contains('i want') ||
            lowerInput.contains('i\'d like') ||
            lowerInput.contains('i would like') ||
            lowerInput.contains('i choose') ||
            lowerInput.contains('i\'ll order') ||
            lowerInput.contains('i\'ll get') ||
            lowerInput.contains('give me') ||
            lowerInput.contains('can i have') ||
            lowerInput.contains('can i get') ||
            lowerInput.contains('order') ||
            (lowerInput.contains('that one') && context.messages.isNotEmpty)) {
          selectedDish = item.name;
          break;
        }
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
      confirmedDish: selectedDish != null,
      turnCount: context.turnCount + 1,
      topicsCovered: newTopics,
    );

    // Debug logging for context updates
    debugPrint('🔄 [CONTEXT] Updated conversation context:');
    debugPrint('  - userInput: "$userInput"');
    debugPrint('  - allergiesDisclosed: ${updatedContext.allergiesDisclosed}');
    debugPrint('  - selectedDish: ${updatedContext.selectedDish}');
    debugPrint('  - confirmedDish: ${updatedContext.confirmedDish}');
    debugPrint('  - turnCount: ${updatedContext.turnCount}');
    debugPrint('  - disclosedAllergies: ${updatedContext.disclosedAllergies}');
    debugPrint(
      '  - isJustAskingAboutDish: ${_isJustAskingAboutDish(userInput.toLowerCase())}',
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
    final lowerDialogue = npcDialogue.toLowerCase();

    // CRITICAL FIX: Don't end conversation on safety warnings!
    // If the dialogue contains warnings or questions, continue the conversation
    final isWarningOrQuestion =
        lowerDialogue.contains('wouldn\'t be safe') ||
        lowerDialogue.contains('not safe') ||
        lowerDialogue.contains('contains') ||
        lowerDialogue.contains('allergic to') ||
        lowerDialogue.contains('would you like') ||
        lowerDialogue.contains('do you want') ||
        lowerDialogue.contains('consider') ||
        lowerDialogue.contains('different dish') ||
        lowerDialogue.contains('something else') ||
        lowerDialogue.contains('another option') ||
        lowerDialogue.contains('?');

    if (isWarningOrQuestion) {
      debugPrint(
        '🔄 [CONTINUE] AI dialogue contains warning/question - continuing conversation: "$npcDialogue"',
      );
      return false;
    }

    // Only end conversation if user has ordered a SAFE dish and AI is confirming it
    if (context.confirmedDish &&
        context.allergiesDisclosed &&
        context.selectedDish != null) {
      // Check if the selected dish is actually safe
      // This should be a more comprehensive check but for now we'll rely on positive confirmation phrases
      final positiveConfirmationPatterns = [
        'enjoy your meal',
        'enjoy your food',
        'enjoy your order',
        'coming right up',
        'your order is complete',
        'i\'ll get that started',
        'i\'ll put that order in',
        'your meal will be ready',
        'all set',
        'thank you for your order',
        'perfect choice',
        'great choice',
        'excellent choice',
      ];

      final hasPositiveConfirmation = positiveConfirmationPatterns.any(
        (pattern) => lowerDialogue.contains(pattern),
      );

      // Also check if it's a short, positive confirmatory response after safe ordering
      final isShortPositiveConfirmation =
          lowerDialogue.length < 100 &&
          (lowerDialogue.contains('perfect') ||
              lowerDialogue.contains('excellent') ||
              lowerDialogue.contains('wonderful')) &&
          !lowerDialogue.contains('?');

      if (hasPositiveConfirmation || isShortPositiveConfirmation) {
        debugPrint(
          '🔚 [END] AI dialogue indicates conversation should end with positive confirmation: "$npcDialogue"',
        );
        return true;
      }
    }

    return false;
  }

  NPCDialogueResponse _performErrorRecovery(
    String openaiResponse,
    String userInput,
    PlayerProfile playerProfile,
    ConversationContext context,
  ) {
    debugPrint('Starting error recovery for response: $openaiResponse');

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
        debugPrint('Extracted dialogue: $npcDialogue');
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

    debugPrint('Using dialogue: $npcDialogue');

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
      debugPrint('Realistic TTS speech started successfully');
    } catch (e) {
      debugPrint('Error with TTS: $e');
      onError?.call('Failed to play speech');
      onTTSCompleted?.call(); // Trigger completion on error
    }
  }

  Future<void> stopSpeaking() async {
    try {
      await _realisticTts.stopSpeaking();
    } catch (e) {
      debugPrint('Error stopping TTS: $e');
    }
  }

  bool get isListening => _isListening;
  ConversationContext get currentContext => _currentContext;

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
