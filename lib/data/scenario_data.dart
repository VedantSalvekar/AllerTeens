import 'package:flutter/material.dart';
import '../models/scenario_models.dart';
import '../core/constants.dart';

/// Provides all available training scenarios
class ScenarioDataProvider {
  static List<TrainingScenario> getAllScenarios() {
    return [
      // BEGINNER LEVEL SCENARIOS
      TrainingScenario(
        id: 'restaurant_beginner',
        title: 'Restaurant Dining',
        description: 'Practice ordering safely with allergy disclosure',
        iconPath: 'assets/icons/restaurant.png',
        type: ScenarioType.restaurant,
        difficulty: DifficultyLevel.beginner,
        learningObjectives: [
          'Clearly state your allergies to the waiter',
          'Ask about ingredients in menu items',
          'Confirm safe options before ordering',
        ],
        scenarioData: {
          'setting': 'Family restaurant',
          'npcRole': 'Friendly waiter',
          'complexity': 'low',
          'prompts': 'high',
        },
        accentColor: AppColors.primary,
        estimatedDuration: 3,
        isUnlocked: true,
        rewards: ['Confidence points', 'Restaurant safety badge'],
      ),

      TrainingScenario(
        id: 'takeaway_beginner',
        title: 'Takeaway Order',
        description: 'Order food safely from a takeaway restaurant',
        iconPath: 'assets/icons/takeaway.png',
        type: ScenarioType.takeaway,
        difficulty: DifficultyLevel.beginner,
        learningObjectives: [
          'Mention allergies during phone/counter ordering',
          'Ask about preparation methods',
          'Confirm packaging safety',
        ],
        scenarioData: {
          'setting': 'Pizza place',
          'npcRole': 'Takeaway staff',
          'complexity': 'low',
          'prompts': 'high',
        },
        accentColor: const Color(0xFFFF9800),
        estimatedDuration: 2,
        isUnlocked: false,
        requiredScore: 80, // Lock until restaurant is mastered
        rewards: ['Takeaway safety badge'],
      ),

      // INTERMEDIATE LEVEL SCENARIOS
      TrainingScenario(
        id: 'birthday_party',
        title: 'Birthday Party',
        description: 'Handle social situations with food allergies',
        iconPath: 'assets/icons/party.png',
        type: ScenarioType.party,
        difficulty: DifficultyLevel.intermediate,
        learningObjectives: [
          'Communicate with party hosts',
          'Handle peer pressure appropriately',
          'Suggest safe alternatives',
        ],
        scenarioData: {
          'setting': 'Friend\'s birthday party',
          'npcRole': 'Party host parent',
          'complexity': 'medium',
          'prompts': 'medium',
        },
        accentColor: const Color(0xFF9C27B0),
        estimatedDuration: 5,
        requiredScore: 150,
        rewards: ['Social confidence badge', 'Party safety points'],
      ),

      // ADVANCED LEVEL SCENARIOS
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
