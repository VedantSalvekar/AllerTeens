import 'scenario_models.dart';

/// Configuration for a dynamic training scenario
class ScenarioConfig {
  final String id;
  final String name;
  final ScenarioType type;
  final DifficultyLevel level;
  final String npcRole;
  final String scenarioContext;
  final String? backgroundImagePath;
  final String? initialDialogue;
  final Map<String, dynamic>? menuData;
  final List<String> allergens;
  final BehaviorRules behaviorRules;
  final ScoringRules scoringRules;
  final List<String> allergyTips;
  final List<String> positiveReinforcements;
  final List<String> gentlePrompts;
  final bool enableAIDialogue;
  final int maxTurns;
  final double difficultyMultiplier;

  const ScenarioConfig({
    required this.id,
    required this.name,
    required this.type,
    required this.level,
    required this.npcRole,
    required this.scenarioContext,
    this.backgroundImagePath,
    this.initialDialogue,
    this.menuData,
    this.allergens = const [],
    required this.behaviorRules,
    required this.scoringRules,
    this.allergyTips = const [],
    this.positiveReinforcements = const [],
    this.gentlePrompts = const [],
    this.enableAIDialogue = true,
    this.maxTurns = 10,
    this.difficultyMultiplier = 1.0,
  });

  factory ScenarioConfig.fromJson(Map<String, dynamic> json) {
    return ScenarioConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      type: ScenarioType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
      ),
      level: DifficultyLevel.values.firstWhere(
        (e) => e.toString().split('.').last == json['level'],
      ),
      npcRole: json['npcRole'] as String,
      scenarioContext: json['scenarioContext'] as String,
      backgroundImagePath: json['backgroundImagePath'] as String?,
      initialDialogue: json['initialDialogue'] as String?,
      menuData: json['menuData'] as Map<String, dynamic>?,
      allergens: List<String>.from(json['allergens'] ?? []),
      behaviorRules: BehaviorRules.fromJson(json['behaviorRules'] ?? {}),
      scoringRules: ScoringRules.fromJson(json['scoringRules'] ?? {}),
      allergyTips: List<String>.from(json['allergyTips'] ?? []),
      positiveReinforcements: List<String>.from(
        json['positiveReinforcements'] ?? [],
      ),
      gentlePrompts: List<String>.from(json['gentlePrompts'] ?? []),
      enableAIDialogue: json['enableAIDialogue'] as bool? ?? true,
      maxTurns: json['maxTurns'] as int? ?? 10,
      difficultyMultiplier:
          (json['difficultyMultiplier'] as num?)?.toDouble() ?? 1.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.toString().split('.').last,
      'level': level.toString().split('.').last,
      'npcRole': npcRole,
      'scenarioContext': scenarioContext,
      'backgroundImagePath': backgroundImagePath,
      'initialDialogue': initialDialogue,
      'menuData': menuData,
      'allergens': allergens,
      'behaviorRules': behaviorRules.toJson(),
      'scoringRules': scoringRules.toJson(),
      'allergyTips': allergyTips,
      'positiveReinforcements': positiveReinforcements,
      'gentlePrompts': gentlePrompts,
      'enableAIDialogue': enableAIDialogue,
      'maxTurns': maxTurns,
      'difficultyMultiplier': difficultyMultiplier,
    };
  }
}

/// AI behavior rules for different scenarios and difficulty levels
class BehaviorRules {
  final double guidanceLevel; // 0.0 (minimal) to 1.0 (high guidance)
  final bool allowProbing; // Can AI ask follow-up questions?
  final bool includePeerPressure; // For social scenarios
  final bool includeHiddenAllergens; // Advanced scenarios
  final bool allowClarification; // Can AI ask for clarification?
  final FeedbackStyle feedbackStyle;
  final List<String> triggerWords; // Words that should trigger responses
  final int patienceLevel; // How long AI waits before prompting

  const BehaviorRules({
    this.guidanceLevel = 0.5,
    this.allowProbing = false,
    this.includePeerPressure = false,
    this.includeHiddenAllergens = false,
    this.allowClarification = true,
    this.feedbackStyle = FeedbackStyle.supportive,
    this.triggerWords = const [],
    this.patienceLevel = 3,
  });

  factory BehaviorRules.fromJson(Map<String, dynamic> json) {
    return BehaviorRules(
      guidanceLevel: (json['guidanceLevel'] as num?)?.toDouble() ?? 0.5,
      allowProbing: json['allowProbing'] as bool? ?? false,
      includePeerPressure: json['includePeerPressure'] as bool? ?? false,
      includeHiddenAllergens: json['includeHiddenAllergens'] as bool? ?? false,
      allowClarification: json['allowClarification'] as bool? ?? true,
      feedbackStyle: FeedbackStyle.values.firstWhere(
        (e) =>
            e.toString().split('.').last ==
            (json['feedbackStyle'] ?? 'supportive'),
        orElse: () => FeedbackStyle.supportive,
      ),
      triggerWords: List<String>.from(json['triggerWords'] ?? []),
      patienceLevel: json['patienceLevel'] as int? ?? 3,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'guidanceLevel': guidanceLevel,
      'allowProbing': allowProbing,
      'includePeerPressure': includePeerPressure,
      'includeHiddenAllergens': includeHiddenAllergens,
      'allowClarification': allowClarification,
      'feedbackStyle': feedbackStyle.toString().split('.').last,
      'triggerWords': triggerWords,
      'patienceLevel': patienceLevel,
    };
  }
}

/// Scoring rules for different scenarios and difficulty levels
class ScoringRules {
  final Map<String, int> basePoints;
  final Map<String, int> bonusPoints;
  final Map<String, int> penalties;
  final int passingScore;
  final bool requireAllergyDisclosure;
  final bool requireSafeOrder;
  final bool requireIngredientQuestions;
  final List<String> requiredActions;

  const ScoringRules({
    this.basePoints = const {},
    this.bonusPoints = const {},
    this.penalties = const {},
    this.passingScore = 70,
    this.requireAllergyDisclosure = true,
    this.requireSafeOrder = true,
    this.requireIngredientQuestions = false,
    this.requiredActions = const [],
  });

  factory ScoringRules.fromJson(Map<String, dynamic> json) {
    return ScoringRules(
      basePoints: Map<String, int>.from(json['basePoints'] ?? {}),
      bonusPoints: Map<String, int>.from(json['bonusPoints'] ?? {}),
      penalties: Map<String, int>.from(json['penalties'] ?? {}),
      passingScore: json['passingScore'] as int? ?? 70,
      requireAllergyDisclosure:
          json['requireAllergyDisclosure'] as bool? ?? true,
      requireSafeOrder: json['requireSafeOrder'] as bool? ?? true,
      requireIngredientQuestions:
          json['requireIngredientQuestions'] as bool? ?? false,
      requiredActions: List<String>.from(json['requiredActions'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'basePoints': basePoints,
      'bonusPoints': bonusPoints,
      'penalties': penalties,
      'passingScore': passingScore,
      'requireAllergyDisclosure': requireAllergyDisclosure,
      'requireSafeOrder': requireSafeOrder,
      'requireIngredientQuestions': requireIngredientQuestions,
      'requiredActions': requiredActions,
    };
  }
}

/// Feedback styles for different difficulty levels
enum FeedbackStyle {
  supportive, // Encouraging, helpful
  neutral, // Factual, straightforward
  challenging, // Pushes for better performance
  realistic, // Real-world responses
}
