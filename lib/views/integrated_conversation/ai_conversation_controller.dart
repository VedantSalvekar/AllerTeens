import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/openai_dialogue_service.dart';
import '../../services/auth_service.dart';
import '../../services/assessment_engine.dart';
import '../../services/progress_tracking_service.dart';
import '../../models/game_state.dart';
import '../../models/simulation_step.dart';
import '../../models/training_assessment.dart';
import 'interactive_waiter_game.dart';
import '../../services/prompt_builder.dart';
import '../../models/user_model.dart';

/// Redesigned controller for managing realistic restaurant AI interaction
class AIConversationController extends ChangeNotifier {
  final OpenAIDialogueService _openaiService = OpenAIDialogueService();
  final AuthService _authService = AuthService();
  final AssessmentEngine _assessmentEngine = AssessmentEngine();
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

  Future<void> initialize() async {
    try {
      await _openaiService.initializeServices();
      await _loadScenario();
      await _startSession();
    } catch (e) {
      onError?.call('Initialization failed: $e');
    }
  }

  Future<void> _loadScenario() async {
    final config = await rootBundle.loadString(
      'assets/data/scenarios/restaurant_beginner.json',
    );
    final map = jsonDecode(config) as Map<String, dynamic>;
    _scenarioStep = SimulationStep.fromJson(map);
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
      scenarioId: _scenarioStep?.id ?? '',
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

    // ✅ FIXED: Robust conversation ending logic
    bool shouldEnd = false;
    String endReason = '';

    // Priority 1: AI explicitly indicates conversation should end
    if (aiResponse.shouldEndConversation) {
      shouldEnd = true;
      endReason = 'AI indicated conversation should end';
    }
    // Priority 2: Natural restaurant flow - order placed and confirmed after reasonable turns
    else if (_context.selectedDish != null &&
        _context.confirmedDish &&
        _turnCount >= 2) {
      shouldEnd = true;
      endReason = 'Order placed and confirmed (realistic restaurant flow)';
    }
    // Priority 3: Complete interaction - user ordered food AND disclosed allergies in reasonable turns
    else if (_context.selectedDish != null &&
        _context.allergiesDisclosed &&
        _turnCount >= 2) {
      shouldEnd = true;
      endReason = 'Complete interaction: order placed and allergies disclosed';
    }
    // Priority 4: Reasonable conversation length (like real restaurant)
    else if (_turnCount >= 6) {
      shouldEnd = true;
      endReason = 'Natural conversation length reached (${_turnCount} turns)';
    }

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

    // Single completion message - only add to messages, don't duplicate
    String completionMessage =
        "All right, I'll place that order for you now. Your training session is complete.";
    _addMessage(completionMessage, role: 'assistant');

    // Set flag before speaking
    _speakingCompletionMessage = true;
    await _speak(completionMessage);
    // Note: _speakingCompletionMessage will be set to false in the TTS callback
  }

  // Call this from the UI when the user taps 'Finish Training' in the dialog
  void finishTrainingAndShowFeedback() {
    if (_assessment != null && onSessionCompleted != null) {
      onSessionCompleted!(_assessment!);
    }
  }

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
  DateTime? get sessionStartTime => _startTime;
  AssessmentResult? get completedAssessment => _assessment;
  List<ConversationTurn> get conversationTurns => _turns;
  void endConversationManually() => onShowCompletionDialog?.call();
}
