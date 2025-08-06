import '../models/training_assessment.dart';
import '../models/scenario_models.dart';

/// Generates personalized, level-appropriate feedback for training assessments
class FeedbackBuilder {
  /// Generate comprehensive feedback based on assessment results and level
  static FeedbackResult generateFeedback({
    required AssessmentResult assessment,
    required DifficultyLevel level,
  }) {
    switch (level) {
      case DifficultyLevel.beginner:
        return _generateBeginnerFeedback(assessment);
      case DifficultyLevel.intermediate:
        return _generateIntermediateFeedback(assessment);
      case DifficultyLevel.advanced:
        return _generateAdvancedFeedback(assessment);
    }
  }

  /// Generate encouraging, growth-focused feedback for beginners
  static FeedbackResult _generateBeginnerFeedback(AssessmentResult assessment) {
    final buffer = StringBuffer();
    final List<String> actionableImprovements = [];

    // Determine overall tone based on performance
    if (assessment.criticalFailure) {
      buffer.write(
        'This training session highlighted some important safety concerns. ',
      );
      buffer.write(
        'The most critical skill for managing food allergies is communicating clearly with restaurant staff. ',
      );
    } else if (assessment.totalScore >= 85) {
      buffer.write('Outstanding work! ');
      buffer.write('You\'re showing excellent allergy communication skills. ');
    } else if (assessment.totalScore >= 70) {
      buffer.write('Great job! ');
      buffer.write(
        'You\'re building strong foundational skills for safe dining. ',
      );
    } else if (assessment.totalScore >= 50) {
      buffer.write('Good effort! ');
      buffer.write('You\'re learning important safety habits. ');
    } else {
      buffer.write('Keep practicing! ');
      buffer.write(
        'Every conversation helps you build confidence and safety skills. ',
      );
    }

    // Convert improvements to actionable advice (for separate display)
    for (final improvement in assessment.improvements) {
      if (improvement.toLowerCase().contains('allerg')) {
        actionableImprovements.add(
          'Practice saying "I have a [your allergy] allergy" right when you sit down',
        );
      } else if (improvement.toLowerCase().contains('ingredient')) {
        actionableImprovements.add(
          'Ask "What are the main ingredients in this dish?" before ordering',
        );
      } else if (improvement.toLowerCase().contains('safe')) {
        actionableImprovements.add(
          'Always verify food is safe before ordering: "Is this dish safe for someone with [your allergy]?"',
        );
      } else if (improvement.toLowerCase().contains('critical') ||
          improvement.toLowerCase().contains('safety')) {
        actionableImprovements.add(
          'Always tell restaurant staff about your allergies BEFORE ordering any food',
        );
      } else if (improvement.toLowerCase().contains(
            'unsafe order after warning',
          ) ||
          improvement.toLowerCase().contains('kept') &&
              improvement.toLowerCase().contains('warning')) {
        actionableImprovements.add(
          'When a waiter warns you about safety risks, cancel your order and choose something safer',
        );
      } else if (improvement.toLowerCase().contains('reorder') &&
          improvement.toLowerCase().contains('unsafe')) {
        actionableImprovements.add(
          'After cancelling an unsafe order, carefully check that your new choice is actually safe',
        );
      } else {
        actionableImprovements.add(improvement);
      }
    }

    // Encouraging conclusion
    buffer.write(
      'Remember: every time you practice, you\'re building life-saving skills and confidence! ',
    );
    buffer.write(
      'Clear communication keeps you safe and helps you enjoy dining out worry-free.',
    );

    return FeedbackResult(
      feedbackParagraph: buffer.toString(),
      strengths: assessment.strengths,
      improvements: actionableImprovements,
      tone: FeedbackTone.encouraging,
    );
  }

  /// Generate balanced feedback with constructive critique for intermediate level
  static FeedbackResult _generateIntermediateFeedback(
    AssessmentResult assessment,
  ) {
    final buffer = StringBuffer();
    final List<String> actionableImprovements = [];

    // Professional but supportive tone
    if (assessment.criticalFailure) {
      buffer.write(
        'This session revealed critical safety gaps that need immediate attention. ',
      );
      buffer.write(
        'At the intermediate level, you should be confidently managing your allergy safety in most restaurant situations. ',
      );
    } else if (assessment.totalScore >= 100) {
      buffer.write('Excellent performance! ');
      buffer.write(
        'You demonstrated strong, professional-level allergy communication skills. ',
      );
    } else if (assessment.totalScore >= 85) {
      buffer.write('Good work! ');
      buffer.write('You\'re showing solid allergy management skills. ');
    } else if (assessment.totalScore >= 65) {
      buffer.write('Decent effort, but there\'s room for improvement. ');
      buffer.write(
        'You need to be more thorough in your safety communication. ',
      );
    } else {
      buffer.write('This performance needs significant improvement. ');
      buffer.write(
        'At the intermediate level, more comprehensive safety practices are expected. ',
      );
    }

    // Convert improvements to actionable advice (for separate display)
    for (final improvement in assessment.improvements) {
      if (improvement.toLowerCase().contains('cross') ||
          improvement.toLowerCase().contains('contamination')) {
        actionableImprovements.add(
          'Ask about cross-contamination: "Are your cooking surfaces and equipment cleaned between orders?"',
        );
      } else if (improvement.toLowerCase().contains('allerg')) {
        actionableImprovements.add(
          'Disclose allergies immediately and specifically: "I have a severe [allergy] allergy"',
        );
      } else if (improvement.toLowerCase().contains('ingredient')) {
        actionableImprovements.add(
          'Inquire about all ingredients including seasonings, sauces, and preparation methods',
        );
      } else if (improvement.toLowerCase().contains('preparation')) {
        actionableImprovements.add(
          'Ask detailed preparation questions: "How is this dish prepared? What cooking oils are used?"',
        );
      } else if (improvement.toLowerCase().contains(
            'unsafe order after warning',
          ) ||
          improvement.toLowerCase().contains('kept') &&
              improvement.toLowerCase().contains('warning')) {
        actionableImprovements.add(
          'When staff raise safety concerns, take them seriously and change your order immediately',
        );
      } else if (improvement.toLowerCase().contains('reorder') &&
          improvement.toLowerCase().contains('unsafe')) {
        actionableImprovements.add(
          'Always verify your replacement order is safe - don\'t assume alternatives are automatically safer',
        );
      } else {
        actionableImprovements.add(improvement);
      }
    }

    // Professional conclusion
    buffer.write(
      'Continue practicing to build the confidence and thoroughness needed for safe dining experiences. ',
    );
    buffer.write(
      'Consistent communication habits will serve you well in any restaurant setting.',
    );

    return FeedbackResult(
      feedbackParagraph: buffer.toString(),
      strengths: assessment.strengths,
      improvements: actionableImprovements,
      tone: FeedbackTone.balanced,
    );
  }

  /// Generate tough, realistic feedback highlighting real-world consequences for advanced level
  static FeedbackResult _generateAdvancedFeedback(AssessmentResult assessment) {
    final buffer = StringBuffer();
    final List<String> actionableImprovements = [];

    // High-pressure, realistic tone
    if (assessment.criticalFailure) {
      buffer.write(
        'CRITICAL FAILURE: This performance would be life-threatening in a real restaurant. ',
      );
      buffer.write(
        'You ordered food containing your allergens without proper disclosure - this is exactly how serious allergic reactions occur. ',
      );
      buffer.write(
        'Advanced training demands the highest safety standards because real-world consequences are severe. ',
      );
    } else if (assessment.totalScore >= 135) {
      buffer.write('Professional-grade performance. ');
      buffer.write(
        'You demonstrated the thorough, systematic approach required for safe dining with severe allergies. ',
      );
    } else if (assessment.totalScore >= 120) {
      buffer.write('Solid work meeting advanced standards. ');
      buffer.write(
        'You showed good awareness of the complex safety considerations required for real-world dining. ',
      );
    } else if (assessment.totalScore >= 90) {
      buffer.write('Insufficient for advanced level expectations. ');
      buffer.write(
        'This level of performance could lead to dangerous situations in busy, high-pressure restaurant environments. ',
      );
    } else {
      buffer.write('Unacceptable performance for advanced training. ');
      buffer.write(
        'This approach to allergy management puts you at serious risk and fails to meet real-world safety standards. ',
      );
    }

    // Convert improvements and missed actions to actionable advice (for separate display)
    final allGaps = [...assessment.improvements, ...assessment.missedActions];

    for (final gap in allGaps.take(6)) {
      if (gap.toLowerCase().contains('allerg') &&
          gap.toLowerCase().contains('critical')) {
        actionableImprovements.add(
          'IMMEDIATE allergy disclosure is non-negotiable - failure to do this causes hospitalizations',
        );
      } else if (gap.toLowerCase().contains('hidden')) {
        actionableImprovements.add(
          'Question every sauce, stock, seasoning, and preparation method - hidden allergens are everywhere',
        );
      } else if (gap.toLowerCase().contains('cross')) {
        actionableImprovements.add(
          'Demand specific details about equipment cleaning, shared fryers, and surface preparation',
        );
      } else if (gap.toLowerCase().contains('preparation')) {
        actionableImprovements.add(
          'Interrogate cooking methods: oils used, shared equipment, cleaning protocols between orders',
        );
      } else if (gap.toLowerCase().contains('assertive')) {
        actionableImprovements.add(
          'Be firmly assertive - your life depends on clear, uncompromising communication',
        );
      } else if (gap.toLowerCase().contains('kitchen')) {
        actionableImprovements.add(
          'Insist on kitchen verification and direct communication with food preparation staff',
        );
      } else if (gap.toLowerCase().contains('kept unsafe order') ||
          gap.toLowerCase().contains('critical failure') &&
              gap.toLowerCase().contains('warning')) {
        actionableImprovements.add(
          'NEVER keep an order when staff warn about safety risks - this is how allergic reactions happen',
        );
      } else if (gap.toLowerCase().contains('reorder') &&
          gap.toLowerCase().contains('unsafe')) {
        actionableImprovements.add(
          'CRITICAL ERROR: You must verify ALL aspects of replacement orders - one mistake can be fatal',
        );
      } else {
        actionableImprovements.add(gap);
      }
    }

    // Realistic, tough conclusion
    if (assessment.criticalFailure) {
      buffer.write(
        'This training revealed potentially fatal communication gaps. ',
      );
      buffer.write(
        'In real restaurants, staff are busy, distracted, and may not understand allergy severity. ',
      );
      buffer.write(
        'Your approach must be flawless, systematic, and assertive every single time.',
      );
    } else if (assessment.totalScore < 120) {
      buffer.write(
        'Real restaurants are chaotic, understaffed environments where mistakes happen frequently. ',
      );
      buffer.write(
        'Your communication must be thorough enough to prevent life-threatening errors.',
      );
    } else {
      buffer.write(
        'This level of systematic safety communication gives you the best chance of avoiding dangerous mistakes in real-world dining situations.',
      );
    }

    return FeedbackResult(
      feedbackParagraph: buffer.toString(),
      strengths: assessment.strengths,
      improvements: actionableImprovements,
      tone: FeedbackTone.challenging,
    );
  }
}

/// Container for generated feedback components
class FeedbackResult {
  final String feedbackParagraph;
  final List<String> strengths;
  final List<String> improvements;
  final FeedbackTone tone;

  const FeedbackResult({
    required this.feedbackParagraph,
    required this.strengths,
    required this.improvements,
    required this.tone,
  });
}

/// Tone of the feedback message
enum FeedbackTone { encouraging, balanced, challenging }
