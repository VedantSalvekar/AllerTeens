import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flame/game.dart';
import 'package:provider/provider.dart';
import '../../services/menu_service.dart';
import '../../services/assessment_engine.dart';
import '../../core/constants.dart';
import '../../models/training_assessment.dart';
import '../../models/game_state.dart';
import 'ai_conversation_controller.dart';
import 'interactive_waiter_game.dart';
import 'clean_feedback_screen.dart';

class IntegratedConversationScreen extends StatefulWidget {
  final String? scenarioId;

  const IntegratedConversationScreen({super.key, this.scenarioId});

  @override
  _IntegratedConversationScreenState createState() =>
      _IntegratedConversationScreenState();
}

class _IntegratedConversationScreenState
    extends State<IntegratedConversationScreen> {
  late AIConversationController _aiController;
  InteractiveWaiterGame? _game;
  bool _isGameInitialized = false;
  bool _isControllerInitialized = false;

  // Subtitle timing management
  bool _showSubtitles = false;
  String? _currentSubtitleText;

  @override
  void initState() {
    super.initState();
    _initializeController();

    // Set up the completion dialog callback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _aiController.onShowCompletionDialog = _showFinishTrainingDialog;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  Future<void> _initializeController() async {
    try {
      // Initialize AI controller with error handling
      _aiController = AIConversationController();
      _setupAIControllerCallbacks();

      // Initialize the controller asynchronously with scenario ID
      await _aiController.initialize(scenarioId: widget.scenarioId);

      setState(() {
        _isControllerInitialized = true;
      });

      // Create game and initialize after a short delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _initializeGame();
        }
      });
    } catch (e) {
      // Handle initialization errors (e.g., missing API keys)
      if (mounted) {
        _showErrorDialog(
          'Initialization Error',
          'Failed to initialize AI conversation system: $e',
        );
      }
    }
  }

  @override
  void dispose() {
    _aiController.dispose();
    super.dispose();
  }

  void _initializeGame() {
    _game = InteractiveWaiterGame();
    _aiController.initializeWithGame(_game!);

    setState(() {
      _isGameInitialized = true;
    });
  }

  String? _lastShownError;

  void _setupAIControllerCallbacks() {
    _aiController.onError = (error) {
      if (mounted && _lastShownError != error) {
        _lastShownError = error;
        Color backgroundColor = Colors.red;

        // Different colors and messages for different error types
        if (error.contains('No speech detected')) {
          backgroundColor = Colors.orange;
        } else if (error.contains('Speech timeout')) {
          backgroundColor = Colors.blue;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: backgroundColor,
            duration: Duration(seconds: 4),
          ),
        );

        // Clear the error after showing it to allow the same error to show again later if needed
        Future.delayed(Duration(seconds: 5), () {
          _lastShownError = null;
        });
      }
    };

    _aiController.onMessagesUpdate = (messages) {
      setState(() {});
    };

    _aiController.onTranscriptionUpdate = (text) {
      setState(() {});
    };

    _aiController.onListeningStateChange = (isListening) {
      // Hide subtitles when user starts speaking
      if (isListening && _showSubtitles) {
        setState(() {
          _showSubtitles = false;
          _currentSubtitleText = null;
        });
      }
      setState(() {});
    };

    _aiController.onProcessingStateChange = (isProcessing) {
      setState(() {});
    };

    _aiController.onSpeechEnabledChange = (enabled) {
      setState(() {});
    };

    // New subtitle callbacks - show/hide based on TTS state
    _aiController.onSubtitleShow = (text) {
      setState(() {
        _showSubtitles = true;
        _currentSubtitleText = text;
      });
    };

    _aiController.onSubtitleHide = () {
      setState(() {
        _showSubtitles = false;
        _currentSubtitleText = null;
      });
    };

    // Handle training session completion
    _aiController.onSessionCompleted = (assessment) {
      if (mounted) {
        _showFeedbackScreen(assessment);
      }
    };

    // Note: onConversationEnded callback removed - we now use onShowCompletionDialog for the proper flow
  }

  void _showFeedbackScreen(AssessmentResult assessment) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CleanFeedbackScreen(
          assessment: assessment,
          scenarioTitle: 'Restaurant Dining - Beginner',
          onRetry: () {
            Navigator.of(context).pop(); // Close feedback screen
            _restartTraining(); // Restart the current training
          },
          onBackToHome: () {
            Navigator.of(context).pop(); // Close feedback screen
            Navigator.of(context).pop(); // Close conversation screen
          },
        ),
      ),
    );
  }

  void _showEndConversationDialog() {
    final hasDisclosedAllergies =
        _aiController.conversationContext.allergiesDisclosed;
    final hasOrderedDish =
        _aiController.conversationContext.selectedDish != null;
    final isComplete = hasDisclosedAllergies && hasOrderedDish;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('End Conversation?'),
          content: Text(
            isComplete
                ? 'Great job! You\'ve completed the training successfully by mentioning your allergies and placing an order.'
                : 'Are you sure you want to end the conversation? You haven\'t completed all training goals:\n\n'
                      '${hasDisclosedAllergies ? "✓" : "✗"} Mentioned allergies\n'
                      '${hasOrderedDish ? "✓" : "✗"} Placed an order\n\n'
                      'Ending now will give you feedback on your current progress.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Continue Training'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                if (isComplete) {
                  // Normal completion flow
                  _aiController.endConversationManually();
                } else {
                  // Incomplete conversation - show assessment anyway
                  _endIncompleteConversation();
                }
              },
              child: Text(isComplete ? 'Get Feedback' : 'End Anyway'),
            ),
          ],
        );
      },
    );
  }

  void _endIncompleteConversation() async {
    try {
      // Generate assessment for incomplete conversation
      final user = await _aiController.authService.getCurrentUserModel();
      // Try to use enhanced assessment if scenario config is available
      AssessmentResult assessment;
      if (_aiController.scenarioConfig != null) {
        assessment = await AssessmentEngine.assessTrainingSessionEnhanced(
          conversationTurns: _aiController.conversationTurns,
          playerProfile: PlayerProfile(
            name: user?.name ?? 'User',
            age: 16,
            allergies: user?.allergies ?? [],
            preferredName: user?.name.split(' ').first ?? 'User',
          ),
          level: _aiController.scenarioConfig!.level,
          conversationContext: _aiController.conversationContext,
          scenarioId: _aiController.scenarioId,
          sessionStart: _aiController.sessionStartTime ?? DateTime.now(),
          sessionEnd: DateTime.now(),
        );
      } else {
        assessment = await _aiController.assessmentEngine.assessTrainingSession(
          conversationTurns: _aiController.conversationTurns,
          playerProfile: PlayerProfile(
            name: user?.name ?? 'User',
            age: 16,
            allergies: user?.allergies ?? [],
            preferredName: user?.name.split(' ').first ?? 'User',
          ),
          scenarioId: _aiController.scenarioId,
          sessionStart: _aiController.sessionStartTime ?? DateTime.now(),
          sessionEnd: DateTime.now(),
          conversationContext: _aiController.conversationContext,
        );
      }

      // Show feedback screen with incomplete conversation indicator
      _showFeedbackScreen(assessment);
    } catch (e) {
      // Fallback assessment for incomplete conversation
      final fallbackAssessment = AssessmentResult(
        allergyDisclosureScore:
            _aiController.conversationContext.allergiesDisclosed ? 8 : 2,
        clarityScore: 6,
        proactivenessScore: 4,
        ingredientInquiryScore: 3,
        riskAssessmentScore: 4,
        confidenceScore: 5,
        politenessScore: 7,
        completionBonus: 0, // No completion bonus for incomplete
        improvementBonus: 0,
        totalScore: 30,
        overallGrade: 'D',
        strengths: _aiController.conversationContext.allergiesDisclosed
            ? ['Mentioned allergies']
            : ['Participated in conversation'],
        improvements: [
          if (!_aiController.conversationContext.allergiesDisclosed)
            'Always mention your allergies when ordering food',
          if (_aiController.conversationContext.selectedDish == null)
            'Complete your order by choosing a dish',
          'Continue practicing to improve your skills',
        ],
        detailedFeedback:
            'This conversation was ended early. Keep practicing to improve your allergy communication skills!',
        assessedAt: DateTime.now(),
      );

      _showFeedbackScreen(fallbackAssessment);
    }
  }

  void _restartTraining() {
    // Restart the training session
    _aiController.dispose();
    _initializeController();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isPortrait = screenSize.height > screenSize.width;

    // Responsive sizing calculations
    final speechBubbleMaxWidth =
        screenSize.width *
        0.9; // Max bubble width: 60% of screen (reduced from 80%)
    final micButtonSize =
        screenSize.width * 0.18; // Microphone button: 18% of screen width
    final bottomPadding =
        screenSize.height * 0.12; // Bottom padding: 12% of screen height

    if (!_isControllerInitialized) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.primary, // Teal
                AppColors.primaryLight, // Lighter teal
                AppColors.background, // Light gray
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                const SizedBox(height: 16),
                Text(
                  'Initializing AI waiter...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: screenSize.width * 0.045,
                    fontWeight: FontWeight.w500,
                    shadows: [
                      Shadow(
                        offset: Offset(1, 1),
                        blurRadius: 3,
                        color: Colors.black45,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ChangeNotifierProvider<AIConversationController>.value(
      value: _aiController,
      child: Scaffold(
        body: Stack(
          children: [
            // 1. Full Screen Game (Restaurant + Waiter integrated)
            if (_isGameInitialized && _game != null)
              Positioned.fill(
                child: GameWidget<InteractiveWaiterGame>.controlled(
                  gameFactory: () => _game!,
                ),
              )
            else
              // Loading screen with app-themed background
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.primary, // Teal
                      AppColors.primaryLight, // Lighter teal
                      AppColors.background, // Light gray
                    ],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Preparing your AI waiter...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: screenSize.width * 0.045,
                          fontWeight: FontWeight.w500,
                          shadows: [
                            Shadow(
                              offset: Offset(1, 1),
                              blurRadius: 3,
                              color: Colors.black45,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // 2. Clean Subtitle Display (Only when waiter is speaking)
            if (_showSubtitles && _currentSubtitleText != null)
              Positioned(
                bottom: bottomPadding + 5, // Above microphone with spacing
                left: screenSize.width * 0.1, // 10% margin from sides
                right: screenSize.width * 0.1,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenSize.width * 0.04,
                    vertical: screenSize.width * 0.03,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    _currentSubtitleText!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: screenSize.width * 0.04,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ),
              ),

            // 3. User Speech Transcription (Above Microphone) - Same design as AI subtitle
            if (_aiController.userSpeechText.isNotEmpty)
              Positioned(
                bottom:
                    bottomPadding +
                    micButtonSize, // Higher above microphone to avoid overlap
                left: screenSize.width * 0.1, // 10% margin from sides
                right: screenSize.width * 0.1,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenSize.width * 0.04,
                    vertical: screenSize.width * 0.03,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryDark.withOpacity(
                      0.9,
                    ), // Slightly different color to distinguish user vs AI
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryDark.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    _aiController.userSpeechText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: screenSize.width * 0.04,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ),
              ),

            // 4. Microphone Button (Bottom Center)
            Positioned(
              bottom: bottomPadding * 0.3, // 30% of bottom padding from bottom
              left:
                  (screenSize.width - micButtonSize) / 2, // Center horizontally
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Main microphone button
                  Container(
                    width: micButtonSize,
                    height: micButtonSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: !_aiController.speechEnabled
                          ? AppColors.grey
                          : (_aiController.isListening
                                ? AppColors.error
                                : AppColors.primary),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(micButtonSize / 2),
                        onTap: _aiController.speechEnabled
                            ? _aiController.handleSpeechInput
                            : null,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _aiController.isListening
                                  ? Icons.mic_off
                                  : Icons.mic,
                              color: Colors.white,
                              size: micButtonSize * 0.35,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _aiController.isListening ? 'STOP' : 'SPEAK',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: screenSize.width * 0.025,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Send button (appears when user has spoken)
                  // if (_aiController.userSpeechText.isNotEmpty)
                  //   Padding(
                  //     padding: const EdgeInsets.only(top: 12),
                  //     child: Container(
                  //       width: micButtonSize * 0.7,
                  //       height: micButtonSize * 0.7,
                  //       decoration: BoxDecoration(
                  //         shape: BoxShape.circle,
                  //         color: AppColors.success,
                  //         boxShadow: [
                  //           BoxShadow(
                  //             color: Colors.black.withOpacity(0.2),
                  //             blurRadius: 10,
                  //             offset: const Offset(0, 3),
                  //           ),
                  //         ],
                  //       ),
                  //       child: Material(
                  //         color: Colors.transparent,
                  //         child: InkWell(
                  //           borderRadius: BorderRadius.circular(
                  //             micButtonSize * 0.35,
                  //           ),
                  //           onTap:
                  //               (_aiController.userSpeechText.isNotEmpty &&
                  //                   !_aiController.isProcessingAI)
                  //               ? () => _aiController.processUserInput(
                  //                   _aiController.userSpeechText,
                  //                 )
                  //               : null,
                  //           child: _aiController.isProcessingAI
                  //               ? Center(
                  //                   child: SizedBox(
                  //                     width: micButtonSize * 0.2,
                  //                     height: micButtonSize * 0.2,
                  //                     child: CircularProgressIndicator(
                  //                       strokeWidth: 2,
                  //                       valueColor:
                  //                           AlwaysStoppedAnimation<Color>(
                  //                             Colors.white,
                  //                           ),
                  //                     ),
                  //                   ),
                  //                 )
                  //               : Icon(
                  //                   Icons.send,
                  //                   color: Colors.white,
                  //                   size: micButtonSize * 0.25,
                  //                 ),
                  //         ),
                  //       ),
                  //     ),
                  //   ),
                  if (_aiController.userSpeechText.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        width: micButtonSize * 0.7,
                        height: micButtonSize * 0.7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.success,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(
                              micButtonSize * 0.35,
                            ),
                            // onTap:
                            //     (!_aiController.isProcessingAI &&
                            //         _aiController.userSpeechText
                            //             .trim()
                            //             .isNotEmpty)
                            //     ? () {
                            //         final input = _aiController.userSpeechText
                            //             .trim();
                            //         _aiController.processUserInput(input);
                            //       }
                            onTap:
                                (!_aiController.isProcessingAI &&
                                    _aiController.userSpeechText
                                        .trim()
                                        .isNotEmpty)
                                ? () async {
                                    final input = _aiController.userSpeechText
                                        .trim();
                                    await _aiController.processUserInput(input);
                                    setState(
                                      () {},
                                    ); // Optional: force UI refresh in case
                                  }
                                : null,

                            child: _aiController.isProcessingAI
                                ? Center(
                                    child: SizedBox(
                                      width: micButtonSize * 0.2,
                                      height: micButtonSize * 0.2,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    ),
                                  )
                                : Icon(
                                    Icons.send,
                                    color: Colors.white,
                                    size: micButtonSize * 0.25,
                                  ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // 5. Status Indicators (Top Overlays)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: screenSize.width * 0.03,
                  vertical: screenSize.height * 0.008,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getAnimationIcon(),
                      color: Colors.white,
                      size: screenSize.width * 0.04,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _getAnimationText(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: screenSize.width * 0.03,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 6. Control Buttons (Top Right)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 16,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Menu button
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: () => _showMenuDialog(),
                      icon: Icon(
                        Icons.restaurant_menu,
                        color: AppColors.primary,
                        size: screenSize.width * 0.06,
                      ),
                      tooltip: 'View Menu',
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Reset button
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: () => _showResetDialog(),
                      icon: Icon(
                        Icons.refresh,
                        color: AppColors.primary,
                        size: screenSize.width * 0.06,
                      ),
                      tooltip: 'Reset Conversation',
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Complete Training button
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: () => _showFinishTrainingDialog(),
                      icon: Icon(
                        Icons.check_circle,
                        color: Colors.white,
                        size: screenSize.width * 0.06,
                      ),
                      tooltip: 'Complete Training',
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Back button with changed icon
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: () => _showExitDialog(),
                      icon: Icon(
                        Icons.home,
                        color: AppColors.primary,
                        size: screenSize.width * 0.06,
                      ),
                      tooltip: 'Back to Home',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getAnimationIcon() {
    switch (_aiController.currentAnimationState) {
      case 'greeting':
        return Icons.waving_hand;
      case 'thinking':
        return Icons.psychology;
      case 'talking':
        return Icons.record_voice_over;
      case 'positive':
        return Icons.thumb_up;
      case 'negative':
        return Icons.info;
      default:
        return Icons.person;
    }
  }

  String _getAnimationText() {
    switch (_aiController.currentAnimationState) {
      case 'greeting':
        return 'Greeting';
      case 'thinking':
        return 'Thinking...';
      case 'talking':
        return 'Speaking';
      case 'positive':
        return 'Positive';
      case 'negative':
        return 'Corrective';
      default:
        return 'Waiting';
    }
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Reset Conversation?'),
          content: const Text(
            'This will clear your current conversation and start fresh with the AI waiter.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _aiController.resetConversation();
                _game?.resetGame();
              },
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );
  }

  void _showMenuDialog() async {
    try {
      // Load menu data based on current scenario
      final scenarioId =
          _aiController.currentScenarioId ?? 'restaurant_beginner';
      final menu = await MenuService.instance.loadMenuForScenario(scenarioId);

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.restaurant_menu, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${menu.restaurantName} Menu',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            constraints: const BoxConstraints(maxHeight: 400),
            child: SingleChildScrollView(child: _buildMenuContent(menu)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      // Show error if menu loading fails
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load menu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildMenuContent(RestaurantMenu menu) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: menu.menuSections.map((section) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                section.section.toUpperCase(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
            ...section.items.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item.name} - £${item.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.description,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                        height: 1.4,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Display allergens with color highlighting
                    if (item.allergens.isNotEmpty) ...[
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: item.allergens.map((allergen) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: Colors.orange.withOpacity(0.5),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              allergen,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.orange,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
            const SizedBox(height: 8),
          ],
        );
      }).toList(),
    );
  }

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Exit Interactive Training?'),
          content: const Text(
            'Are you sure you want to return to the home screen?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                _resetControllerState(); // Reset controller state
                Navigator.of(context).pop(); // Return to home
              },
              child: const Text('Exit'),
            ),
          ],
        );
      },
    );
  }

  void _resetControllerState() {
    // Properly reset all controller state when exiting
    _aiController.resetConversation();

    // Reset subtitles
    setState(() {
      _showSubtitles = false;
      _currentSubtitleText = null;
    });
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showFinishTrainingDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Training Complete!'),
          content: const Text(
            'Great job! You successfully completed your training. Would you like to finish and see your feedback?',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _aiController.finishTrainingAndShowFeedback();
              },
              child: const Text('Finish Training'),
            ),
          ],
        );
      },
    );
  }
}

// Custom painter for speech bubble tail
class SpeechBubbleTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(size.width * 0.5, size.height);
    path.lineTo(size.width * 0.3, 0);
    path.lineTo(size.width * 0.7, 0);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
