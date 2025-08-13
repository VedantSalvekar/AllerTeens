import 'package:flutter/material.dart';
import '../../services/openai_dialogue_service.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';

class MultiCharacterAIController extends ChangeNotifier {
  final OpenAIDialogueService _openaiService = OpenAIDialogueService();
  final AuthService _authService = AuthService();

  // Conversation state
  bool _isListening = false;
  bool _isProcessingAI = false;
  bool _speechEnabled = false;
  String _userSpeechText = '';

  // Multi-character state
  List<ConversationMessage> _messages = [];
  String _currentSpeaker =
      'friend1'; // Tracks which AI character should respond next

  // Conversation context tracking
  bool _allergyExplained = false;
  bool _severityExplained = false;
  bool _symptomsExplained = false;
  int _conversationStage =
      1; // 1: Initial pressure, 2: Explaining, 3: Understanding, 4: Supportive

  // Character definitions
  Map<String, CharacterProfile> _characters = {
    'friend1': CharacterProfile(
      name: 'Emma',
      voice: 'nova', // Updated to nova as specified
      personality:
          'Enthusiastic party-lover who wants everyone to have fun. Initially pushy about food but becomes very caring once she understands the severity. Quick to apologize and find alternatives.',
    ),
    'friend2': CharacterProfile(
      name: 'Jake',
      voice: 'shimmer', // Correct as specified
      personality:
          'Skeptical and logical, often dismissive of things he doesn\'t understand. Has misconceptions about allergies but is genuinely shocked when he learns the truth. Becomes protective once convinced.',
    ),
    'friend3': CharacterProfile(
      name: 'Maya',
      voice: 'fable', // Updated to fable as specified
      personality:
          'Curious and empathetic, asks thoughtful questions. Quick to learn and understand. Often becomes the mediator who helps educate others and finds solutions.',
    ),
  };

  // Callbacks
  Function(String)? onError;
  Function(String)? onTranscriptionUpdate;
  Function(bool)? onListeningStateChange;
  Function(bool)? onProcessingStateChange;
  Function(bool)? onSpeechEnabledChange;
  Function(String)? onSpeakerNotice;
  Function(String)? onAIResponse;
  Function(String, String)? onCharacterSpeak; // character, message
  VoidCallback? onSpeakerFinished;

  // Getters
  bool get isListening => _isListening;
  bool get isProcessingAI => _isProcessingAI;
  bool get speechEnabled => _speechEnabled;
  String get userSpeechText => _userSpeechText;
  List<ConversationMessage> get messages => _messages;
  String get currentSpeaker => _currentSpeaker;

  MultiCharacterAIController({String? scenarioType}) {
    _setupCallbacks();
    _loadScenarioCharacters(scenarioType);
    _initialize();
  }

  void _loadScenarioCharacters(String? scenarioType) {
    debugPrint('🎭 Loading characters for scenario: $scenarioType');

    if (scenarioType == 'dinner_with_friends') {
      _characters = {
        'friend1': CharacterProfile(
          name: 'Sam',
          voice: 'nova',
          personality:
              'Food enthusiast who loves trying new dishes. Gets excited about sharing meals and trying everything on the menu.',
        ),
        'friend2': CharacterProfile(
          name: 'Riley',
          voice: 'shimmer',
          personality:
              'Practical and budget-conscious. Often suggests sharing dishes to save money and tries to convince others to go along with group decisions.',
        ),
        'friend3': CharacterProfile(
          name: 'Alex',
          voice: 'fable',
          personality:
              'Social connector who wants everyone included. Quick to suggest alternatives and help find solutions that work for everyone.',
        ),
        'waiter': CharacterProfile(
          name: 'Server',
          voice: 'onyx',
          personality:
              'Professional restaurant server who understands allergies and food safety. Helpful in explaining ingredients and modifications.',
        ),
      };
      debugPrint('✅ Loaded dinner characters: ${_characters.keys.join(', ')}');
    } else {
      // Default birthday party characters
      _characters = {
        'friend1': CharacterProfile(
          name: 'Emma',
          voice: 'nova',
          personality:
              'Enthusiastic party-lover who gets excited about food and celebrations. Often the first to offer treats and encourage others to try new things.',
        ),
        'friend2': CharacterProfile(
          name: 'Jake',
          voice: 'shimmer',
          personality:
              'Skeptical and logical. Questions things but can be convinced with good reasons. Often dismissive of concerns initially.',
        ),
        'friend3': CharacterProfile(
          name: 'Maya',
          voice: 'fable',
          personality:
              'Curious and empathetic, asks thoughtful questions. Quick to learn and understand. Often becomes the mediator who helps educate others and finds solutions.',
        ),
      };
      debugPrint(
        '✅ Loaded birthday characters: ${_characters.keys.join(', ')}',
      );
    }
  }

  void _setupCallbacks() {
    // Exactly replicate the existing AI conversation controller callbacks
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

    _openaiService.onSpeechEnabledChange = (enabled) {
      _speechEnabled = enabled;
      onSpeechEnabledChange?.call(enabled);
      notifyListeners();
    };

    _openaiService.onError = (error) {
      onError?.call(error);
    };

    // TTS callbacks for proper speech handling
    _openaiService.onTTSStarted = () {
      // Character is speaking, stop listening if active
      if (_isListening) {
        _openaiService.stopListening();
      }
      notifyListeners();
    };

    _openaiService.onTTSCompleted = () {
      // Character finished speaking
      notifyListeners();
    };
  }

  Future<void> _initialize() async {
    try {
      await _openaiService.initializeServices();

      // Start with AI-to-AI conversation to set the scene
      await _startGroupConversation();
    } catch (e) {
      onError?.call('Failed to initialize AI service: $e');
    }
  }

  Future<void> _startGroupConversation() async {
    if (_characters.containsKey('waiter')) {
      // Dinner scenario - only 2 friends speak initially
      await _addAndSpeakMessage(
        'friend1',
        "This place looks amazing! I've been dying to try their satay chicken skewers.",
      );
      await _waitForAudioComplete();

      await _addAndSpeakMessage(
        'friend2',
        "Yeah! Let's all get that — we can share and it'll be cheaper too.",
      );
      await _waitForAudioComplete();
    } else {
      // Birthday party scenario - only 2 friends speak initially
      await _addAndSpeakMessage(
        'friend1',
        "Oh my god, this cake is insane — here, you have to try it!",
      );
      await _waitForAudioComplete();

      await _addAndSpeakMessage(
        'friend2',
        "Yeah, come on! Don't be the only one not eating cake!",
      );
      await _waitForAudioComplete();
    }
  }

  Future<void> _waitForAudioComplete() async {
    // Wait a moment for TTS to start
    await Future.delayed(const Duration(milliseconds: 500));

    // Wait for TTS to complete before starting next speaker
    while (_openaiService.isPlaying) {
      await Future.delayed(const Duration(milliseconds: 200));
    }

    // Additional pause between speakers for natural conversation flow
    await Future.delayed(const Duration(milliseconds: 1500));
  }

  Future<void> _addAndSpeakMessage(String speaker, String message) async {
    // Show speaker notice
    _showSpeakerNotice(speaker);
    await Future.delayed(const Duration(milliseconds: 800));

    _addMessage(speaker, message);
    await _speakCharacterMessage(speaker, message);

    // Ensure audio completes before returning
    await _waitForCurrentAudioComplete();
  }

  Future<void> _waitForCurrentAudioComplete() async {
    // Wait for current TTS to finish completely
    while (_openaiService.isPlaying) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  void _showSpeakerNotice(String speaker) {
    final character = _characters[speaker];
    if (character != null) {
      onSpeakerNotice?.call('${character.name} is speaking...');
    }
  }

  Future<void> handleSpeechInput() async {
    // Exactly replicate the existing AI conversation controller speech handling
    if (_isListening) {
      await _openaiService.stopListening();
    } else {
      _userSpeechText = '';
      onTranscriptionUpdate?.call('');
      await _openaiService.startListening();
    }
  }

  Future<void> processUserInput(String input) async {
    if (input.trim().isEmpty) return;

    _userSpeechText = '';
    onTranscriptionUpdate?.call('');
    _isProcessingAI = true;
    onProcessingStateChange?.call(true);
    notifyListeners();

    // Add user message
    _addMessage('user', input);

    try {
      // Get current user
      final user = await _authService.getCurrentUserModel();
      if (user == null) {
        onError?.call('User not found');
        return;
      }

      // Generate AI response from current character
      final response = await _generateCharacterResponse(input, user);

      if (response.isNotEmpty) {
        // Show notice before AI speaks and add natural pause
        _showSpeakerNotice(_currentSpeaker);
        await Future.delayed(const Duration(milliseconds: 600));

        _addMessage(_currentSpeaker, response);
        await _speakCharacterMessage(_currentSpeaker, response);
        await _waitForCurrentAudioComplete();

        // Advance to next character or determine next speaker based on conversation flow
        _determineNextSpeaker();
      }
    } catch (e) {
      onError?.call('Error processing input: $e');
    } finally {
      _isProcessingAI = false;
      onProcessingStateChange?.call(false);
      notifyListeners();
    }
  }

  Future<String> _generateCharacterResponse(
    String userInput,
    UserModel user,
  ) async {
    final character = _characters[_currentSpeaker]!;

    // Analyze user input for context tracking
    _updateConversationContext(userInput);

    // Build conversation history is handled in knownFacts section

    // Extract EXACTLY what user said to prevent memory loss and repetitive questions
    final List<String> userStatements = [];
    for (final msg in _messages) {
      if (msg.speaker == 'user') {
        userStatements.add('"${msg.content}"');
      }
    }

    // Build comprehensive fact list from actual user statements
    final List<String> knownFacts = [];
    if (userStatements.isNotEmpty) {
      knownFacts.add('WHAT USER ALREADY TOLD YOU:');
      knownFacts.addAll(userStatements.map((s) => '  $s'));
    }

    // Critical facts to prevent asking about things already explained
    final userText = userStatements.join(' ').toLowerCase();
    if (userText.contains('allergic') || userText.contains('allergy')) {
      knownFacts.add(
        '✓ KNOWN: User is allergic to peanuts (STOP asking about allergies)',
      );
    }
    if (userText.contains('severe') ||
        userText.contains('serious') ||
        userText.contains('attack')) {
      knownFacts.add(
        '✓ KNOWN: User said severe attacks happen (STOP asking what happens)',
      );
    }
    if (userText.contains('breathing') ||
        userText.contains('breath') ||
        userText.contains('stop') ||
        userText.contains('anaphylaxis')) {
      knownFacts.add(
        '✓ KNOWN: User said breathing stops/anaphylaxis (SYMPTOMS ALREADY EXPLAINED)',
      );
    }

    final knownFactsText = knownFacts.isEmpty
        ? 'User has not said anything yet.'
        : knownFacts.join('\n');

    // Intent recognition handled in knownFacts extraction above

    // Derive recent AI question usage to throttle questioning
    final recentAiContents = _messages
        .where((m) => m.speaker != 'user')
        .map((m) => m.content.trim())
        .toList();
    final recentQuestionsCount = recentAiContents.reversed
        .take(3)
        .where((c) => c.endsWith('?'))
        .length;

    // Get recent AI responses to avoid repetition
    final recentAiResponses = _messages
        .where((m) => m.speaker != 'user')
        .map((m) => m.content.toLowerCase())
        .take(3)
        .toList();

    // Dynamic prompt based on conversation analysis
    final systemPrompt =
        '''
You are ${character.name}, a realistic 16-year-old ${_characters.containsKey('waiter') ? 'at a restaurant' : 'at a birthday party'}.

$knownFactsText

ANTI-REPETITION RULES (CRITICAL):
- NEVER use these phrases you just said: ${recentAiResponses.join(', ')}
- NEVER repeat exact phrases - vary your dismissive language
- Pushiness variety: "just a little", "tiny piece", "small amount", "barely any", "don't be difficult", "stop being picky"
- Allergy dismissal variety: "pick off the nuts", "it's probably fine", "don't be dramatic", "allergies aren't that serious"
- Think about what they ACTUALLY said - but DISMISS their concerns until severe symptoms

CONVERSATION CONTEXT:
- This is turn ${_messages.length + 1}
- Stage ${_conversationStage}: ${_getStageDescription()}
- You must be pushy for minimum 3 turns unless severe symptoms mentioned
- User said: "$userInput"

RESPONSE STRATEGY:
${_getResponseStrategy(_currentSpeaker, userInput, _messages.length)}

Respond naturally as ${character.name} (1 sentence, different from previous):''';

    try {
      // Use existing OpenAI service but with character-specific prompt
      String response = await _openaiService.getSimpleAIResponse(
        userInput,
        systemPrompt: systemPrompt,
      );

      // Multiple layers of prevention for bad responses
      final trimmed = response.trim().toLowerCase();

      // Prevent asking about already explained things
      bool needsRedo = false;
      String redoReason = '';

      // Only prevent questions about things already explained - but stay PUSHY about allergies
      if (userText.contains('allergic') &&
          (trimmed.contains('allergic?') ||
              trimmed.contains('are you allergic'))) {
        needsRedo = true;
        redoReason =
            'User already said they are allergic. BE DISMISSIVE: "Allergies? Just pick off the nuts" or "It\'s probably fine" or "Don\'t be so dramatic"';
      } else if ((userText.contains('attack') ||
              userText.contains('breathing') ||
              userText.contains('severe')) &&
          (trimmed.contains('what happens') ||
              trimmed.contains('what would happen'))) {
        needsRedo = true;
        redoReason =
            'User already explained symptoms. If still early stages, be dismissive: "You\'re probably exaggerating" or "How bad can it be?"';
      } else if (_conversationStage <= 2 &&
          recentQuestionsCount > 0 &&
          trimmed.contains('?')) {
        needsRedo = true;
        redoReason =
            'Too many questions. Make dismissive statement: "Come on, just try it" or "Don\'t be difficult"';
      }

      if (needsRedo) {
        final fixPrompt =
            '''
$redoReason

Respond as ${character.name} with exactly one pushy sentence (no question mark):''';
        response = await _openaiService.getSimpleAIResponse(
          userInput,
          systemPrompt: fixPrompt,
        );
      }

      return response;
    } catch (e) {
      debugPrint('Error generating character response: $e');
      return _getFallbackResponse();
    }
  }

  String _getFallbackResponse() {
    // Provide realistic, stage-appropriate fallback responses
    if (_conversationStage >= 4) {
      // Supportive responses - only after severe symptoms mentioned
      switch (_currentSpeaker) {
        case 'friend1':
          return "Oh my god, I'm so sorry! I had no idea it was that serious.";
        case 'friend2':
          return "Holy crap, that's terrifying! I'm really sorry for pushing.";
        case 'friend3':
          return "That sounds really scary. What can we do to help?";
        default:
          return "I understand now. Your health is way more important.";
      }
    } else if (_conversationStage >= 3) {
      // Questioning responses - learning and concerned
      switch (_currentSpeaker) {
        case 'friend1':
          return "Wait, what actually happens if you eat it?";
        case 'friend2':
          return "Are you serious? Like, how dangerous is it?";
        case 'friend3':
          return "I didn't know allergies could be that serious...";
        default:
          return "I'm starting to understand this is serious.";
      }
    } else if (_conversationStage >= 2) {
      // Just learned about allergies but don't understand severity
      switch (_currentSpeaker) {
        case 'friend1':
          return "Allergies? Can't you just pick around it?";
        case 'friend2':
          return "How bad can allergies really be though?";
        case 'friend3':
          return "I don't really know much about allergies...";
        default:
          return "Is it really that serious?";
      }
    } else {
      // Normal curious friends - don't know about allergies yet
      switch (_currentSpeaker) {
        case 'friend1':
          return "Why not? What's wrong with it?";
        case 'friend2':
          return "Are you being picky or is there a reason?";
        case 'friend3':
          return "Oh, is everything okay? Why can't you have it?";
        default:
          return "What's the problem with it?";
      }
    }
  }

  void _updateConversationContext(String userInput) {
    final input = userInput.toLowerCase();

    // Track what user has explained - BE MORE STRICT about progression
    if (input.contains('allergic') ||
        input.contains('allergy') ||
        input.contains('peanut')) {
      _allergyExplained = true;
      // Stay in stage 1 initially - friends should still be pushy
    }

    // Only advance to stage 2 if user mentions these specific severity terms
    if (input.contains('severe') ||
        input.contains('serious') ||
        input.contains('dangerous') ||
        input.contains('life threatening') ||
        input.contains('really bad') ||
        input.contains('very bad')) {
      _severityExplained = true;
    }

    // Only advance to final stage if user mentions actual medical symptoms
    if (input.contains('stop breathing') ||
        input.contains('breathing could stop') ||
        input.contains('breathing stop') ||
        input.contains('breath stop') ||
        input.contains('can\'t breathe') ||
        input.contains('cant breathe') ||
        input.contains('throat close') ||
        input.contains('throat closing') ||
        input.contains('anaphylaxis') ||
        input.contains('difficulty breathing') ||
        input.contains('difficulty in breathing') ||
        input.contains('swollen') ||
        input.contains('hospital') ||
        input.contains('die') ||
        input.contains('emergency') ||
        input.contains('ambulance') ||
        input.contains('choking')) {
      _symptomsExplained = true;
      _severityExplained = true;
      print(
        '🔄 STAGE UPDATE: User mentioned severe symptoms, moving to Stage 4 (supportive)',
      );
    }

    // Special case: If user mentions EpiPen OR confirms they've used one after being asked
    if (input.contains('epipen') ||
        input.contains('epi pen') ||
        ((input.contains('yes') || input.contains('yeah')) &&
            _messages.any(
              (msg) => msg.content.toLowerCase().contains('epipen'),
            ))) {
      _symptomsExplained = true;
      _severityExplained = true;
      print(
        '🔄 STAGE UPDATE: User mentioned/confirmed EpiPen, moving to Stage 4 (supportive)',
      );
    }

    // Update conversation stage - MUCH MORE RESTRICTIVE progression
    if (_symptomsExplained) {
      _conversationStage = 4; // Only supportive after severe symptoms mentioned
    } else if (_severityExplained && _allergyExplained) {
      _conversationStage = 3; // Questioning/learning stage
    } else if (_allergyExplained) {
      _conversationStage = 2; // Still pushy but slightly aware
    }
    // Stage 1 = completely pushy and dismissive
  }

  String _getStageDescription() {
    switch (_conversationStage) {
      case 1:
        return "Initial pushiness - don't know about allergies";
      case 2:
        return "Know about allergy but think it's minor";
      case 3:
        return "Learning it's serious, asking questions";
      case 4:
        return "Supportive after severe symptoms explained";
      default:
        return "Unknown stage";
    }
  }

  String _getResponseStrategy(String speaker, String userInput, int turnCount) {
    final input = userInput.toLowerCase();
    final isBirthday = !_characters.containsKey('waiter');

    if (_conversationStage >= 4) {
      return "BE SUPPORTIVE: User explained severe symptoms. Show genuine concern and offer help.";
    }

    // FORCE PUSHINESS - be very dismissive about allergies until severe symptoms
    if (input.contains('cannot') || input.contains("can't")) {
      if (turnCount < 4) {
        return "FORCE THEM: They said they can't have it. Be pushy! Say things like 'Why not?', 'Just try it', 'Don't be picky', 'Come on!'. ${isBirthday ? 'It\'s a party, live a little!' : 'Everyone\'s sharing, don\'t be difficult!'}";
      } else {
        return "Still be persistent but ask WHY they can't have it.";
      }
    }

    if (input.contains('allergic') &&
        !input.contains('severe') &&
        !input.contains('breathing') &&
        !input.contains('attack')) {
      return "DISMISS THE ALLERGY COMPLETELY: Be very casual and dismissive! Say things like 'Allergies? Just pick off the nuts', 'It\'s probably fine', 'Allergies aren\'t that serious', 'Just avoid the obvious bits', '${isBirthday ? 'It\'s your birthday, live dangerously!' : 'The kitchen can handle it'}'. Keep pushing hard!";
    }

    if (input.contains('severe') || input.contains('attack')) {
      if (_conversationStage <= 2) {
        return "BE VERY DISMISSIVE: They said severe/attack but you think they're being dramatic. Say things like 'How bad can it really be?', 'You\'re probably exaggerating', 'Everyone says that', 'You\'re being dramatic', 'It can\'t be THAT bad'.";
      } else {
        return "Still somewhat skeptical but starting to ask: 'What actually happens?', 'Have you been to hospital?', but don't become fully supportive yet.";
      }
    }

    if (input.contains('breathing') || input.contains('difficulty')) {
      if (_conversationStage <= 3) {
        return "DISMISS BREATHING ISSUES: Say things like 'Breathing problems? That sounds extreme', 'Are you sure it\'s that bad?', 'Maybe you just panic', 'Lots of people think they can\'t breathe'.";
      } else {
        return "Now getting worried about breathing - this sounds serious.";
      }
    }

    if (input.contains('epipen') || input.contains('epi pen')) {
      if (_conversationStage <= 3) {
        return "DISMISS EPIPEN: Say things like 'EpiPen? That\'s a bit dramatic', 'Do you actually need that?', 'People carry those but never use them', 'Sounds like overkill'.";
      } else {
        return "EpiPen means this is really serious - show concern.";
      }
    }

    // Default - keep being very pushy
    return "KEEP PUSHING HARD: Be very persistent and dismissive! ${isBirthday ? 'Focus on party fun - everyone needs to participate!' : 'Focus on sharing food - don\'t let them ruin the group meal!'}. Don't give up!";
  }

  // Extract key outcomes for a simple feedback summary
  GroupTrainingOutcome getTrainingOutcome() {
    bool mentionedAllergy = false;
    bool refusedUnsafeFood = false;
    bool explainedSeverity = false;
    bool mentionedSevereSymptoms = false;

    for (final msg in _messages) {
      if (msg.speaker == 'user') {
        final text = msg.content.toLowerCase();
        if (text.contains('allergic') || text.contains('allergy')) {
          mentionedAllergy = true;
        }
        if (text.contains("i can't") ||
            text.contains("i cannot") ||
            text.contains('i wont') ||
            text.contains("i won't") ||
            text.contains('no thanks') ||
            text.contains('i will pass') ||
            text.contains('i’ll pass') ||
            text.contains('i will not') ||
            text.contains('i do not want') ||
            text.contains('i dont want') ||
            text.contains('i don\'t want') ||
            text.contains('i can\'t eat') ||
            text.contains('i cannot eat')) {
          refusedUnsafeFood = true;
        }
        if (text.contains('severe') ||
            text.contains('serious') ||
            text.contains('dangerous') ||
            text.contains('life threatening') ||
            text.contains('really bad') ||
            text.contains('very bad')) {
          explainedSeverity = true;
        }
        if (text.contains('stop breathing') ||
            text.contains("can't breathe") ||
            text.contains('cant breathe') ||
            text.contains('throat close') ||
            text.contains('throat closing') ||
            text.contains('anaphylaxis') ||
            text.contains('epi') ||
            text.contains('swollen') ||
            text.contains('hospital') ||
            text.contains('die') ||
            text.contains('emergency') ||
            text.contains('ambulance') ||
            text.contains('choking')) {
          mentionedSevereSymptoms = true;
        }
      }
    }

    return GroupTrainingOutcome(
      mentionedAllergy: mentionedAllergy,
      refusedUnsafeFood: refusedUnsafeFood,
      explainedSeverity: explainedSeverity,
      mentionedSevereSymptoms: mentionedSevereSymptoms,
    );
  }

  void _determineNextSpeaker() {
    // Smart speaker selection based on conversation stage and character roles
    if (_conversationStage >= 4) {
      // In supportive stage, rotate normally but focus on helpful responses
      _rotateToNextSpeaker();
    } else if (_conversationStage == 3) {
      // In understanding stage, let Maya (the learner) respond more often
      if (_currentSpeaker == 'friend1') {
        _currentSpeaker = 'friend3'; // Skip to Maya
      } else {
        _rotateToNextSpeaker();
      }
    } else {
      // Early stages: prioritize 2-push, 1-question rhythm to avoid over-questioning
      // If last few AI turns already contained a question, force a pushy statement next.
      final recentAi = _messages.reversed
          .where((m) => m.speaker != 'user')
          .take(3)
          .map((m) => m.content)
          .toList();
      final hasRecentQuestion = recentAi.any((c) => c.trim().endsWith('?'));

      if (hasRecentQuestion) {
        // Switch to a different friend to vary pressure and likely produce a statement
        _rotateToNextSpeaker();
      } else {
        // Keep up pressure with rotation as usual
        _rotateToNextSpeaker();
      }
    }
  }

  void _rotateToNextSpeaker() {
    switch (_currentSpeaker) {
      case 'friend1':
        _currentSpeaker = 'friend2';
        break;
      case 'friend2':
        _currentSpeaker = 'friend3';
        break;
      case 'friend3':
        _currentSpeaker = 'friend1';
        break;
    }
  }

  void _addMessage(String speaker, String message) {
    _messages.add(
      ConversationMessage(
        role: speaker == 'user' ? 'user' : 'assistant',
        content: message,
        timestamp: DateTime.now(),
        speaker: speaker,
      ),
    );
    notifyListeners();
  }

  Future<void> _speakCharacterMessage(String character, String message) async {
    final characterProfile = _characters[character];
    if (characterProfile == null) return;

    // Add a small delay before first TTS call to ensure proper initialization
    if (_messages.length <= 1) {
      await Future.delayed(const Duration(milliseconds: 300));
    }

    await _openaiService.speakWithNaturalVoice(
      message,
      voice: characterProfile.voice,
    );
    onCharacterSpeak?.call(character, message);

    // Notify UI that speaker has finished
    onSpeakerFinished?.call();
  }

  Future<void> resetConversation() async {
    _messages.clear();
    _currentSpeaker = 'friend1';
    _userSpeechText = '';

    // Reset conversation context tracking
    _allergyExplained = false;
    _severityExplained = false;
    _symptomsExplained = false;
    _conversationStage = 1;

    // Restart with natural group conversation
    await _startGroupConversation();

    notifyListeners();
  }

  @override
  void dispose() {
    // Stop any ongoing TTS
    _openaiService.stopSpeaking();
    // Stop any listening
    if (_isListening) {
      _openaiService.stopListening();
    }
    // Clean up any resources
    super.dispose();
  }
}

class CharacterProfile {
  final String name;
  final String voice;
  final String personality;

  CharacterProfile({
    required this.name,
    required this.voice,
    required this.personality,
  });
}

class ConversationMessage {
  final String role;
  final String content;
  final DateTime timestamp;
  final String speaker;

  ConversationMessage({
    required this.role,
    required this.content,
    required this.timestamp,
    required this.speaker,
  });
}

class GroupTrainingOutcome {
  final bool mentionedAllergy;
  final bool refusedUnsafeFood;
  final bool explainedSeverity;
  final bool mentionedSevereSymptoms;

  const GroupTrainingOutcome({
    required this.mentionedAllergy,
    required this.refusedUnsafeFood,
    required this.explainedSeverity,
    required this.mentionedSevereSymptoms,
  });
}
