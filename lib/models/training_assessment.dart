import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a complete training session
class TrainingSession {
  final String sessionId;
  final String userId;
  final String scenarioId;
  final DateTime startTime;
  final DateTime? endTime;
  final List<ConversationTurn> conversationTurns;
  final AssessmentResult? finalAssessment;
  final SessionStatus status;
  final int durationMinutes;

  const TrainingSession({
    required this.sessionId,
    required this.userId,
    required this.scenarioId,
    required this.startTime,
    this.endTime,
    required this.conversationTurns,
    this.finalAssessment,
    required this.status,
    this.durationMinutes = 0,
  });

  factory TrainingSession.fromJson(Map<String, dynamic> json) {
    return TrainingSession(
      sessionId: json['sessionId'],
      userId: json['userId'],
      scenarioId: json['scenarioId'],
      startTime: (json['startTime'] as Timestamp).toDate(),
      endTime: json['endTime'] != null
          ? (json['endTime'] as Timestamp).toDate()
          : null,
      conversationTurns:
          (json['conversationTurns'] as List?)
              ?.map((turn) => ConversationTurn.fromJson(turn))
              .toList() ??
          [],
      finalAssessment: json['finalAssessment'] != null
          ? AssessmentResult.fromJson(json['finalAssessment'])
          : null,
      status: SessionStatus.values.firstWhere(
        (status) => status.name == json['status'],
        orElse: () => SessionStatus.inProgress,
      ),
      durationMinutes: json['durationMinutes'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'userId': userId,
      'scenarioId': scenarioId,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'conversationTurns': conversationTurns
          .map((turn) => turn.toJson())
          .toList(),
      'finalAssessment': finalAssessment?.toJson(),
      'status': status.name,
      'durationMinutes': durationMinutes,
    };
  }
}

/// Individual conversation turn in a training session
class ConversationTurn {
  final String userInput;
  final String aiResponse;
  final List<String> detectedAllergies;
  final DateTime timestamp;
  final TurnAssessment assessment;
  final int turnNumber;

  const ConversationTurn({
    required this.userInput,
    required this.aiResponse,
    required this.detectedAllergies,
    required this.timestamp,
    required this.assessment,
    required this.turnNumber,
  });

  factory ConversationTurn.fromJson(Map<String, dynamic> json) {
    return ConversationTurn(
      userInput: json['userInput'],
      aiResponse: json['aiResponse'],
      detectedAllergies: List<String>.from(json['detectedAllergies'] ?? []),
      timestamp: (json['timestamp'] as Timestamp).toDate(),
      assessment: TurnAssessment.fromJson(json['assessment']),
      turnNumber: json['turnNumber'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userInput': userInput,
      'aiResponse': aiResponse,
      'detectedAllergies': detectedAllergies,
      'timestamp': Timestamp.fromDate(timestamp),
      'assessment': assessment.toJson(),
      'turnNumber': turnNumber,
    };
  }
}

/// Assessment for individual conversation turn
class TurnAssessment {
  final int allergyMentionScore;
  final int clarityScore;
  final int proactivenessScore;
  final bool mentionedAllergies;
  final bool askedQuestions;
  final List<String> detectedSkills;

  const TurnAssessment({
    required this.allergyMentionScore,
    required this.clarityScore,
    required this.proactivenessScore,
    required this.mentionedAllergies,
    required this.askedQuestions,
    required this.detectedSkills,
  });

  factory TurnAssessment.fromJson(Map<String, dynamic> json) {
    return TurnAssessment(
      allergyMentionScore: json['allergyMentionScore'],
      clarityScore: json['clarityScore'],
      proactivenessScore: json['proactivenessScore'],
      mentionedAllergies: json['mentionedAllergies'],
      askedQuestions: json['askedQuestions'],
      detectedSkills: List<String>.from(json['detectedSkills'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'allergyMentionScore': allergyMentionScore,
      'clarityScore': clarityScore,
      'proactivenessScore': proactivenessScore,
      'mentionedAllergies': mentionedAllergies,
      'askedQuestions': askedQuestions,
      'detectedSkills': detectedSkills,
    };
  }
}

/// Comprehensive assessment result for the entire session
class AssessmentResult {
  // Core Communication Skills (40 points max)
  final int allergyDisclosureScore; // 0-15 points
  final int clarityScore; // 0-10 points
  final int proactivenessScore; // 0-15 points

  // Safety Awareness (30 points max)
  final int ingredientInquiryScore; // 0-15 points
  final int riskAssessmentScore; // 0-15 points

  // Social Skills (20 points max)
  final int confidenceScore; // 0-10 points
  final int politenessScore; // 0-10 points

  // Bonus Points (10 points max)
  final int completionBonus; // 0-5 points
  final int improvementBonus; // 0-5 points

  // Penalty Points
  final int unsafeOrderPenalty; // -30 points for ordering unsafe food

  // Advanced Level Additional Fields
  final int crossContaminationScore; // 0-20 points for advanced
  final int hiddenAllergenScore; // 0-20 points for advanced
  final int preparationMethodScore; // 0-15 points for advanced
  final int specificIngredientScore; // 0-10 points for advanced
  final List<String> missedActions; // Actions user forgot to perform
  final List<String> earnedBonuses; // Bonus actions performed
  final Map<String, int> detailedScores; // Category breakdown
  final bool isAdvancedLevel; // Flag to determine scoring display

  final int totalScore; // 0-100 points (beginner) or 0-200 points (advanced)
  final String overallGrade; // A+, A, B+, B, C+, C, D
  final List<String> strengths;
  final List<String> improvements;
  final String detailedFeedback;
  final DateTime assessedAt;

  const AssessmentResult({
    required this.allergyDisclosureScore,
    required this.clarityScore,
    required this.proactivenessScore,
    required this.ingredientInquiryScore,
    required this.riskAssessmentScore,
    required this.confidenceScore,
    required this.politenessScore,
    required this.completionBonus,
    required this.improvementBonus,
    this.unsafeOrderPenalty = 0,
    this.crossContaminationScore = 0,
    this.hiddenAllergenScore = 0,
    this.preparationMethodScore = 0,
    this.specificIngredientScore = 0,
    this.missedActions = const [],
    this.earnedBonuses = const [],
    this.detailedScores = const {},
    this.isAdvancedLevel = false,
    required this.totalScore,
    required this.overallGrade,
    required this.strengths,
    required this.improvements,
    required this.detailedFeedback,
    required this.assessedAt,
  });

  factory AssessmentResult.fromJson(Map<String, dynamic> json) {
    return AssessmentResult(
      allergyDisclosureScore: json['allergyDisclosureScore'],
      clarityScore: json['clarityScore'],
      proactivenessScore: json['proactivenessScore'],
      ingredientInquiryScore: json['ingredientInquiryScore'],
      riskAssessmentScore: json['riskAssessmentScore'],
      confidenceScore: json['confidenceScore'],
      politenessScore: json['politenessScore'],
      completionBonus: json['completionBonus'],
      improvementBonus: json['improvementBonus'],
      unsafeOrderPenalty: json['unsafeOrderPenalty'] ?? 0,
      crossContaminationScore: json['crossContaminationScore'] ?? 0,
      hiddenAllergenScore: json['hiddenAllergenScore'] ?? 0,
      preparationMethodScore: json['preparationMethodScore'] ?? 0,
      specificIngredientScore: json['specificIngredientScore'] ?? 0,
      missedActions: List<String>.from(json['missedActions'] ?? []),
      earnedBonuses: List<String>.from(json['earnedBonuses'] ?? []),
      detailedScores: Map<String, int>.from(json['detailedScores'] ?? {}),
      isAdvancedLevel: json['isAdvancedLevel'] ?? false,
      totalScore: json['totalScore'],
      overallGrade: json['overallGrade'],
      strengths: List<String>.from(json['strengths'] ?? []),
      improvements: List<String>.from(json['improvements'] ?? []),
      detailedFeedback: json['detailedFeedback'],
      assessedAt: (json['assessedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'allergyDisclosureScore': allergyDisclosureScore,
      'clarityScore': clarityScore,
      'proactivenessScore': proactivenessScore,
      'ingredientInquiryScore': ingredientInquiryScore,
      'riskAssessmentScore': riskAssessmentScore,
      'confidenceScore': confidenceScore,
      'politenessScore': politenessScore,
      'completionBonus': completionBonus,
      'improvementBonus': improvementBonus,
      'unsafeOrderPenalty': unsafeOrderPenalty,
      'crossContaminationScore': crossContaminationScore,
      'hiddenAllergenScore': hiddenAllergenScore,
      'preparationMethodScore': preparationMethodScore,
      'specificIngredientScore': specificIngredientScore,
      'missedActions': missedActions,
      'earnedBonuses': earnedBonuses,
      'detailedScores': detailedScores,
      'isAdvancedLevel': isAdvancedLevel,
      'totalScore': totalScore,
      'overallGrade': overallGrade,
      'strengths': strengths,
      'improvements': improvements,
      'detailedFeedback': detailedFeedback,
      'assessedAt': Timestamp.fromDate(assessedAt),
    };
  }

  /// Calculate communication skills subtotal
  int get communicationScore =>
      allergyDisclosureScore + clarityScore + proactivenessScore;

  /// Calculate safety awareness subtotal
  int get safetyScore => ingredientInquiryScore + riskAssessmentScore;

  /// Calculate social skills subtotal
  int get socialScore => confidenceScore + politenessScore;

  /// Calculate bonus points subtotal
  int get bonusScore => completionBonus + improvementBonus;
}

/// User's progress across all scenarios
class UserProgress {
  final String userId;
  final Map<String, ScenarioProgress> scenarioProgress;
  final int totalPoints;
  final int currentLevel;
  final List<String> unlockedAchievements;
  final ProgressStats stats;
  final DateTime lastUpdated;

  const UserProgress({
    required this.userId,
    required this.scenarioProgress,
    required this.totalPoints,
    required this.currentLevel,
    required this.unlockedAchievements,
    required this.stats,
    required this.lastUpdated,
  });

  factory UserProgress.fromJson(Map<String, dynamic> json) {
    return UserProgress(
      userId: json['userId'],
      scenarioProgress: Map<String, ScenarioProgress>.from(
        (json['scenarioProgress'] as Map<String, dynamic>? ?? {}).map(
          (key, value) => MapEntry(key, ScenarioProgress.fromJson(value)),
        ),
      ),
      totalPoints: json['totalPoints'],
      currentLevel: json['currentLevel'],
      unlockedAchievements: List<String>.from(
        json['unlockedAchievements'] ?? [],
      ),
      stats: ProgressStats.fromJson(json['stats']),
      lastUpdated: (json['lastUpdated'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'scenarioProgress': scenarioProgress.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
      'totalPoints': totalPoints,
      'currentLevel': currentLevel,
      'unlockedAchievements': unlockedAchievements,
      'stats': stats.toJson(),
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }
}

/// Progress tracking for individual scenarios
class ScenarioProgress {
  final String scenarioId;
  final List<String> sessionIds;
  final int bestScore;
  final int averageScore;
  final int totalAttempts;
  final DateTime firstAttempt;
  final DateTime lastAttempt;
  final List<String> masteredSkills;
  final List<String> needsImprovement;
  final bool isCompleted;
  final double improvementRate; // Store calculated improvement rate

  const ScenarioProgress({
    required this.scenarioId,
    required this.sessionIds,
    required this.bestScore,
    required this.averageScore,
    required this.totalAttempts,
    required this.firstAttempt,
    required this.lastAttempt,
    required this.masteredSkills,
    required this.needsImprovement,
    required this.isCompleted,
    this.improvementRate = 0.0,
  });

  factory ScenarioProgress.fromJson(Map<String, dynamic> json) {
    return ScenarioProgress(
      scenarioId: json['scenarioId'],
      sessionIds: List<String>.from(json['sessionIds'] ?? []),
      bestScore: json['bestScore'],
      averageScore: json['averageScore'],
      totalAttempts: json['totalAttempts'],
      firstAttempt: (json['firstAttempt'] as Timestamp).toDate(),
      lastAttempt: (json['lastAttempt'] as Timestamp).toDate(),
      masteredSkills: List<String>.from(json['masteredSkills'] ?? []),
      needsImprovement: List<String>.from(json['needsImprovement'] ?? []),
      isCompleted: json['isCompleted'] ?? false,
      improvementRate: json['improvementRate']?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'scenarioId': scenarioId,
      'sessionIds': sessionIds,
      'bestScore': bestScore,
      'averageScore': averageScore,
      'totalAttempts': totalAttempts,
      'firstAttempt': Timestamp.fromDate(firstAttempt),
      'lastAttempt': Timestamp.fromDate(lastAttempt),
      'masteredSkills': masteredSkills,
      'needsImprovement': needsImprovement,
      'isCompleted': isCompleted,
      'improvementRate': improvementRate,
    };
  }
}

/// Overall progress statistics
class ProgressStats {
  final int totalSessions;
  final int totalMinutesPracticed;
  final int currentStreak;
  final int longestStreak;
  final double averageSessionScore;
  final Map<String, int> skillLevels;

  const ProgressStats({
    required this.totalSessions,
    required this.totalMinutesPracticed,
    required this.currentStreak,
    required this.longestStreak,
    required this.averageSessionScore,
    required this.skillLevels,
  });

  factory ProgressStats.fromJson(Map<String, dynamic> json) {
    return ProgressStats(
      totalSessions: json['totalSessions'],
      totalMinutesPracticed: json['totalMinutesPracticed'],
      currentStreak: json['currentStreak'],
      longestStreak: json['longestStreak'],
      averageSessionScore: json['averageSessionScore']?.toDouble() ?? 0.0,
      skillLevels: Map<String, int>.from(json['skillLevels'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalSessions': totalSessions,
      'totalMinutesPracticed': totalMinutesPracticed,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'averageSessionScore': averageSessionScore,
      'skillLevels': skillLevels,
    };
  }
}

/// Session status enumeration
enum SessionStatus { inProgress, completed, abandoned, failed }

/// Communication skills that can be assessed
enum CommunicationSkill {
  allergyDisclosure,
  clarityOfSpeech,
  proactiveQuestioning,
  ingredientInquiry,
  riskAssessment,
  confidence,
  politeness,
}
