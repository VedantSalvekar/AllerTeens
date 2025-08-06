import 'package:flutter/foundation.dart';
import '../models/training_assessment.dart';
import '../models/game_state.dart';
import '../models/scenario_models.dart';
import 'menu_service.dart';
import 'openai_dialogue_service.dart';

/// Level-specific scoring engine implementing the new behavioral learning system
class ScoringEngine {
  /// Main scoring method that routes to level-specific scoring
  static Future<AssessmentResult> scoreTrainingSession({
    required List<ConversationTurn> conversationTurns,
    required PlayerProfile playerProfile,
    required DifficultyLevel level,
    required ConversationContext conversationContext,
    required String scenarioId,
    required DateTime sessionStart,
    required DateTime sessionEnd,
  }) async {
    switch (level) {
      case DifficultyLevel.beginner:
        return await _scoreBeginnerLevel(
          conversationTurns,
          playerProfile,
          conversationContext,
          scenarioId,
          sessionStart,
          sessionEnd,
        );
      case DifficultyLevel.intermediate:
        return await _scoreIntermediateLevel(
          conversationTurns,
          playerProfile,
          conversationContext,
          scenarioId,
          sessionStart,
          sessionEnd,
        );
      case DifficultyLevel.advanced:
        return await _scoreAdvancedLevel(
          conversationTurns,
          playerProfile,
          conversationContext,
          scenarioId,
          sessionStart,
          sessionEnd,
        );
    }
  }

  /// Beginner Level Scoring (Total: 100 pts, Pass: 70+)
  static Future<AssessmentResult> _scoreBeginnerLevel(
    List<ConversationTurn> conversationTurns,
    PlayerProfile playerProfile,
    ConversationContext conversationContext,
    String scenarioId,
    DateTime sessionStart,
    DateTime sessionEnd,
  ) async {
    int totalScore = 0;
    List<String> strengths = [];
    List<String> improvements = [];
    Map<String, int> detailedScores = {};

    // 1. Allergy Disclosure (50 pts)
    int allergyDisclosureScore = 0;
    if (conversationContext.allergiesDisclosed) {
      allergyDisclosureScore = 50;
      strengths.add('Clearly disclosed your allergies to the waiter');
    } else {
      improvements.add('Always tell the waiter about your allergies first');
    }
    detailedScores['allergy_disclosure'] = allergyDisclosureScore;
    totalScore += allergyDisclosureScore;

    // 2. Safe Food Choice (30 pts)
    int safeFoodScore = 0;
    bool orderedUnsafeFood = false;
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
        if (isSafe) {
          safeFoodScore = 30;
          strengths.add('Selected a safe food option');
        } else {
          orderedUnsafeFood = true;
          safeFoodScore = -30; // Negative score for unsafe choice
          improvements.add(
            'Ordered food containing your allergens - always check ingredients',
          );
        }
      }
    } else {
      improvements.add('Practice ordering food during conversations');
    }
    detailedScores['safe_food_choice'] = safeFoodScore;
    totalScore += safeFoodScore;

    // 2.5. Order Decision After Safety Warning (20 pts)
    int orderDecisionScore = 0;
    if (conversationContext.safetyWarningGiven) {
      if (conversationContext.cancelledOrdersAfterWarning.isNotEmpty) {
        orderDecisionScore = 20;
        strengths.add(
          'Made a smart decision to cancel unsafe order after learning about risks',
        );

        // Check if reorder was safe
        if (conversationContext.reorderedItemsAfterCancellation.isNotEmpty) {
          await MenuService.instance.loadMenu();
          final reorderedItem =
              conversationContext.reorderedItemsAfterCancellation.last;
          final menuItem = MenuService.instance.findItemByName(reorderedItem);
          if (menuItem != null) {
            final isSafe = MenuService.instance.isItemSafeForUser(
              menuItem,
              playerProfile.allergies,
            );
            if (isSafe) {
              orderDecisionScore += 10; // Bonus for safe reorder
              strengths.add('Excellent choice - reordered a safe alternative');
            } else {
              orderDecisionScore -= 15; // Penalty for unsafe reorder
              improvements.add(
                'Your reorder was also unsafe - double-check ingredients',
              );
            }
          }
        }
      } else if (conversationContext.keptUnsafeOrdersAfterWarning.isNotEmpty) {
        orderDecisionScore = -20;
        improvements.add(
          'You kept an unsafe order even after being warned about risks',
        );
      }
    }
    detailedScores['order_decision_after_warning'] = orderDecisionScore;
    totalScore += orderDecisionScore;

    // 3. Ingredient Questions (10 pts)
    int ingredientScore = 0;
    bool askedAboutIngredients = conversationTurns.any(
      (turn) =>
          turn.userInput.toLowerCase().contains('ingredient') ||
          turn.userInput.toLowerCase().contains('contain') ||
          turn.userInput.toLowerCase().contains('what\'s in') ||
          turn.userInput.toLowerCase().contains('does it have'),
    );

    if (askedAboutIngredients) {
      ingredientScore = 10;
      strengths.add('Asked about ingredients');
    } else {
      improvements.add('Ask about ingredients to ensure food is safe');
    }
    detailedScores['ingredient_questions'] = ingredientScore;
    totalScore += ingredientScore;

    // 4. Politeness Bonus (+10 pts)
    int politenessBonus = 0;
    bool wasPolite = conversationTurns.any(
      (turn) =>
          turn.userInput.toLowerCase().contains('please') ||
          turn.userInput.toLowerCase().contains('thank'),
    );

    if (wasPolite) {
      politenessBonus = 10;
      strengths.add('Used polite language');
    }
    detailedScores['politeness_bonus'] = politenessBonus;
    totalScore += politenessBonus;

    // Simple scoring: 0 if not done, full points if done
    // No penalties - just tracking what wasn't done for feedback

    // Critical Failure tracking (for feedback only, no score penalty)
    bool criticalFailure =
        orderedUnsafeFood && !conversationContext.allergiesDisclosed;
    if (criticalFailure) {
      improvements.insert(
        0,
        'CRITICAL: Ordered unsafe food without disclosing allergies',
      );
    }

    // Clamp score
    totalScore = totalScore.clamp(0, 100);
    detailedScores['total'] = totalScore;

    // Determine pass/fail
    bool passed = totalScore >= 70;
    String result = passed ? 'PASSED' : 'FAILED';

    return AssessmentResult(
      allergyDisclosureScore: allergyDisclosureScore,
      clarityScore: 0, // Not used in new system
      proactivenessScore: 0, // Not used in new system
      ingredientInquiryScore: ingredientScore,
      riskAssessmentScore: safeFoodScore,
      confidenceScore: 0, // Not used in new system
      politenessScore: politenessBonus,
      completionBonus: 0, // Not used in new system
      improvementBonus: 0, // Not used in new system
      unsafeOrderPenalty: 0, // Penalty now included in safe food score
      totalScore: totalScore,
      overallGrade: passed ? 'PASS' : 'FAIL',
      strengths: strengths,
      improvements: improvements,
      detailedFeedback: '', // Will be generated by FeedbackBuilder
      assessedAt: sessionEnd,
      detailedScores: detailedScores,
      isAdvancedLevel: false,
      level: DifficultyLevel.beginner,
      maxPossibleScore: 100,
      passingScore: 70,
      criticalFailure: criticalFailure,
    );
  }

  /// Intermediate Level Scoring (Total: 120 pts, Pass: 85+)
  static Future<AssessmentResult> _scoreIntermediateLevel(
    List<ConversationTurn> conversationTurns,
    PlayerProfile playerProfile,
    ConversationContext conversationContext,
    String scenarioId,
    DateTime sessionStart,
    DateTime sessionEnd,
  ) async {
    int totalScore = 0;
    List<String> strengths = [];
    List<String> improvements = [];
    Map<String, int> detailedScores = {};

    // 1. Allergy Disclosure (40 pts)
    int allergyDisclosureScore = 0;
    if (conversationContext.allergiesDisclosed) {
      allergyDisclosureScore = 40;
      strengths.add('Disclosed allergies to the waiter');
    } else {
      improvements.add('Must disclose allergies to ensure safety');
    }
    detailedScores['allergy_disclosure'] = allergyDisclosureScore;
    totalScore += allergyDisclosureScore;

    // 2. Safe Food Choice (30 pts)
    int safeFoodScore = 0;
    bool orderedUnsafeFood = false;
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
        if (isSafe) {
          safeFoodScore = 30;
          strengths.add('Chose a safe food option');
        } else {
          orderedUnsafeFood = true;
          safeFoodScore = -35; // Negative score for unsafe choice
          improvements.add(
            'Selected food containing allergens - verify ingredients first',
          );
        }
      }
    }
    detailedScores['safe_food_choice'] = safeFoodScore;
    totalScore += safeFoodScore;

    // 2.5. Order Decision After Safety Warning (25 pts)
    int orderDecisionScore = 0;
    if (conversationContext.safetyWarningGiven) {
      if (conversationContext.cancelledOrdersAfterWarning.isNotEmpty) {
        orderDecisionScore = 25;
        strengths.add(
          'Professionally handled safety concerns by changing order',
        );

        // Check if reorder was safe
        if (conversationContext.reorderedItemsAfterCancellation.isNotEmpty) {
          await MenuService.instance.loadMenu();
          final reorderedItem =
              conversationContext.reorderedItemsAfterCancellation.last;
          final menuItem = MenuService.instance.findItemByName(reorderedItem);
          if (menuItem != null) {
            final isSafe = MenuService.instance.isItemSafeForUser(
              menuItem,
              playerProfile.allergies,
            );
            if (isSafe) {
              orderDecisionScore += 10; // Bonus for safe reorder
              strengths.add('Made an informed decision on safer alternative');
            } else {
              orderDecisionScore -= 20; // Penalty for unsafe reorder
              improvements.add(
                'Reordered item was also unsafe - need better ingredient verification',
              );
            }
          }
        }
      } else if (conversationContext.keptUnsafeOrdersAfterWarning.isNotEmpty) {
        orderDecisionScore = -25;
        improvements.add(
          'Kept potentially unsafe order despite warnings - practice assertiveness',
        );
      }
    }
    detailedScores['order_decision_after_warning'] = orderDecisionScore;
    totalScore += orderDecisionScore;

    // 3. Ingredient Questions (15 pts)
    int ingredientScore = 0;
    bool askedAboutIngredients = conversationTurns.any(
      (turn) =>
          turn.userInput.toLowerCase().contains('ingredient') ||
          turn.userInput.toLowerCase().contains('contain') ||
          turn.userInput.toLowerCase().contains('what\'s in') ||
          turn.userInput.toLowerCase().contains('made with'),
    );

    if (askedAboutIngredients) {
      ingredientScore = 15;
      strengths.add('Asked about ingredients');
    } else {
      improvements.add('Ask about ingredients and preparation methods');
    }
    detailedScores['ingredient_questions'] = ingredientScore;
    totalScore += ingredientScore;

    // 4. Cross-Contact Questions (15 pts)
    int crossContactScore = 0;
    bool askedAboutCrossContact = conversationTurns.any(
      (turn) =>
          turn.userInput.toLowerCase().contains('cross') ||
          turn.userInput.toLowerCase().contains('contamination') ||
          turn.userInput.toLowerCase().contains('shared') ||
          turn.userInput.toLowerCase().contains('separate'),
    );

    if (askedAboutCrossContact) {
      crossContactScore = 15;
      strengths.add('Inquired about cross-contamination');
    } else {
      improvements.add('Ask about cross-contamination and shared equipment');
    }
    detailedScores['cross_contact_questions'] = crossContactScore;
    totalScore += crossContactScore;

    bool criticalFailure =
        orderedUnsafeFood && !conversationContext.allergiesDisclosed;
    if (criticalFailure) {
      improvements.insert(
        0,
        'CRITICAL: Ordered unsafe food without disclosing allergies',
      );
    }

    // Clamp score
    totalScore = totalScore.clamp(0, 120);
    detailedScores['total'] = totalScore;

    // Determine pass/fail
    bool passed = totalScore >= 85;
    String result = passed ? 'PASSED' : 'FAILED';

    return AssessmentResult(
      allergyDisclosureScore: allergyDisclosureScore,
      clarityScore: 0,
      proactivenessScore: 0,
      ingredientInquiryScore: ingredientScore,
      riskAssessmentScore: safeFoodScore,
      confidenceScore: 0,
      politenessScore: 0,
      completionBonus: 0,
      improvementBonus: 0,
      unsafeOrderPenalty: 0, // Penalty now included in safe food score
      crossContaminationScore: crossContactScore,
      totalScore: totalScore,
      overallGrade: passed ? 'PASS' : 'FAIL',
      strengths: strengths,
      improvements: improvements,
      detailedFeedback: '',
      assessedAt: sessionEnd,
      detailedScores: detailedScores,
      isAdvancedLevel: false,
      level: DifficultyLevel.intermediate,
      maxPossibleScore: 120,
      passingScore: 85,
      criticalFailure: criticalFailure,
    );
  }

  /// Advanced Level Scoring (Total: 150 pts, Pass: 120+)
  static Future<AssessmentResult> _scoreAdvancedLevel(
    List<ConversationTurn> conversationTurns,
    PlayerProfile playerProfile,
    ConversationContext conversationContext,
    String scenarioId,
    DateTime sessionStart,
    DateTime sessionEnd,
  ) async {
    int totalScore = 0;
    List<String> strengths = [];
    List<String> improvements = [];
    List<String> missedActions = [];
    List<String> earnedBonuses = [];
    Map<String, int> detailedScores = {};

    // 1. Allergy Disclosure (30 pts)
    int allergyDisclosureScore = 0;
    if (conversationContext.allergiesDisclosed) {
      allergyDisclosureScore = 30;
      strengths.add('Proactively disclosed allergies');
    } else {
      improvements.add('Advanced level requires immediate allergy disclosure');
      missedActions.add('Disclose allergies proactively');
    }
    detailedScores['allergy_disclosure'] = allergyDisclosureScore;
    totalScore += allergyDisclosureScore;

    // 2. Safe Food Choice (30 pts)
    int safeFoodScore = 0;
    bool orderedUnsafeFood = false;
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
        if (isSafe) {
          safeFoodScore = 30;
          strengths.add('Selected safe food option');
        } else {
          orderedUnsafeFood = true;
          safeFoodScore = -50; // Negative score for unsafe choice
          improvements.add('CRITICAL: Ordered food containing allergens');
        }
      }
    }
    detailedScores['safe_food_choice'] = safeFoodScore;
    totalScore += safeFoodScore;

    // 2.5. Order Decision After Safety Warning (30 pts) - CRITICAL FOR ADVANCED
    int orderDecisionScore = 0;
    if (conversationContext.safetyWarningGiven) {
      if (conversationContext.cancelledOrdersAfterWarning.isNotEmpty) {
        orderDecisionScore = 30;
        strengths.add(
          'Demonstrated excellent self-advocacy by cancelling unsafe order',
        );

        // Check if reorder was safe - critical for advanced level
        if (conversationContext.reorderedItemsAfterCancellation.isNotEmpty) {
          await MenuService.instance.loadMenu();
          final reorderedItem =
              conversationContext.reorderedItemsAfterCancellation.last;
          final menuItem = MenuService.instance.findItemByName(reorderedItem);
          if (menuItem != null) {
            final isSafe = MenuService.instance.isItemSafeForUser(
              menuItem,
              playerProfile.allergies,
            );
            if (isSafe) {
              orderDecisionScore += 20; // Higher bonus for advanced level
              strengths.add(
                'Expertly selected safe alternative after cancellation',
              );
            } else {
              orderDecisionScore -= 30; // Higher penalty for advanced level
              improvements.add(
                'CRITICAL: Reordered another unsafe item - failed to verify safety',
              );
              missedActions.add('Verify safety of reordered items');
            }
          }
        }
      } else if (conversationContext.keptUnsafeOrdersAfterWarning.isNotEmpty) {
        orderDecisionScore = -40; // Severe penalty for advanced level
        improvements.add(
          'CRITICAL FAILURE: Kept unsafe order despite clear warnings - this is dangerous',
        );
        missedActions.add('Cancel unsafe orders when warned about risks');
      }
    }
    detailedScores['order_decision_after_warning'] = orderDecisionScore;
    totalScore += orderDecisionScore;

    // 3. Ingredient Inquiry (20 pts)
    int ingredientScore = 0;
    bool askedAboutIngredients = conversationTurns.any(
      (turn) =>
          turn.userInput.toLowerCase().contains('ingredient') ||
          turn.userInput.toLowerCase().contains('contain') ||
          turn.userInput.toLowerCase().contains('what\'s in') ||
          turn.userInput.toLowerCase().contains('made with'),
    );

    if (askedAboutIngredients) {
      ingredientScore = 20;
      strengths.add('Asked detailed ingredient questions');
    } else {
      improvements.add('Must ask detailed ingredient questions');
      missedActions.add('Ask detailed ingredient questions');
    }
    detailedScores['ingredient_inquiry'] = ingredientScore;
    totalScore += ingredientScore;

    // 4. Cross-Contact Awareness (20 pts)
    int crossContactScore = 0;
    bool askedAboutCrossContact = conversationTurns.any(
      (turn) =>
          turn.userInput.toLowerCase().contains('cross') ||
          turn.userInput.toLowerCase().contains('contamination') ||
          turn.userInput.toLowerCase().contains('shared') ||
          turn.userInput.toLowerCase().contains('fryer') ||
          turn.userInput.toLowerCase().contains('equipment'),
    );

    if (askedAboutCrossContact) {
      crossContactScore = 20;
      strengths.add('Demonstrated cross-contamination awareness');
    } else {
      improvements.add('Must inquire about cross-contamination risks');
      missedActions.add('Inquire about cross-contamination risks');
    }
    detailedScores['cross_contact_awareness'] = crossContactScore;
    totalScore += crossContactScore;

    // 5. Preparation Method Check (15 pts)
    int preparationScore = 0;
    bool askedAboutPreparation = conversationTurns.any(
      (turn) =>
          turn.userInput.toLowerCase().contains('prepare') ||
          turn.userInput.toLowerCase().contains('cook') ||
          turn.userInput.toLowerCase().contains('made') ||
          turn.userInput.toLowerCase().contains('how is it'),
    );

    if (askedAboutPreparation) {
      preparationScore = 15;
      strengths.add('Verified preparation methods');
    } else {
      improvements.add('Ask about preparation methods');
      missedActions.add('Verify preparation methods');
    }
    detailedScores['preparation_method_check'] = preparationScore;
    totalScore += preparationScore;

    // 6. Hidden Allergen Questions (20 pts)
    int hiddenAllergenScore = 0;
    bool askedAboutHiddenAllergens = conversationTurns.any(
      (turn) =>
          turn.userInput.toLowerCase().contains('hidden') ||
          turn.userInput.toLowerCase().contains('sauce') ||
          turn.userInput.toLowerCase().contains('dressing') ||
          turn.userInput.toLowerCase().contains('stock') ||
          turn.userInput.toLowerCase().contains('broth'),
    );

    if (askedAboutHiddenAllergens) {
      hiddenAllergenScore = 20;
      strengths.add('Asked about hidden allergens in sauces/preparation');
    } else {
      improvements.add(
        'Must ask about hidden allergens in sauces and preparation',
      );
      missedActions.add('Ask about hidden allergens in sauces/dressings');
    }
    detailedScores['hidden_allergen_questions'] = hiddenAllergenScore;
    totalScore += hiddenAllergenScore;

    // 7. Reaction to Unsafe Dish (20 pts) - Only if unsafe dish was suggested
    int reactionScore = 0;
    bool waiterSuggestedUnsafe = false;
    for (final turn in conversationTurns) {
      final aiResponse = turn.aiResponse.toLowerCase();
      // Check if AI waiter mentioned any of the user's allergens in food suggestions
      for (final allergy in playerProfile.allergies) {
        if (aiResponse.contains(allergy.toLowerCase()) &&
            (aiResponse.contains('contains') || aiResponse.contains('has'))) {
          waiterSuggestedUnsafe = true;
          break;
        }
      }
    }

    if (waiterSuggestedUnsafe) {
      // Check if user properly rejected the unsafe suggestion
      bool rejectedUnsafeSuggestion = conversationTurns.any(
        (turn) =>
            turn.userInput.toLowerCase().contains('no') ||
            turn.userInput.toLowerCase().contains('different') ||
            turn.userInput.toLowerCase().contains('alternative') ||
            turn.userInput.toLowerCase().contains('not safe'),
      );

      if (rejectedUnsafeSuggestion) {
        reactionScore = 20;
        strengths.add('Properly rejected unsafe food suggestion');
      } else {
        improvements.add('Must reject unsafe food suggestions immediately');
      }
    } else {
      // Give partial credit if no unsafe suggestions were made
      reactionScore = 10;
    }
    detailedScores['reaction_to_unsafe_dish'] = reactionScore;
    totalScore += reactionScore;

    // 8. Assertiveness (10 pts)
    int assertivenessScore = 0;
    bool showedAssertiveness = conversationTurns.any(
      (turn) =>
          turn.userInput.toLowerCase().contains('need to') ||
          turn.userInput.toLowerCase().contains('must') ||
          turn.userInput.toLowerCase().contains('important') ||
          turn.userInput.toLowerCase().contains('serious') ||
          turn.userInput.toLowerCase().contains('cannot'),
    );

    if (showedAssertiveness) {
      assertivenessScore = 10;
      strengths.add('Demonstrated assertiveness about allergy needs');
    } else {
      improvements.add('Be more assertive about your allergy needs');
    }
    detailedScores['assertiveness'] = assertivenessScore;
    totalScore += assertivenessScore;

    // Simple scoring: 0 if not done, full points if done
    // No penalties - just tracking what wasn't done for feedback

    // Bonus tracking
    if (conversationTurns.any(
      (turn) =>
          turn.userInput.toLowerCase().contains('kitchen') ||
          turn.userInput.toLowerCase().contains('chef'),
    )) {
      earnedBonuses.add('Asked to verify with kitchen/chef');
    }

    if (conversationTurns.length >= 4) {
      earnedBonuses.add('Thorough questioning approach');
    }

    // Critical Failure Check
    bool criticalFailure =
        orderedUnsafeFood && !conversationContext.allergiesDisclosed;
    if (criticalFailure) {
      totalScore = (totalScore * 0.1).round(); // 90% penalty
      improvements.insert(
        0,
        'CRITICAL FAILURE: This would be life-threatening in real life',
      );
    }

    // Clamp score
    totalScore = totalScore.clamp(0, 150);
    detailedScores['total'] = totalScore;

    // Determine pass/fail
    bool passed = totalScore >= 120;
    String result = passed ? 'PASSED' : 'FAILED';

    return AssessmentResult(
      allergyDisclosureScore: allergyDisclosureScore,
      clarityScore: 0,
      proactivenessScore: 0,
      ingredientInquiryScore: ingredientScore,
      riskAssessmentScore: safeFoodScore,
      confidenceScore: 0,
      politenessScore: 0,
      completionBonus: 0,
      improvementBonus: 0,
      unsafeOrderPenalty: 0, // Penalty now included in safe food score
      crossContaminationScore: crossContactScore,
      hiddenAllergenScore: hiddenAllergenScore,
      preparationMethodScore: preparationScore,
      specificIngredientScore: 0,
      missedActions: missedActions,
      earnedBonuses: earnedBonuses,
      totalScore: totalScore,
      overallGrade: passed ? 'PASS' : 'FAIL',
      strengths: strengths,
      improvements: improvements,
      detailedFeedback: '',
      assessedAt: sessionEnd,
      detailedScores: detailedScores,
      isAdvancedLevel: true,
      level: DifficultyLevel.advanced,
      maxPossibleScore: 150,
      passingScore: 120,
      criticalFailure: criticalFailure,
    );
  }
}
