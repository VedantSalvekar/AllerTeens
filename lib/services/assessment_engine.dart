import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/training_assessment.dart';
import '../models/game_state.dart';
import '../core/config/app_config.dart';
import 'openai_dialogue_service.dart';
import '../models/scenario_models.dart';
import '../models/user_model.dart';
import 'menu_service.dart';

/// Advanced assessment engine that analyzes AI conversations for training effectiveness
class AssessmentEngine {
  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';

  /// Assess a complete training session and generate comprehensive feedback
  Future<AssessmentResult> assessTrainingSession({
    required List<ConversationTurn> conversationTurns,
    required PlayerProfile playerProfile,
    required String scenarioId,
    required DateTime sessionStart,
    required DateTime sessionEnd,
    required ConversationContext conversationContext,
  }) async {
    try {
      // ENHANCED BEGINNER ASSESSMENT - Focus on key skills:
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

      // Allergy disclosure detection: check all turns and context
      final allergyDisclosed =
          conversationContext.allergiesDisclosed ||
          conversationTurns.any(
            (turn) =>
                turn.detectedAllergies.isNotEmpty ||
                (turn.userInput.toLowerCase().contains('allergy') ||
                    turn.userInput.toLowerCase().contains('allergic')),
          );

      // FIXED: Use conversation context state if available, otherwise fall back to text analysis
      if (conversationContext != null) {
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
        String? finalOrder;
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
            finalOrder = selectedDish;
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
      debugPrint('🔍 [ALLERGY DETECTION] POSITIVE: "$lowerInput"');
      debugPrint('  - hasAllergyDisclosure: $hasAllergyDisclosure');
      debugPrint('  - isOrdering: $isOrdering');
      debugPrint('  - isOnlyGeneralResponse: $isOnlyGeneralResponse');
    } else {
      debugPrint('🔍 [ALLERGY DETECTION] NEGATIVE: "$lowerInput"');
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
}
