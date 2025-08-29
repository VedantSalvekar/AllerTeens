import 'package:flutter/foundation.dart';

/// Enhanced conversation flow manager for multi-character AI interactions
/// Handles natural conversation patterns where AI characters talk among themselves
class EnhancedConversationFlow {
  static const Duration _defaultPauseBetweenSpeakers = Duration(seconds: 2);
  static const Duration _shortPause = Duration(seconds: 1);

  /// Determines if AI characters should have a side conversation
  static bool shouldTriggerAIToAIConversation({
    required String userInput,
    required int conversationStage,
    required int totalMessages,
    required bool allergyExplained,
    required bool severityExplained,
  }) {
    final input = userInput.toLowerCase();

    // Trigger AI-to-AI in these scenarios:
    return (
    // First time mentioning allergies
    (input.contains('allergic') && !allergyExplained) ||
        // When user explains severity but friends are still skeptical
        (severityExplained && conversationStage < 3) ||
        // Random chance for natural conversation flow
        (totalMessages > 3 && totalMessages % 4 == 0) ||
        // When user mentions specific severe symptoms
        (input.contains('anaphylaxis') || input.contains('epipen')));
  }

  /// Gets the pause duration between speakers based on conversation context
  static Duration getPauseDuration({
    required String lastMessage,
    required int conversationStage,
    required bool isEmergencyTopic,
  }) {
    if (isEmergencyTopic || conversationStage >= 4) {
      return _shortPause; // Faster responses when serious
    }

    if (lastMessage.length > 50) {
      return Duration(seconds: 3); // Longer pause for longer messages
    }

    return _defaultPauseBetweenSpeakers;
  }

  /// Determines conversation flow patterns for different scenarios
  static List<String> getConversationPattern({
    required String scenarioType,
    required int conversationStage,
  }) {
    if (scenarioType == 'dinner_with_friends') {
      return _getDinnerConversationPattern(conversationStage);
    } else {
      return _getBirthdayConversationPattern(conversationStage);
    }
  }

  static List<String> _getDinnerConversationPattern(int stage) {
    switch (stage) {
      case 1: // Initial ordering pressure
        return ['friend1', 'friend2', 'friend3', 'user_expected'];
      case 2: // Pushing for shared dishes
        return ['friend2', 'friend1', 'user_expected'];
      case 3: // Understanding concerns
        return ['friend3', 'friend1', 'friend2', 'user_expected'];
      case 4: // Supportive and helpful
        return ['friend1', 'friend3', 'waiter', 'user_expected'];
      default:
        return ['friend1', 'friend2', 'user_expected'];
    }
  }

  static List<String> _getBirthdayConversationPattern(int stage) {
    switch (stage) {
      case 1: // Peer pressure about cake
        return ['friend1', 'friend2', 'friend3', 'user_expected'];
      case 2: // Still pushing but curious
        return ['friend2', 'friend3', 'user_expected'];
      case 3: // Getting concerned
        return ['friend3', 'friend1', 'user_expected'];
      case 4: // Supportive and apologetic
        return ['friend1', 'friend2', 'friend3', 'user_expected'];
      default:
        return ['friend1', 'friend2', 'user_expected'];
    }
  }

  /// Natural conversation starters for AI-to-AI interactions
  static Map<String, List<String>> getAIToAIPrompts() {
    return {
      'agreement': [
        "Yeah, exactly!",
        "I totally agree with that.",
        "That's what I was thinking too.",
      ],
      'concern': [
        "Wait, are you serious about this?",
        "I'm starting to get worried...",
        "This sounds really serious.",
      ],
      'peer_pressure': [
        "Come on, don't be the only one!",
        "Everyone else is doing it.",
        "You're missing out!",
      ],
      'support': [
        "We should definitely help you out.",
        "Your safety is what matters most.",
        "Let's find something that works for everyone.",
      ],
    };
  }

  /// Debugging helper to log conversation flow
  static void logConversationFlow({
    required String speaker,
    required String message,
    required int stage,
    required int messageCount,
  }) {
    if (kDebugMode) {
      debugPrint(
        '🎭 CONVERSATION FLOW: [$messageCount] $speaker (Stage $stage): ${message.substring(0, 30)}...',
      );
    }
  }
}
