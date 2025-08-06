import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../models/training_assessment.dart';
import '../../models/scenario_models.dart';
import '../../shared/widgets/custom_button.dart';

/// Clean, professional feedback screen for all training levels
class CleanFeedbackScreen extends ConsumerStatefulWidget {
  final AssessmentResult assessment;
  final String scenarioTitle;
  final VoidCallback onRetry;
  final VoidCallback onBackToHome;

  const CleanFeedbackScreen({
    super.key,
    required this.assessment,
    required this.scenarioTitle,
    required this.onRetry,
    required this.onBackToHome,
  });

  @override
  ConsumerState<CleanFeedbackScreen> createState() =>
      _CleanFeedbackScreenState();
}

class _CleanFeedbackScreenState extends ConsumerState<CleanFeedbackScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: SafeArea(
                child: Column(
                  children: [
                    // Clean Header with Score
                    _buildCleanHeader(),

                    // Main Content
                    Expanded(
                      child: Container(
                        decoration: const BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(30),
                            topRight: Radius.circular(30),
                          ),
                        ),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              // Critical Status (if applicable)
                              if (widget.assessment.criticalFailure)
                                _buildCriticalFailureAlert(),

                              const SizedBox(height: 20),

                              // Main Score Card
                              _buildMainScoreCard(),

                              const SizedBox(height: 24),

                              // Level-Specific Scoring Breakdown
                              _buildLevelSpecificBreakdown(),

                              const SizedBox(height: 24),

                              // Feedback Section
                              _buildFeedbackSection(),

                              const SizedBox(height: 32),

                              // Action Buttons
                              _buildActionButtons(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCleanHeader() {
    final bool passed =
        widget.assessment.totalScore >= widget.assessment.passingScore;
    final String levelName = widget.assessment.level
        .toString()
        .split('.')
        .last
        .toUpperCase();

    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          // Score Circle
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: passed
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFFFF6F00),
                width: 3,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${widget.assessment.totalScore}',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: passed
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFFFF6F00),
                    ),
                  ),
                  Text(
                    '/${widget.assessment.maxPossibleScore}',
                    style: TextStyle(
                      fontSize: 10,
                      color: passed
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFFFF6F00),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 20),

          // Title and Result
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$levelName TRAINING',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: widget.assessment.criticalFailure
                            ? const Color(0xFFD32F2F)
                            : passed
                            ? const Color(0xFF388E3C)
                            : const Color(0xFFFF6F00),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        widget.assessment.criticalFailure
                            ? 'CRITICAL FAILURE'
                            : passed
                            ? 'PASSED'
                            : 'FAILED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  widget.scenarioTitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCriticalFailureAlert() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE57373)),
      ),
      child: Row(
        children: [
          Icon(Icons.dangerous, color: const Color(0xFFD32F2F), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Critical Safety Failure',
                  style: TextStyle(
                    color: const Color(0xFFD32F2F),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'You ordered food containing your allergens without proper disclosure. This would be dangerous in a real restaurant.',
                  style: TextStyle(
                    color: const Color(0xFFD32F2F),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainScoreCard() {
    final bool passed =
        widget.assessment.totalScore >= widget.assessment.passingScore;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: passed ? const Color(0xFFF1F8E9) : const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: passed ? const Color(0xFF4CAF50) : const Color(0xFFFF9800),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Final Score',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                'Target: ${widget.assessment.passingScore}+',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value:
                  (widget.assessment.totalScore /
                          widget.assessment.maxPossibleScore)
                      .clamp(0.0, 1.0),
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                passed ? const Color(0xFF4CAF50) : const Color(0xFFFF9800),
              ),
              minHeight: 12,
            ),
          ),

          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${widget.assessment.totalScore} / ${widget.assessment.maxPossibleScore} points',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Icon(
                passed ? Icons.check_circle : Icons.cancel,
                color: passed
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFFFF9800),
                size: 24,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLevelSpecificBreakdown() {
    switch (widget.assessment.level) {
      case DifficultyLevel.beginner:
        return _buildBeginnerBreakdown();
      case DifficultyLevel.intermediate:
        return _buildIntermediateBreakdown();
      case DifficultyLevel.advanced:
        return _buildAdvancedBreakdown();
    }
  }

  Widget _buildBeginnerBreakdown() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Beginner Level Breakdown',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          _buildScoreRow(
            'Allergy Disclosure',
            widget.assessment.allergyDisclosureScore,
            50,
          ),
          _buildScoreRow(
            'Safe Food Choice',
            widget.assessment.riskAssessmentScore,
            30,
          ),
          _buildScoreRow(
            'Ingredient Questions',
            widget.assessment.ingredientInquiryScore,
            10,
          ),
          if (widget.assessment.politenessScore > 0)
            _buildScoreRow(
              'Politeness Bonus',
              widget.assessment.politenessScore,
              10,
            ),

          if ((widget.assessment.detailedScores['no_disclosure_penalty'] ?? 0) <
              0)
            _buildScoreRow(
              'No Allergy Disclosure Penalty',
              widget.assessment.detailedScores['no_disclosure_penalty'] ?? 0,
              0,
              isNegative: true,
            ),
        ],
      ),
    );
  }

  Widget _buildIntermediateBreakdown() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Intermediate Level Breakdown',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          _buildScoreRow(
            'Allergy Disclosure',
            widget.assessment.allergyDisclosureScore,
            40,
          ),
          _buildScoreRow(
            'Safe Food Choice',
            widget.assessment.riskAssessmentScore,
            30,
          ),
          _buildScoreRow(
            'Ingredient Questions',
            widget.assessment.ingredientInquiryScore,
            15,
          ),
          _buildScoreRow(
            'Cross-Contact Awareness',
            widget.assessment.crossContaminationScore,
            15,
          ),

          if ((widget.assessment.detailedScores['no_disclosure_penalty'] ?? 0) <
              0)
            _buildScoreRow(
              'No Allergy Disclosure Penalty',
              widget.assessment.detailedScores['no_disclosure_penalty'] ?? 0,
              0,
              isNegative: true,
            ),
        ],
      ),
    );
  }

  Widget _buildAdvancedBreakdown() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Advanced Level Breakdown',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          _buildScoreRow(
            'Allergy Disclosure',
            widget.assessment.allergyDisclosureScore,
            30,
          ),
          _buildScoreRow(
            'Safe Food Choice',
            widget.assessment.riskAssessmentScore,
            30,
          ),
          _buildScoreRow(
            'Ingredient Inquiry',
            widget.assessment.ingredientInquiryScore,
            20,
          ),
          _buildScoreRow(
            'Cross-Contact Awareness',
            widget.assessment.crossContaminationScore,
            20,
          ),
          _buildScoreRow(
            'Preparation Methods',
            widget.assessment.preparationMethodScore,
            15,
          ),
          _buildScoreRow(
            'Hidden Allergen Questions',
            widget.assessment.hiddenAllergenScore,
            20,
          ),

          if ((widget.assessment.detailedScores['no_disclosure_penalty'] ?? 0) <
              0)
            _buildScoreRow(
              'No Allergy Disclosure Penalty',
              widget.assessment.detailedScores['no_disclosure_penalty'] ?? 0,
              0,
              isNegative: true,
            ),
          if ((widget
                      .assessment
                      .detailedScores['ignored_hidden_allergens_penalty'] ??
                  0) <
              0)
            _buildScoreRow(
              'Ignored Hidden Allergens Penalty',
              widget
                      .assessment
                      .detailedScores['ignored_hidden_allergens_penalty'] ??
                  0,
              0,
              isNegative: true,
            ),
          if ((widget.assessment.detailedScores['no_cross_contact_penalty'] ??
                  0) <
              0)
            _buildScoreRow(
              'No Cross-Contact Check Penalty',
              widget.assessment.detailedScores['no_cross_contact_penalty'] ?? 0,
              0,
              isNegative: true,
            ),
          if ((widget
                      .assessment
                      .detailedScores['missed_prep_inquiry_penalty'] ??
                  0) <
              0)
            _buildScoreRow(
              'Missed Preparation Inquiry Penalty',
              widget.assessment.detailedScores['missed_prep_inquiry_penalty'] ??
                  0,
              0,
              isNegative: true,
            ),
          if ((widget
                      .assessment
                      .detailedScores['critical_missed_actions_penalty'] ??
                  0) <
              0)
            _buildScoreRow(
              'Critical Missed Actions Penalty',
              widget
                      .assessment
                      .detailedScores['critical_missed_actions_penalty'] ??
                  0,
              0,
              isNegative: true,
            ),

          // Show missed actions for advanced
          if (widget.assessment.missedActions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Missed Critical Actions',
                    style: TextStyle(
                      color: Colors.red[800],
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...widget.assessment.missedActions.map(
                    (action) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('• ', style: TextStyle(color: Colors.red[700])),
                          Expanded(
                            child: Text(
                              action,
                              style: TextStyle(
                                color: Colors.red[700],
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScoreRow(
    String label,
    int score,
    int maxScore, {
    bool isNegative = false,
  }) {
    final Color color = isNegative
        ? Colors.red[600]!
        : score >= maxScore * 0.8
        ? const Color(0xFF4CAF50)
        : score >= maxScore * 0.5
        ? const Color(0xFFFF9800)
        : const Color(0xFFE57373);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              isNegative ? '$score pts' : '$score / $maxScore',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Personalized Feedback',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          Text(
            widget.assessment.detailedFeedback,
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: AppColors.textPrimary,
            ),
          ),

          if (widget.assessment.strengths.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'What You Did Well:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF4CAF50),
              ),
            ),
            const SizedBox(height: 8),
            ...widget.assessment.strengths.map(
              (strength) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: const Color(0xFF4CAF50),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        strength,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          if (widget.assessment.improvements.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Areas for Improvement:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFFF9800),
              ),
            ),
            const SizedBox(height: 8),
            ...widget.assessment.improvements
                .take(3)
                .map(
                  (improvement) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          color: const Color(0xFFFF9800),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            improvement,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: CustomButton(
            text: 'Try Again',
            onPressed: widget.onRetry,
            backgroundColor: AppColors.primary,
            textColor: AppColors.white,
            height: 48,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: CustomButton(
            text: 'Back to Home',
            onPressed: widget.onBackToHome,
            backgroundColor: AppColors.grey.withOpacity(0.2),
            textColor: AppColors.textPrimary,
            height: 48,
          ),
        ),
      ],
    );
  }
}
