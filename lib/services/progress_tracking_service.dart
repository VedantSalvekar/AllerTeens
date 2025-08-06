import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/training_assessment.dart';
import '../models/scenario_models.dart' show TrainingScenario;

/// Comprehensive progress tracking service for managing user training data
class ProgressTrackingService {
  static const String _sessionsCollection = 'training_sessions';
  static const String _userProgressCollection = 'user_progress';
  static const String _achievementsCollection = 'achievements';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Save a completed training session
  Future<void> saveTrainingSession(TrainingSession session) async {
    try {
      debugPrint('💾 [PROGRESS] Saving training session: ${session.sessionId}');

      await _firestore
          .collection(_sessionsCollection)
          .doc(session.sessionId)
          .set(session.toJson());

      debugPrint('✅ [PROGRESS] Training session saved successfully');
    } catch (e) {
      debugPrint('❌ [PROGRESS] Error saving training session: $e');

      // Don't rethrow for permission errors to avoid breaking the training flow
      if (e.toString().contains('permission-denied')) {
        debugPrint(
          '⚠️ [PROGRESS] Firestore permission denied - training will continue without cloud save',
        );
        debugPrint(
          '💡 [PROGRESS] Please update Firestore security rules to enable progress tracking',
        );
        return; // Allow training to continue
      }

      rethrow;
    }
  }

  /// Update user progress after completing a session
  Future<void> updateUserProgress({
    required String userId,
    required String scenarioId,
    required AssessmentResult assessment,
    required TrainingSession session,
  }) async {
    try {
      debugPrint('📈 [PROGRESS] Updating user progress for: $userId');

      final userProgressRef = _firestore
          .collection(_userProgressCollection)
          .doc(userId);

      await _firestore.runTransaction((transaction) async {
        final userProgressDoc = await transaction.get(userProgressRef);

        UserProgress currentProgress;
        if (userProgressDoc.exists) {
          currentProgress = UserProgress.fromJson(userProgressDoc.data()!);
        } else {
          currentProgress = _createInitialProgress(userId);
        }

        // Update scenario progress
        final updatedScenarioProgress = await _updateScenarioProgress(
          currentProgress.scenarioProgress[scenarioId],
          assessment,
          session,
        );

        // Update overall progress
        final updatedProgress = _updateOverallProgress(
          currentProgress,
          scenarioId,
          updatedScenarioProgress,
          assessment,
        );

        // Save updated progress
        transaction.set(userProgressRef, updatedProgress.toJson());
      });

      debugPrint('✅ [PROGRESS] User progress updated successfully');
    } catch (e) {
      debugPrint('❌ [PROGRESS] Error updating user progress: $e');

      // Don't rethrow for permission errors to avoid breaking the training flow
      if (e.toString().contains('permission-denied')) {
        debugPrint(
          '⚠️ [PROGRESS] Firestore permission denied - progress not saved to cloud',
        );
        return; // Allow training to continue
      }

      rethrow;
    }
  }

  /// Get user progress for a specific scenario
  Future<ScenarioProgress?> getScenarioProgress(
    String userId,
    String scenarioId,
  ) async {
    try {
      final userProgressDoc = await _firestore
          .collection(_userProgressCollection)
          .doc(userId)
          .get();

      if (!userProgressDoc.exists) return null;

      final userProgress = UserProgress.fromJson(userProgressDoc.data()!);
      return userProgress.scenarioProgress[scenarioId];
    } catch (e) {
      debugPrint('❌ [PROGRESS] Error getting scenario progress: $e');
      return null;
    }
  }

  /// Get complete user progress
  Future<UserProgress?> getUserProgress(String userId) async {
    try {
      final userProgressDoc = await _firestore
          .collection(_userProgressCollection)
          .doc(userId)
          .get();

      if (!userProgressDoc.exists) return null;

      return UserProgress.fromJson(userProgressDoc.data()!);
    } catch (e) {
      debugPrint('❌ [PROGRESS] Error getting user progress: $e');
      return null;
    }
  }

  /// Get user's training session history
  Future<List<TrainingSession>> getUserSessions(
    String userId, {
    int limit = 10,
  }) async {
    try {
      final sessionsQuery = await _firestore
          .collection(_sessionsCollection)
          .where('userId', isEqualTo: userId)
          .orderBy('startTime', descending: true)
          .limit(limit)
          .get();

      return sessionsQuery.docs
          .map((doc) => TrainingSession.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('❌ [PROGRESS] Error getting user sessions: $e');
      return [];
    }
  }

  /// Get sessions for a specific scenario
  Future<List<TrainingSession>> getScenarioSessions(
    String userId,
    String scenarioId,
  ) async {
    try {
      final sessionsQuery = await _firestore
          .collection(_sessionsCollection)
          .where('userId', isEqualTo: userId)
          .where('scenarioId', isEqualTo: scenarioId)
          .orderBy('startTime', descending: true)
          .get();

      return sessionsQuery.docs
          .map((doc) => TrainingSession.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('❌ [PROGRESS] Error getting scenario sessions: $e');
      return [];
    }
  }

  /// Check if user has unlocked a scenario
  Future<bool> isScenarioUnlocked(
    String userId,
    TrainingScenario scenario,
  ) async {
    try {
      // Restaurant scenarios are always unlocked for testing
      if (scenario.id == 'restaurant_beginner' || scenario.id == 'restaurant_advanced') return true;

      final userProgress = await getUserProgress(userId);
      if (userProgress == null) return false;

      // Check if user has required score from prerequisite scenarios
      if (scenario.requiredScore != null) {
        final totalScore = userProgress.totalPoints;
        return totalScore >= scenario.requiredScore!;
      }

      return scenario.isUnlocked;
    } catch (e) {
      debugPrint('❌ [PROGRESS] Error checking scenario unlock: $e');
      return false;
    }
  }

  /// Get user's mastered skills across all scenarios
  Future<List<String>> getUserMasteredSkills(String userId) async {
    try {
      final userProgress = await getUserProgress(userId);
      if (userProgress == null) return [];

      final allMasteredSkills = <String>{};

      for (final scenarioProgress in userProgress.scenarioProgress.values) {
        allMasteredSkills.addAll(scenarioProgress.masteredSkills);
      }

      return allMasteredSkills.toList();
    } catch (e) {
      debugPrint('❌ [PROGRESS] Error getting mastered skills: $e');
      return [];
    }
  }

  /// Get user's achievement progress
  Future<List<String>> getUserAchievements(String userId) async {
    try {
      final userProgress = await getUserProgress(userId);
      if (userProgress == null) return [];

      return userProgress.unlockedAchievements;
    } catch (e) {
      debugPrint('❌ [PROGRESS] Error getting achievements: $e');
      return [];
    }
  }

  /// Award achievement to user
  Future<void> awardAchievement(String userId, String achievementId) async {
    try {
      final userProgressRef = _firestore
          .collection(_userProgressCollection)
          .doc(userId);

      await _firestore.runTransaction((transaction) async {
        final userProgressDoc = await transaction.get(userProgressRef);

        if (!userProgressDoc.exists) return;

        final userProgress = UserProgress.fromJson(userProgressDoc.data()!);

        if (!userProgress.unlockedAchievements.contains(achievementId)) {
          final updatedAchievements = [
            ...userProgress.unlockedAchievements,
            achievementId,
          ];

          final updatedProgress = UserProgress(
            userId: userProgress.userId,
            scenarioProgress: userProgress.scenarioProgress,
            totalPoints: userProgress.totalPoints,
            currentLevel: userProgress.currentLevel,
            unlockedAchievements: updatedAchievements,
            stats: userProgress.stats,
            lastUpdated: DateTime.now(),
          );

          transaction.set(userProgressRef, updatedProgress.toJson());
        }
      });
    } catch (e) {
      debugPrint('❌ [PROGRESS] Error awarding achievement: $e');
    }
  }

  /// Get user's current level and progress to next level
  Future<Map<String, int>> getUserLevelInfo(String userId) async {
    try {
      final userProgress = await getUserProgress(userId);
      if (userProgress == null) {
        return {
          'currentLevel': 1,
          'currentLevelPoints': 0,
          'nextLevelPoints': 100,
        };
      }

      final currentLevel = userProgress.currentLevel;
      final totalPoints = userProgress.totalPoints;

      // Calculate level thresholds (exponential growth)
      final currentLevelThreshold = _calculateLevelThreshold(currentLevel);
      final nextLevelThreshold = _calculateLevelThreshold(currentLevel + 1);

      return {
        'currentLevel': currentLevel,
        'currentLevelPoints': totalPoints - currentLevelThreshold,
        'nextLevelPoints': nextLevelThreshold - currentLevelThreshold,
      };
    } catch (e) {
      debugPrint('❌ [PROGRESS] Error getting level info: $e');
      return {
        'currentLevel': 1,
        'currentLevelPoints': 0,
        'nextLevelPoints': 100,
      };
    }
  }

  /// Calculate level threshold for a given level
  int _calculateLevelThreshold(int level) {
    // Exponential progression: Level 1 = 0, Level 2 = 100, Level 3 = 250, etc.
    if (level <= 1) return 0;
    return (100 * (level - 1) * (level - 1) * 0.5).round();
  }

  /// Create initial progress for new user
  UserProgress _createInitialProgress(String userId) {
    return UserProgress(
      userId: userId,
      scenarioProgress: {},
      totalPoints: 0,
      currentLevel: 1,
      unlockedAchievements: [],
      stats: const ProgressStats(
        totalSessions: 0,
        totalMinutesPracticed: 0,
        currentStreak: 0,
        longestStreak: 0,
        averageSessionScore: 0.0,
        skillLevels: {},
      ),
      lastUpdated: DateTime.now(),
    );
  }

  /// Update scenario-specific progress
  Future<ScenarioProgress> _updateScenarioProgress(
    ScenarioProgress? currentProgress,
    AssessmentResult assessment,
    TrainingSession session,
  ) async {
    if (currentProgress == null) {
      return ScenarioProgress(
        scenarioId: session.scenarioId,
        sessionIds: [session.sessionId],
        bestScore: assessment.totalScore,
        averageScore: assessment.totalScore,
        totalAttempts: 1,
        firstAttempt: session.startTime,
        lastAttempt: session.startTime,
        masteredSkills: _extractMasteredSkills(assessment),
        needsImprovement: assessment.improvements,
        isCompleted:
            assessment.totalScore >= 90, // Updated completion threshold
        improvementRate: 0.0, // No improvement for first attempt
      );
    }

    final newBestScore = assessment.totalScore > currentProgress.bestScore
        ? assessment.totalScore
        : currentProgress.bestScore;

    final newAverageScore =
        ((currentProgress.averageScore * currentProgress.totalAttempts) +
            assessment.totalScore) /
        (currentProgress.totalAttempts + 1);

    final updatedMasteredSkills = <String>{
      ...currentProgress.masteredSkills,
      ..._extractMasteredSkills(assessment),
    }.toList();

    // Calculate improvement rate comparing first vs latest scores
    double improvementRate = 0.0;
    if (currentProgress.totalAttempts >= 1) {
      // Get the first session score - it's the oldest in the list
      final firstScore = currentProgress.sessionIds.isNotEmpty
          ? await getFirstSessionScore(session.userId, session.scenarioId) ??
                currentProgress.averageScore
          : currentProgress.averageScore;

      if (firstScore > 0) {
        improvementRate =
            ((assessment.totalScore - firstScore) / firstScore * 100).clamp(
              -100.0,
              100.0,
            );
      }
    }

    return ScenarioProgress(
      scenarioId: currentProgress.scenarioId,
      sessionIds: [...currentProgress.sessionIds, session.sessionId],
      bestScore: newBestScore,
      averageScore: newAverageScore.round(),
      totalAttempts: currentProgress.totalAttempts + 1,
      firstAttempt: currentProgress.firstAttempt,
      lastAttempt: session.startTime,
      masteredSkills: updatedMasteredSkills,
      needsImprovement: assessment.improvements,
      isCompleted: newBestScore >= 90, // Updated completion threshold
      improvementRate: improvementRate,
    );
  }

  /// Update overall user progress
  UserProgress _updateOverallProgress(
    UserProgress currentProgress,
    String scenarioId,
    ScenarioProgress updatedScenarioProgress,
    AssessmentResult assessment,
  ) {
    final updatedScenarioProgressMap = {
      ...currentProgress.scenarioProgress,
      scenarioId: updatedScenarioProgress,
    };

    // Calculate new total points
    final newTotalPoints = currentProgress.totalPoints + assessment.totalScore;

    // Calculate new level
    final newLevel = _calculateLevel(newTotalPoints);

    // Update statistics
    final updatedStats = _updateProgressStats(
      currentProgress.stats,
      assessment,
      currentProgress.totalPoints,
    );

    // Check for new achievements
    final newAchievements = _checkForNewAchievements(
      currentProgress,
      updatedScenarioProgress,
      assessment,
    );

    return UserProgress(
      userId: currentProgress.userId,
      scenarioProgress: updatedScenarioProgressMap,
      totalPoints: newTotalPoints,
      currentLevel: newLevel,
      unlockedAchievements: [
        ...currentProgress.unlockedAchievements,
        ...newAchievements,
      ],
      stats: updatedStats,
      lastUpdated: DateTime.now(),
    );
  }

  /// Calculate user level based on total points
  int _calculateLevel(int totalPoints) {
    int level = 1;
    while (_calculateLevelThreshold(level + 1) <= totalPoints) {
      level++;
    }
    return level;
  }

  /// Extract mastered skills from assessment
  List<String> _extractMasteredSkills(AssessmentResult assessment) {
    final masteredSkills = <String>[];

    if (assessment.allergyDisclosureScore >= 12)
      masteredSkills.add('Allergy Disclosure');
    if (assessment.clarityScore >= 8) masteredSkills.add('Clear Communication');
    if (assessment.proactivenessScore >= 12)
      masteredSkills.add('Proactive Questioning');
    if (assessment.ingredientInquiryScore >= 12)
      masteredSkills.add('Ingredient Inquiry');
    if (assessment.riskAssessmentScore >= 12)
      masteredSkills.add('Risk Assessment');
    if (assessment.confidenceScore >= 8) masteredSkills.add('Confidence');
    if (assessment.politenessScore >= 9) masteredSkills.add('Politeness');

    return masteredSkills;
  }

  /// Update progress statistics
  ProgressStats _updateProgressStats(
    ProgressStats currentStats,
    AssessmentResult assessment,
    int previousTotalPoints,
  ) {
    final newTotalSessions = currentStats.totalSessions + 1;
    final newAverageScore =
        ((currentStats.averageSessionScore * currentStats.totalSessions) +
            assessment.totalScore) /
        newTotalSessions;

    // Update skill levels based on assessment
    final updatedSkillLevels = Map<String, int>.from(currentStats.skillLevels);

    if (assessment.allergyDisclosureScore >= 12) {
      updatedSkillLevels['allergyDisclosure'] =
          (updatedSkillLevels['allergyDisclosure'] ?? 0) + 1;
    }
    if (assessment.clarityScore >= 8) {
      updatedSkillLevels['clarity'] = (updatedSkillLevels['clarity'] ?? 0) + 1;
    }
    if (assessment.proactivenessScore >= 12) {
      updatedSkillLevels['proactiveness'] =
          (updatedSkillLevels['proactiveness'] ?? 0) + 1;
    }

    return ProgressStats(
      totalSessions: newTotalSessions,
      totalMinutesPracticed:
          currentStats.totalMinutesPracticed +
          (assessment.totalScore > 60 ? 5 : 3), // Estimate based on performance
      currentStreak: assessment.totalScore >= 70
          ? currentStats.currentStreak + 1
          : 0,
      longestStreak: assessment.totalScore >= 70
          ? (currentStats.currentStreak + 1 > currentStats.longestStreak
                ? currentStats.currentStreak + 1
                : currentStats.longestStreak)
          : currentStats.longestStreak,
      averageSessionScore: newAverageScore,
      skillLevels: updatedSkillLevels,
    );
  }

  /// Check for new achievements
  List<String> _checkForNewAchievements(
    UserProgress currentProgress,
    ScenarioProgress updatedScenarioProgress,
    AssessmentResult assessment,
  ) {
    final newAchievements = <String>[];

    // First completion achievement
    if (updatedScenarioProgress.totalAttempts == 1 &&
        assessment.totalScore >= 80) {
      newAchievements.add('first_perfect_score');
    }

    // Improvement achievement
    if (updatedScenarioProgress.totalAttempts > 1 &&
        assessment.totalScore >
            updatedScenarioProgress.bestScore - assessment.totalScore) {
      newAchievements.add('improvement_master');
    }

    // Consistency achievement
    if (updatedScenarioProgress.totalAttempts >= 3 &&
        updatedScenarioProgress.averageScore >= 75) {
      newAchievements.add('consistency_champion');
    }

    // Allergy disclosure master
    if (assessment.allergyDisclosureScore >= 15) {
      newAchievements.add('allergy_disclosure_master');
    }

    return newAchievements;
  }

  /// Stream user progress updates
  Stream<UserProgress?> watchUserProgress(String userId) {
    return _firestore
        .collection(_userProgressCollection)
        .doc(userId)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) return null;
          return UserProgress.fromJson(snapshot.data()!);
        });
  }

  /// Get leaderboard data
  Future<List<Map<String, dynamic>>> getLeaderboard({int limit = 10}) async {
    try {
      final leaderboardQuery = await _firestore
          .collection(_userProgressCollection)
          .orderBy('totalPoints', descending: true)
          .limit(limit)
          .get();

      return leaderboardQuery.docs
          .map(
            (doc) => {
              'userId': doc.id,
              'totalPoints': doc.data()['totalPoints'],
              'currentLevel': doc.data()['currentLevel'],
              'lastUpdated': doc.data()['lastUpdated'],
            },
          )
          .toList();
    } catch (e) {
      debugPrint('❌ [PROGRESS] Error getting leaderboard: $e');
      return [];
    }
  }

  /// Get the latest session score for a scenario
  Future<int?> getLatestSessionScore(String userId, String scenarioId) async {
    try {
      final sessions = await getScenarioSessions(userId, scenarioId);
      if (sessions.isEmpty) return null;

      // Get the most recent session (first in the list since it's ordered by startTime descending)
      final latestSession = sessions.first;
      return latestSession.finalAssessment?.totalScore;
    } catch (e) {
      debugPrint('❌ [PROGRESS] Error getting latest session score: $e');
      return null;
    }
  }

  /// Get the first session score for a scenario
  Future<int?> getFirstSessionScore(String userId, String scenarioId) async {
    try {
      final sessions = await getScenarioSessions(userId, scenarioId);
      if (sessions.isEmpty) return null;

      // Get the oldest session (last in the list since it's ordered by startTime descending)
      final firstSession = sessions.last;
      return firstSession.finalAssessment?.totalScore;
    } catch (e) {
      debugPrint('❌ [PROGRESS] Error getting first session score: $e');
      return null;
    }
  }

  /// Calculate proper improvement rate comparing first vs latest scores
  Future<double> calculateImprovementRate(
    String userId,
    String scenarioId,
  ) async {
    try {
      final sessions = await getScenarioSessions(userId, scenarioId);
      if (sessions.length < 2) return 0.0;

      final firstScore = sessions.last.finalAssessment?.totalScore ?? 0;
      final latestScore = sessions.first.finalAssessment?.totalScore ?? 0;

      if (firstScore == 0) return 0.0;

      final improvement = ((latestScore - firstScore) / firstScore * 100).clamp(
        -100.0,
        100.0,
      );
      return improvement;
    } catch (e) {
      debugPrint('❌ [PROGRESS] Error calculating improvement rate: $e');
      return 0.0;
    }
  }
}
