import 'package:flutter/material.dart';
import 'training_assessment.dart' show ScenarioProgress;

/// Represents a training scenario for allergy communication
class TrainingScenario {
  final String id;
  final String title;
  final String description;
  final String iconPath;
  final ScenarioType type;
  final DifficultyLevel difficulty;
  final List<String> learningObjectives;
  final Map<String, dynamic> scenarioData;
  final Color accentColor;
  final int estimatedDuration; // in minutes
  final bool isUnlocked;
  final int requiredScore; // minimum score needed to unlock
  final List<String> rewards; // what users get for completing

  const TrainingScenario({
    required this.id,
    required this.title,
    required this.description,
    required this.iconPath,
    required this.type,
    required this.difficulty,
    required this.learningObjectives,
    required this.scenarioData,
    required this.accentColor,
    required this.estimatedDuration,
    this.isUnlocked = true,
    this.requiredScore = 0,
    this.rewards = const [],
  });
}

/// Different types of scenarios
enum ScenarioType {
  restaurant,
  takeaway,
  party,
  school,
  friends,
  family,
  emergencyPrep,
  travel,
  workplace,
  healthcare,
}

/// Difficulty levels for progressive learning
enum DifficultyLevel {
  beginner, // Clear prompts, supportive AI
  intermediate, // Some challenges, requires initiative
  advanced, // Complex situations, minimal guidance, real-world complexity
}

/// Achievement system for gamification
class Achievement {
  final String id;
  final String title;
  final String description;
  final String iconPath;
  final int pointsRequired;
  final bool isUnlocked;
  final DateTime? unlockedAt;
  final Color badgeColor;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.iconPath,
    required this.pointsRequired,
    required this.isUnlocked,
    this.unlockedAt,
    required this.badgeColor,
  });
}

/// Overall training progress for the user
class TrainingProgress {
  final int totalScore;
  final int completedScenarios;
  final int totalScenarios;
  final String currentLevel;
  final int currentLevelProgress;
  final List<Achievement> achievements;
  final Map<String, ScenarioProgress> scenarioProgress;
  final int streak; // consecutive days of practice
  final DateTime lastActivity;

  const TrainingProgress({
    required this.totalScore,
    required this.completedScenarios,
    required this.totalScenarios,
    required this.currentLevel,
    required this.currentLevelProgress,
    required this.achievements,
    required this.scenarioProgress,
    required this.streak,
    required this.lastActivity,
  });

  double get completionPercentage => completedScenarios / totalScenarios;

  bool get isOnStreak => DateTime.now().difference(lastActivity).inDays <= 1;
}
