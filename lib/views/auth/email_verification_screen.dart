import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../../core/constants.dart';
import '../../controllers/auth_controller.dart';
import '../../shared/widgets/custom_button.dart';
import '../home/home_view.dart';
import 'allergy_selection_screen.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen> {
  Timer? _timer;
  bool _isResending = false;
  int _resendCooldown = 0;
  bool _showDeveloperOptions = false;

  @override
  void initState() {
    super.initState();
    _startEmailVerificationCheck();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startEmailVerificationCheck() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      await ref.read(authControllerProvider.notifier).checkEmailVerification();

      final authState = ref.read(authControllerProvider);
      if (authState.user?.isEmailVerified == true) {
        _timer?.cancel();
        if (mounted) {
          // Check if user has allergies already set
          final hasAllergyData = authState.user!.allergies.isNotEmpty;

          if (hasAllergyData) {
            // User already has allergy data, go directly to home
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const HomeView()),
              (route) => false,
            );
          } else {
            // User needs to set allergies first
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => const AllergySelectionScreen(),
              ),
              (route) => false,
            );
          }
        }
      }
    });
  }

  Future<void> _resendVerificationEmail() async {
    if (_isResending || _resendCooldown > 0) return;

    setState(() {
      _isResending = true;
    });

    await ref.read(authControllerProvider.notifier).sendEmailVerification();

    setState(() {
      _isResending = false;
      _resendCooldown = 60;
    });

    // Countdown timer
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCooldown > 0) {
        setState(() {
          _resendCooldown--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _bypassEmailVerification() async {
    if (!kDebugMode) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Developer Mode'),
        content: const Text(
          'This will bypass email verification for testing purposes. '
          'This option is only available in debug mode.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Bypass'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authControllerProvider.notifier).bypassEmailVerification();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final userEmail = authState.user?.email ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.developer_mode, color: AppColors.primary),
              onPressed: () {
                setState(() {
                  _showDeveloperOptions = !_showDeveloperOptions;
                });
              },
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom -
                  kToolbarHeight -
                  48, // Account for app bar and padding
            ),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  const SizedBox(height: 40),

                  // Email verification illustration
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.primary.withOpacity(0.8),
                          AppColors.secondary.withOpacity(0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(50),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.mark_email_unread_rounded,
                      size: 50,
                      color: AppColors.white,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Title
                  Text(
                    'Verify Your Email',
                    style: AppTextStyles.headline2.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 12),

                  // Subtitle
                  Text(
                    kDebugMode && _showDeveloperOptions
                        ? 'We\'ve sent a verification email to:'
                        : 'We\'ve sent a verification email to:',
                    style: AppTextStyles.bodyText1.copyWith(
                      color: AppColors.darkGrey,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 8),

                  // Email address
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      userEmail,
                      style: AppTextStyles.bodyText1.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Development mode notice
                  if (kDebugMode && _showDeveloperOptions) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.warning.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.developer_mode,
                                color: AppColors.warning,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Development Mode',
                                  style: AppTextStyles.bodyText1.copyWith(
                                    color: AppColors.warning,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'In the simulator, Firebase will send real emails to real email addresses. '
                            'For testing, you can use the bypass option below.',
                            style: AppTextStyles.bodyText2.copyWith(
                              color: AppColors.darkGrey,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Instructions
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.info.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.info.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: AppColors.info,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'What to do next:',
                                style: AppTextStyles.bodyText1.copyWith(
                                  color: AppColors.info,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '1. Check your email inbox (and spam folder)\n'
                          '2. Click the verification link in the email\n'
                          '3. Come back here - we\'ll automatically detect verification',
                          style: AppTextStyles.bodyText2.copyWith(
                            color: AppColors.darkGrey,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Resend email button
                  SizedBox(
                    width: double.infinity,
                    child: CustomButton(
                      text: _resendCooldown > 0
                          ? 'Resend in ${_resendCooldown}s'
                          : 'Resend Verification Email',
                      onPressed: _resendCooldown > 0
                          ? null
                          : _resendVerificationEmail,
                      isLoading: _isResending,
                      isOutlined: true,
                      icon: const Icon(Icons.refresh, size: 20),
                    ),
                  ),

                  // Developer bypass button
                  if (kDebugMode && _showDeveloperOptions) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: CustomButton(
                        text: 'Bypass Email Verification (Dev Only)',
                        onPressed: _bypassEmailVerification,
                        isOutlined: true,
                        backgroundColor: AppColors.warning,
                        icon: const Icon(Icons.developer_mode, size: 20),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Status indicator
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.warning.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.warning,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Checking verification status...',
                            style: AppTextStyles.bodyText2.copyWith(
                              color: AppColors.warning,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Help text
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Text(
                      kDebugMode
                          ? 'Having trouble? Use the developer mode button above, contact support, or try signing in with Google instead.'
                          : 'Having trouble? Contact support or try signing in with Google instead.',
                      style: AppTextStyles.bodyText2.copyWith(
                        color: AppColors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
