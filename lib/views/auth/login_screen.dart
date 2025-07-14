import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../controllers/auth_controller.dart';
import '../../models/user_model.dart';
import '../../shared/widgets/custom_button.dart';
import '../../core/constants.dart';
import '../home/home_view.dart';
import 'signup_screen.dart';
import 'email_verification_screen.dart';
import 'allergy_selection_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _rememberMe = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final authController = ref.read(authControllerProvider.notifier);

    // Listen to auth state changes
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      // Clear any existing errors first
      if (next.error != null) {
        _showErrorSnackBar(context, next.error!);
        return;
      }

      // Check if user just signed in successfully
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.largePadding),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 60),
                _buildHeader(),
                const SizedBox(height: 40),
                _buildEmailField(),
                const SizedBox(height: 20),
                _buildPasswordField(),
                const SizedBox(height: 12),
                _buildRememberMeAndForgotPassword(),
                const SizedBox(height: 32),
                _buildLoginButton(authState, authController),
                const SizedBox(height: 24),
                _buildDivider(),
                const SizedBox(height: 24),
                _buildGoogleSignInButton(authState, authController),
                const SizedBox(height: 40),
                _buildSignUpPrompt(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Text(
          'Welcome Back',
          style: AppTextStyles.headline1.copyWith(color: AppColors.primary),
        ),
        const SizedBox(height: 8),
        Text(
          'Log in to your ${AppConstants.appName} account',
          style: AppTextStyles.bodyText1.copyWith(color: AppColors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    return CustomTextField(
      label: 'Email Address',
      hint: 'Enter your email address',
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      isRequired: true,
      prefixIcon: const HugeIcon(
        icon: HugeIcons.strokeRoundedMail01,
        color: AppColors.grey,
        size: 20,
      ),
      validator: ValidationPatterns.validateEmail,
    );
  }

  Widget _buildPasswordField() {
    return CustomTextField(
      label: 'Password',
      hint: 'Enter your password',
      controller: _passwordController,
      isPassword: true,
      textInputAction: TextInputAction.done,
      isRequired: true,
      prefixIcon: const HugeIcon(
        icon: HugeIcons.strokeRoundedLockPassword,
        color: AppColors.grey,
        size: 20,
      ),
      validator: ValidationPatterns.validatePassword,
    );
  }

  Widget _buildRememberMeAndForgotPassword() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Checkbox(
              value: _rememberMe,
              onChanged: (value) {
                setState(() {
                  _rememberMe = value ?? false;
                });
              },
              activeColor: AppColors.primary,
            ),
            const Text('Remember me', style: AppTextStyles.bodyText2),
          ],
        ),
        TextButton(
          onPressed: () {
            _showForgotPasswordDialog();
          },
          child: Text(
            'Forgot Password?',
            style: AppTextStyles.bodyText2.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton(AuthState authState, AuthController authController) {
    return CustomButton.primary(
      text: 'Log In',
      isLoading: authState.isLoading,
      onPressed: () => _handleLogin(authController),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        const Expanded(
          child: Divider(color: AppColors.lightGrey, thickness: 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'OR',
            style: AppTextStyles.bodyText2.copyWith(
              color: AppColors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const Expanded(
          child: Divider(color: AppColors.lightGrey, thickness: 1),
        ),
      ],
    );
  }

  Widget _buildGoogleSignInButton(
    AuthState authState,
    AuthController authController,
  ) {
    return CustomButton.google(
      text: 'Sign in with Google',
      isLoading: authState.isLoading,
      onPressed: () => _handleGoogleSignIn(authController),
    );
  }

  Widget _buildSignUpPrompt() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Don\'t have an account? ',
          style: AppTextStyles.bodyText2.copyWith(color: AppColors.grey),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const SignupScreen()),
            );
          },
          child: Text(
            'Sign Up',
            style: AppTextStyles.bodyText2.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  void _handleLogin(AuthController authController) {
    if (_formKey.currentState!.validate()) {
      authController.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    }
  }

  void _handleGoogleSignIn(AuthController authController) {
    authController.signInWithGoogle();
  }

  void _showForgotPasswordDialog() {
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your email address and we\'ll send you a link to reset your password.',
            ),
            const SizedBox(height: 16),
            CustomTextField(
              label: 'Email Address',
              hint: 'Enter your email address',
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              isRequired: true,
              prefixIcon: const HugeIcon(
                icon: HugeIcons.strokeRoundedMail01,
                color: AppColors.grey,
                size: 20,
              ),
              validator: ValidationPatterns.validateEmail,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref
                  .read(authControllerProvider.notifier)
                  .sendPasswordResetEmail(emailController.text.trim());
            },
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.smallBorderRadius),
        ),
      ),
    );
  }

  void _navigateBasedOnUserState(UserModel user) {
    if (!user.isEmailVerified) {
      // Email not verified, go to email verification screen
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const EmailVerificationScreen(),
        ),
        (route) => false,
      );
    } else {
      // Check if user has allergies already set
      final hasAllergyData = user.allergies.isNotEmpty;

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
}
