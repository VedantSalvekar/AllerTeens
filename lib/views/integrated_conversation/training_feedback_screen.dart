import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../models/training_assessment.dart';
import '../../shared/widgets/custom_button.dart';

/// Comprehensive feedback screen displaying training assessment results
class TrainingFeedbackScreen extends ConsumerStatefulWidget {
  final AssessmentResult assessment;
  final String scenarioTitle;
  final VoidCallback onRetry;
  final VoidCallback onBackToHome;

  const TrainingFeedbackScreen({
    super.key,
    required this.assessment,
    required this.scenarioTitle,
    required this.onRetry,
    required this.onBackToHome,
  });

  @override
  ConsumerState<TrainingFeedbackScreen> createState() =>
      _TrainingFeedbackScreenState();
}

class _TrainingFeedbackScreenState extends ConsumerState<TrainingFeedbackScreen>
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
                    // Header
                    _buildHeader(),

                    // Feedback Content
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Performance Overview
                              _buildPerformanceOverview(),

                              const SizedBox(height: 24),

                              // Detailed Skills Assessment
                              _buildDetailedSkillsAssessment(),

                              const SizedBox(height: 24),

                              // Progress Insights
                              _buildProgressInsights(),

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

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.8),
            AppColors.primary.withOpacity(0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          // Score circle with color coding
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: _getScoreColor(widget.assessment.totalScore),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: _getScoreColor(
                    widget.assessment.totalScore,
                  ).withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${widget.assessment.totalScore}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _getScoreColor(widget.assessment.totalScore),
                    ),
                  ),
                  Text(
                    '/100',
                    style: TextStyle(
                      fontSize: 12,
                      color: _getScoreColor(widget.assessment.totalScore),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 20),
          // Title and subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Training Complete!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.scenarioTitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.assessment.detailedFeedback,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.white.withOpacity(0.8),
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimplifiedResults() {
    final mentionedAllergies = widget.assessment.allergyDisclosureScore > 0;
    final orderedSafely =
        widget.assessment.totalScore >= 90 ||
        (widget.assessment.totalScore >= 70 && mentionedAllergies);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Training Results',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),

        // Allergy Disclosure
        _buildSimpleResultItem(
          'Told waiter about allergies',
          mentionedAllergies,
          mentionedAllergies
              ? 'Great job!'
              : 'Remember to mention your allergies',
        ),

        const SizedBox(height: 12),

        // Safe Ordering
        _buildSimpleResultItem(
          'Ordered safe food',
          orderedSafely,
          orderedSafely ? 'Good choice!' : 'Ask about ingredients to stay safe',
        ),
      ],
    );
  }

  Widget _buildSimpleResultItem(String title, bool passed, String message) {
    final color = passed ? const Color(0xFF4CAF50) : const Color(0xFFFF9800);
    final icon = passed ? Icons.check_circle : Icons.warning;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    color: AppColors.textSecondary,
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

  Widget _buildPerformanceOverview() {
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
            'Performance Overview',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildScoreCard(
                  'Allergy Disclosure',
                  widget.assessment.allergyDisclosureScore,
                  70,
                  AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildScoreCard(
                  'Safety Awareness',
                  widget.assessment.riskAssessmentScore,
                  30,
                  AppColors.success,
                ),
              ),
            ],
          ),
          if (widget.assessment.unsafeOrderPenalty < 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.error.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: AppColors.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Unsafe Order Penalty',
                          style: TextStyle(
                            color: AppColors.error,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${widget.assessment.unsafeOrderPenalty} points - Ordered food containing your allergens',
                          style: TextStyle(
                            color: AppColors.error,
                            fontSize: 12,
                          ),
                        ),
                      ],
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

  Widget _buildScoreCard(
    String title,
    int score,
    int maxScore,
    Color fallbackColor,
  ) {
    final percentage = (score / maxScore).clamp(0.0, 1.0);
    final dynamicColor = _getScoreColorForPercentage(percentage);

    return Column(
      children: [
        Icon(Icons.analytics, color: dynamicColor, size: 20),
        const SizedBox(height: 8),
        Text(
          title,
          style: TextStyle(
            color: dynamicColor,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          '$score/$maxScore',
          style: TextStyle(
            color: dynamicColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: percentage,
          backgroundColor: dynamicColor.withOpacity(0.2),
          valueColor: AlwaysStoppedAnimation<Color>(dynamicColor),
          minHeight: 4,
        ),
      ],
    );
  }

  Widget _buildDetailedSkillsAssessment() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.assessment, color: AppColors.textPrimary, size: 24),
              const SizedBox(width: 12),
              Text(
                'Skills Assessment',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Key Skills Breakdown
          _buildSkillBreakdown(
            'Allergy Disclosure',
            widget.assessment.allergyDisclosureScore,
            70, // Updated max score
            widget.assessment.allergyDisclosureScore >= 70
                ? 'Excellent'
                : 'Needs Work',
            AppColors.primary,
          ),

          const SizedBox(height: 12),

          _buildSkillBreakdown(
            'Safety Awareness',
            widget.assessment.riskAssessmentScore,
            30, // Updated max score
            widget.assessment.riskAssessmentScore >= 30
                ? 'Excellent'
                : 'Needs Work',
            const Color(0xFF4CAF50),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillBreakdown(
    String skill,
    int score,
    int maxScore,
    String level,
    Color fallbackColor,
  ) {
    final percentage = (score / maxScore).clamp(0.0, 1.0);
    final dynamicColor = _getScoreColorForPercentage(percentage);

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            skill,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: LinearProgressIndicator(
            value: percentage,
            backgroundColor: dynamicColor.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(dynamicColor),
            minHeight: 6,
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: dynamicColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            level,
            style: TextStyle(
              color: dynamicColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressInsights() {
    final strengths = widget.assessment.strengths;
    final improvements = widget.assessment.improvements;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF4CAF50).withOpacity(0.1),
            const Color(0xFF4CAF50).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up, color: const Color(0xFF4CAF50), size: 24),
              const SizedBox(width: 12),
              Text(
                'Progress Insights',
                style: TextStyle(
                  color: const Color(0xFF4CAF50),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (strengths.isNotEmpty) ...[
            _buildInsightSection(
              'What You Did Well',
              strengths,
              const Color(0xFF4CAF50),
              Icons.check_circle,
            ),
            const SizedBox(height: 16),
          ],

          if (improvements.isNotEmpty) ...[
            _buildInsightSection(
              'Areas for Improvement',
              improvements,
              const Color(0xFFFF9800),
              Icons.lightbulb,
            ),
          ],

          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info, color: AppColors.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Each practice session helps you build confidence and develop essential allergy communication skills.',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightSection(
    String title,
    List<String> items,
    Color color,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 4,
                  margin: const EdgeInsets.only(top: 8, right: 12),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    item,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEssentialFeedback() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb, color: AppColors.primary, size: 24),
              const SizedBox(width: 12),
              Text(
                'Key Takeaway',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            widget.assessment.detailedFeedback,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              height: 1.5,
            ),
          ),
          if (widget.assessment.improvements.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Next time: ${widget.assessment.improvements.join(', ')}',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailedScores() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Detailed Breakdown',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),

        // Communication Skills
        _buildScoreCategory(
          'Communication Skills',
          widget.assessment.communicationScore,
          40,
          AppColors.primary,
          [
            _buildScoreItem(
              'Allergy Disclosure',
              widget.assessment.allergyDisclosureScore,
              15,
            ),
            _buildScoreItem('Clarity', widget.assessment.clarityScore, 10),
            _buildScoreItem(
              'Proactiveness',
              widget.assessment.proactivenessScore,
              15,
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Safety Awareness
        _buildScoreCategory(
          'Safety Awareness',
          widget.assessment.safetyScore,
          30,
          const Color(0xFF4CAF50),
          [
            _buildScoreItem(
              'Ingredient Inquiry',
              widget.assessment.ingredientInquiryScore,
              15,
            ),
            _buildScoreItem(
              'Risk Assessment',
              widget.assessment.riskAssessmentScore,
              15,
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Social Skills
        _buildScoreCategory(
          'Social Skills',
          widget.assessment.socialScore,
          20,
          const Color(0xFF9C27B0),
          [
            _buildScoreItem(
              'Confidence',
              widget.assessment.confidenceScore,
              10,
            ),
            _buildScoreItem(
              'Politeness',
              widget.assessment.politenessScore,
              10,
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Bonus Points
        _buildScoreCategory(
          'Bonus Points',
          widget.assessment.bonusScore,
          10,
          const Color(0xFFFF9800),
          [
            _buildScoreItem('Completion', widget.assessment.completionBonus, 5),
            _buildScoreItem(
              'Improvement',
              widget.assessment.improvementBonus,
              5,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildScoreCategory(
    String title,
    int score,
    int maxScore,
    Color color,
    List<Widget> items,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '$score/$maxScore',
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: score / maxScore,
            backgroundColor: color.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
          const SizedBox(height: 12),
          ...items,
        ],
      ),
    );
  }

  Widget _buildScoreItem(String title, int score, int maxScore) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const Spacer(),
          Text(
            '$score/$maxScore',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStrengthsAndImprovements() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Strengths
        Expanded(
          child: _buildFeedbackCard(
            title: 'Strengths',
            icon: Icons.star,
            color: const Color(0xFF4CAF50),
            items: widget.assessment.strengths,
          ),
        ),

        const SizedBox(width: 16),

        // Improvements
        Expanded(
          child: _buildFeedbackCard(
            title: 'Areas to Improve',
            icon: Icons.trending_up,
            color: const Color(0xFFFF9800),
            items: widget.assessment.improvements,
          ),
        ),
      ],
    );
  }

  Widget _buildFeedbackCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<String> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Text(
              'Keep practicing!',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            )
          else
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle, color: color, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailedFeedback() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.feedback, color: AppColors.primary, size: 24),
              const SizedBox(width: 12),
              Text(
                'Detailed Feedback',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            widget.assessment.detailedFeedback,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              height: 1.5,
            ),
          ),
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
            height: 44,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: CustomButton(
            text: 'Back to Home',
            onPressed: widget.onBackToHome,
            backgroundColor: AppColors.grey.withOpacity(0.2),
            textColor: AppColors.textPrimary,
            height: 44,
          ),
        ),
      ],
    );
  }

  Color _getGradeColor(String grade) {
    switch (grade) {
      case 'A+':
      case 'A':
        return const Color(0xFF4CAF50);
      case 'B+':
      case 'B':
        return const Color(0xFF2196F3);
      case 'C+':
      case 'C':
        return const Color(0xFFFF9800);
      case 'D+':
      case 'D':
        return const Color(0xFFFF5722);
      default:
        return const Color(0xFFF44336);
    }
  }

  String _getScoreMessage(int score) {
    if (score >= 90) return 'Outstanding Performance!';
    if (score >= 80) return 'Great Job!';
    if (score >= 70) return 'Good Work!';
    if (score >= 60) return 'Keep Practicing!';
    return 'Let\'s Try Again!';
  }

  Color _getScoreColor(int score) {
    if (score >= 90) return const Color(0xFF4CAF50); // Green - Excellent
    if (score >= 70) return const Color(0xFF2196F3); // Blue - Good
    if (score >= 50) return const Color(0xFFFF9800); // Orange - Average
    return const Color(0xFFF44336); // Red - Poor
  }

  Color _getScoreColorForPercentage(double percentage) {
    if (percentage >= 0.9) return const Color(0xFF4CAF50); // Green - Excellent
    if (percentage >= 0.7) return const Color(0xFF2196F3); // Blue - Good
    if (percentage >= 0.5) return const Color(0xFFFF9800); // Orange - Average
    return const Color(0xFFF44336); // Red - Poor
  }
}
