import 'package:flutter/material.dart';
import '../../services/openai_dialogue_service.dart';
import '../../services/auth_service.dart';
import '../../services/assessment_engine.dart';
import '../../services/progress_tracking_service.dart';
import '../../models/game_state.dart';
import '../../models/simulation_step.dart';
import '../../models/training_assessment.dart';
import '../../models/scenario_config.dart';
import '../../models/scenario_models.dart';
import 'interactive_waiter_game.dart';
import '../../services/prompt_builder.dart';
import '../../services/scenario_loader.dart';
import '../../services/menu_service.dart';
import '../../models/user_model.dart';

/// Redesigned controller for managing realistic restaurant AI interaction
class AIConversationController extends ChangeNotifier {
  final OpenAIDialogueService _openaiService = OpenAIDialogueService();
  final AuthService _authService = AuthService();
  final AssessmentEngine _assessmentEngine = AssessmentEngine();
  final ScenarioLoader _scenarioLoader = ScenarioLoader.instance;
  final ProgressTrackingService _progressService = ProgressTrackingService();
  InteractiveWaiterGame? _game;

  // Conversation state
  bool _isListening = false;
  bool _isProcessingAI = false;
  bool _speechEnabled = false;
  bool _conversationEnded = false;
  // Note: Removed _waitingForCompletionDialog - now using onShowCompletionDialog approach

  String _userSpeechText = '';
  String _currentAnimationState = 'idle';
  bool _isWaiterSpeaking = false;

  ConversationContext _context = const ConversationContext();
  List<ConversationMessage> _messages = [];

  // Session info
  TrainingSession? _session;
  SimulationStep? _scenarioStep;
  ScenarioConfig? _scenarioConfig;
  String? _currentScenarioId;
  DateTime? _startTime;
  int _turnCount = 0;
  int _allergyMentions = 0;
  List<ConversationTurn> _turns = [];
  AssessmentResult? _assessment;

  // Callbacks
  Function(String)? onError;
  Function(List<ConversationMessage>)? onMessagesUpdate;
  Function(String)? onTranscriptionUpdate;
  Function(bool)? onListeningStateChange;
  Function(bool)? onProcessingStateChange;
  Function(bool)? onSpeechEnabledChange;
  Function(String)? onSubtitleShow;
  Function()? onSubtitleHide;
  Function(AssessmentResult)? onSessionCompleted;
  // Note: onConversationEnded removed - now using onShowCompletionDialog

  // Add a flag to track if we're speaking the completion message
  bool _speakingCompletionMessage = false;
  Function()? onShowCompletionDialog;

  AIConversationController() {
    _setupCallbacks();
  }

  Future<void> initialize({String? scenarioId}) async {
    try {
      _currentScenarioId = scenarioId ?? 'restaurant_beginner';
      await _openaiService.initializeServices();
      await _loadScenario();
      await _startSession();
    } catch (e) {
      onError?.call('Initialization failed: $e');
    }
  }

  /// Initialize with a specific scenario
  Future<void> initializeWithScenario(String scenarioId) async {
    _currentScenarioId = scenarioId;
    await initialize(scenarioId: scenarioId);
  }

  Future<void> _loadScenario() async {
    if (_currentScenarioId == null) {
      throw Exception('No scenario ID specified');
    }

    try {
      // Load the full scenario configuration
      _scenarioConfig = await _scenarioLoader.loadScenario(_currentScenarioId!);

      // Create a SimulationStep for backward compatibility
      _scenarioStep = SimulationStep(
        id: _scenarioConfig!.id,
        backgroundImagePath:
            _scenarioConfig!.backgroundImagePath ??
            'assets/images/backgrounds/restaurant_interior.png',
        npcDialogue: _scenarioConfig!.initialDialogue ?? 'Welcome!',
        responseOptions: [], // Not used in AI dialogue mode
        correctResponseIndex: 0,
        successFeedback: 'Great job!',
        generalFailureFeedback: 'Keep practicing!',
        npcRole: _scenarioConfig!.npcRole,
        scenarioContext: _scenarioConfig!.scenarioContext,
        enableAIDialogue: _scenarioConfig!.enableAIDialogue,
        initialPrompt: _scenarioConfig!.initialDialogue,
      );

      print(
        '[AI_CONTROLLER] Loaded scenario: ${_scenarioConfig!.name} (${_scenarioConfig!.level.toString().split('.').last})',
      );

      try {
        await MenuService.instance.loadMenuForScenario(_currentScenarioId!);
        print('[AI_CONTROLLER] Loaded menu for scenario: $_currentScenarioId');
      } catch (e) {
        print(
          '[AI_CONTROLLER] Failed to load menu for scenario $_currentScenarioId: $e',
        );
        // Fallback to default menu
        await MenuService.instance.loadMenu();
      }
    } catch (e) {
      throw Exception('Failed to load scenario $_currentScenarioId: $e');
    }
  }

  Future<void> _startSession() async {
    final user = await _authService.getCurrentUserModel();
    if (user == null) {
      onError?.call('User not found');
      return;
    }
    _startTime = DateTime.now();
    _session = TrainingSession(
      sessionId: 'session_${_startTime!.millisecondsSinceEpoch}',
      userId: user.id,
      scenarioId: _currentScenarioId ?? _scenarioStep?.id ?? '',
      startTime: _startTime!,
      conversationTurns: [],
      status: SessionStatus.inProgress,
    );
  }

  void initializeWithGame(InteractiveWaiterGame game) {
    _game = game;
    _startConversation();
  }

  void _startConversation() {
    _openaiService.resetConversation();

    // Use varied natural greetings based on difficulty level
    final greetings = _getVariedGreetings();
    final selectedGreeting =
        greetings[DateTime.now().millisecond % greetings.length];

    _addMessage(selectedGreeting, role: 'assistant');
    _setAnimation('greeting');
    Future.delayed(
      const Duration(milliseconds: 500),
      () => _speak(selectedGreeting),
    );
  }

  List<String> _getVariedGreetings() {
    // Get difficulty level from scenario config
    final level = _scenarioConfig?.level ?? DifficultyLevel.beginner;

    switch (level) {
      case DifficultyLevel.beginner:
        return [
          "Hello, are you ready to order?",
          "Hi there! Welcome!",
          "Hey, what can I get for you today?",
          "Welcome! How can I help you?",
        ];
      case DifficultyLevel.intermediate:
        return [
          "Hi, how are you today?",
          "Hello, what can I get started for you?",
          "Good evening, ready to order?",
          "Welcome! Have you had a chance to look at the menu?",
        ];
      case DifficultyLevel.advanced:
        return [
          "Hello, welcome! Have you had time to look at the menu?",
          "Hi, are you ready to order?",
          "Good evening, what can I get for you?",
          "Welcome! Ready when you are.",
        ];
      default:
        return [
          "Hello, are you ready to order?",
          "Hi there! Welcome!",
          "Welcome! How can I help you?",
        ];
    }
  }

  Future<void> processUserInput(String input) async {
    if (_conversationEnded || input.trim().isEmpty) return;

    _userSpeechText = '';
    onTranscriptionUpdate?.call('');
    _isProcessingAI = true;
    onProcessingStateChange?.call(true);
    notifyListeners();

    final user = await _authService.getCurrentUserModel();
    if (user == null || _scenarioStep == null) return;

    _turnCount++;

    final aiResponse = await _openaiService.getOpenAIResponse(
      userInput: input,
      currentStep: _scenarioStep!,
      playerProfile: PlayerProfile(
        name: user.name,
        preferredName: user.name.split(' ').first,
        age: 16,
        allergies: user.allergies,
      ),
      npcRole: _scenarioStep!.npcRole ?? 'waiter',
      scenarioContext: _scenarioStep!.scenarioContext ?? '',
      context: _context,
      systemPrompt: PromptBuilder.buildSystemPrompt(
        step: _scenarioStep!,
        profile: PlayerProfile(
          name: user.name,
          preferredName: user.name.split(' ').first,
          age: 16,
          allergies: user.allergies,
        ),
        totalTurns: _turnCount,
        allergyMentionCount: _allergyMentions,
      ),
      scenarioConfig: _scenarioConfig,
    );

    _context = aiResponse.updatedContext;

    // Update allergy mention count for prompt building
    if (_context.allergiesDisclosed && _allergyMentions == 0) {
      _allergyMentions = 1;
    }

    _turns.add(
      ConversationTurn(
        userInput: input,
        aiResponse: aiResponse.npcDialogue,
        turnNumber: _turnCount,
        detectedAllergies: aiResponse.detectedAllergies,
        assessment: TurnAssessment(
          allergyMentionScore: aiResponse.detectedAllergies.isNotEmpty ? 10 : 0,
          clarityScore: input.length > 10 ? 8 : 5,
          proactivenessScore:
              _turnCount <= 2 && aiResponse.detectedAllergies.isNotEmpty
              ? 10
              : 0,
          mentionedAllergies: aiResponse.detectedAllergies.isNotEmpty,
          askedQuestions: input.contains('?'),
          detectedSkills: aiResponse.detectedAllergies.isNotEmpty
              ? ['Allergy Disclosure']
              : [],
        ),
        timestamp: DateTime.now(),
      ),
    );

    _addMessage(input, role: 'user');

    // Check if conversation should end based on improved criteria
    bool shouldEnd = false;
    String endReason = '';

    // Check if user has indicated they're done/satisfied
    final lastUserInput = input.toLowerCase().trim();
    final userIndicatesCompletion =
        lastUserInput == 'no' ||
        lastUserInput == 'nope' ||
        (lastUserInput.contains('thank you') &&
            lastUserInput.length < 15) || // Only short thank you responses
        (lastUserInput.contains('thanks') &&
            lastUserInput.length < 15 &&
            !lastUserInput.contains('can')) || // Thanks without ordering
        lastUserInput.contains('no questions') ||
        lastUserInput.contains('i\'m good') ||
        lastUserInput.contains('that\'s all') ||
        lastUserInput.contains('i don\'t need') ||
        lastUserInput.contains('nothing else') ||
        lastUserInput == 'perfect' ||
        lastUserInput == 'great';

    // Check if user is confirming their order (after AI asks for confirmation)
    final isConfirmingOrder =
        lastUserInput == 'yes' ||
        lastUserInput == 'correct' ||
        lastUserInput == 'right' ||
        lastUserInput.contains('that\'s right') ||
        lastUserInput.contains('that\'s correct') ||
        lastUserInput.contains('that\'s grand') ||
        lastUserInput.contains('yes, that\'s') ||
        (lastUserInput.contains('yes') && lastUserInput.length < 10);

    // Check if user is asking for order repetition
    final isAskingForOrderRepeat =
        lastUserInput.contains('repeat my order') ||
        lastUserInput.contains('repeat the order') ||
        lastUserInput.contains('what did i order') ||
        lastUserInput.contains('can you repeat') ||
        (lastUserInput.contains('repeat') && lastUserInput.contains('order'));

    // Check if user is asking questions or seeking safety information (don't end training)
    final isJustAskingQuestions =
        lastUserInput.contains('what can i have') ||
        lastUserInput.contains('what can i eat') ||
        lastUserInput.contains('what\'s on the menu') ||
        lastUserInput.contains('what options') ||
        lastUserInput.contains('what\'s available') ||
        lastUserInput.contains('recommend') ||
        lastUserInput.contains('suggest') ||
        lastUserInput.contains('menu');

    // Enhanced: Check if user is asking safety-related questions
    final isAskingSafetyQuestions =
        lastUserInput.contains('cross') ||
        lastUserInput.contains('contamination') ||
        lastUserInput.contains('contact') ||
        lastUserInput.contains('check with') ||
        lastUserInput.contains('chef') ||
        lastUserInput.contains('kitchen') ||
        lastUserInput.contains('safe') ||
        lastUserInput.contains('allergen') ||
        lastUserInput.contains('ingredient') ||
        lastUserInput.contains('contain') ||
        lastUserInput.contains('preparation') ||
        lastUserInput.contains('prepared') ||
        lastUserInput.contains('cook') ||
        lastUserInput.contains('made with') ||
        lastUserInput.contains('oil') ||
        lastUserInput.contains('fryer') ||
        lastUserInput.contains('clean') ||
        lastUserInput.contains('separate') ||
        lastUserInput.contains('shared') ||
        lastUserInput.contains('equipment') ||
        lastUserInput.contains('sauce') ||
        lastUserInput.contains('dressing') ||
        lastUserInput.contains('seasoning') ||
        lastUserInput.contains('can you') ||
        lastUserInput.contains('could you') ||
        lastUserInput.contains('would you') ||
        lastUserInput.contains('are you able') ||
        input.contains('?'); // Any question should extend conversation

    // Enhanced: Check if user is expressing ongoing safety concerns
    final hasOngoingSafetyConcerns =
        lastUserInput.contains('really allergic') ||
        lastUserInput.contains('very allergic') ||
        lastUserInput.contains('severely allergic') ||
        lastUserInput.contains('serious') ||
        lastUserInput.contains('important') ||
        lastUserInput.contains('need to') ||
        lastUserInput.contains('have to') ||
        lastUserInput.contains('must') ||
        lastUserInput.contains('reaction') ||
        lastUserInput.contains('dangerous') ||
        lastUserInput.contains('worry') ||
        lastUserInput.contains('concerned') ||
        lastUserInput.contains('sure that') ||
        lastUserInput.contains('make sure') ||
        lastUserInput.contains('also') ||
        lastUserInput.contains('but') ||
        lastUserInput.contains('and') ||
        lastUserInput.contains('because');

    // Check if AI just gave a safety warning about the current order
    final aiJustGaveSafetyWarning =
        aiResponse.npcDialogue.toLowerCase().contains('wouldn\'t be safe') ||
        aiResponse.npcDialogue.toLowerCase().contains('not safe') ||
        aiResponse.npcDialogue.toLowerCase().contains('contains') &&
            aiResponse.npcDialogue.toLowerCase().contains('allergic to') ||
        aiResponse.npcDialogue.toLowerCase().contains(
          'would you like to choose a different',
        ) ||
        aiResponse.npcDialogue.toLowerCase().contains(
          'consider a different dish',
        );

    // Level-aware minimum turn requirements
    int minTurnsForLevel = 3;
    if (_scenarioConfig != null) {
      switch (_scenarioConfig!.level) {
        case DifficultyLevel.beginner:
          minTurnsForLevel = 3; // More interaction time for practice
          break;
        case DifficultyLevel.intermediate:
          minTurnsForLevel = 4; // More thorough discussion
          break;
        case DifficultyLevel.advanced:
          minTurnsForLevel =
              5; // Comprehensive safety conversation with challenges
          break;
      }
    }

    // Priority 1: AI explicitly indicates conversation should end
    if (aiResponse.shouldEndConversation) {
      shouldEnd = true;
      endReason = 'AI indicated conversation should end';
    }
    // Priority 2: User confirms their order (natural ending)
    else if (isConfirmingOrder &&
        _context.selectedDish != null &&
        _context.confirmedDish &&
        !isAskingSafetyQuestions &&
        !hasOngoingSafetyConcerns &&
        _turnCount >= minTurnsForLevel) {
      shouldEnd = true;
      endReason = 'User confirmed their order - natural ending';
    }
    // Priority 3: User explicitly indicates they want to end/are satisfied
    else if (userIndicatesCompletion &&
        !isAskingSafetyQuestions &&
        !hasOngoingSafetyConcerns &&
        _turnCount >= minTurnsForLevel) {
      shouldEnd = true;
      endReason = 'User explicitly indicated satisfaction';
    }
    // Priority 3: NEVER end if user is actively asking safety questions or expressing concerns
    else if (isAskingSafetyQuestions || hasOngoingSafetyConcerns) {
      shouldEnd = false;
      endReason = 'User still has safety questions or concerns';
    }
    // Priority 4: Natural completion - order complete, allergies handled, conversation feels concluded
    else if (_context.selectedDish != null &&
        _context.confirmedDish &&
        _context.allergiesDisclosed &&
        !aiJustGaveSafetyWarning &&
        !isJustAskingQuestions &&
        !isAskingSafetyQuestions &&
        !hasOngoingSafetyConcerns &&
        _turnCount >= minTurnsForLevel) {
      // Additional check: Make sure AI's last response feels conclusive
      final aiSoundsConclusive =
          aiResponse.npcDialogue.toLowerCase().contains('enjoy') ||
          aiResponse.npcDialogue.toLowerCase().contains('perfect') ||
          aiResponse.npcDialogue.toLowerCase().contains('all set') ||
          aiResponse.npcDialogue.toLowerCase().contains('thank you') ||
          aiResponse.npcDialogue.toLowerCase().contains('you\'re welcome') ||
          aiResponse.npcDialogue.toLowerCase().contains('sounds good') ||
          aiResponse.npcDialogue.toLowerCase().contains('great choice') ||
          aiResponse.npcDialogue.toLowerCase().contains('coming right up') ||
          aiResponse.npcDialogue.toLowerCase().contains('be right out');

      if (aiSoundsConclusive) {
        shouldEnd = true;
        endReason = 'Natural conversation conclusion with order completed';
      }
    }
    // Priority 5: Reasonable conversation length (prevent infinite loops)
    else if (_turnCount >= 10) {
      shouldEnd = true;
      endReason = 'Maximum conversation length reached (${_turnCount} turns)';
    }

    debugPrint('🔍 [CONVERSATION] Checking end conditions:');
    debugPrint('  - turnCount: $_turnCount (min required: $minTurnsForLevel)');
    debugPrint('  - allergiesDisclosed: ${_context.allergiesDisclosed}');
    debugPrint('  - selectedDish: ${_context.selectedDish}');
    debugPrint('  - confirmedDish: ${_context.confirmedDish}');
    debugPrint('  - userIndicatesCompletion: $userIndicatesCompletion');
    debugPrint('  - isConfirmingOrder: $isConfirmingOrder');
    debugPrint('  - isAskingForOrderRepeat: $isAskingForOrderRepeat');
    debugPrint('  - isJustAskingQuestions: $isJustAskingQuestions');
    debugPrint('  - isAskingSafetyQuestions: $isAskingSafetyQuestions');
    debugPrint('  - hasOngoingSafetyConcerns: $hasOngoingSafetyConcerns');
    debugPrint('  - aiJustGaveSafetyWarning: $aiJustGaveSafetyWarning');
    debugPrint('  - shouldEnd: $shouldEnd');
    debugPrint('  - endReason: $endReason');

    if (shouldEnd) {
      // Don't add or speak the regular AI response when ending - let _completeSession handle the final message
      debugPrint('[CONVERSATION END] Ending conversation: $endReason');
      debugPrint(
        '[CONVERSATION END] State: allergies=${_context.allergiesDisclosed}, dish=${_context.selectedDish}, confirmed=${_context.confirmedDish}, turns=${_turnCount}',
      );
      await _completeSession(user);
    } else {
      // Normal flow - add and speak the AI response
      _addMessage(aiResponse.npcDialogue, role: 'assistant');
      await _speak(aiResponse.npcDialogue);
      debugPrint(
        '[CONVERSATION CONTINUE] allergies=${_context.allergiesDisclosed}, dish=${_context.selectedDish}, confirmed=${_context.confirmedDish}, turns=${_turnCount}',
      );
    }

    _isProcessingAI = false;
    onProcessingStateChange?.call(false);
    notifyListeners();
  }

  Future<void> _completeSession(UserModel user) async {
    _conversationEnded = true;

    // Stop any current speech first
    await _openaiService.stopSpeaking();

    // Add and speak a proper completion message from the AI waiter
    final completionMessage = "Your training session is now complete.";
    _addMessage(completionMessage, role: 'assistant');
    await _speak(completionMessage);

    // Create the assessment and session data first
    final endTime = DateTime.now();
    final completedSession = TrainingSession(
      sessionId: _session!.sessionId,
      userId: _session!.userId,
      scenarioId: _session!.scenarioId,
      startTime: _session!.startTime,
      endTime: endTime,
      conversationTurns: _turns,
      finalAssessment: null,
      status: SessionStatus.completed,
      durationMinutes: endTime.difference(_startTime!).inMinutes,
    );

    // Try to use enhanced assessment if scenario config is available
    AssessmentResult assessment;
    if (_scenarioConfig != null) {
      debugPrint(
        '[CONTROLLER] Using enhanced assessment for level: ${_scenarioConfig!.level}',
      );
      assessment = await AssessmentEngine.assessTrainingSessionEnhanced(
        conversationTurns: _turns,
        playerProfile: PlayerProfile(
          name: user.name,
          preferredName: user.name.split(' ').first,
          age: 16,
          allergies: user.allergies,
        ),
        level: _scenarioConfig!.level,
        conversationContext: _context,
        scenarioId: _session!.scenarioId,
        sessionStart: _session!.startTime,
        sessionEnd: endTime,
      );
    } else {
      debugPrint('[CONTROLLER] Using legacy assessment - no scenario config');
      assessment = await _assessmentEngine.assessTrainingSession(
        conversationTurns: _turns,
        playerProfile: PlayerProfile(
          name: user.name,
          preferredName: user.name.split(' ').first,
          age: 16,
          allergies: user.allergies,
        ),
        scenarioId: _session!.scenarioId,
        sessionStart: _session!.startTime,
        sessionEnd: endTime,
        conversationContext: _context,
        scenarioConfig: _scenarioConfig,
      );
    }

    try {
      await _progressService.saveTrainingSession(completedSession);
      await _progressService.updateUserProgress(
        userId: user.id,
        scenarioId: _session!.scenarioId,
        assessment: assessment,
        session: completedSession,
      );
    } catch (_) {}

    _assessment = assessment;

    // Show completion dialog instead of immediately triggering feedback
    if (onShowCompletionDialog != null) {
      onShowCompletionDialog!();
    }
  }

  // Call this from the UI when the user taps 'Finish Training' in the dialog
  void finishTrainingAndShowFeedback() async {
    if (_assessment != null && onSessionCompleted != null) {
      onSessionCompleted!(_assessment!);
    } else {
      // Create assessment for manual completion if none exists
      try {
        final user = await _authService.getCurrentUserModel();
        if (user != null) {
          // Generate assessment for manual completion
          AssessmentResult assessment;
          if (_scenarioConfig != null) {
            assessment = await AssessmentEngine.assessTrainingSessionEnhanced(
              conversationTurns: _turns,
              playerProfile: PlayerProfile(
                name: user.name,
                preferredName: user.name.split(' ').first,
                age: 16,
                allergies: user.allergies,
              ),
              level: _scenarioConfig!.level,
              conversationContext: _context,
              scenarioId: _currentScenarioId ?? '',
              sessionStart: _startTime ?? DateTime.now(),
              sessionEnd: DateTime.now(),
            );
          } else {
            assessment = await _assessmentEngine.assessTrainingSession(
              conversationTurns: _turns,
              playerProfile: PlayerProfile(
                name: user.name,
                preferredName: user.name.split(' ').first,
                age: 16,
                allergies: user.allergies,
              ),
              scenarioId: _currentScenarioId ?? '',
              sessionStart: _startTime ?? DateTime.now(),
              sessionEnd: DateTime.now(),
              conversationContext: _context,
            );
          }

          _assessment = assessment;
          if (onSessionCompleted != null) {
            onSessionCompleted!(_assessment!);
          }
        }
      } catch (e) {
        debugPrint('Error creating manual completion assessment: $e');
        // Show fallback assessment
        final fallbackAssessment = AssessmentResult(
          allergyDisclosureScore: _context.allergiesDisclosed ? 8 : 4,
          clarityScore: 6,
          proactivenessScore: 5,
          ingredientInquiryScore: 4,
          riskAssessmentScore: 5,
          confidenceScore: 6,
          politenessScore: 7,
          completionBonus: 0,
          improvementBonus: 0,
          totalScore: 35,
          overallGrade: 'C',
          strengths: ['Participated in training'],
          improvements: ['Continue practicing to improve skills'],
          detailedFeedback:
              'Training completed manually. Keep practicing to improve your allergy communication skills!',
          assessedAt: DateTime.now(),
        );
        _assessment = fallbackAssessment;
        if (onSessionCompleted != null) {
          onSessionCompleted!(_assessment!);
        }
      }
    }
  }

  // Getter for scenario config
  ScenarioConfig? get scenarioConfig => _scenarioConfig;

  Future<void> _speak(String text) async {
    try {
      onSubtitleShow?.call(text); // 👈 SHOW SUBTITLES BEFORE SPEAKING
      await _openaiService.speakNPCResponse(text);
    } catch (_) {
      _isWaiterSpeaking = false;
      _setAnimation('idle');
    }
  }

  void _addMessage(String text, {required String role}) {
    final msg = ConversationMessage(
      role: role,
      content: text,
      timestamp: DateTime.now(),
    );
    _messages.add(msg);
    onMessagesUpdate?.call(_messages);
  }

  void _setAnimation(String anim) {
    _currentAnimationState = anim;
    switch (anim) {
      case 'greeting':
        _game?.onAIGreeting();
        break;
      case 'thinking':
        _game?.onAIThinking();
        break;
      case 'positive':
        _game?.onPositiveFeedback();
        break;
      case 'negative':
        _game?.onNegativeFeedback();
        break;
      default:
        _game?.onAIStopSpeaking();
    }
    notifyListeners();
  }

  void _setupCallbacks() {
    _openaiService.onTranscriptionUpdate = (t) {
      _userSpeechText = t;
      onTranscriptionUpdate?.call(t);
    };
    _openaiService.onListeningStateChange = (v) {
      _isListening = !_conversationEnded && v;
      onListeningStateChange?.call(_isListening);
    };
    _openaiService.onSpeechEnabledChange = (v) {
      _speechEnabled = v;
      onSpeechEnabledChange?.call(v);
    };
    _openaiService.onTTSStarted = () {
      _isWaiterSpeaking = true;
      _game?.onAIStartSpeaking(); // Switch to talking spritesheet
      _currentAnimationState = 'talking';
      notifyListeners();
    };
    _openaiService.onTTSCompleted = () {
      _isWaiterSpeaking = false;
      _game?.onAIStopSpeaking(); // Switch back to idle spritesheet
      _currentAnimationState = 'idle';
      onSubtitleHide?.call();

      // If we just finished the completion message, show the dialog
      if (_speakingCompletionMessage) {
        _speakingCompletionMessage = false;
        if (onShowCompletionDialog != null) {
          Future.delayed(const Duration(milliseconds: 200), () {
            onShowCompletionDialog!();
          });
        }
      }

      // Note: Removed _waitingForCompletionDialog logic - now using onShowCompletionDialog
      notifyListeners();
    };
    _openaiService.onError = (err) => onError?.call(err);
  }

  Future<void> handleSpeechInput() async {
    if (_conversationEnded) return;
    if (_isListening) {
      await _openaiService.stopListening();
    } else {
      _userSpeechText = '';
      await _openaiService.startListening();
    }
  }

  void resetConversation() {
    _messages.clear();
    _context = const ConversationContext();
    _turnCount = 0;
    _allergyMentions = 0;
    _isProcessingAI = false;
    _isListening = false;
    _isWaiterSpeaking = false;
    _conversationEnded = false;
    _assessment = null;
    onMessagesUpdate?.call(_messages);
    _startConversation();
  }

  @override
  void dispose() {
    _openaiService.dispose();
    super.dispose();
  }

  // Exposed for external needs
  bool get isListening => _isListening;
  bool get isProcessingAI => _isProcessingAI;
  bool get speechEnabled => _speechEnabled;
  String get userSpeechText => _userSpeechText;
  String get currentAnimationState => _currentAnimationState;
  ConversationContext get conversationContext => _context;
  List<ConversationMessage> get displayMessages => _messages;
  AssessmentEngine get assessmentEngine => _assessmentEngine;
  AuthService get authService => _authService;
  String get scenarioId => _scenarioStep?.id ?? '';
  String? get currentScenarioId => _currentScenarioId;
  DateTime? get sessionStartTime => _startTime;
  AssessmentResult? get completedAssessment => _assessment;
  List<ConversationTurn> get conversationTurns => _turns;
  void endConversationManually() => onShowCompletionDialog?.call();
}
