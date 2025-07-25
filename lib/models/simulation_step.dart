class SimulationStep {
  final String id;
  final String backgroundImagePath;
  final String npcDialogue;
  final List<ResponseOption> responseOptions;
  final int correctResponseIndex;
  final String successFeedback;
  final String generalFailureFeedback;

  // New fields for AI dialogue
  final String? npcRole; // e.g., "Waiter", "Teacher", "Friend"
  final String? scenarioContext; // Description of the scenario for Claude
  final List<String>? requiredAllergies; // Allergies that should be mentioned
  final bool
  enableAIDialogue; // Whether to use AI dialogue or traditional responses
  final String? initialPrompt; // What the NPC says to start the conversation

  const SimulationStep({
    required this.id,
    required this.backgroundImagePath,
    required this.npcDialogue,
    required this.responseOptions,
    required this.correctResponseIndex,
    required this.successFeedback,
    required this.generalFailureFeedback,
    this.npcRole,
    this.scenarioContext,
    this.requiredAllergies,
    this.enableAIDialogue = false,
    this.initialPrompt,
  });

  ResponseOption get correctResponse => responseOptions[correctResponseIndex];

  // Helper method to get the effective NPC role
  String get effectiveNpcRole => npcRole ?? 'Person';

  // Helper method to get the effective scenario context
  String get effectiveScenarioContext =>
      scenarioContext ?? 'A conversation about food and dining';

  factory SimulationStep.fromJson(Map<String, dynamic> json) {
    final isAIMode = json['enableAIDialogue'] == true;

    return SimulationStep(
      id: json['id'] ?? '',
      backgroundImagePath: json['backgroundImagePath'] ?? '',
      npcDialogue: isAIMode ? '' : (json['npcDialogue'] ?? ''),
      responseOptions: isAIMode
          ? []
          : (json['responseOptions'] as List<dynamic>? ?? [])
                .map((e) => ResponseOption.fromJson(e))
                .toList(),
      correctResponseIndex: isAIMode ? 0 : (json['correctResponseIndex'] ?? 0),
      successFeedback: isAIMode ? '' : (json['successFeedback'] ?? ''),
      generalFailureFeedback: isAIMode
          ? ''
          : (json['generalFailureFeedback'] ?? ''),
      npcRole: json['npcRole'],
      scenarioContext: json['scenarioContext'],
      requiredAllergies: json['requiredAllergies'] != null
          ? List<String>.from(json['requiredAllergies'])
          : null,
      enableAIDialogue: json['enableAIDialogue'] ?? false,
      initialPrompt:
          json['initialPrompt'] ?? json['initialDialogue'], // fallback
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'backgroundImagePath': backgroundImagePath,
      'npcDialogue': npcDialogue,
      'responseOptions': responseOptions.map((e) => e.toJson()).toList(),
      'correctResponseIndex': correctResponseIndex,
      'successFeedback': successFeedback,
      'generalFailureFeedback': generalFailureFeedback,
      'npcRole': npcRole,
      'scenarioContext': scenarioContext,
      'requiredAllergies': requiredAllergies,
      'enableAIDialogue': enableAIDialogue,
      'initialPrompt': initialPrompt,
    };
  }
}

class ResponseOption {
  final String text;
  final bool isCorrect;
  final String? specificFeedback; // Custom feedback for this wrong answer
  final int confidencePoints; // Points awarded for confidence building

  const ResponseOption({
    required this.text,
    required this.isCorrect,
    this.specificFeedback,
    this.confidencePoints = 0,
  });

  factory ResponseOption.fromJson(Map<String, dynamic> json) {
    return ResponseOption(
      text: json['text'],
      isCorrect: json['isCorrect'],
      specificFeedback: json['specificFeedback'],
      confidencePoints: json['confidencePoints'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'isCorrect': isCorrect,
      'specificFeedback': specificFeedback,
      'confidencePoints': confidencePoints,
    };
  }
}
