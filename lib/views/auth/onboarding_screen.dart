import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../controllers/auth_controller.dart';
import '../../models/user_model.dart';
import '../../shared/widgets/custom_button.dart';
import '../../core/constants.dart';
import '../home/home_view.dart';
import 'login_screen.dart';
import 'signup_screen.dart';
import 'email_verification_screen.dart';
import 'allergy_selection_screen.dart';

/// Modern onboarding screen for AllerWise matching the exact design
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    // Listen to auth state changes
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      // Clear any existing errors first
      if (next.error != null) {
        _showErrorSnackBar(context, next.error!);
        return;
      }

      // Check if user just authenticated successfully
      if (next.user != null && next.isInitialized) {
        // Add a small delay to ensure state is properly set
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _navigateBasedOnUserState(next.user!);
          }
        });
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const SizedBox(height: 80),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Main heading text
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                        children: [
                          const TextSpan(text: 'Train your mind with '),
                          TextSpan(
                            text: 'AI',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const TextSpan(text: ' to\nstay '),
                          TextSpan(
                            text: 'Allergy-safe',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const TextSpan(text: ' in real life.'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 120),

                    // App name
                    Text(
                      'AllerWise',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Tagline
                    Text(
                      'Built to prepare you for the moments that matter.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              // Buttons section
              Column(
                children: [
                  // Get Started button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: authState.isLoading
                          ? null
                          : () => _navigateToSignup(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      child: Text(
                        'Get Started',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Continue with Google button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: authState.isLoading
                          ? null
                          : () => _handleGoogleSignIn(
                              ref.read(authControllerProvider.notifier),
                            ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.grey,
                        foregroundColor: AppColors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      child: authState.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.white,
                                ),
                              ),
                            )
                          : Text(
                              'Continue with Google',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.white,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Or text
                  Text(
                    'Or',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Login to your Account button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      onPressed: authState.isLoading
                          ? null
                          : () => _navigateToLogin(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: BorderSide(color: AppColors.textPrimary),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      child: Text(
                        'Login to your Account',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  /// Navigate based on user state
  void _navigateBasedOnUserState(UserModel user) {
    if (!user.isEmailVerified) {
      // Email not verified, go to email verification screen
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const EmailVerificationScreen(),
        ),
        (route) => false,
      );
    } else if (user.allergies.isNotEmpty) {
      // User already has allergy data, go directly to home
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const HomeView()),
        (route) => false,
      );
    } else {
      // User needs to set allergies first
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AllergySelectionScreen()),
        (route) => false,
      );
    }
  }

  /// Handle authentication state changes for navigation
  void _handleAuthStateChange(
    BuildContext context,
    AuthState? previous,
    AuthState next,
  ) {
    // This method is now replaced by the improved listener above
  }

  /// Navigate to signup screen
  void _navigateToSignup(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const SignupScreen()));
  }

  /// Navigate to login screen
  void _navigateToLogin(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const LoginScreen()));
  }

  /// Handle Google Sign In
  void _handleGoogleSignIn(AuthController authController) {
    authController.signInWithGoogle();
  }

  /// Show error snackbar
  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }
}
