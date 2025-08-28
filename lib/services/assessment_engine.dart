import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/training_assessment.dart';
import '../models/game_state.dart';
import '../models/scenario_config.dart';
import '../core/config/app_config.dart';
import 'openai_dialogue_service.dart';
import '../models/scenario_models.dart';
import 'menu_service.dart';
import 'scoring_engine.dart';
import 'feedback_builder.dart';

/// Advanced assessment engine that analyzes AI conversations for training effectiveness
class AssessmentEngine {
  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';

  /// NEW: Assess training session using the enhanced level-based scoring system
  static Future<AssessmentResult> assessTrainingSessionEnhanced({
    required List<ConversationTurn> conversationTurns,
    required PlayerProfile playerProfile,
    required DifficultyLevel level,
    required ConversationContext conversationContext,
    required String scenarioId,
    required DateTime sessionStart,
    required DateTime sessionEnd,
  }) async {
    debugPrint(
      '🎯 [ASSESSMENT] Starting enhanced assessment for level: $level',
    );

    try {
      // Use the new scoring engine
      var assessmentResult = await ScoringEngine.scoreTrainingSession(
        conversationTurns: conversationTurns,
        playerProfile: playerProfile,
        level: level,
        conversationContext: conversationContext,
        scenarioId: scenarioId,
        sessionStart: sessionStart,
        sessionEnd: sessionEnd,
      );

      // Generate enhanced feedback using FeedbackBuilder
      final feedbackResult = FeedbackBuilder.generateFeedback(
        assessment: assessmentResult,
        level: level,
      );

      // Return updated assessment with enhanced feedback (replacing duplicates)
      return AssessmentResult(
        allergyDisclosureScore: assessmentResult.allergyDisclosureScore,
        clarityScore: assessmentResult.clarityScore,
        proactivenessScore: assessmentResult.proactivenessScore,
        ingredientInquiryScore: assessmentResult.ingredientInquiryScore,
        riskAssessmentScore: assessmentResult.riskAssessmentScore,
        confidenceScore: assessmentResult.confidenceScore,
        politenessScore: assessmentResult.politenessScore,
        completionBonus: assessmentResult.completionBonus,
        improvementBonus: assessmentResult.improvementBonus,
        unsafeOrderPenalty: assessmentResult.unsafeOrderPenalty,
        crossContaminationScore: assessmentResult.crossContaminationScore,
        hiddenAllergenScore: assessmentResult.hiddenAllergenScore,
        preparationMethodScore: assessmentResult.preparationMethodScore,
        specificIngredientScore: assessmentResult.specificIngredientScore,
        missedActions: assessmentResult.missedActions,
        earnedBonuses: assessmentResult.earnedBonuses,
        detailedScores: assessmentResult.detailedScores,
        isAdvancedLevel: assessmentResult.isAdvancedLevel,
        totalScore: assessmentResult.totalScore,
        overallGrade: assessmentResult.overallGrade,
        strengths: feedbackResult
            .strengths, // Use FeedbackBuilder strengths (replaces ScoringEngine ones)
        improvements: feedbackResult
            .improvements, // Use FeedbackBuilder improvements (replaces ScoringEngine ones)
        detailedFeedback: feedbackResult.feedbackParagraph,
        assessedAt: assessmentResult.assessedAt,
        level: assessmentResult.level,
        maxPossibleScore: assessmentResult.maxPossibleScore,
        passingScore: assessmentResult.passingScore,
        criticalFailure: assessmentResult.criticalFailure,
      );
    } catch (e) {
      debugPrint('[ASSESSMENT] Enhanced assessment failed: $e');
      // Fallback to legacy assessment
      final assessmentEngine = AssessmentEngine();
      return await assessmentEngine.assessTrainingSession(
        conversationTurns: conversationTurns,
        playerProfile: playerProfile,
        scenarioId: scenarioId,
        sessionStart: sessionStart,
        sessionEnd: sessionEnd,
        conversationContext: conversationContext,
      );
    }
  }

  /// LEGACY: Assess a complete training session and generate comprehensive feedback
  Future<AssessmentResult> assessTrainingSession({
    required List<ConversationTurn> conversationTurns,
    required PlayerProfile playerProfile,
    required String scenarioId,
    required DateTime sessionStart,
    required DateTime sessionEnd,
    required ConversationContext conversationContext,
    ScenarioConfig? scenarioConfig,
  }) async {
    try {
      // Use scenario-specific assessment if available
      if (scenarioConfig != null) {
        return await _assessWithScenarioConfig(
          conversationTurns,
          playerProfile,
          scenarioId,
          sessionStart,
          sessionEnd,
          conversationContext,
          scenarioConfig,
        );
      }

      // FALLBACK: ENHANCED BEGINNER ASSESSMENT - Focus on key skills:
      // 1. Did they mention their allergies? (0-70 points)
      // 2. Did they order safe food? (0-30 points)
      // 3. Did they ask about ingredients? (+5 bonus points)
      // 4. Penalty for unsafe orders (-30 points)
      // 5. Partial credit for correcting unsafe orders

      bool mentionedAllergies = false;
      bool orderedSafeFood = false;
      bool orderedUnsafeFood = false;
      bool askedAboutIngredients = false;
      bool correctedUnsafeOrder = false;
      String? selectedDish;
      List<String> unsafeAllergens = [];

      // Load menu for enhanced safety checking
      await MenuService.instance.loadMenu();

      // Check if allergies were disclosed through context or conversation analysis

      // FIXED: Use conversation context state if available, otherwise fall back to text analysis
      if (conversationContext.allergiesDisclosed ||
          conversationContext.selectedDish != null) {
        // Use the reliable conversation context state
        mentionedAllergies = conversationContext.allergiesDisclosed;
        selectedDish = conversationContext.selectedDish;

        // Enhanced safety checking using MenuService
        if (selectedDish != null) {
          final menuItem = MenuService.instance.findItemByName(selectedDish);
          if (menuItem != null) {
            final isSafe = MenuService.instance.isItemSafeForUser(
              menuItem,
              playerProfile.allergies,
            );

            if (isSafe) {
              orderedSafeFood = true;
            } else {
              orderedUnsafeFood = true;
              // Get specific allergens that make it unsafe
              final allAllergens = [
                ...menuItem.allergens,
                ...menuItem.hiddenAllergens,
              ];
              for (final allergen in allAllergens) {
                for (final userAllergy in playerProfile.allergies) {
                  if (allergen.toLowerCase().contains(
                        userAllergy.toLowerCase(),
                      ) ||
                      userAllergy.toLowerCase().contains(
                        allergen.toLowerCase(),
                      )) {
                    unsafeAllergens.add(allergen);
                  }
                }
              }
            }
          } else {
            // Fallback to old method if menu item not found
            final dishAllergens = _getDishAllergens(selectedDish);
            final userAllergens = playerProfile.allergies
                .map((a) => _normalizeAllergen(a.toLowerCase()))
                .toSet();

            bool containsUserAllergens = false;
            for (final allergen in dishAllergens) {
              if (userAllergens.contains(
                _normalizeAllergen(allergen.toLowerCase()),
              )) {
                containsUserAllergens = true;
                unsafeAllergens.add(allergen);
              }
            }

            if (containsUserAllergens) {
              orderedUnsafeFood = true;
              orderedSafeFood = false;
            } else {
              orderedSafeFood = true;
            }
          }
        }

        // Check if user asked about ingredients
        for (final turn in conversationTurns) {
          final userInput = turn.userInput.toLowerCase();
          if (userInput.contains('ingredient') ||
              userInput.contains('contain') ||
              userInput.contains('made with') ||
              userInput.contains('what\'s in') ||
              userInput.contains('what is in') ||
              userInput.contains('does it have') ||
              userInput.contains('is there') ||
              userInput.contains('any ') &&
                  (userInput.contains('allergen') ||
                      userInput.contains('dairy') ||
                      userInput.contains('egg') ||
                      userInput.contains('nut') ||
                      userInput.contains('fish'))) {
            askedAboutIngredients = true;
            break;
          }
        }

        // Check for order correction (if they initially ordered unsafe, then changed)
        String? firstOrder;
        for (final turn in conversationTurns) {
          final userInput = turn.userInput.toLowerCase();
          if ((userInput.contains('i\'ll have') ||
                  userInput.contains('i want') ||
                  userInput.contains('i\'d like')) &&
              firstOrder == null) {
            firstOrder = selectedDish;
          } else if ((userInput.contains('actually') ||
                  userInput.contains('instead') ||
                  userInput.contains('change') ||
                  userInput.contains('different')) &&
              (userInput.contains('i\'ll have') ||
                  userInput.contains('i want'))) {
            correctedUnsafeOrder = true;
            break;
          }
        }
      } else {
        // Fall back to text analysis for older sessions
        // FIXED: Check if allergies were actually disclosed using proper logic
        for (final turn in conversationTurns) {
          if (_isActuallyDisclosingAllergies(
            turn.userInput.toLowerCase(),
            playerProfile.allergies,
          )) {
            mentionedAllergies = true;

            break;
          }
        }

        // Check if they ordered food and analyze safety
        for (final turn in conversationTurns) {
          final userInput = turn.userInput.toLowerCase();

          // Check if they ordered something
          if (userInput.contains('i\'ll have') ||
              userInput.contains('i will have') ||
              userInput.contains('i want') ||
              userInput.contains('i\'d like') ||
              userInput.contains('i would like') ||
              userInput.contains('i\'ll take') ||
              userInput.contains('i will take') ||
              userInput.contains('order')) {
            // Extract dish and check safety
            if (userInput.contains('salad')) {
              selectedDish = 'Caesar Salad';
              // Check if Caesar salad contains allergens
              if (playerProfile.allergies.contains('Eggs')) {
                orderedUnsafeFood = true;
                unsafeAllergens.add('Eggs');
              }
            } else if (userInput.contains('veggie') ||
                userInput.contains('vegetable')) {
              selectedDish = 'Grilled Veggie Bowl';
              orderedSafeFood = true; // Generally safe
            } else if (userInput.contains('chicken')) {
              selectedDish = 'Grilled Chicken';
              orderedSafeFood = true; // Generally safe
            } else if (userInput.contains('fish')) {
              selectedDish = 'Fish & Chips';
              // Check if they're allergic to fish
              if (playerProfile.allergies.contains('Fish')) {
                orderedUnsafeFood = true;
                unsafeAllergens.add('Fish');
              } else {
                orderedSafeFood = true;
              }
            } else if (userInput.contains('soup')) {
              selectedDish = 'Tomato Soup';
              orderedSafeFood = true; // Generally safe
            } else if (userInput.contains('brownie') ||
                userInput.contains('chocolate')) {
              selectedDish = 'Chocolate Brownie';
              // Chocolate brownie typically contains milk and eggs
              final brownieAllergens = ['Milk', 'Eggs'];
              bool hasAllergenInBrownie = false;
              for (final allergen in brownieAllergens) {
                if (playerProfile.allergies.contains(allergen)) {
                  orderedUnsafeFood = true;
                  unsafeAllergens.add(allergen);
                  hasAllergenInBrownie = true;
                }
              }
              if (!hasAllergenInBrownie) {
                orderedSafeFood = true;
              }
            }
            break;
          }
        }

        // If they mentioned allergies but didn't order anything unsafe, check AI confirmation
        if (mentionedAllergies && !orderedUnsafeFood && selectedDish != null) {
          for (final turn in conversationTurns) {
            if (turn.aiResponse.toLowerCase().contains('safe') ||
                turn.aiResponse.toLowerCase().contains('free from') ||
                turn.aiResponse.toLowerCase().contains('doesn\'t contain')) {
              orderedSafeFood = true;
              break;
            }
          }
        }
      }

      // Enhanced scoring system
      final allergyScore = mentionedAllergies ? 70 : 0;
      final safetyScore = orderedSafeFood ? 30 : 0;
      final ingredientBonus = askedAboutIngredients ? 5 : 0;
      final correctionCredit = correctedUnsafeOrder
          ? 10
          : 0; // Partial credit for correction
      final unsafeOrderPenalty = orderedUnsafeFood && !correctedUnsafeOrder
          ? -30
          : 0;

      final totalScore =
          (allergyScore +
                  safetyScore +
                  ingredientBonus +
                  correctionCredit +
                  unsafeOrderPenalty)
              .clamp(0, 100);

      // Generate feedback
      final strengths = <String>[];
      final improvements = <String>[];

      if (mentionedAllergies) {
        strengths.add('Mentioned your allergies');
      } else {
        improvements.add('Always tell the waiter about your allergies');
      }

      if (orderedSafeFood) {
        strengths.add('Ordered safe food');
      } else if (orderedUnsafeFood) {
        if (correctedUnsafeOrder) {
          strengths.add('Corrected unsafe order after waiter warning');
          improvements.add(
            'Try to ask about ingredients before ordering to avoid unsafe choices',
          );
        } else {
          improvements.add(
            'Ordered food containing your allergens (${unsafeAllergens.join(', ')})',
          );
          improvements.add('Always check ingredients before ordering');
        }
      } else {
        improvements.add('Ask about ingredients before ordering');
      }

      if (askedAboutIngredients) {
        strengths.add('Asked about ingredients');
      } else if (orderedSafeFood && !mentionedAllergies) {
        improvements.add(
          'Ask about ingredients even for seemingly safe dishes',
        );
      }

      String feedback;

      if (orderedUnsafeFood && !correctedUnsafeOrder) {
        feedback =
            'SAFETY CONCERN: You ordered $selectedDish which contains ${unsafeAllergens.join(' and ')}, but you\'re allergic to ${unsafeAllergens.join(' and ')}! ${mentionedAllergies ? 'Even though you mentioned your allergies, ' : ''}always make sure to avoid foods with your allergens.';
      } else if (totalScore >= 90) {
        feedback =
            'Excellent! You communicated your allergies clearly and ordered safely. ${askedAboutIngredients ? 'Great job asking about ingredients!' : ''}';
      } else if (totalScore >= 70) {
        feedback =
            'Good job! You mentioned your allergies. ${orderedSafeFood ? 'Great choice ordering safe food!' : 'Next time, make sure to verify your order is safe.'} ${askedAboutIngredients ? 'Asking about ingredients shows good safety awareness.' : 'Consider asking about ingredients to be extra safe.'}';
      } else if (correctedUnsafeOrder) {
        feedback =
            'Good recovery! You listened to the waiter\'s warning and changed your order to something safe. Next time, try asking about ingredients before ordering to avoid this situation.';
      } else if (totalScore >= 30) {
        feedback =
            'You ordered food, but remember to always mention your allergies first! ${askedAboutIngredients ? 'Good job asking about ingredients.' : 'Also ask about ingredients to ensure safety.'}';
      } else {
        feedback =
            'Keep practicing! Remember to mention your allergies and ask about safe options.';
      }

      // FIXED: Use proper scoring structure for feedback screen (removed letter grades)
      final result = AssessmentResult(
        allergyDisclosureScore: allergyScore, // 70 or 0
        clarityScore: 0,
        proactivenessScore: 0,
        ingredientInquiryScore: 0,
        riskAssessmentScore: safetyScore, // 30 or 0
        confidenceScore: 0,
        politenessScore: 0,
        completionBonus: 0,
        improvementBonus: 0,
        totalScore: totalScore,
        overallGrade: '', // Removed letter grades
        strengths: strengths,
        improvements: improvements,
        detailedFeedback: feedback,
        assessedAt: DateTime.now(),
        unsafeOrderPenalty: unsafeOrderPenalty, // Add penalty to result
      );

      return result;
    } catch (e) {
      return _getFallbackAssessment();
    }
  }

  /// Assess individual conversation turn in real-time
  Future<TurnAssessment> _assessConversationTurn(
    ConversationTurn turn,
    PlayerProfile playerProfile,
    int turnNumber,
  ) async {
    try {
      // Analyze user input for various aspects
      final allergyMentioned = _checkAllergyMention(
        turn.userInput,
        playerProfile.allergies,
      );
      final askedQuestions = _checkQuestionAsking(turn.userInput);
      final clarityScore = _assessClarity(turn.userInput);
      final proactivenessScore = _assessProactiveness(
        turn.userInput,
        turnNumber,
      );

      final detectedSkills = <String>[];
      if (allergyMentioned) detectedSkills.add('Allergy Disclosure');
      if (askedQuestions) detectedSkills.add('Proactive Questioning');
      if (clarityScore >= 8) detectedSkills.add('Clear Communication');

      return TurnAssessment(
        allergyMentionScore: allergyMentioned ? 10 : 0,
        clarityScore: clarityScore,
        proactivenessScore: proactivenessScore,
        mentionedAllergies: allergyMentioned,
        askedQuestions: askedQuestions,
        detectedSkills: detectedSkills,
      );
    } catch (e) {
      return const TurnAssessment(
        allergyMentionScore: 0,
        clarityScore: 5,
        proactivenessScore: 0,
        mentionedAllergies: false,
        askedQuestions: false,
        detectedSkills: [],
      );
    }
  }

  /// Generate overall assessment using AI
  Future<Map<String, dynamic>> _generateOverallAssessment(
    List<ConversationTurn> conversationTurns,
    List<TurnAssessment> turnAssessments,
    PlayerProfile playerProfile,
    String scenarioId,
  ) async {
    try {
      final prompt = _buildAssessmentPrompt(
        conversationTurns,
        turnAssessments,
        playerProfile,
      );

      final response = await _sendAssessmentRequest(prompt);
      return jsonDecode(response);
    } catch (e) {
      return {
        'confidence': 6,
        'politeness': 8,
        'riskAwareness': 7,
        'overallPerformance': 'good',
      };
    }
  }

  /// Calculate detailed scores based on conversation analysis
  Map<String, int> _calculateDetailedScores(
    List<TurnAssessment> turnAssessments,
    List<ConversationTurn> conversationTurns,
    PlayerProfile playerProfile,
  ) {
    // Core Communication Skills (40 points max)
    int allergyDisclosureScore = 0;
    int clarityScore = 0;
    int proactivenessScore = 0;

    // Safety Awareness (30 points max)
    int ingredientInquiryScore = 0;
    int riskAssessmentScore = 0;

    // Social Skills (20 points max)
    int confidenceScore = 0;
    int politenessScore = 0;

    // Bonus Points (10 points max)
    int completionBonus = 0;
    int improvementBonus = 0;

    // 1. Allergy Disclosure Assessment (0-15 points)
    final allergyMentions = turnAssessments
        .where((t) => t.mentionedAllergies)
        .length;
    if (allergyMentions > 0) {
      allergyDisclosureScore =
          (15 * (allergyMentions / conversationTurns.length)).round().clamp(
            0,
            15,
          );
    }

    // 2. Clarity Assessment (0-10 points)
    final avgClarity =
        turnAssessments.map((t) => t.clarityScore).reduce((a, b) => a + b) /
        turnAssessments.length;
    clarityScore = (avgClarity * 1.25).round().clamp(0, 10);

    // 3. Proactiveness Assessment (0-15 points)
    final questionAskers = turnAssessments
        .where((t) => t.askedQuestions)
        .length;
    proactivenessScore = (15 * (questionAskers / conversationTurns.length))
        .round()
        .clamp(0, 15);

    // 4. Ingredient Inquiry Assessment (0-15 points)
    ingredientInquiryScore = _assessIngredientInquiry(conversationTurns);

    // 5. Risk Assessment Score (0-15 points)
    riskAssessmentScore = _assessRiskAwareness(
      conversationTurns,
      playerProfile,
    );

    // 6. Confidence Score (0-10 points) - based on conversation length and engagement
    confidenceScore = _assessConfidence(conversationTurns);

    // 7. Politeness Score (0-10 points) - based on language analysis
    politenessScore = _assessPoliteness(conversationTurns);

    // 8. Completion Bonus (0-5 points)
    if (conversationTurns.length >= 3)
      completionBonus = 5;
    else if (conversationTurns.length >= 2)
      completionBonus = 3;

    // 9. Improvement Bonus (0-5 points) - awarded for consistent improvement
    if (turnAssessments.length > 1) {
      final firstHalf = turnAssessments.take(turnAssessments.length ~/ 2);
      final secondHalf = turnAssessments.skip(turnAssessments.length ~/ 2);

      final firstAvg =
          firstHalf
              .map((t) => t.allergyMentionScore + t.clarityScore)
              .reduce((a, b) => a + b) /
          firstHalf.length;
      final secondAvg =
          secondHalf
              .map((t) => t.allergyMentionScore + t.clarityScore)
              .reduce((a, b) => a + b) /
          secondHalf.length;

      if (secondAvg > firstAvg) improvementBonus = 5;
    }

    final totalScore =
        allergyDisclosureScore +
        clarityScore +
        proactivenessScore +
        ingredientInquiryScore +
        riskAssessmentScore +
        confidenceScore +
        politenessScore +
        completionBonus +
        improvementBonus;

    return {
      'allergyDisclosure': allergyDisclosureScore,
      'clarity': clarityScore,
      'proactiveness': proactivenessScore,
      'ingredientInquiry': ingredientInquiryScore,
      'riskAssessment': riskAssessmentScore,
      'confidence': confidenceScore,
      'politeness': politenessScore,
      'completion': completionBonus,
      'improvement': improvementBonus,
      'total': totalScore,
    };
  }

  /// Check if user mentioned their allergies
  bool _checkAllergyMention(String userInput, List<String> userAllergies) {
    final lowerInput = userInput.toLowerCase();

    // Check for explicit allergy mentions
    for (final allergy in userAllergies) {
      if (lowerInput.contains(allergy.toLowerCase()) ||
          lowerInput.contains('${allergy.toLowerCase()}s') ||
          lowerInput.contains('allergic to')) {
        return true;
      }
    }

    // Check for general allergy keywords
    final allergyKeywords = [
      'allergy',
      'allergies',
      'allergic',
      'intolerant',
      'sensitivity',
      'reaction',
    ];
    return allergyKeywords.any((keyword) => lowerInput.contains(keyword));
  }

  /// Check if user asked questions
  bool _checkQuestionAsking(String userInput) {
    return userInput.contains('?') ||
        userInput.toLowerCase().contains('what') ||
        userInput.toLowerCase().contains('how') ||
        userInput.toLowerCase().contains('does it contain') ||
        userInput.toLowerCase().contains('is there') ||
        userInput.toLowerCase().contains('can you tell me');
  }

  /// Assess clarity of communication (0-10)
  int _assessClarity(String userInput) {
    int score = 5; // Base score

    // Add points for complete sentences
    if (userInput.trim().endsWith('.') || userInput.trim().endsWith('?'))
      score += 2;

    // Add points for specific language
    if (userInput.split(' ').length >= 5) score += 2;

    // Add points for proper grammar indicators
    if (userInput.contains('I ') ||
        userInput.contains('my ') ||
        userInput.contains('can '))
      score += 1;

    return score.clamp(0, 10);
  }

  /// Assess proactiveness (0-10)
  int _assessProactiveness(String userInput, int turnNumber) {
    int score = 0;

    // Higher score for early disclosure
    if (turnNumber <= 2 && _checkAllergyMention(userInput, ['allergy'])) {
      score += 8;
    } else if (turnNumber <= 3 && _checkQuestionAsking(userInput)) {
      score += 6;
    }

    // Points for taking initiative
    if (userInput.toLowerCase().contains('before') ||
        userInput.toLowerCase().contains('first') ||
        userInput.toLowerCase().contains('should mention')) {
      score += 2;
    }

    return score.clamp(0, 10);
  }

  /// Assess ingredient inquiry behavior
  int _assessIngredientInquiry(List<ConversationTurn> turns) {
    int score = 0;

    for (final turn in turns) {
      final input = turn.userInput.toLowerCase();
      if (input.contains('ingredient') ||
          input.contains('contain') ||
          input.contains('made with') ||
          input.contains('preparation') ||
          input.contains('cross contamination')) {
        score += 5;
      }
    }

    return score.clamp(0, 15);
  }

  /// Assess risk awareness
  int _assessRiskAwareness(
    List<ConversationTurn> turns,
    PlayerProfile playerProfile,
  ) {
    int score = 0;

    for (final turn in turns) {
      final input = turn.userInput.toLowerCase();
      if (input.contains('safe') ||
          input.contains('dangerous') ||
          input.contains('reaction') ||
          input.contains('serious') ||
          input.contains('epipen')) {
        score += 5;
      }
    }

    return score.clamp(0, 15);
  }

  /// Assess confidence level
  int _assessConfidence(List<ConversationTurn> turns) {
    // Base score on engagement and conversation length
    if (turns.length >= 4) return 10;
    if (turns.length >= 3) return 8;
    if (turns.length >= 2) return 6;
    return 4;
  }

  /// Assess politeness
  int _assessPoliteness(List<ConversationTurn> turns) {
    int score = 8; // Default polite score

    for (final turn in turns) {
      final input = turn.userInput.toLowerCase();
      if (input.contains('please') ||
          input.contains('thank') ||
          input.contains('excuse me')) {
        score = 10;
        break;
      }
    }

    return score;
  }

  /// Generate personalized feedback
  Future<Map<String, dynamic>> _generatePersonalizedFeedback(
    List<ConversationTurn> conversationTurns,
    Map<String, int> scores,
    PlayerProfile playerProfile,
  ) async {
    final strengths = <String>[];
    final improvements = <String>[];

    // Analyze strengths
    if (scores['allergyDisclosure']! >= 12)
      strengths.add('Excellent allergy disclosure');
    if (scores['clarity']! >= 8) strengths.add('Clear communication');
    if (scores['proactiveness']! >= 12) strengths.add('Proactive questioning');
    if (scores['confidence']! >= 8) strengths.add('Confident interaction');
    if (scores['politeness']! >= 9) strengths.add('Polite communication');

    // Analyze improvements
    if (scores['allergyDisclosure']! < 8)
      improvements.add('Practice mentioning allergies earlier');
    if (scores['ingredientInquiry']! < 8)
      improvements.add('Ask more questions about ingredients');
    if (scores['riskAssessment']! < 8)
      improvements.add('Show more awareness of food safety');
    if (scores['proactiveness']! < 8)
      improvements.add('Take more initiative in conversations');

    String detailed = _generateDetailedFeedback(
      scores,
      strengths,
      improvements,
    );

    return {
      'strengths': strengths,
      'improvements': improvements,
      'detailed': detailed,
    };
  }

  /// Generate detailed written feedback
  String _generateDetailedFeedback(
    Map<String, int> scores,
    List<String> strengths,
    List<String> improvements,
  ) {
    final buffer = StringBuffer();

    if (scores['total']! >= 80) {
      buffer.write('Outstanding performance! ');
    } else if (scores['total']! >= 70) {
      buffer.write('Great job! ');
    } else if (scores['total']! >= 60) {
      buffer.write('Good effort! ');
    } else {
      buffer.write('Keep practicing! ');
    }

    if (strengths.isNotEmpty) {
      buffer.write('Your strengths include ${strengths.join(", ")}. ');
    }

    if (improvements.isNotEmpty) {
      buffer.write('Focus on: ${improvements.join(", ")}. ');
    }

    buffer.write(
      'Remember: clear allergy communication keeps you safe and builds confidence!',
    );

    return buffer.toString();
  }

  /// Calculate letter grade from total score
  String _calculateGrade(int totalScore) {
    if (totalScore >= 95) return 'A+';
    if (totalScore >= 90) return 'A';
    if (totalScore >= 85) return 'B+';
    if (totalScore >= 80) return 'B';
    if (totalScore >= 75) return 'C+';
    if (totalScore >= 70) return 'C';
    if (totalScore >= 65) return 'D+';
    if (totalScore >= 60) return 'D';
    return 'F';
  }

  /// Build prompt for AI assessment
  String _buildAssessmentPrompt(
    List<ConversationTurn> conversationTurns,
    List<TurnAssessment> turnAssessments,
    PlayerProfile playerProfile,
  ) {
    final conversationText = conversationTurns
        .map((turn) => 'User: ${turn.userInput}\nAI: ${turn.aiResponse}')
        .join('\n\n');

    return '''
You are evaluating a teenager's allergy communication skills in a restaurant scenario.

STUDENT PROFILE:
- Name: ${playerProfile.name}
- Age: ${playerProfile.age}
- Allergies: ${playerProfile.allergies.join(', ')}

CONVERSATION:
$conversationText

EVALUATION CRITERIA:
- Confidence level (1-10)
- Politeness (1-10)
- Risk awareness (1-10)
- Overall performance rating

Respond with JSON only:
{
  "confidence": [1-10],
  "politeness": [1-10],
  "riskAwareness": [1-10],
  "overallPerformance": "excellent/good/fair/needs_improvement"
}''';
  }

  /// Send assessment request to OpenAI
  Future<String> _sendAssessmentRequest(String prompt) async {
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${OpenAIConfig.apiKey}',
    };

    final body = json.encode({
      'model': 'gpt-3.5-turbo',
      'messages': [
        {'role': 'system', 'content': prompt},
        {'role': 'user', 'content': 'Please evaluate this conversation.'},
      ],
      'max_tokens': 200,
      'temperature': 0.3,
    });

    final response = await http
        .post(Uri.parse(_baseUrl), headers: headers, body: body)
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['choices'][0]['message']['content'];
    } else {
      throw Exception('Assessment API request failed: ${response.statusCode}');
    }
  }

  /// Fallback assessment when AI fails
  AssessmentResult _getFallbackAssessment() {
    return AssessmentResult(
      allergyDisclosureScore: 8,
      clarityScore: 7,
      proactivenessScore: 6,
      ingredientInquiryScore: 5,
      riskAssessmentScore: 7,
      confidenceScore: 6,
      politenessScore: 8,
      completionBonus: 3,
      improvementBonus: 0,
      crossContaminationScore: 0,
      hiddenAllergenScore: 0,
      preparationMethodScore: 0,
      specificIngredientScore: 0,
      missedActions: ['Unable to assess - system error'],
      earnedBonuses: [],
      detailedScores: {},
      isAdvancedLevel: false,
      totalScore: 50,
      overallGrade: 'C',
      strengths: ['Completed the conversation'],
      improvements: ['Practice allergy disclosure', 'Ask more questions'],
      detailedFeedback:
          'Keep practicing! Focus on mentioning your allergies early and asking about ingredients.',
      assessedAt: DateTime.now(),
    );
  }

  /// Get known allergens for a dish
  List<String> _getDishAllergens(String dishName) {
    final dishAllergens = <String, List<String>>{
      'Chicken Satay Bowl': ['Peanut', 'Soy', 'Sesame'],
      'Caesar Salad': ['Egg', 'Dairy', 'Gluten', 'Anchovy'],
      'Grilled Veggie Bowl': [], // No allergens
      'Tomato Basil Soup': ['Dairy', 'Gluten'],
      'Fish & Chips': ['Fish', 'Gluten', 'Egg'],
      'Chocolate Brownie': ['Dairy', 'Egg', 'Tree Nuts', 'Gluten'],
      'Grilled Chicken': [], // Generally safe
      'Tomato Soup': ['Dairy', 'Gluten'],
      // ✅ REALISTIC: Handle flexible dish names
      'Vegetarian Pasta': ['Gluten'], // May contain dairy depending on sauce
      'Chicken Dish': [], // Generally safe
      'Pasta': ['Gluten'], // Basic pasta
      'Pizza': ['Gluten', 'Dairy'], // Basic pizza
      'Salad': [], // Basic salad, generally safe
      'Soup': ['Dairy'], // Most soups contain dairy
      'Fish': ['Fish'], // Any fish dish
      'Beef': [], // Generally safe
      'Pork': [], // Generally safe
      'Burger': ['Gluten', 'Dairy'], // Typical burger
      'Sandwich': ['Gluten'], // Bread-based
      'Rice': [], // Generally safe
      'Noodles': ['Gluten'], // Wheat-based noodles
      'Curry': [], // Generally safe unless specified
      'Steak': [], // Generally safe
      'Salmon': ['Fish'], // Fish dish
      'Tuna': ['Fish'], // Fish dish
      'Cheese': ['Dairy'], // Cheese-based dishes
      'Bread': ['Gluten'], // Bread products
      'Fries': [], // Generally safe
      'Chips': [], // Generally safe
      'Brownie': ['Dairy', 'Egg', 'Tree Nuts', 'Gluten'],
      'Cake': ['Dairy', 'Egg', 'Gluten'],
      'Ice Cream': ['Dairy'],
    };

    // ✅ FLEXIBLE: Try exact match first, then partial matches
    if (dishAllergens.containsKey(dishName)) {
      return dishAllergens[dishName]!;
    }

    // Try partial matches for flexible dish names
    final lowerDish = dishName.toLowerCase();
    for (final entry in dishAllergens.entries) {
      final lowerKey = entry.key.toLowerCase();
      if (lowerDish.contains(lowerKey) || lowerKey.contains(lowerDish)) {
        return entry.value;
      }
    }

    // Check for specific allergen words in dish name
    final allergenWords = {
      'fish': ['Fish'],
      'salmon': ['Fish'],
      'tuna': ['Fish'],
      'cheese': ['Dairy'],
      'milk': ['Dairy'],
      'cream': ['Dairy'],
      'butter': ['Dairy'],
      'egg': ['Egg'],
      'peanut': ['Peanut'],
      'nut': ['Tree Nuts'],
      'almond': ['Tree Nuts'],
      'walnut': ['Tree Nuts'],
      'bread': ['Gluten'],
      'pasta': ['Gluten'],
      'noodle': ['Gluten'],
      'pizza': ['Gluten', 'Dairy'],
      'wheat': ['Gluten'],
    };

    List<String> detectedAllergens = [];
    for (final entry in allergenWords.entries) {
      if (lowerDish.contains(entry.key)) {
        detectedAllergens.addAll(entry.value);
      }
    }

    return detectedAllergens.toSet().toList(); // Remove duplicates
  }

  /// Check if user is actually disclosing allergies vs ordering food
  bool _isActuallyDisclosingAllergies(
    String lowerInput,
    List<String> userAllergies,
  ) {
    // STRICT allergy disclosure patterns - only clear, explicit allergy mentions
    final allergyDisclosurePatterns = [
      'i\'m allergic to',
      'i am allergic to',
      'i have allergies to',
      'i have an allergy to',
      'i have allergies',
      'i have allergy',
      'my allergies are',
      'my allergy is',
      'i can\'t eat',
      'i cannot eat',
      'i\'m intolerant to',
      'i am intolerant to',
      'i have a sensitivity to',
      'i react to',
      'i\'m sensitive to',
      'i am sensitive to',
      'allergic to',
      'allergy to',
      'intolerant to',
      'sensitive to',
      'reaction to',
      'can\'t have',
      'cannot have',
      'i avoid',
      'i stay away from',
      'bad reaction to',
      'makes me sick',
      'i don\'t eat',
      'i won\'t eat',
      'i shouldn\'t eat',
      'i mustn\'t eat',
      'doctor said i can\'t',
      'doctor told me not to',
      'advised not to eat',
      'told not to eat',
      'not supposed to eat',
      'shouldn\'t have',
      'mustn\'t have',
      'can\'t consume',
      'cannot consume',
      'restricted from',
      'forbidden from eating',
      'prohibited from eating',
      'not allowed to eat',
      // Explicit "no allergies" statements - these ARE allergy disclosure
      'i don\'t have any allergies',
      'i don\'t have allergies',
      'no food allergies',
      'not allergic to anything',
      'no allergies',
      'i have no allergies',
      'i\'m not allergic',
      'i am not allergic',
    ];

    // Check for actual allergy disclosure patterns
    final hasAllergyDisclosure = allergyDisclosurePatterns.any(
      (pattern) => lowerInput.contains(pattern),
    );

    // Additional check for specific allergen mentions with "i have" pattern
    // This catches cases like "i have fish, egg and milk allergies"
    if (!hasAllergyDisclosure && lowerInput.contains('i have')) {
      for (final allergy in userAllergies) {
        if (lowerInput.contains('i have ${allergy.toLowerCase()}') ||
            lowerInput.contains('i have ${allergy.toLowerCase()},') ||
            lowerInput.contains('i have ${allergy.toLowerCase()} and') ||
            lowerInput.contains('i have ${allergy.toLowerCase()} allerg')) {
          return true; // Direct allergen disclosure found
        }
      }
    }

    // Patterns that indicate ordering food (not disclosing allergies)
    // FIXED: Exclude questions that start with "what" from ordering patterns
    final orderingPatterns = [
      'i\'ll have',
      'i\'ll take',
      'i want',
      'i\'d like',
      'i choose',
      'i\'ll order',
      'i\'ll get',
      'give me',
      'have the',
      'take the',
      'get the',
      'that one',
      'this one',
      'sounds good',
      'sounds great',
      'perfect',
      'yes',
      'sure',
      'okay',
      'fine',
      'yep',
      'yup',
      'alright',
      'right',
      'exactly',
      'that\'s it',
      'that\'s right',
      'that\'s what i want',
      'that\'s good',
      'that works',
      'that\'s fine',
      'that\'s perfect',
      'let\'s do that',
      'let\'s go with',
      'bring me',
      'make me',
      'prepare',
      'cook',
      'fix me',
      'serve me',
      'deliver',
    ];

    // Check if user is ordering food - but exclude questions
    final isOrdering =
        orderingPatterns.any((pattern) => lowerInput.contains(pattern)) &&
        !lowerInput.startsWith('what') &&
        !lowerInput.startsWith('so what');

    // Patterns that are general responses (not allergy disclosure)
    // FIXED: Removed overly broad patterns like "what"
    final generalResponsePatterns = [
      'no, thank you',
      'no thanks',
      'no thank you',
      'nope',
      'nah',
      'no way',
      'not really',
      'not at all',
      'nothing',
      'hello',
      'hi',
      'hey',
      'good morning',
      'good evening',
      'how are you',
      'fine',
      'good',
      'great',
      'awesome',
      'cool',
      'nice',
      'ok',
      'okay',
      'alright',
      'sure',
      'yes',
      'yeah',
      'yep',
      'yup',
      'uh huh',
      'mmm',
      'hmm',
      'huh',
      'excuse me',
      'pardon',
      'sorry',
    ];

    // Check if it's ONLY a general response (not containing substantive content)
    final isOnlyGeneralResponse = generalResponsePatterns.any(
      (pattern) =>
          lowerInput.trim() == pattern ||
          lowerInput.trim().startsWith(pattern + ' ') ||
          lowerInput.trim().endsWith(' ' + pattern),
    );

    // FIXED: Prioritize allergy disclosure - if someone mentions allergies, that takes precedence
    // Only exclude if it's ONLY a general response with no allergy content
    final result =
        hasAllergyDisclosure && !isOrdering && !isOnlyGeneralResponse;

    // Add debug logging to help track detection
    if (result) {
      debugPrint('[ALLERGY DETECTION] POSITIVE: "$lowerInput"');
      debugPrint('  - hasAllergyDisclosure: $hasAllergyDisclosure');
      debugPrint('  - isOrdering: $isOrdering');
      debugPrint('  - isOnlyGeneralResponse: $isOnlyGeneralResponse');
    } else {
      debugPrint('[ALLERGY DETECTION] NEGATIVE: "$lowerInput"');
      debugPrint('  - hasAllergyDisclosure: $hasAllergyDisclosure');
      debugPrint('  - isOrdering: $isOrdering');
      debugPrint('  - isOnlyGeneralResponse: $isOnlyGeneralResponse');
    }

    return result;
  }

  /// Normalize allergen names to handle plural forms and variations
  String _normalizeAllergen(String allergen) {
    final normalized = allergen.toLowerCase().trim();

    // Handle plural forms
    final pluralMappings = {
      'peanuts': 'peanut',
      'nuts': 'nut',
      'eggs': 'egg',
      'fish': 'fish', // Already singular
      'dairy': 'dairy', // Already singular
      'milk': 'dairy', // Map milk to dairy
      'gluten': 'gluten', // Already singular
      'wheat': 'gluten', // Map wheat to gluten
      'tree nuts': 'tree nut',
      'tree nut': 'tree nut',
      'shellfish': 'shellfish',
      'soy': 'soy',
      'sesame': 'sesame',
    };

    return pluralMappings[normalized] ?? normalized;
  }

  /// Scenario-aware assessment using configuration rules
  Future<AssessmentResult> _assessWithScenarioConfig(
    List<ConversationTurn> conversationTurns,
    PlayerProfile playerProfile,
    String scenarioId,
    DateTime sessionStart,
    DateTime sessionEnd,
    ConversationContext conversationContext,
    ScenarioConfig scenarioConfig,
  ) async {
    final scoringRules = scenarioConfig.scoringRules;
    int totalScore = 0;
    List<String> strengths = [];
    List<String> improvements = [];
    Map<String, int> scores = {};

    // Apply base scoring rules
    for (final entry in scoringRules.basePoints.entries) {
      final criterion = entry.key;
      final maxPoints = entry.value;
      int earnedPoints = 0;

      switch (criterion) {
        case 'allergy_disclosure':
          if (conversationContext.allergiesDisclosed) {
            earnedPoints = maxPoints;
            strengths.add('Clear allergy disclosure');
          } else {
            improvements.add('Remember to disclose allergies early');
          }
          break;

        case 'safe_food_order':
          if (conversationContext.selectedDish != null) {
            debugPrint(
              '[SCORING] Checking safe food for dish: "${conversationContext.selectedDish}"',
            );
            // Load menu for advanced safety checking
            await MenuService.instance.loadMenu();
            final menuItem = MenuService.instance.findItemByName(
              conversationContext.selectedDish!,
            );
            debugPrint(
              '[SCORING] Found menu item: ${menuItem?.name ?? "NOT FOUND"}',
            );
            if (menuItem != null) {
              final isSafe = MenuService.instance.isItemSafeForUser(
                menuItem,
                playerProfile.allergies,
              );
              debugPrint(
                '[SCORING] Is safe for allergies ${playerProfile.allergies}: $isSafe',
              );
              if (isSafe) {
                earnedPoints = maxPoints;
                strengths.add('Selected safe food option');
                debugPrint(
                  '[SCORING] Awarded $maxPoints points for safe food selection',
                );
              } else {
                improvements.add(
                  'Ordered unsafe food - always check ingredients',
                );
                debugPrint('[SCORING] No points - unsafe food selected');
              }
            } else {
              debugPrint(
                '[SCORING] Could not find menu item for "${conversationContext.selectedDish}" - no points awarded',
              );
            }
          } else {
            debugPrint(
              '[SCORING] No dish selected - no safe food points awarded',
            );
          }
          break;

        case 'ingredient_questions':
          bool askedQuestions = conversationTurns.any(
            (turn) =>
                turn.userInput.contains('ingredient') ||
                turn.userInput.contains('contain') ||
                turn.userInput.contains('?'),
          );
          if (askedQuestions) {
            earnedPoints = maxPoints;
            strengths.add('Asked about ingredients');
          } else if (scoringRules.requireIngredientQuestions) {
            improvements.add('Ask about ingredients in dishes');
          }
          break;

        case 'cross_contamination_awareness':
          bool mentionedCrossContamination = conversationTurns.any(
            (turn) =>
                turn.userInput.toLowerCase().contains('cross') ||
                turn.userInput.toLowerCase().contains('contamination') ||
                turn.userInput.toLowerCase().contains('preparation') ||
                turn.userInput.toLowerCase().contains('shared'),
          );
          if (mentionedCrossContamination) {
            earnedPoints = maxPoints;
            strengths.add('Showed cross-contamination awareness');
          }
          break;
      }

      scores[criterion] = earnedPoints;
      totalScore += earnedPoints;
    }

    // Apply bonus points
    for (final entry in scoringRules.bonusPoints.entries) {
      final criterion = entry.key;
      final bonusPoints = entry.value;
      bool earned = false;

      switch (criterion) {
        case 'detailed_questions':
          earned = conversationTurns.any(
            (turn) =>
                turn.userInput.length > 50 && turn.userInput.contains('?'),
          );
          break;

        case 'preparation_method_inquiry':
          earned = conversationTurns.any(
            (turn) =>
                turn.userInput.toLowerCase().contains('prepare') ||
                turn.userInput.toLowerCase().contains('cook') ||
                turn.userInput.toLowerCase().contains('made'),
          );
          break;

        case 'kitchen_verification_request':
          earned = conversationTurns.any(
            (turn) =>
                turn.userInput.toLowerCase().contains('kitchen') ||
                turn.userInput.toLowerCase().contains('chef') ||
                turn.userInput.toLowerCase().contains('check'),
          );
          break;

        case 'alternative_suggestions':
          earned = conversationTurns.any(
            (turn) =>
                turn.userInput.toLowerCase().contains('instead') ||
                turn.userInput.toLowerCase().contains('alternative') ||
                turn.userInput.toLowerCase().contains('substitute'),
          );
          break;
      }

      if (earned) {
        totalScore += bonusPoints;
        scores[criterion] = bonusPoints;
        strengths.add('Bonus: ${criterion.replaceAll('_', ' ')}');
      }
    }

    // Apply penalties
    for (final entry in scoringRules.penalties.entries) {
      final criterion = entry.key;
      final penaltyPoints = entry.value;
      bool applied = false;

      switch (criterion) {
        case 'unsafe_food_order':
          if (conversationContext.selectedDish != null) {
            await MenuService.instance.loadMenu();
            final menuItem = MenuService.instance.findItemByName(
              conversationContext.selectedDish!,
            );
            if (menuItem != null) {
              final isSafe = MenuService.instance.isItemSafeForUser(
                menuItem,
                playerProfile.allergies,
              );
              if (!isSafe) {
                applied = true;
                improvements.add('Avoid ordering unsafe foods');
              }
            }
          }
          break;

        case 'no_allergy_disclosure':
          if (!conversationContext.allergiesDisclosed) {
            applied = true;
            improvements.add('Always disclose allergies at the start');
          }
          break;

        case 'insufficient_questioning':
          int questionCount = conversationTurns
              .where((turn) => turn.userInput.contains('?'))
              .length;
          if (scenarioConfig.level == DifficultyLevel.advanced &&
              questionCount < 3) {
            applied = true;
            improvements.add(
              'Advanced level requires at least 3 detailed questions about ingredients, preparation, and cross-contamination',
            );
          }
          break;

        case 'ignored_hidden_allergens':
          if (scenarioConfig.level == DifficultyLevel.advanced) {
            // Check if user failed to ask about hidden allergens for their selected dish
            if (conversationContext.selectedDish != null) {
              await MenuService.instance.loadMenu();
              final menuItem = MenuService.instance.findItemByName(
                conversationContext.selectedDish!,
              );
              if (menuItem != null && menuItem.hiddenAllergens.isNotEmpty) {
                bool askedAboutHiddenAllergens = conversationTurns.any(
                  (turn) =>
                      turn.userInput.toLowerCase().contains('hidden') ||
                      turn.userInput.toLowerCase().contains('sauce') ||
                      turn.userInput.toLowerCase().contains('stock') ||
                      turn.userInput.toLowerCase().contains('preparation') ||
                      turn.userInput.toLowerCase().contains('made with'),
                );
                if (!askedAboutHiddenAllergens) {
                  applied = true;
                  improvements.add(
                    'Advanced level requires asking about hidden allergens in sauces, stocks, and preparation methods',
                  );
                }
              }
            }
          }
          break;

        case 'no_cross_contamination_inquiry':
          if (scenarioConfig.level == DifficultyLevel.advanced) {
            bool askedAboutCrossContamination = conversationTurns.any(
              (turn) =>
                  turn.userInput.toLowerCase().contains('cross') ||
                  turn.userInput.toLowerCase().contains('contamination') ||
                  turn.userInput.toLowerCase().contains('shared') ||
                  turn.userInput.toLowerCase().contains('separate') ||
                  turn.userInput.toLowerCase().contains('fryer') ||
                  turn.userInput.toLowerCase().contains('equipment'),
            );
            if (!askedAboutCrossContamination) {
              applied = true;
              improvements.add(
                'Advanced level requires asking about cross-contamination and shared equipment',
              );
            }
          }
          break;

        case 'no_modification_request':
          if (scenarioConfig.level == DifficultyLevel.advanced) {
            // Check if user's selected dish could be modified to be safe
            if (conversationContext.selectedDish != null) {
              await MenuService.instance.loadMenu();
              final menuItem = MenuService.instance.findItemByName(
                conversationContext.selectedDish!,
              );
              if (menuItem != null &&
                  !MenuService.instance.isItemSafeForUser(
                    menuItem,
                    playerProfile.allergies,
                  ) &&
                  menuItem.canBeModifiedToSafe) {
                bool requestedModification = conversationTurns.any(
                  (turn) =>
                      turn.userInput.toLowerCase().contains('without') ||
                      turn.userInput.toLowerCase().contains('modify') ||
                      turn.userInput.toLowerCase().contains('change') ||
                      turn.userInput.toLowerCase().contains('substitute') ||
                      turn.userInput.toLowerCase().contains('alternative') ||
                      turn.userInput.toLowerCase().contains('skip'),
                );
                if (!requestedModification) {
                  applied = true;
                  improvements.add(
                    'Ask about modifying dishes to make them safe when possible',
                  );
                }
              }
            }
          }
          break;

        case 'rushed_decision':
          if (conversationTurns.length < 3 &&
              conversationContext.selectedDish != null) {
            applied = true;
            improvements.add('Take time to ask questions before ordering');
          }
          break;
      }

      if (applied) {
        totalScore += penaltyPoints; // penaltyPoints are negative
        scores[criterion] = penaltyPoints;
      }
    }

    String? failureReason;

    if (scenarioConfig.level == DifficultyLevel.advanced) {
      // Auto-fail if user orders unsafe food despite having allergies
      if (conversationContext.selectedDish != null &&
          conversationContext.allergiesDisclosed) {
        await MenuService.instance.loadMenu();
        final menuItem = MenuService.instance.findItemByName(
          conversationContext.selectedDish!,
        );
        if (menuItem != null &&
            !MenuService.instance.isItemSafeForUser(
              menuItem,
              playerProfile.allergies,
            )) {
          failureReason =
              'CRITICAL: Ordered unsafe food despite disclosing allergies. This is extremely dangerous!';
          totalScore = (totalScore * 0.1).round(); // 90% penalty but not zero
        }
      }

      // Heavy penalty if user doesn't disclose allergies at all in advanced scenario
      if (!conversationContext.allergiesDisclosed) {
        failureReason =
            'CRITICAL: Advanced scenarios require proactive allergy disclosure!';
        totalScore = (totalScore * 0.2).round(); // 80% penalty
      }

      // Auto-fail if user has insufficient safety questioning
      int safetyQuestions = conversationTurns.where((turn) {
        final input = turn.userInput.toLowerCase();
        return input.contains('cross') ||
            input.contains('contamination') ||
            input.contains('shared') ||
            input.contains('preparation') ||
            input.contains('allergen') ||
            input.contains('ingredient') ||
            input.contains('safe');
      }).length;

      if (safetyQuestions < 2) {
        if (failureReason == null) {
          failureReason =
              'CRITICAL: Advanced level requires extensive safety questioning!';
        }
        totalScore = (totalScore * 0.6).round(); // 40% penalty
      }
    }

    // Apply difficulty multiplier
    totalScore = (totalScore * scenarioConfig.difficultyMultiplier).round();

    // Clamp to appropriate maximum for the scenario level
    int maxScore = scenarioConfig.level == DifficultyLevel.advanced ? 200 : 100;
    totalScore = totalScore.clamp(0, maxScore);

    scores['total'] = totalScore;

    // Add failure reason to improvements if it occurred
    if (failureReason != null) {
      improvements.insert(0, failureReason);
    }

    // Generate level-appropriate feedback
    String feedback = _generateScenarioFeedback(
      totalScore,
      strengths,
      improvements,
      scenarioConfig,
    );

    String grade = _calculateGrade(totalScore);

    // Enhanced scoring for advanced level
    bool isAdvanced = scenarioConfig.level == DifficultyLevel.advanced;
    List<String> missedActions = [];
    List<String> earnedBonuses = [];

    // Create detailed scores map with correct structure
    Map<String, int> detailedScores = Map.from(scores);

    // Track missed critical actions for advanced level (informational only, penalties already applied above)
    if (isAdvanced) {
      // Track what actions were missed for display
      if (!conversationContext.allergiesDisclosed) {
        missedActions.add('Disclose allergies proactively');
      }
      if (!conversationTurns.any(
        (turn) =>
            turn.userInput.toLowerCase().contains('ingredient') ||
            turn.userInput.toLowerCase().contains('contain'),
      )) {
        missedActions.add('Ask detailed ingredient questions');
      }
      if (!conversationTurns.any(
        (turn) =>
            turn.userInput.toLowerCase().contains('preparation') ||
            turn.userInput.toLowerCase().contains('prepared') ||
            turn.userInput.toLowerCase().contains('cook') ||
            turn.userInput.toLowerCase().contains('made'),
      )) {
        missedActions.add('Verify preparation methods');
      }
      if (!conversationTurns.any(
        (turn) =>
            turn.userInput.toLowerCase().contains('hidden') ||
            turn.userInput.toLowerCase().contains('sauce') ||
            turn.userInput.toLowerCase().contains('dressing'),
      )) {
        missedActions.add('Ask about hidden allergens in sauces/dressings');
      }
      if (!conversationTurns.any(
        (turn) =>
            turn.userInput.toLowerCase().contains('cross') ||
            turn.userInput.toLowerCase().contains('contamination') ||
            turn.userInput.toLowerCase().contains('shared'),
      )) {
        missedActions.add('Inquire about cross-contamination risks');
      }

      // Track bonus actions for advanced
      if (conversationTurns.any(
        (turn) =>
            turn.userInput.toLowerCase().contains('kitchen') ||
            turn.userInput.toLowerCase().contains('chef'),
      )) {
        earnedBonuses.add('Asked to verify with kitchen');
      }
      if (conversationTurns.length >= 4) {
        earnedBonuses.add('Thorough questioning approach');
      }
    }

    // The score has already been processed above, no need to re-clamp here

    return AssessmentResult(
      allergyDisclosureScore: scores['allergy_disclosure'] ?? 0,
      clarityScore: 8, // Default good clarity
      proactivenessScore: scores['cross_contamination_awareness'] ?? 0,
      ingredientInquiryScore: scores['ingredient_questions'] ?? 0,
      riskAssessmentScore: (scores['safe_food_order'] ?? 0) ~/ 2,
      confidenceScore: totalScore >= (isAdvanced ? 120 : 70) ? 8 : 5,
      politenessScore: 8, // Assume good politeness
      completionBonus: totalScore >= scoringRules.passingScore ? 5 : 0,
      improvementBonus: 0, // Could be calculated based on previous sessions
      unsafeOrderPenalty: scores['unsafe_food_order'] ?? 0,
      crossContaminationScore: scores['cross_contamination_awareness'] ?? 0,
      hiddenAllergenScore: scores['hidden_allergen_questions'] ?? 0,
      preparationMethodScore: scores['preparation_method_inquiry'] ?? 0,
      specificIngredientScore: scores['specific_ingredient_inquiry'] ?? 0,
      missedActions: missedActions,
      earnedBonuses: earnedBonuses,
      detailedScores: detailedScores,
      isAdvancedLevel: isAdvanced,
      totalScore: totalScore,
      overallGrade: grade,
      strengths: strengths,
      improvements: improvements,
      detailedFeedback: feedback,
      assessedAt: sessionEnd,
    );
  }

  String _generateScenarioFeedback(
    int totalScore,
    List<String> strengths,
    List<String> improvements,
    ScenarioConfig scenarioConfig,
  ) {
    final buffer = StringBuffer();

    // Level-specific feedback style
    switch (scenarioConfig.behaviorRules.feedbackStyle) {
      case FeedbackStyle.supportive:
        buffer.write(
          _generateSupportiveFeedback(totalScore, strengths, improvements),
        );
        break;
      case FeedbackStyle.challenging:
        buffer.write(
          _generateChallengingFeedback(totalScore, strengths, improvements),
        );
        break;
      case FeedbackStyle.realistic:
        buffer.write(
          _generateRealisticFeedback(totalScore, strengths, improvements),
        );
        break;
      case FeedbackStyle.neutral:
        buffer.write(
          _generateNeutralFeedback(totalScore, strengths, improvements),
        );
        break;
    }

    // Add scenario-specific context
    buffer.write('\n\nScenario: ${scenarioConfig.name}');
    buffer.write(
      '\nDifficulty: ${scenarioConfig.level.toString().split('.').last}',
    );
    buffer.write(
      '\nPassing Score: ${scenarioConfig.scoringRules.passingScore}%',
    );

    return buffer.toString();
  }

  String _generateSupportiveFeedback(
    int score,
    List<String> strengths,
    List<String> improvements,
  ) {
    final buffer = StringBuffer();
    if (score >= 85) {
      buffer.write('Excellent work! ');
    } else if (score >= 70) {
      buffer.write('Great job! ');
    } else if (score >= 50) {
      buffer.write('Good effort! ');
    } else {
      buffer.write('Keep practicing - you\'re learning! ');
    }

    if (strengths.isNotEmpty) {
      buffer.write('Your strengths: ${strengths.join(", ")}. ');
    }
    if (improvements.isNotEmpty) {
      buffer.write('Areas to focus on: ${improvements.join(", ")}. ');
    }

    return buffer.toString();
  }

  String _generateChallengingFeedback(
    int score,
    List<String> strengths,
    List<String> improvements,
  ) {
    final buffer = StringBuffer();
    if (score >= 90) {
      buffer.write(
        'Strong performance, but there\'s always room for improvement. ',
      );
    } else if (score >= 75) {
      buffer.write('Solid work, but push yourself further. ');
    } else if (score >= 60) {
      buffer.write('Acceptable, but you can do better. ');
    } else {
      buffer.write('This needs significant improvement. ');
    }

    if (improvements.isNotEmpty) {
      buffer.write('Focus on: ${improvements.join(", ")}. ');
    }
    if (strengths.isNotEmpty) {
      buffer.write('Build on: ${strengths.join(", ")}. ');
    }

    return buffer.toString();
  }

  String _generateRealisticFeedback(
    int score,
    List<String> strengths,
    List<String> improvements,
  ) {
    final buffer = StringBuffer();
    if (score >= 85) {
      buffer.write('Professional-level communication. ');
    } else if (score >= 70) {
      buffer.write('Good communication skills demonstrated. ');
    } else if (score >= 50) {
      buffer.write('Basic communication achieved. ');
    } else {
      buffer.write('Communication needs development. ');
    }

    if (improvements.isNotEmpty) {
      buffer.write('Consider: ${improvements.join(", ")}. ');
    }

    return buffer.toString();
  }

  String _generateNeutralFeedback(
    int score,
    List<String> strengths,
    List<String> improvements,
  ) {
    final buffer = StringBuffer();
    buffer.write('Score: $score%. ');

    if (strengths.isNotEmpty) {
      buffer.write('Achieved: ${strengths.join(", ")}. ');
    }
    if (improvements.isNotEmpty) {
      buffer.write('Areas for development: ${improvements.join(", ")}. ');
    }

    return buffer.toString();
  }
}
