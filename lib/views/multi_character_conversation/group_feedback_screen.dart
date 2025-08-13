import 'package:flutter/material.dart';
import '../../core/constants.dart';

class GroupFeedbackScreen extends StatelessWidget {
  final String scenarioTitle;
  final bool refusedUnsafeFood;
  final bool mentionedAllergy;
  final bool explainedSeverity;
  final bool mentionedSevereSymptoms;
  final VoidCallback onRetry;
  final VoidCallback onBackToHome;

  const GroupFeedbackScreen({
    super.key,
    required this.scenarioTitle,
    required this.refusedUnsafeFood,
    required this.mentionedAllergy,
    required this.explainedSeverity,
    required this.mentionedSevereSymptoms,
    required this.onRetry,
    required this.onBackToHome,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildOutcomeRow(
                        'Refused unsafe food',
                        refusedUnsafeFood,
                      ),
                      _buildOutcomeRow('Disclosed allergy', mentionedAllergy),
                      _buildOutcomeRow(
                        'Explained seriousness',
                        explainedSeverity,
                      ),
                      _buildOutcomeRow(
                        'Mentioned severe symptoms',
                        mentionedSevereSymptoms,
                      ),
                      const SizedBox(height: 24),
                      _buildSuggestions(),
                      const SizedBox(height: 24),
                      _buildActions(context),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              scenarioTitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutcomeRow(String label, bool done) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: done ? const Color(0xFFF1F8E9) : const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: done ? const Color(0xFF4CAF50) : const Color(0xFFFF9800),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle : Icons.info_outline,
            color: done ? const Color(0xFF2E7D32) : const Color(0xFFEF6C00),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestions() {
    final suggestions = <String>[];
    if (!refusedUnsafeFood) {
      suggestions.add(
        'Practice a clear refusal like: "No thanks, I can\'t eat that."',
      );
    }
    if (!mentionedAllergy) {
      suggestions.add('Say explicitly: "I\'m allergic to peanuts."');
    }
    if (!explainedSeverity) {
      suggestions.add(
        'Explain the risk: "It\'s not mild — it can be serious for me."',
      );
    }
    if (!mentionedSevereSymptoms) {
      suggestions.add(
        'Mention outcomes: "I could have trouble breathing/anaphylaxis."',
      );
    }
    if (suggestions.isEmpty) {
      suggestions.add(
        'Great job! You disclosed, refused, and explained the risk clearly.',
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Suggestions',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          ...suggestions.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• '),
                  Expanded(
                    child: Text(
                      s,
                      style: const TextStyle(
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
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: onRetry,
            child: const Text('Try Again'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              side: BorderSide(color: AppColors.grey.withOpacity(0.3)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: onBackToHome,
            child: const Text('Back to Home'),
          ),
        ),
      ],
    );
  }
}
