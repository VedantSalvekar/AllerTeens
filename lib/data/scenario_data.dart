import 'package:flutter/material.dart';
import '../models/scenario_models.dart';
import '../core/constants.dart';
import '../services/scenario_loader.dart';

/// Provides all available training scenarios using the new dynamic system
class ScenarioDataProvider {
  static final ScenarioLoader _scenarioLoader = ScenarioLoader.instance;

  /// Get all scenarios from the dynamic manifest
  static Future<List<TrainingScenario>> getAllScenariosAsync() async {
    try {
      final scenarioMetadataList = await _scenarioLoader
          .getAvailableScenarios();
      return scenarioMetadataList
          .map((metadata) => _convertToTrainingScenario(metadata))
          .toList();
    } catch (e) {
      // Fallback to hardcoded scenarios if loading fails
      return _getHardcodedScenarios();
    }
  }

  /// Synchronous version for backward compatibility - loads from cache or fallback
  static List<TrainingScenario> getAllScenarios() {
    // Return fallback scenarios immediately - the UI should use the async version for live data
    return _getHardcodedScenarios();
  }

  /// Convert ScenarioMetadata to TrainingScenario for UI compatibility
  static TrainingScenario _convertToTrainingScenario(
    ScenarioMetadata metadata,
  ) {
    return TrainingScenario(
      id: metadata.id,
      title: metadata.name,
      description: metadata.description,
      iconPath: _getIconPathForType(metadata.type),
      type: metadata.type,
      difficulty: metadata.level,
      learningObjectives: _getLearningObjectives(metadata.type, metadata.level),
      scenarioData: {
        'setting': _getSettingForScenario(metadata.id),
        'npcRole': _getNpcRoleForScenario(metadata.id),
        'complexity': metadata.level == DifficultyLevel.beginner
            ? 'low'
            : metadata.level == DifficultyLevel.intermediate
            ? 'medium'
            : 'high',
        'prompts': metadata.level == DifficultyLevel.beginner
            ? 'high'
            : metadata.level == DifficultyLevel.intermediate
            ? 'medium'
            : 'low',
      },
      accentColor: _getColorForType(metadata.type),
      estimatedDuration: _getDurationForScenario(metadata.id),
      isUnlocked: metadata.enabled,
      requiredScore: metadata.requiredScore,
      rewards: _getRewardsForScenario(metadata.id),
    );
  }

  /// Get icon path based on scenario type
  static String _getIconPathForType(ScenarioType type) {
    switch (type) {
      case ScenarioType.restaurant:
        return 'assets/icons/restaurant.png';
      case ScenarioType.party:
        return 'assets/icons/party.png';
      case ScenarioType.school:
        return 'assets/icons/school.png';
      case ScenarioType.takeaway:
        return 'assets/icons/takeaway.png';
      default:
        return 'assets/icons/default.png';
    }
  }

  /// Get accent color based on scenario type
  static Color _getColorForType(ScenarioType type) {
    switch (type) {
      case ScenarioType.restaurant:
        return AppColors.primary;
      case ScenarioType.party:
        return const Color(0xFF9C27B0);
      case ScenarioType.school:
        return const Color(0xFF2196F3);
      case ScenarioType.takeaway:
        return const Color(0xFFFF9800);
      default:
        return AppColors.primary;
    }
  }

  /// Get learning objectives based on type and level
  static List<String> _getLearningObjectives(
    ScenarioType type,
    DifficultyLevel level,
  ) {
    if (type == ScenarioType.restaurant) {
      if (level == DifficultyLevel.beginner) {
        return [
          'Clearly state your allergies to the waiter',
          'Ask about ingredients in menu items',
          'Confirm safe options before ordering',
        ];
      } else if (level == DifficultyLevel.advanced) {
        return [
          'Navigate complex menus with hidden allergens',
          'Ask detailed questions about preparation methods',
          'Handle professional service with minimal guidance',
          'Demonstrate cross-contamination awareness',
        ];
      }
    } else if (type == ScenarioType.party) {
      return [
        'Communicate with party hosts',
        'Handle peer pressure appropriately',
        'Suggest safe alternatives',
      ];
    }

    return ['Practice allergy communication skills'];
  }

  /// Get setting description for scenario
  static String _getSettingForScenario(String id) {
    switch (id) {
      case 'restaurant_beginner':
        return 'Casual family restaurant';
      case 'restaurant_advanced':
        return 'Upscale fine dining restaurant';
      case 'party_intermediate':
        return 'Friend\'s birthday party';
      default:
        return 'Training environment';
    }
  }

  /// Get NPC role for scenario
  static String _getNpcRoleForScenario(String id) {
    switch (id) {
      case 'restaurant_beginner':
        return 'Friendly waiter';
      case 'restaurant_advanced':
        return 'Professional waiter';
      case 'party_intermediate':
        return 'Party host parent';
      default:
        return 'Training partner';
    }
  }

  /// Get estimated duration for scenario
  static int _getDurationForScenario(String id) {
    switch (id) {
      case 'restaurant_beginner':
        return 3;
      case 'restaurant_advanced':
        return 5;
      case 'party_intermediate':
        return 6;
      default:
        return 4;
    }
  }

  /// Get rewards for scenario
  static List<String> _getRewardsForScenario(String id) {
    switch (id) {
      case 'restaurant_beginner':
        return ['Confidence points', 'Restaurant safety badge'];
      case 'restaurant_advanced':
        return ['Advanced communication badge', 'Professional dining skills'];
      case 'party_intermediate':
        return ['Social confidence badge', 'Party safety points'];
      default:
        return ['Training completion points'];
    }
  }

  /// Fallback hardcoded scenarios (includes restaurant_advanced)
  static List<TrainingScenario> _getHardcodedScenarios() {
    return [
      // BEGINNER LEVEL SCENARIOS
      TrainingScenario(
        id: 'restaurant_beginner',
        title: 'Restaurant Dining - Beginner',
        description: 'Practice basic allergy disclosure with a friendly waiter',
        iconPath: 'assets/icons/restaurant.png',
        type: ScenarioType.restaurant,
        difficulty: DifficultyLevel.beginner,
        learningObjectives: [
          'Clearly state your allergies to the waiter',
          'Ask about ingredients in menu items',
          'Confirm safe options before ordering',
        ],
        scenarioData: {
          'setting': 'Casual family restaurant',
          'npcRole': 'Friendly waiter',
          'complexity': 'low',
          'prompts': 'high',
        },
        accentColor: AppColors.primary,
        estimatedDuration: 3,
        isUnlocked: true,
        rewards: ['Confidence points', 'Restaurant safety badge'],
      ),

      // ADVANCED LEVEL SCENARIOS
      TrainingScenario(
        id: 'restaurant_advanced',
        title: 'Restaurant Dining - Advanced',
        description:
            'Navigate complex menu items with hidden allergens and professional service',
        iconPath: 'assets/icons/restaurant.png',
        type: ScenarioType.restaurant,
        difficulty: DifficultyLevel.advanced,
        learningObjectives: [
          'Navigate complex menus with hidden allergens',
          'Ask detailed questions about preparation methods',
          'Handle professional service with minimal guidance',
          'Demonstrate cross-contamination awareness',
        ],
        scenarioData: {
          'setting': 'Upscale fine dining restaurant',
          'npcRole': 'Professional waiter',
          'complexity': 'high',
          'prompts': 'low',
        },
        accentColor: AppColors.primary,
        estimatedDuration: 5,
        isUnlocked: true,
        requiredScore: 0,
        rewards: ['Advanced communication badge', 'Professional dining skills'],
      ),

      // TrainingScenario(
      //   id: 'takeaway_beginner',
      //   title: 'Takeaway Order',
      //   description: 'Order food safely from a takeaway restaurant',
      //   iconPath: 'assets/icons/takeaway.png',
      //   type: ScenarioType.takeaway,
      //   difficulty: DifficultyLevel.beginner,
      //   learningObjectives: [
      //     'Mention allergies during phone/counter ordering',
      //     'Ask about preparation methods',
      //     'Confirm packaging safety',
      //   ],
      //   scenarioData: {
      //     'setting': 'Pizza place',
      //     'npcRole': 'Takeaway staff',
      //     'complexity': 'low',
      //     'prompts': 'high',
      //   },
      //   accentColor: const Color(0xFFFF9800),
      //   estimatedDuration: 2,
      //   isUnlocked: false,
      //   requiredScore: 80,
      //   rewards: ['Takeaway safety badge'],
      // ),

      // // INTERMEDIATE LEVEL SCENARIOS
      // TrainingScenario(
      //   id: 'party_intermediate',
      //   title: 'Birthday Party',
      //   description:
      //       'Handle social pressure and peer interactions at a friend\'s party',
      //   iconPath: 'assets/icons/party.png',
      //   type: ScenarioType.party,
      //   difficulty: DifficultyLevel.intermediate,
      //   learningObjectives: [
      //     'Communicate with party hosts',
      //     'Handle peer pressure appropriately',
      //     'Suggest safe alternatives',
      //   ],
      //   scenarioData: {
      //     'setting': 'Friend\'s birthday party',
      //     'npcRole': 'Party host parent',
      //     'complexity': 'medium',
      //     'prompts': 'medium',
      //   },
      //   accentColor: const Color(0xFF9C27B0),
      //   estimatedDuration: 5,
      //   requiredScore: 150,
      //   rewards: ['Social confidence badge', 'Party safety points'],
      // ),

      // OTHER SCENARIOS
      TrainingScenario(
        id: 'emergency_prep',
        title: 'Emergency Situations',
        description: 'Handle allergic reactions and emergency prep',
        iconPath: 'assets/icons/emergency.png',
        type: ScenarioType.emergencyPrep,
        difficulty: DifficultyLevel.advanced,
        learningObjectives: [
          'Communicate during an allergic reaction',
          'Teach others to use your EpiPen',
          'Create emergency action plans',
        ],
        scenarioData: {
          'setting': 'Emergency situation',
          'npcRole': 'EMT/First responder',
          'complexity': 'high',
          'prompts': 'low',
        },
        accentColor: const Color(0xFFF44336),
        estimatedDuration: 8,
        requiredScore: 250,
        rewards: ['Emergency hero badge', 'Life-saving skills'],
      ),
    ];
  }

  /// Get scenarios filtered by difficulty level
  static List<TrainingScenario> getScenariosByDifficulty(
    DifficultyLevel difficulty,
  ) {
    return getAllScenarios()
        .where((scenario) => scenario.difficulty == difficulty)
        .toList();
  }

  /// Get scenarios that are unlocked for the user
  static List<TrainingScenario> getUnlockedScenarios(int userScore) {
    return getAllScenarios()
        .where(
          (scenario) =>
              scenario.isUnlocked && userScore >= scenario.requiredScore,
        )
        .toList();
  }

  /// Get scenario by ID
  static TrainingScenario? getScenarioById(String id) {
    try {
      return getAllScenarios().firstWhere((scenario) => scenario.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get achievements for the gamification system
  static List<Achievement> getAllAchievements() {
    return [
      Achievement(
        id: 'first_conversation',
        title: 'First Steps',
        description: 'Complete your first AI conversation',
        iconPath: 'assets/icons/first_steps.png',
        pointsRequired: 10,
        isUnlocked: false,
        badgeColor: const Color(0xFFCD7F32), // Bronze
      ),
      Achievement(
        id: 'allergy_advocate',
        title: 'Allergy Advocate',
        description: 'Successfully disclose allergies in 5 conversations',
        iconPath: 'assets/icons/advocate.png',
        pointsRequired: 100,
        isUnlocked: false,
        badgeColor: const Color(0xFFC0C0C0), // Silver
      ),
      Achievement(
        id: 'confident_communicator',
        title: 'Confident Communicator',
        description: 'Achieve 90% communication score',
        iconPath: 'assets/icons/confident.png',
        pointsRequired: 200,
        isUnlocked: false,
        badgeColor: const Color(0xFFFFD700), // Gold
      ),
      Achievement(
        id: 'scenario_master',
        title: 'Scenario Master',
        description: 'Complete all difficulty levels',
        iconPath: 'assets/icons/master.png',
        pointsRequired: 500,
        isUnlocked: false,
        badgeColor: const Color(0xFFE5E4E2), // Platinum
      ),
    ];
  }
}
