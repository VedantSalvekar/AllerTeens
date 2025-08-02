import 'package:flutter/material.dart';
import '../../services/openai_dialogue_service.dart';
import '../../services/auth_service.dart';
import '../../services/assessment_engine.dart';
import '../../services/progress_tracking_service.dart';
import '../../models/game_state.dart';
import '../../models/simulation_step.dart';
import '../../models/training_assessment.dart';
import '../../models/scenario_config.dart';
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
        '✅ [AI_CONTROLLER] Loaded scenario: ${_scenarioConfig!.name} (${_scenarioConfig!.level.toString().split('.').last})',
      );

      // ✅ Load scenario-specific menu
      try {
        await MenuService.instance.loadMenuForScenario(_currentScenarioId!);
        print(
          '✅ [AI_CONTROLLER] Loaded menu for scenario: $_currentScenarioId',
        );
      } catch (e) {
        print(
          '❌ [AI_CONTROLLER] Failed to load menu for scenario $_currentScenarioId: $e',
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
    _addMessage(
      "Welcome! Let me know whenever you're ready to order.",
      role: 'assistant',
    );
    _setAnimation('greeting');
    Future.delayed(
      const Duration(milliseconds: 500),
      () => _speak("Welcome! Let me know whenever you're ready to order."),
    );
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

    // ✅ NEW: AI handles all analysis - no manual phrase detection needed
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

    // ✅ NEW: Use AI-analyzed context directly
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

    // Priority 1: AI explicitly indicates conversation should end
    if (aiResponse.shouldEndConversation) {
      shouldEnd = true;
      endReason = 'AI indicated conversation should end';
    }
    // Priority 2: User completed order AND indicates completion (regardless of allergy disclosure)
    else if (_context.selectedDish != null &&
        _context.confirmedDish &&
        userIndicatesCompletion &&
        !aiJustGaveSafetyWarning) {
      shouldEnd = true;
      endReason = 'User completed order and indicated satisfaction';
    }
    // Priority 3: Complete interaction - user ordered food AND disclosed allergies AND no safety warning AND not asking questions
    else if (_context.selectedDish != null &&
        _context.confirmedDish &&
        _context.allergiesDisclosed &&
        !aiJustGaveSafetyWarning &&
        !isJustAskingQuestions &&
        _turnCount >= 2) {
      shouldEnd = true;
      endReason =
          'Complete interaction: order placed and allergies disclosed safely';
    }
    // Priority 4: Realistic restaurant flow - natural conversation completion
    else if (_context.selectedDish != null &&
        _context.confirmedDish &&
        _turnCount >= 3 &&
        !isJustAskingQuestions &&
        !aiJustGaveSafetyWarning) {
      shouldEnd = true;
      endReason = 'Natural restaurant conversation completion';
    }
    // Priority 5: Reasonable conversation length (prevent infinite loops)
    else if (_turnCount >= 8) {
      shouldEnd = true;
      endReason = 'Maximum conversation length reached (${_turnCount} turns)';
    }

    debugPrint('🔍 [CONVERSATION] Checking end conditions:');
    debugPrint('  - turnCount: $_turnCount');
    debugPrint('  - allergiesDisclosed: ${_context.allergiesDisclosed}');
    debugPrint('  - selectedDish: ${_context.selectedDish}');
    debugPrint('  - confirmedDish: ${_context.confirmedDish}');
    debugPrint('  - userIndicatesCompletion: $userIndicatesCompletion');
    debugPrint('  - isJustAskingQuestions: $isJustAskingQuestions');
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

    final assessment = await _assessmentEngine.assessTrainingSession(
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
      scenarioConfig:
          _scenarioConfig, // ✅ Use loaded scenario config for level-aware assessment
    );

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
  void finishTrainingAndShowFeedback() {
    if (_assessment != null && onSessionCompleted != null) {
      onSessionCompleted!(_assessment!);
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
