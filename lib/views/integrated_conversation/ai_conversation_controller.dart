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
      }
    } catch (e) {
      onError?.call('Failed to start training session');
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
      if (_conversationEnded) {
        return;
      }

      _userSpeechText = '';
      onTranscriptionUpdate?.call('');
      await _openaiService.stopListening();

      _totalTurns++;
      _isProcessingAI = true;
      onProcessingStateChange?.call(true);

      if (_isWaiterSpeaking) {
        await _openaiService.stopSpeaking();
        _isWaiterSpeaking = false;
      }

      _setWaiterAnimation('thinking');

      notifyListeners();

      final user = await _authService.getCurrentUserModel();
      if (user == null) {
        onError?.call('User not authenticated');
        return;
      }

      final mentionedAllergies = _analyzeAllergyMentions(
        userInput,
        user.allergies,
      );
      if (mentionedAllergies.isNotEmpty) {
        _allergyMentionCount++;
      }

      final trainingContext = _createTrainingContext(
        user,
        _totalTurns,
        _allergyMentionCount,
      );

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

      _updateConversationMessages(userInput, response.npcDialogue);

      if (_shouldEndTraining(response)) {
        await _endTrainingSession();
        return;
      } else {
        _conversationContext = response.updatedContext;
        _setWaiterAnimation(_determineAnimationType(response));
        await _speakNPCResponse(response.npcDialogue);
      }
    } catch (e) {
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

  List<String> _analyzeAllergyMentions(
    String userInput,
    List<String> userAllergies,
  ) {
    final mentionedAllergies = <String>[];
    final lowerInput = userInput.toLowerCase();

    final isDisclosingAllergies = _isActuallyDisclosingAllergies(
      lowerInput,
      userAllergies,
    );

    if (!isDisclosingAllergies) {
      return mentionedAllergies;
    }

    for (final allergy in userAllergies) {
      if (lowerInput.contains(allergy.toLowerCase()) ||
          lowerInput.contains('${allergy.toLowerCase()}s') ||
          lowerInput.contains('allergic to $allergy')) {
        mentionedAllergies.add(allergy);
      }
    }

    if (lowerInput.contains('allergy') ||
        lowerInput.contains('allergic') ||
        lowerInput.contains('reaction')) {
      mentionedAllergies.addAll(['allergy_mentioned']);
    }

    return mentionedAllergies;
  }

  bool _isActuallyDisclosingAllergies(
    String lowerInput,
    List<String> userAllergies,
  ) {
    final allergyDisclosurePatterns = [
      'i\'m allergic to',
      'i am allergic to',
      'i have allergies',
      'i have allergy',
      'i have an allergy',
      'my allergies are',
      'my allergy is',
      'i can\'t eat',
      'i cannot eat',
      'i\'m intolerant to',
      'i am intolerant to',
      'i have a sensitivity to',
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
      'i avoid',
      'i stay away from',
      'bad reaction to',
      'makes me sick',
      'doctor said',
      'doctor told me',
      'advised not to eat',
      'told not to eat',
      'not supposed to eat',
      'shouldn\'t eat',
      'mustn\'t eat',
      'restricted from',
      'forbidden from eating',
      'yes, i have',
      'yes i have',
      'yes, i\'m allergic',
      'yes i\'m allergic',
      'yes, i am allergic',
      'yes i am allergic',
    ];

    for (final pattern in allergyDisclosurePatterns) {
      if (lowerInput.contains(pattern)) {
        return true;
      }
    }

    final foodOrderingPatterns = [
      'i\'ll have',
      'i will have',
      'i want',
      'i\'d like',
      'i would like',
      'i\'ll take',
      'i will take',
      'i\'ll order',
      'i will order',
      'i\'ll get',
      'i will get',
      'give me',
      'can i have',
      'can i get',
      'order',
      'menu',
      'what do you have',
      'what can i have',
      'what options',
      'recommend',
      'suggest',
    ];

    for (final pattern in foodOrderingPatterns) {
      if (lowerInput.contains(pattern)) {
        return false;
      }
    }

    return false;
  }

  String _createTrainingContext(
    dynamic user,
    int totalTurns,
    int allergyMentionCount,
  ) {
    if (totalTurns >= 3 && allergyMentionCount == 0) {
      return '''[TRAINING CONTEXT: User has NOT mentioned any allergies in $totalTurns turns. 
This is a BEGINNER training session. The AI waiter should:
- Give GENTLE but CLEAR guidance about allergy disclosure
- Explain WHY allergy disclosure is important for safety
- Encourage the user to mention any allergies they might have
- Ask direct questions about allergies if needed
- Be supportive but emphasize the importance of food safety
- DO NOT assume what allergies the user has - only respond to what they tell you]''';
    } else if (totalTurns >= 2 && allergyMentionCount == 0) {
      return '''[TRAINING CONTEXT: User should mention any allergies they have soon.
Gently prompt them to share any dietary restrictions or allergies.
DO NOT assume what allergies they have - only respond to what they tell you.]''';
    } else if (allergyMentionCount > 0) {
      return '''[TRAINING CONTEXT: Great! User has mentioned allergies. 
Provide positive reinforcement and continue with helpful service.]''';
    }

    return '';
  }

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

  bool _shouldEndTraining(NPCDialogueResponse response) {
    final hasDisclosedAllergies = _conversationContext.allergiesDisclosed;
    final hasCompletedOrder =
        _conversationContext.confirmedDish &&
        _conversationContext.selectedDish != null;

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

    final isJustAskingQuestions =
        lastUserInput.contains('what can i have') ||
        lastUserInput.contains('what can i eat') ||
        lastUserInput.contains('what\'s on the menu') ||
        lastUserInput.contains('what options') ||
        lastUserInput.contains('what\'s available') ||
        lastUserInput.contains('recommend') ||
        lastUserInput.contains('suggest') ||
        lastUserInput.contains('menu');

    final aiIndicatesEnd = response.shouldEndConversation;
    final tooManyTurns = _totalTurns > 8;

    final shouldEnd =
        ((hasCompletedOrder && userIndicatesCompletion) ||
            (hasDisclosedAllergies &&
                hasCompletedOrder &&
                !aiJustGaveSafetyWarning) ||
            aiIndicatesEnd ||
            tooManyTurns) &&
        !isJustAskingQuestions;

    return shouldEnd;
  }

  Future<void> _endTrainingSession() async {
    try {
      _conversationEnded = true;

      final hasActualSafeOrder =
          _conversationContext.selectedDish != null &&
          _conversationContext.confirmedDish &&
          _conversationContext.allergiesDisclosed;

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
        completionContent =
            "Perfect! Your ${_conversationContext.selectedDish} is all set and will be prepared safely for your allergies. Your training session is now complete. Well done!";
      } else if (_conversationContext.allergiesDisclosed) {
        completionContent =
            "Excellent work! You did a great job communicating about your allergies and staying safe by avoiding unsafe food. That's the most important part of dining safely. Your training session is now complete. Well done!";
      } else {
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

      await _speakNPCResponse(completionMessage.content);

      _waitingForCompletionDialog = true;

      if (_currentSession == null) {
        return;
      }

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
        conversationContext: _conversationContext,
      );

      try {
        await _progressService.saveTrainingSession(completedSession);
        await _progressService.updateUserProgress(
          userId: _currentSession!.userId,
          scenarioId: _currentSession!.scenarioId,
          assessment: assessment,
          session: completedSession,
        );
      } catch (saveError) {
        // Continue with feedback screen even if cloud save fails
      }

      _completedAssessment = assessment;
      _hasCompletedTraining = true;
    } catch (e) {
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

  Future<void> handlePrematureExit() async {
    try {
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
      }
    } catch (e) {
      // Handle error silently
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

    _openaiService.onTTSStarted = () {
      _isWaiterSpeaking = true;
      _currentAnimationState = 'talking';
      _game?.onAIStartSpeaking();

      final latestAI = _getLatestAIMessage();
      if (latestAI != null) {
        onSubtitleShow?.call(latestAI);
      }

      notifyListeners();
    };

    _openaiService.onTTSCompleted = () {
      _isWaiterSpeaking = false;
      _currentAnimationState = 'idle';
      _game?.onAIStopSpeaking();

      onSubtitleHide?.call();

      if (_waitingForCompletionDialog) {
        _waitingForCompletionDialog = false;
        Future.delayed(const Duration(milliseconds: 300), () {
          onConversationEnded?.call();
        });
      }

      notifyListeners();
    };
  }

  void _startConversation() {
    _openaiService.resetConversation();

    final initialMessage = ConversationMessage(
      role: 'assistant',
      content:
          "Hello! I'm your AI waiter. Welcome to our restaurant! I'm here to help you order safely. What can I get started for you today?",
      timestamp: DateTime.now(),
    );

    _displayMessages = [initialMessage];
    onMessagesUpdate?.call(_displayMessages);

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

    _setWaiterAnimation('thinking');

    try {
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

      final authState = _authService.currentUser;
      final userModel = await _authService.getCurrentUserModel();
      final playerProfile = PlayerProfile(
        name: userModel?.name ?? 'User',
        preferredName: userModel?.name?.split(' ').first ?? 'User',
        age: 16,
        allergies: userModel?.allergies ?? [],
      );

      final aiResponse = await _openaiService.getOpenAIResponse(
        userInput: userInput,
        currentStep: mockStep,
        playerProfile: playerProfile,
        npcRole: 'Waiter',
        scenarioContext:
            'You are a friendly, professional waiter at a busy restaurant. Help this teenager practice communicating about their food allergies safely. Be encouraging when they communicate well, and gently guide them when they need improvement.',
        context: _conversationContext,
      );

      final aiMessage = ConversationMessage(
        role: 'assistant',
        content: aiResponse.npcDialogue,
        timestamp: DateTime.now(),
      );

      _displayMessages = [..._displayMessages, aiMessage];
      _conversationContext = aiResponse.updatedContext;

      onMessagesUpdate?.call(_displayMessages);
      notifyListeners();

      final animationType = _determineAnimationType(aiResponse);

      if (animationType != 'talking') {
        _setWaiterAnimation(animationType);
      }

      await _speakNPCResponse(aiResponse.npcDialogue);
    } catch (e) {
      onError?.call('Sorry, I had trouble understanding. Please try again.');
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
    if (_currentAnimationState == 'talking' &&
        animationType != 'talking' &&
        animationType != 'idle') {
      return;
    }

    if (animationType == 'talking') {
      return;
    }

    _currentAnimationState = animationType;

    switch (animationType) {
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
        break;
    }

    notifyListeners();
  }

  Future<void> _speakNPCResponse(String text) async {
    try {
      await _openaiService.speakNPCResponse(text);
    } catch (e) {
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

  Future<void> stopSpeaking() async {
    await _openaiService.stopSpeaking();

    _isWaiterSpeaking = false;
    _currentAnimationState = 'idle';
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
