class GameState {
  final int currentScore;
  final int totalConfidencePoints;
  final int currentStepIndex;
  final List<SimulationResult> completedSteps;
  final PlayerProfile playerProfile;

  const GameState({
    this.currentScore = 0,
    this.totalConfidencePoints = 0,
    this.currentStepIndex = 0,
    this.completedSteps = const [],
    required this.playerProfile,
  });

  GameState copyWith({
    int? currentScore,
    int? totalConfidencePoints,
    int? currentStepIndex,
    List<SimulationResult>? completedSteps,
    PlayerProfile? playerProfile,
  }) {
    return GameState(
      currentScore: currentScore ?? this.currentScore,
      totalConfidencePoints:
          totalConfidencePoints ?? this.totalConfidencePoints,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      completedSteps: completedSteps ?? this.completedSteps,
      playerProfile: playerProfile ?? this.playerProfile,
    );
  }

  // Calculate confidence level based on performance
  String get confidenceLevel {
    if (totalConfidencePoints >= 100) return "Highly Confident";
    if (totalConfidencePoints >= 75) return "Confident";
    if (totalConfidencePoints >= 50) return "Building Confidence";
    if (totalConfidencePoints >= 25) return "Learning";
    return "Getting Started";
  }

  double get progressPercentage =>
      completedSteps.length / 10.0; // Assuming 10 total scenarios

  Map<String, dynamic> toJson() {
    return {
      'currentScore': currentScore,
      'totalConfidencePoints': totalConfidencePoints,
      'currentStepIndex': currentStepIndex,
      'completedSteps': completedSteps.map((e) => e.toJson()).toList(),
      'playerProfile': playerProfile.toJson(),
    };
  }

  factory GameState.fromJson(Map<String, dynamic> json) {
    return GameState(
      currentScore: json['currentScore'] ?? 0,
      totalConfidencePoints: json['totalConfidencePoints'] ?? 0,
      currentStepIndex: json['currentStepIndex'] ?? 0,
      completedSteps:
          (json['completedSteps'] as List?)
              ?.map((e) => SimulationResult.fromJson(e))
              .toList() ??
          [],
      playerProfile: PlayerProfile.fromJson(json['playerProfile']),
    );
  }
}

class SimulationResult {
  final String stepId;
  final bool wasCorrect;
  final int selectedResponseIndex;
  final DateTime completedAt;
  final int pointsEarned;

  // New fields for AI dialogue
  final String? userSpeechInput; // What the user actually said
  final List<String>?
  detectedAllergies; // Allergies that were successfully mentioned
  final String? aiAssessment; // Claude's assessment of the communication
  final bool
  wasAIDialogue; // Whether this was an AI dialogue or traditional multiple choice

  const SimulationResult({
    required this.stepId,
    required this.wasCorrect,
    required this.selectedResponseIndex,
    required this.completedAt,
    required this.pointsEarned,
    this.userSpeechInput,
    this.detectedAllergies,
    this.aiAssessment,
    this.wasAIDialogue = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'stepId': stepId,
      'wasCorrect': wasCorrect,
      'selectedResponseIndex': selectedResponseIndex,
      'completedAt': completedAt.toIso8601String(),
      'pointsEarned': pointsEarned,
      'userSpeechInput': userSpeechInput,
      'detectedAllergies': detectedAllergies,
      'aiAssessment': aiAssessment,
      'wasAIDialogue': wasAIDialogue,
    };
  }

  factory SimulationResult.fromJson(Map<String, dynamic> json) {
    return SimulationResult(
      stepId: json['stepId'],
      wasCorrect: json['wasCorrect'],
      selectedResponseIndex: json['selectedResponseIndex'],
      completedAt: DateTime.parse(json['completedAt']),
      pointsEarned: json['pointsEarned'],
      userSpeechInput: json['userSpeechInput'],
      detectedAllergies: json['detectedAllergies'] != null
          ? List<String>.from(json['detectedAllergies'])
          : null,
      aiAssessment: json['aiAssessment'],
      wasAIDialogue: json['wasAIDialogue'] ?? false,
    );
  }
}

class PlayerProfile {
  final String name;
  final List<String> allergies;
  final int age;
  final String preferredName;

  const PlayerProfile({
    required this.name,
    required this.allergies,
    required this.age,
    required this.preferredName,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'allergies': allergies,
      'age': age,
      'preferredName': preferredName,
    };
  }

  factory PlayerProfile.fromJson(Map<String, dynamic> json) {
    return PlayerProfile(
      name: json['name'],
      allergies: List<String>.from(json['allergies']),
      age: json['age'],
      preferredName: json['preferredName'],
    );
  }
}
