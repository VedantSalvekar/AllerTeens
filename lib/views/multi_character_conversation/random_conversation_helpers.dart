import 'dart:math';

/// Helper methods for random conversation flow in multi-character scenarios
class RandomConversationHelpers {
  static final Random _random = Random();

  /// Randomly select 1-2 speakers from available friends
  static List<String> getRandomSpeakers(
    List<String> availableSpeakers, {
    int maxSpeakers = 2,
  }) {
    if (availableSpeakers.isEmpty) return [];

    // Randomly choose 1 or 2 speakers
    final numSpeakers = _random.nextInt(maxSpeakers) + 1;
    final shuffled = List<String>.from(availableSpeakers)..shuffle(_random);

    return shuffled.take(numSpeakers).toList();
  }

  /// Determine if AI should respond based on random chance and conversation context
  static bool shouldTriggerAIResponse({
    required String userInput,
    required int conversationStage,
    required int messageCount,
    double baseProbability = 0.6,
  }) {
    // Higher chance if user mentions something important
    final input = userInput.toLowerCase();

    if (input.contains('allergic') || input.contains('allergy')) {
      return _random.nextDouble() < 0.8; // 80% chance
    }

    if (input.contains('serious') || input.contains('severe')) {
      return _random.nextDouble() < 0.7; // 70% chance
    }

    if (input.contains('anaphylaxis') || input.contains('breathing')) {
      return _random.nextDouble() < 0.9; // 90% chance
    }

    // Base probability affected by conversation stage
    final adjustedProbability = baseProbability * (conversationStage / 4.0);
    return _random.nextDouble() < adjustedProbability;
  }

  /// Get random delay between speakers to make conversation feel natural
  static Duration getRandomPauseDuration({
    bool isImportantTopic = false,
    bool isEmotionalResponse = false,
  }) {
    if (isImportantTopic || isEmotionalResponse) {
      // Shorter pauses for urgent/emotional topics
      return Duration(milliseconds: 500 + _random.nextInt(1000)); // 0.5-1.5s
    }

    // Normal conversation pauses
    return Duration(milliseconds: 1000 + _random.nextInt(2000)); // 1-3s
  }

  /// Generate random conversation prompts for AI-to-AI interactions
  static String getRandomAIPrompt({
    required String conversationType,
    required String userMessage,
    required int conversationStage,
  }) {
    final prompts = _getPromptsForStage(conversationType, conversationStage);
    return prompts[_random.nextInt(prompts.length)].replaceAll(
      '{userMessage}',
      userMessage,
    );
  }

  static List<String> _getPromptsForStage(String conversationType, int stage) {
    final basePrompts = {
      1: [
        // Initial pushiness
        "React to what your friend just said: '{userMessage}'. Be dismissive and pushy.",
        "Your friend said '{userMessage}' - convince them they're overreacting.",
        "Respond to '{userMessage}' with peer pressure tactics.",
      ],
      2: [
        // Still pushing but aware
        "Your friend mentioned '{userMessage}' - show some skepticism but keep pushing.",
        "React to '{userMessage}' with doubt about how serious it really is.",
        "Your friend said '{userMessage}' - question if it's really that bad.",
      ],
      3: [
        // Getting concerned
        "Your friend explained '{userMessage}' - start showing real concern.",
        "React to '{userMessage}' with growing understanding and worry.",
        "Your friend said '{userMessage}' - ask questions to understand better.",
      ],
      4: [
        // Supportive
        "Your friend said '{userMessage}' - be completely supportive and helpful.",
        "React to '{userMessage}' with full understanding and support.",
        "Your friend explained '{userMessage}' - help find safe alternatives.",
      ],
    };

    return basePrompts[stage] ?? basePrompts[1]!;
  }
}
