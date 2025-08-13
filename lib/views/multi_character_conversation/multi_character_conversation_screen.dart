import 'package:flutter/material.dart';
import '../../core/constants.dart';
import 'multi_character_ai_controller.dart';
import 'group_feedback_screen.dart';

class MultiCharacterConversationScreen extends StatefulWidget {
  final String dialogueFile;
  final String scenarioTitle;
  final String? scenarioType;

  const MultiCharacterConversationScreen({
    super.key,
    required this.dialogueFile,
    required this.scenarioTitle,
    this.scenarioType,
  });

  @override
  _MultiCharacterConversationScreenState createState() =>
      _MultiCharacterConversationScreenState();
}

class _MultiCharacterConversationScreenState
    extends State<MultiCharacterConversationScreen> {
  late MultiCharacterAIController _aiController;
  String _speakerNotice = '';

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  @override
  void dispose() {
    // Ensure all audio stops when leaving screen
    _aiController.dispose();
    super.dispose();
  }

  void _initializeController() {
    _aiController = MultiCharacterAIController(
      scenarioType: widget.scenarioType,
    );
    _setupCallbacks();
  }

  void _setupCallbacks() {
    _aiController.onError = (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    };

    _aiController.onTranscriptionUpdate = (text) {
      setState(() {});
    };

    _aiController.onListeningStateChange = (isListening) {
      setState(() {});
    };

    _aiController.onProcessingStateChange = (isProcessing) {
      setState(() {});
    };

    _aiController.onSpeechEnabledChange = (enabled) {
      setState(() {});
    };

    _aiController.onCharacterSpeak = (character, message) {
      // Visual feedback when character speaks
      setState(() {});
    };

    _aiController.onSpeakerNotice = (text) {
      setState(() {
        _speakerNotice = text;
      });
    };

    _aiController.onSpeakerFinished = () {
      setState(() {
        _speakerNotice = "";
      });
    };
  }

  Color _getSpeakerColor(String speaker) {
    switch (speaker) {
      case 'user':
        return AppColors.primary;
      case 'friend1':
        return Colors.purple;
      case 'friend2':
        return Colors.orange;
      case 'friend3':
        return Colors.green;
      default:
        return AppColors.textSecondary;
    }
  }

  String _getSpeakerName(String speaker) {
    switch (speaker) {
      case 'user':
        return 'You';
      case 'friend1':
        return 'Emma';
      case 'friend2':
        return 'Jake';
      case 'friend3':
        return 'Maya';
      default:
        return speaker;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.scenarioTitle,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Complete Training button in app bar
          IconButton(
            onPressed: () => _showFinishTrainingDialog(),
            icon: Icon(Icons.check_circle, color: Colors.white, size: 28),
            tooltip: 'Complete Training',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_speakerNotice.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _speakerNotice,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
          // Party scene header
          // Container(
          //   width: double.infinity,
          //   padding: const EdgeInsets.all(16),
          //   decoration: BoxDecoration(
          //     gradient: LinearGradient(
          //       begin: Alignment.topCenter,
          //       end: Alignment.bottomCenter,
          //       colors: [AppColors.primary, AppColors.primaryLight],
          //     ),
          //   ),
          //   child: Column(
          //     children: [
          //       const Icon(Icons.cake, size: 48, color: Colors.white),
          //       const SizedBox(height: 8),
          //       const Text(
          //         "Birthday Party",
          //         style: TextStyle(
          //           fontSize: 24,
          //           fontWeight: FontWeight.bold,
          //           color: Colors.white,
          //         ),
          //       ),
          //       //const SizedBox(height: 4),
          //       // Text(
          //       //   "Navigate peer pressure around food allergies",
          //       //   style: TextStyle(
          //       //     fontSize: 14,
          //       //     color: Colors.white.withOpacity(0.9),
          //       //   ),
          //       // ),
          //     ],
          //   ),
          // ),

          // Conversation display
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _aiController.messages.length,
              itemBuilder: (context, index) {
                final message = _aiController.messages[index];
                final isUser = message.speaker == 'user';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Speaker avatar
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _getSpeakerColor(message.speaker),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            _getSpeakerName(message.speaker)[0],
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Message bubble
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getSpeakerName(message.speaker),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _getSpeakerColor(message.speaker),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: isUser
                                    ? AppColors.primary.withOpacity(0.1)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Text(
                                message.content,
                                style: TextStyle(
                                  fontSize: 16,
                                  height: 1.4,
                                  color: isUser
                                      ? AppColors.primaryDark
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // User speech transcription
          if (_aiController.userSpeechText.isNotEmpty)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryDark.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primaryDark),
              ),
              child: Text(
                _aiController.userSpeechText,
                style: const TextStyle(
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                  color: AppColors.primaryDark,
                ),
              ),
            ),

          // Control panel
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Microphone button
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: !_aiController.speechEnabled
                          ? AppColors.grey
                          : (_aiController.isListening
                                ? AppColors.error
                                : AppColors.primary),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(28),
                        onTap: _aiController.speechEnabled
                            ? _aiController.handleSpeechInput
                            : null,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _aiController.isListening
                                  ? Icons.mic_off
                                  : Icons.mic,
                              color: Colors.white,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _aiController.isListening ? 'Stop' : 'Speak',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                // Send button
                if (_aiController.userSpeechText.trim().isNotEmpty)
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(28),
                        onTap:
                            (!_aiController.isProcessingAI &&
                                _aiController.userSpeechText.trim().isNotEmpty)
                            ? () => _aiController.processUserInput(
                                _aiController.userSpeechText.trim(),
                              )
                            : null,
                        child: _aiController.isProcessingAI
                            ? const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.send,
                                color: Colors.white,
                                size: 24,
                              ),
                      ),
                    ),
                  ),

                const SizedBox(width: 12),

                // Reset button
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(28),
                      onTap: () => _aiController.resetConversation(),
                      child: const Icon(
                        Icons.refresh,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Continue Training'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _finishTrainingAndShowFeedback();
              },
              child: const Text('Finish Training'),
            ),
          ],
        );
      },
    );
  }

  void _finishTrainingAndShowFeedback() {
    final outcome = _aiController.getTrainingOutcome();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupFeedbackScreen(
          scenarioTitle: widget.scenarioTitle,
          refusedUnsafeFood: outcome.refusedUnsafeFood,
          mentionedAllergy: outcome.mentionedAllergy,
          explainedSeverity: outcome.explainedSeverity,
          mentionedSevereSymptoms: outcome.mentionedSevereSymptoms,
          onRetry: () {
            Navigator.pop(context);
            _aiController.resetConversation();
          },
          onBackToHome: () {
            Navigator.popUntil(context, (route) => route.isFirst);
          },
        ),
      ),
    );
  }
}
