import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../controllers/pen_reminder_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants.dart';

/// Dialog that appears when user taps on pen reminder notification
class PenReminderDialog extends ConsumerWidget {
  const PenReminderDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminderState = ref.watch(penReminderStateProvider);
    final reminderController = ref.watch(
      penReminderControllerProvider.notifier,
    );

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
      ),
      child: Container(
        padding: const EdgeInsets.all(AppConstants.defaultPadding * 1.5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.medication,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppConstants.defaultPadding),

            // Title
            const Text(
              '💉 Pen Check!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.defaultPadding / 2),

            // Message
            const Text(
              'Did you remember to bring your adrenaline pen today?',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.defaultPadding * 1.5),

            // Buttons
            if (reminderState.isLoading)
              const CircularProgressIndicator()
            else
              Row(
                children: [
                  // No button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final success = await reminderController.saveResponse(
                          false,
                        );
                        if (success && context.mounted) {
                          Navigator.of(context).pop();
                          _showConfirmationSnackBar(
                            context,
                            'No worries! Remember to carry it tomorrow',
                            isSuccess: false,
                          );
                        }
                      },
                      icon: const Icon(Icons.close, color: Colors.red),
                      label: const Text(
                        'No',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.red,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppConstants.defaultBorderRadius,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppConstants.defaultPadding),

                  // Yes button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final success = await reminderController.saveResponse(
                          true,
                        );
                        if (success && context.mounted) {
                          Navigator.of(context).pop();
                          _showConfirmationSnackBar(
                            context,
                            'Great! You\'re all set for today',
                            isSuccess: true,
                          );
                        }
                      },
                      icon: const Icon(Icons.check, color: Colors.white),
                      label: const Text(
                        'Yes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppConstants.defaultBorderRadius,
                          ),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),
                ],
              ),

            // Error message
            if (reminderState.error != null) ...[
              const SizedBox(height: AppConstants.defaultPadding),
              Container(
                padding: const EdgeInsets.all(AppConstants.defaultPadding),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(
                    AppConstants.defaultBorderRadius,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        reminderState.error!,
                        style: const TextStyle(color: Colors.red, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Close button (optional)
            const SizedBox(height: AppConstants.defaultPadding),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Remind me later',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Show confirmation snack bar after response
  void _showConfirmationSnackBar(
    BuildContext context,
    String message, {
    required bool isSuccess,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.info,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
        backgroundColor: isSuccess ? Colors.green : Colors.orange,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

/// Function to show pen reminder dialog
void showPenReminderDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false, // Prevent dismissal by tapping outside
    builder: (context) => const PenReminderDialog(),
  );
}

/// Full-screen version for when app is opened from notification
class PenReminderScreen extends ConsumerWidget {
  const PenReminderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminderState = ref.watch(penReminderStateProvider);
    final reminderController = ref.watch(
      penReminderControllerProvider.notifier,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Pen Reminder'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Large icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.medication,
                  size: 60,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: AppConstants.defaultPadding * 2),

              // Title
              const Text(
                '💉 Daily Pen Check!',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppConstants.defaultPadding),

              // Subtitle
              const Text(
                'It\'s important to carry your adrenaline pen every day for your safety.',
                style: TextStyle(
                  fontSize: 18,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppConstants.defaultPadding / 2),

              // Main question
              Container(
                padding: const EdgeInsets.all(AppConstants.defaultPadding),
                margin: const EdgeInsets.symmetric(
                  vertical: AppConstants.defaultPadding,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(
                    AppConstants.defaultBorderRadius,
                  ),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: const Text(
                  'Did you remember to bring your adrenaline pen today?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AppConstants.defaultPadding * 2),

              // Buttons
              if (reminderState.isLoading)
                const CircularProgressIndicator()
              else
                Column(
                  children: [
                    // Yes button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final success = await reminderController.saveResponse(
                            true,
                          );
                          if (success && context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                        icon: const Icon(
                          Icons.check_circle,
                          color: Colors.white,
                          size: 24,
                        ),
                        label: const Text(
                          'Yes, I have my pen!',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppConstants.defaultBorderRadius,
                            ),
                          ),
                          elevation: 3,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppConstants.defaultPadding),

                    // No button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final success = await reminderController.saveResponse(
                            false,
                          );
                          if (success && context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                        icon: const Icon(
                          Icons.cancel,
                          color: Colors.red,
                          size: 24,
                        ),
                        label: const Text(
                          'No, I forgot it',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.red,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          side: const BorderSide(color: Colors.red, width: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppConstants.defaultBorderRadius,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

              // Error message
              if (reminderState.error != null) ...[
                const SizedBox(height: AppConstants.defaultPadding),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppConstants.defaultPadding),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(
                      AppConstants.defaultBorderRadius,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          reminderState.error!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
