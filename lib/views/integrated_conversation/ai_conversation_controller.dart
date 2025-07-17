import 'package:flutter/material.dart';
import '../../services/openai_dialogue_service.dart';
import '../../services/auth_service.dart';
import '../../services/assessment_engine.dart';
import '../../services/progress_tracking_service.dart';
import '../../models/game_state.dart';
import '../../models/simulation_step.dart';
import '../../models/training_assessment.dart';
import 'interactive_waiter_game.dart';

/// Controller that manages the synchronization between AI conversation and waiter animations
class AIConversationController extends ChangeNotifier {
  final OpenAIDialogueService _openaiService;
  final AuthService _authService;
  final AssessmentEngine _assessmentEngine;
  final ProgressTrackingService _progressService;
  InteractiveWaiterGame? _game;

  // Conversation state
  bool _isListening = false;
  bool _isProcessingAI = false;
  bool _speechEnabled = false;
  String _userSpeechText = '';

  // Conversation context
  ConversationContext _conversationContext = const ConversationContext();
  List<ConversationMessage> _displayMessages = [];

  // Animation state tracking
  bool _isWaiterSpeaking = false;
  String _currentAnimationState = 'idle';
  bool _conversationEnded = false;
  bool _waitingForCompletionDialog = false;

  // Training session management
  TrainingSession? _currentSession;
  List<ConversationTurn> _conversationTurns = [];
  int _allergyMentionCount = 0;
  int _totalTurns = 0;
  bool _hasCompletedTraining = false;
  DateTime? _sessionStartTime;
  String _scenarioId = 'restaurant_beginner';
  AssessmentResult? _completedAssessment;

  // Callbacks for UI updates
  Function(String)? onError;
  Function(List<ConversationMessage>)? onMessagesUpdate;
  Function(String)? onTranscriptionUpdate;
  Function(bool)? onListeningStateChange;
  Function(bool)? onProcessingStateChange;
  Function(bool)? onSpeechEnabledChange;
  Function(String)? onSubtitleShow;
  Function()? onSubtitleHide;
  Function(AssessmentResult)? onSessionCompleted;
  Function()? onConversationEnded;

  AIConversationController()
    : _openaiService = OpenAIDialogueService(),
      _authService = AuthService(),
      _assessmentEngine = AssessmentEngine(),
      _progressService = ProgressTrackingService() {
    _setupOpenAICallbacks();
  }

  // Manual end conversation method
  void endConversationManually() {
    _conversationEnded = true;
    onConversationEnded?.call();
  }

  // Initialize the controller asynchronously
  Future<void> initialize() async {
    try {
      // Wait for services to initialize
      await _openaiService.initializeServices();

      // Start training session
      await _startTrainingSession();

      notifyListeners();
    } catch (e) {
      onError?.call('Failed to initialize AI controller: $e');
    }
  }

  // Start a new training session
  Future<void> _startTrainingSession() async {
    try {
      _sessionStartTime = DateTime.now();
      _conversationTurns.clear();
      _allergyMentionCount = 0;
      _totalTurns = 0;
      _hasCompletedTraining = false;

      final user = await _authService.getCurrentUserModel();
      if (user != null) {
        final sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
        _currentSession = TrainingSession(
          sessionId: sessionId,
          userId: user.id,
          scenarioId: _scenarioId,
          startTime: _sessionStartTime!,
          conversationTurns: [],
          status: SessionStatus.inProgress,
        );

        debugPrint('🎯 [TRAINING] Started new training session: $sessionId');
      }
    } catch (e) {
      debugPrint('❌ [TRAINING] Failed to start training session: $e');
    }
  }

  // Getters
  bool get isListening => _isListening;
  bool get isProcessingAI => _isProcessingAI;
  bool get speechEnabled => _speechEnabled;
  String get userSpeechText => _userSpeechText;
  ConversationContext get conversationContext => _conversationContext;
  List<ConversationMessage> get displayMessages => _displayMessages;
  bool get isWaiterSpeaking => _isWaiterSpeaking;
  String get currentAnimationState => _currentAnimationState;
  bool get conversationEnded => _conversationEnded;
  List<ConversationTurn> get conversationTurns => _conversationTurns;
  AuthService get authService => _authService;
  AssessmentEngine get assessmentEngine => _assessmentEngine;
  String get scenarioId => _scenarioId;
  DateTime? get sessionStartTime => _sessionStartTime;
  AssessmentResult? get completedAssessment => _completedAssessment;

  // Initialize the controller with the game instance
  void initializeWithGame(InteractiveWaiterGame game) {
    _game = game;
    _startConversation();
  }

  // Enhanced method to process user input with training assessment
  Future<void> processUserInputWithAssessment(String userInput) async {
    try {
      debugPrint('🎯 [TRAINING] Processing user input: $userInput');

      // Check if conversation has ended
      if (_conversationEnded) {
        debugPrint('🎯 [TRAINING] Conversation has ended, ignoring input');
        return;
      }

      // Immediately clear user speech text and stop listening to prevent overlaps
      _userSpeechText = '';
      onTranscriptionUpdate?.call('');
      await _openaiService.stopListening();

      _totalTurns++;
      _isProcessingAI = true;
      onProcessingStateChange?.call(true);

      // Set thinking animation while processing (only if not currently speaking)
      if (_isWaiterSpeaking) {
        debugPrint(
          '💭 [INPUT] User input received but waiter is speaking, stopping TTS first',
        );
        await _openaiService.stopSpeaking();
        _isWaiterSpeaking = false;
      }

      debugPrint('💭 [INPUT] User input received, setting thinking animation');
      _setWaiterAnimation('thinking');

      // Force UI update to clear speech bubble immediately
      notifyListeners();

      // Get current user profile
      final user = await _authService.getCurrentUserModel();
      if (user == null) {
        onError?.call('User not authenticated');
        return;
      }

      // Analyze user input for allergy mentions
      final mentionedAllergies = _analyzeAllergyMentions(
        userInput,
        user.allergies,
      );
      if (mentionedAllergies.isNotEmpty) {
        _allergyMentionCount++;
        debugPrint('✅ [TRAINING] Allergy mentioned: $mentionedAllergies');
      }

      // Create training context separately from user input
      final trainingContext = _createTrainingContext(
        user,
        _totalTurns,
        _allergyMentionCount,
      );

      // Get AI response with clean user input (temporarily revert to original working approach)
      final response = await _openaiService.getOpenAIResponse(
        userInput: userInput,
        currentStep: SimulationStep(
          id: 'training_step',
          backgroundImagePath:
              'assets/images/backgrounds/restaurant_interior.png',
          npcDialogue: 'Welcome to training',
          responseOptions: [],
          correctResponseIndex: 0,
          successFeedback: 'Good job',
          generalFailureFeedback: 'Try again',
          npcRole: 'waiter',
          scenarioContext: 'restaurant_training',
          enableAIDialogue: true,
        ),
        playerProfile: PlayerProfile(
          name: user.name,
          age: 16,
          allergies: user.allergies,
          preferredName: user.name.split(' ').first,
        ),
        npcRole: 'waiter',
        scenarioContext: 'restaurant_training',
        context: _conversationContext,
      );

      // Create conversation turn for assessment
      final conversationTurn = ConversationTurn(
        userInput: userInput,
        aiResponse: response.npcDialogue,
        detectedAllergies: mentionedAllergies,
        timestamp: DateTime.now(),
        assessment: TurnAssessment(
          allergyMentionScore: mentionedAllergies.isNotEmpty ? 10 : 0,
          clarityScore: userInput.length > 10 ? 8 : 5,
          proactivenessScore: _totalTurns <= 2 && mentionedAllergies.isNotEmpty
              ? 10
              : 0,
          mentionedAllergies: mentionedAllergies.isNotEmpty,
          askedQuestions: userInput.contains('?'),
          detectedSkills: mentionedAllergies.isNotEmpty
              ? ['Allergy Disclosure']
              : [],
        ),
        turnNumber: _totalTurns,
      );

      _conversationTurns.add(conversationTurn);

      // Update UI with conversation messages
      _updateConversationMessages(userInput, response.npcDialogue);

      // Check if training should end
      if (_shouldEndTraining(response)) {
        await _endTrainingSession();
        return; // Don't continue processing after training ends
      } else {
        // Continue conversation
        _conversationContext = response.updatedContext;
        _setWaiterAnimation(_determineAnimationType(response));
        await _speakNPCResponse(response.npcDialogue);
      }
    } catch (e) {
      debugPrint('❌ [TRAINING] Error processing user input: $e');
      onError?.call(
        'Sorry, I had trouble processing your message. Please try again.',
      );
      _setWaiterAnimation('idle');
    } finally {
      _isProcessingAI = false;
      onProcessingStateChange?.call(false);
      notifyListeners();
    }
  }

  // Analyze user input for allergy mentions
  List<String> _analyzeAllergyMentions(
    String userInput,
    List<String> userAllergies,
  ) {
    final mentionedAllergies = <String>[];
    final lowerInput = userInput.toLowerCase();

    for (final allergy in userAllergies) {
      if (lowerInput.contains(allergy.toLowerCase()) ||
          lowerInput.contains('${allergy.toLowerCase()}s') ||
          lowerInput.contains('allergic to $allergy')) {
        mentionedAllergies.add(allergy);
      }
    }

    // Also check for general allergy keywords
    if (lowerInput.contains('allergy') ||
        lowerInput.contains('allergic') ||
        lowerInput.contains('reaction')) {
      // Add detected allergy keywords
      mentionedAllergies.addAll(['allergy_mentioned']);
    }

    return mentionedAllergies;
  }

  // Create training context separately from user input
  String _createTrainingContext(
    dynamic user,
    int totalTurns,
    int allergyMentionCount,
  ) {
    // Add training context based on performance
    if (totalTurns >= 3 && allergyMentionCount == 0) {
      return '''[TRAINING CONTEXT: User has NOT mentioned their allergies (${user.allergies.join(', ')}) in $totalTurns turns. 
This is a BEGINNER training session. The AI waiter should:
- Give GENTLE but CLEAR negative feedback about not mentioning allergies
- Explain WHY allergy disclosure is important for safety
- Encourage the user to mention their allergies proactively
- Ask direct questions about allergies if needed
- Be supportive but emphasize the importance of food safety]''';
    } else if (totalTurns >= 2 && allergyMentionCount == 0) {
      return '''[TRAINING CONTEXT: User should mention their allergies (${user.allergies.join(', ')}) soon.
Gently prompt them to share any dietary restrictions or allergies.]''';
    } else if (allergyMentionCount > 0) {
      return '''[TRAINING CONTEXT: Great! User has mentioned allergies. 
Provide positive reinforcement and continue with helpful service.]''';
    }

    return '';
  }

  // Update conversation messages in UI
  void _updateConversationMessages(String userInput, String aiResponse) {
    final userMessage = ConversationMessage(
      role: 'user',
      content: userInput,
      timestamp: DateTime.now(),
    );

    final aiMessage = ConversationMessage(
      role: 'assistant',
      content: aiResponse,
      timestamp: DateTime.now(),
    );

    _displayMessages.addAll([userMessage, aiMessage]);
    onMessagesUpdate?.call(_displayMessages);
    notifyListeners();
  }

  // Check if training should end
  bool _shouldEndTraining(NPCDialogueResponse response) {
    // FIXED: Make training more user-friendly and realistic
    // End training if:
    // 1. User completed order AND indicates completion (regardless of allergy disclosure)
    // 2. User disclosed allergies AND completed SAFE order (ideal scenario)
    // 3. AI explicitly indicates conversation should end
    // 4. Training has gone on too long (> 8 turns to prevent infinite loops)

    final hasDisclosedAllergies = _conversationContext.allergiesDisclosed;
    final hasCompletedOrder =
        _conversationContext.confirmedDish &&
        _conversationContext.selectedDish != null;

    // CRITICAL FIX: Check if AI just gave a safety warning about the current order
    final aiJustGaveSafetyWarning =
        response.npcDialogue.toLowerCase().contains('wouldn\'t be safe') ||
        response.npcDialogue.toLowerCase().contains('not safe') ||
        response.npcDialogue.toLowerCase().contains('contains') &&
            response.npcDialogue.toLowerCase().contains('allergic to') ||
        response.npcDialogue.toLowerCase().contains(
          'would you like to choose a different',
        ) ||
        response.npcDialogue.toLowerCase().contains(
          'consider a different dish',
        );

    // Check if user has indicated they're done/satisfied
    final lastUserInput = _conversationTurns.isNotEmpty
        ? _conversationTurns.last.userInput.toLowerCase()
        : '';
    final userIndicatesCompletion =
        lastUserInput.contains('thank you') ||
        lastUserInput.contains('thanks') ||
        lastUserInput.contains('no questions') ||
        lastUserInput.contains('i\'m good') ||
        lastUserInput.contains('that\'s all') ||
        lastUserInput.contains('i don\'t need') ||
        lastUserInput.contains('nothing else');

    // Check if user is just asking questions (don't end training)
    final isJustAskingQuestions =
        lastUserInput.contains('what can i have') ||
        lastUserInput.contains('what can i eat') ||
        lastUserInput.contains('what\'s on the menu') ||
        lastUserInput.contains('what options') ||
        lastUserInput.contains('what\'s available') ||
        lastUserInput.contains('recommend') ||
        lastUserInput.contains('suggest') ||
        lastUserInput.contains('menu');

    // If AI explicitly indicates conversation should end
    final aiIndicatesEnd = response.shouldEndConversation;

    // Force end if too many turns to prevent infinite loops
    final tooManyTurns = _totalTurns > 8;

    // FIXED: Don't end training if AI just gave a safety warning - user needs to reorder
    // End training if:
    // - User completed order AND indicates completion (regardless of allergy disclosure)
    // - User disclosed allergies AND completed order AND no safety warning (ideal scenario)
    // - AI indicates end OR too many turns
    final shouldEnd =
        ((hasCompletedOrder && userIndicatesCompletion) ||
            (hasDisclosedAllergies &&
                hasCompletedOrder &&
                !aiJustGaveSafetyWarning) ||
            aiIndicatesEnd ||
            tooManyTurns) &&
        !isJustAskingQuestions;

    debugPrint('🔍 [TRAINING] Checking end conditions:');
    debugPrint('  - totalTurns: $_totalTurns');
    debugPrint('  - hasDisclosedAllergies: $hasDisclosedAllergies');
    debugPrint('  - hasCompletedOrder: $hasCompletedOrder');
    debugPrint('  - aiJustGaveSafetyWarning: $aiJustGaveSafetyWarning');
    debugPrint('  - userIndicatesCompletion: $userIndicatesCompletion');
    debugPrint('  - isJustAskingQuestions: $isJustAskingQuestions');
    debugPrint('  - aiIndicatesEnd: $aiIndicatesEnd');
    debugPrint('  - tooManyTurns: $tooManyTurns');
    debugPrint('  - shouldEnd: $shouldEnd');
    debugPrint('  - allergyMentionCount: $_allergyMentionCount');
    debugPrint('  - confirmedDish: ${_conversationContext.confirmedDish}');
    debugPrint('  - selectedDish: ${_conversationContext.selectedDish}');
    debugPrint('  - lastUserInput: "$lastUserInput"');

    return shouldEnd;
  }

  // End training session and show feedback
  Future<void> _endTrainingSession() async {
    try {
      debugPrint('🎯 [TRAINING] Ending training session');

      // Mark conversation as ended to prevent further input
      _conversationEnded = true;

      // Add a completion message and show dialog
      // CRITICAL FIX: Only confirm safe orders, not unsafe ones user was warned about
      final hasActualSafeOrder =
          _conversationContext.selectedDish != null &&
          _conversationContext.confirmedDish &&
          _conversationContext.allergiesDisclosed;

      // Check if the last conversation turn had the AI warning about safety
      final lastAIResponse = _conversationTurns.isNotEmpty
          ? _conversationTurns.last.aiResponse.toLowerCase()
          : '';
      final hadSafetyWarning =
          lastAIResponse.contains('wouldn\'t be safe') ||
          lastAIResponse.contains('not safe') ||
          lastAIResponse.contains('contains') ||
          lastAIResponse.contains('allergic to');

      String completionContent;
      if (hasActualSafeOrder && !hadSafetyWarning) {
        // User has a confirmed safe order
        completionContent =
            "Perfect! Your ${_conversationContext.selectedDish} is all set and will be prepared safely for your allergies. Your training session is now complete. Well done!";
      } else if (_conversationContext.allergiesDisclosed) {
        // User disclosed allergies but either no safe order or had safety warning
        completionContent =
            "Excellent work! You did a great job communicating about your allergies and staying safe by avoiding unsafe food. That's the most important part of dining safely. Your training session is now complete. Well done!";
      } else {
        // Fallback for incomplete training
        completionContent =
            "Training session complete! Remember: always tell your waiter about your food allergies to stay safe. Keep practicing!";
      }

      final completionMessage = ConversationMessage(
        role: 'assistant',
        content: completionContent,
        timestamp: DateTime.now(),
      );

      _displayMessages.add(completionMessage);
      onMessagesUpdate?.call(_displayMessages);

      // Speak the completion message and wait for it to finish
      await _speakNPCResponse(completionMessage.content);

      // Wait for TTS to complete before showing completion dialog
      // The completion dialog will be triggered by the TTS completion callback
      _waitingForCompletionDialog = true;
      debugPrint(
        '🎯 [TRAINING] Waiting for TTS to complete before showing completion dialog',
      );

      if (_currentSession == null) {
        debugPrint('❌ [TRAINING] No active session to end');
        return;
      }

      // Update session with final data
      final completedSession = TrainingSession(
        sessionId: _currentSession!.sessionId,
        userId: _currentSession!.userId,
        scenarioId: _currentSession!.scenarioId,
        startTime: _currentSession!.startTime,
        endTime: DateTime.now(),
        conversationTurns: _conversationTurns,
        status: SessionStatus.completed,
        durationMinutes: DateTime.now()
            .difference(_currentSession!.startTime)
            .inMinutes,
      );

      // Generate assessment
      final user = await _authService.getCurrentUserModel();
      final assessment = await _assessmentEngine.assessTrainingSession(
        conversationTurns: _conversationTurns,
        playerProfile: PlayerProfile(
          name: user?.name ?? 'User',
          age: 16,
          allergies: user?.allergies ?? [],
          preferredName: user?.name.split(' ').first ?? 'User',
        ),
        scenarioId: _currentSession!.scenarioId,
        sessionStart: _currentSession!.startTime,
        sessionEnd: DateTime.now(),
      );

      // Save session and update progress (with graceful error handling)
      try {
        await _progressService.saveTrainingSession(completedSession);
        await _progressService.updateUserProgress(
          userId: _currentSession!.userId,
          scenarioId: _currentSession!.scenarioId,
          assessment: assessment,
          session: completedSession,
        );
        debugPrint('✅ [TRAINING] Progress saved to cloud successfully');
      } catch (saveError) {
        debugPrint(
          '⚠️ [TRAINING] Could not save to cloud, but training completed: $saveError',
        );
        // Continue with feedback screen even if cloud save fails
      }

      // Store assessment for later use - don't show feedback screen yet
      _completedAssessment = assessment;
      _hasCompletedTraining = true;

      debugPrint('✅ [TRAINING] Training session completed successfully');
    } catch (e) {
      debugPrint('❌ [TRAINING] Error ending training session: $e');

      // Still try to show feedback screen with a fallback assessment
      if (onSessionCompleted != null) {
        final fallbackAssessment = AssessmentResult(
          allergyDisclosureScore: 8,
          clarityScore: 7,
          proactivenessScore: 6,
          ingredientInquiryScore: 5,
          riskAssessmentScore: 7,
          confidenceScore: 6,
          politenessScore: 8,
          completionBonus: 3,
          improvementBonus: 0,
          totalScore: 50,
          overallGrade: 'C',
          strengths: ['Completed the conversation'],
          improvements: ['Practice allergy disclosure', 'Ask more questions'],
          detailedFeedback:
              'Training completed! Keep practicing to improve your allergy communication skills.',
          assessedAt: DateTime.now(),
        );
        onSessionCompleted?.call(fallbackAssessment);
      } else {
        onError?.call(
          'Training completed but could not show detailed feedback',
        );
      }
    }
  }

  // Handle premature exit
  Future<void> handlePrematureExit() async {
    try {
      debugPrint('⚠️ [TRAINING] Handling premature exit');

      if (_currentSession != null) {
        final abandonedSession = TrainingSession(
          sessionId: _currentSession!.sessionId,
          userId: _currentSession!.userId,
          scenarioId: _currentSession!.scenarioId,
          startTime: _currentSession!.startTime,
          endTime: DateTime.now(),
          conversationTurns: _conversationTurns,
          status: SessionStatus.abandoned,
          durationMinutes: DateTime.now()
              .difference(_currentSession!.startTime)
              .inMinutes,
        );

        await _progressService.saveTrainingSession(abandonedSession);
        debugPrint('✅ [TRAINING] Premature exit handled');
      }
    } catch (e) {
      debugPrint('❌ [TRAINING] Error handling premature exit: $e');
    }
  }

  void _setupOpenAICallbacks() {
    _openaiService.onTranscriptionUpdate = (text) {
      _userSpeechText = text;
      onTranscriptionUpdate?.call(text);
      notifyListeners();
    };

    _openaiService.onListeningStateChange = (isListening) {
      _isListening = isListening;
      onListeningStateChange?.call(isListening);
      notifyListeners();
    };

    _openaiService.onError = (error) {
      onError?.call(error);
    };

    _openaiService.onSpeechEnabledChange = (enabled) {
      _speechEnabled = enabled;
      onSpeechEnabledChange?.call(enabled);
      notifyListeners();
    };

    _openaiService.onContextUpdate = (context) {
      _conversationContext = context;
      notifyListeners();
    };

    // TTS animation synchronization callbacks
    _openaiService.onTTSStarted = () {
      debugPrint(
        '🔊 [TTS] TTS STARTED - Current animation state: $_currentAnimationState',
      );
      debugPrint('🔊 [TTS] Starting talking animation directly');
      _isWaiterSpeaking = true;

      // Directly trigger talking animation through game, bypassing _setWaiterAnimation
      _currentAnimationState = 'talking';
      _game?.onAIStartSpeaking();

      // Show subtitles with the latest AI message
      final latestAI = _getLatestAIMessage();
      if (latestAI != null) {
        onSubtitleShow?.call(latestAI);
      }

      notifyListeners();
    };

    _openaiService.onTTSCompleted = () {
      debugPrint(
        '🔊 [TTS] TTS COMPLETED - Current animation state: $_currentAnimationState',
      );
      debugPrint('🔊 [TTS] Stopping talking animation');
      _isWaiterSpeaking = false;

      // Force the animation to idle state when TTS completes
      _currentAnimationState = 'idle'; // Direct assignment to bypass blocking
      _game?.onAIStopSpeaking();

      // Hide subtitles when TTS completes
      onSubtitleHide?.call();

      // Check if we should show the completion dialog now that TTS is done
      if (_waitingForCompletionDialog) {
        _waitingForCompletionDialog = false;
        debugPrint(
          '🎯 [TRAINING] TTS completed, showing completion dialog after delay',
        );

        // Add small delay to ensure audio is fully finished
        Future.delayed(const Duration(milliseconds: 300), () {
          onConversationEnded?.call();
        });
      }

      notifyListeners();
    };
  }

  void _startConversation() {
    // Reset conversation for new session
    _openaiService.resetConversation();

    // Add initial AI greeting
    final initialMessage = ConversationMessage(
      role: 'assistant',
      content:
          "Hello! I'm your AI waiter. Welcome to our restaurant! I'm here to help you order safely. What can I get started for you today?",
      timestamp: DateTime.now(),
    );

    _displayMessages = [initialMessage];
    onMessagesUpdate?.call(_displayMessages);

    // Start waiter greeting animation and then speak
    _setWaiterAnimation('greeting');

    Future.delayed(const Duration(milliseconds: 500), () {
      _speakNPCResponse(initialMessage.content);
    });
  }

  // Handle speech input
  Future<void> handleSpeechInput() async {
    if (_isListening) {
      await _openaiService.stopListening();
    } else {
      _userSpeechText = '';
      onTranscriptionUpdate?.call('');
      await _openaiService.startListening();
    }
  }

  // Process user speech and get AI response
  Future<void> processUserSpeech() async {
    if (_isProcessingAI || _userSpeechText.trim().isEmpty) return;

    final userInput = _userSpeechText;

    // Add user message to display immediately
    final userMessage = ConversationMessage(
      role: 'user',
      content: userInput,
      timestamp: DateTime.now(),
    );

    _isProcessingAI = true;
    _userSpeechText = '';
    _displayMessages = [..._displayMessages, userMessage];

    onProcessingStateChange?.call(true);
    onTranscriptionUpdate?.call('');
    onMessagesUpdate?.call(_displayMessages);
    notifyListeners();

    // Set waiter to thinking/processing animation
    _setWaiterAnimation('thinking');

    try {
      // Create mock simulation step for AI conversation
      final mockStep = SimulationStep(
        id: 'interactive_ai_conversation',
        backgroundImagePath: 'backgrounds/restaurant_interior.png',
        npcDialogue: '',
        responseOptions: [],
        correctResponseIndex: 0,
        successFeedback: 'Great conversation!',
        generalFailureFeedback: 'Keep practicing!',
        npcRole: 'Waiter',
        scenarioContext:
            'A busy restaurant where you need to order food safely with your allergies',
        enableAIDialogue: true,
      );

      // Create realistic player profile from authenticated user
      final authState = _authService.currentUser;
      final userModel = await _authService.getCurrentUserModel();
      final playerProfile = PlayerProfile(
        name: userModel?.name ?? 'User',
        preferredName: userModel?.name?.split(' ').first ?? 'User',
        age: 16,
        allergies: userModel?.allergies ?? [],
      );

      // Get AI response
      final aiResponse = await _openaiService.getOpenAIResponse(
        userInput: userInput,
        currentStep: mockStep,
        playerProfile: playerProfile,
        npcRole: 'Waiter',
        scenarioContext:
            'You are a friendly, professional waiter at a busy restaurant. Help this teenager practice communicating about their food allergies safely. Be encouraging when they communicate well, and gently guide them when they need improvement.',
        context: _conversationContext,
      );

      // Add AI response to display
      final aiMessage = ConversationMessage(
        role: 'assistant',
        content: aiResponse.npcDialogue,
        timestamp: DateTime.now(),
      );

      _displayMessages = [..._displayMessages, aiMessage];
      _conversationContext = aiResponse.updatedContext;

      onMessagesUpdate?.call(_displayMessages);
      notifyListeners();

      // Determine animation based on response sentiment (for feedback animations)
      final animationType = _determineAnimationType(aiResponse);

      // Only set non-talking animations here - talking will be handled by TTS events
      if (animationType != 'talking') {
        _setWaiterAnimation(animationType);
      }

      // Speak the AI response - TTS events will handle talking animation
      await _speakNPCResponse(aiResponse.npcDialogue);
    } catch (e) {
      debugPrint('Error processing user speech: $e');
      onError?.call('Sorry, I had trouble understanding. Please try again.');

      // Reset to idle animation on error
      _setWaiterAnimation('idle');
    } finally {
      _isProcessingAI = false;
      onProcessingStateChange?.call(false);
      notifyListeners();
    }
  }

  String _determineAnimationType(NPCDialogueResponse response) {
    final content = response.npcDialogue.toLowerCase();

    // Check for positive feedback indicators
    if (content.contains('great') ||
        content.contains('good') ||
        content.contains('excellent') ||
        content.contains('perfect') ||
        content.contains('well done') ||
        content.contains('nice')) {
      return 'positive';
    }

    // Check for negative/corrective feedback
    if (content.contains('remember') ||
        content.contains('important') ||
        content.contains('should') ||
        content.contains('need to') ||
        content.contains('don\'t forget')) {
      return 'negative';
    }

    // Default to talking animation
    return 'talking';
  }

  void _setWaiterAnimation(String animationType) {
    debugPrint(
      '🎭 [ANIMATION] Setting waiter animation to: $animationType (current: $_currentAnimationState)',
    );

    // Prevent overriding talking animation unless it's a stop command or another talking command
    if (_currentAnimationState == 'talking' &&
        animationType != 'talking' &&
        animationType != 'idle') {
      debugPrint(
        '🎭 [ANIMATION] Blocking animation change from talking to $animationType - waiter is currently speaking',
      );
      return;
    }

    // Skip direct 'talking' animation triggers - only allow through TTS callbacks
    if (animationType == 'talking') {
      debugPrint(
        '🎭 [ANIMATION] Skipping direct talking animation trigger - will be handled by TTS callback',
      );
      return;
    }

    _currentAnimationState = animationType;

    switch (animationType) {
      case 'greeting':
        debugPrint('🎭 [ANIMATION] Triggering greeting animation');
        _game?.onAIGreeting();
        break;
      case 'thinking':
        debugPrint('🎭 [ANIMATION] Triggering thinking animation');
        _game?.onAIThinking();
        break;
      case 'positive':
        debugPrint('🎭 [ANIMATION] Triggering positive feedback animation');
        _game?.onPositiveFeedback();
        break;
      case 'negative':
        debugPrint('🎭 [ANIMATION] Triggering negative feedback animation');
        _game?.onNegativeFeedback();
        break;
      default:
        debugPrint('🎭 [ANIMATION] Triggering stop speaking animation (idle)');
        _game?.onAIStopSpeaking();
        break;
    }

    notifyListeners();
  }

  Future<void> _speakNPCResponse(String text) async {
    try {
      debugPrint(
        '🗣️  [SPEAK] Starting to speak NPC response: "${text.substring(0, text.length > 50 ? 50 : text.length)}..."',
      );
      debugPrint(
        '🗣️  [SPEAK] Current animation state before speaking: $_currentAnimationState',
      );

      // Animation state is now handled by TTS callbacks
      // onTTSStarted will trigger talking animation
      // onTTSCompleted will trigger idle animation
      await _openaiService.speakNPCResponse(text);

      debugPrint('🗣️  [SPEAK] NPC response speech initiated successfully');
    } catch (e) {
      debugPrint('❌ [SPEAK] Error speaking NPC response: $e');
      // On error, make sure we reset to idle
      _isWaiterSpeaking = false;
      _setWaiterAnimation('idle');
      notifyListeners();
    }
  }

  // Reset conversation
  void resetConversation() {
    _displayMessages.clear();
    _conversationContext = const ConversationContext();
    _userSpeechText = '';
    _isProcessingAI = false;
    _isListening = false;
    _isWaiterSpeaking = false;
    _conversationEnded = false;
    _waitingForCompletionDialog = false;
    _completedAssessment = null;

    onMessagesUpdate?.call(_displayMessages);
    notifyListeners();

    _startConversation();
  }

  // Allow continuing conversation after it was marked as ended
  void continueConversation() {
    _conversationEnded = false;
    _waitingForCompletionDialog = false;
    notifyListeners();
  }

  // Stop all speech
  Future<void> stopSpeaking() async {
    debugPrint('🛑 [STOP] Stopping TTS and resetting animation');
    await _openaiService.stopSpeaking();

    // Manually trigger the completion callback since stopping doesn't trigger it
    _isWaiterSpeaking = false;

    // Force the animation to idle state when manually stopping
    _currentAnimationState = 'idle'; // Direct assignment to bypass blocking
    _game?.onAIStopSpeaking();

    notifyListeners();
  }

  String? _getLatestAIMessage() {
    if (_displayMessages.isEmpty) return null;

    // Find the most recent AI message
    for (int i = _displayMessages.length - 1; i >= 0; i--) {
      if (_displayMessages[i].role == 'assistant') {
        return _displayMessages[i].content;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _openaiService.dispose();
    super.dispose();
  }
}
