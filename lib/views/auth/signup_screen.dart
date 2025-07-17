import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../controllers/auth_controller.dart';
import '../../models/user_model.dart';
import '../../shared/widgets/custom_button.dart';
import '../../core/constants.dart';
import '../home/home_view.dart';
import 'email_verification_screen.dart';
import 'allergy_selection_screen.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _acceptTerms = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final authController = ref.read(authControllerProvider.notifier);

    // Listen to auth state changes for error handling only
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next.error != null) {
        _showErrorSnackBar(context, next.error!);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.largePadding),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                const SizedBox(height: 32),
                _buildNameField(),
                const SizedBox(height: 20),
                _buildEmailField(),
                const SizedBox(height: 20),
                _buildPasswordField(),
                const SizedBox(height: 20),
                _buildConfirmPasswordField(),
                const SizedBox(height: 20),
                _buildTermsAndConditions(),
                const SizedBox(height: 32),
                _buildSignUpButton(authState, authController),
                const SizedBox(height: 24),
                _buildDivider(),
                const SizedBox(height: 24),
                _buildGoogleSignInButton(authState, authController),
                const SizedBox(height: 40),
                _buildLoginPrompt(),
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
          'Create Account',
          style: AppTextStyles.headline1.copyWith(color: AppColors.primary),
        ),
        const SizedBox(height: 8),
        Text(
          'Join ${AppConstants.appName} to manage your allergies safely',
          style: AppTextStyles.bodyText1.copyWith(color: AppColors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildNameField() {
    return CustomTextField(
      label: 'Full Name',
      hint: 'Enter your full name',
      controller: _nameController,
      keyboardType: TextInputType.name,
      textInputAction: TextInputAction.next,
      isRequired: true,
      prefixIcon: const HugeIcon(
        icon: HugeIcons.strokeRoundedUser,
        color: AppColors.grey,
        size: 20,
      ),
      validator: ValidationPatterns.validateName,
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
      hint: 'Create a strong password',
      controller: _passwordController,
      isPassword: true,
      textInputAction: TextInputAction.next,
      isRequired: true,
      prefixIcon: const HugeIcon(
        icon: HugeIcons.strokeRoundedLockPassword,
        color: AppColors.grey,
        size: 20,
      ),
      validator: ValidationPatterns.validatePassword,
    );
  }

  Widget _buildConfirmPasswordField() {
    return CustomTextField(
      label: 'Confirm Password',
      hint: 'Confirm your password',
      controller: _confirmPasswordController,
      isPassword: true,
      textInputAction: TextInputAction.done,
      isRequired: true,
      prefixIcon: const HugeIcon(
        icon: HugeIcons.strokeRoundedLockPassword,
        color: AppColors.grey,
        size: 20,
      ),
      validator: (value) => ValidationPatterns.validateConfirmPassword(
        value,
        _passwordController.text,
      ),
    );
  }

  Widget _buildTermsAndConditions() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: _acceptTerms,
          onChanged: (value) {
            setState(() {
              _acceptTerms = value ?? false;
            });
          },
          activeColor: AppColors.primary,
        ),
        Expanded(
          child: RichText(
            text: TextSpan(
              text: 'I agree to the ',
              style: AppTextStyles.bodyText2.copyWith(
                color: AppColors.darkGrey,
              ),
              children: [
                TextSpan(
                  text: 'Terms of Service',
                  style: AppTextStyles.bodyText2.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
                TextSpan(
                  text: ' and ',
                  style: AppTextStyles.bodyText2.copyWith(
                    color: AppColors.darkGrey,
                  ),
                ),
                TextSpan(
                  text: 'Privacy Policy',
                  style: AppTextStyles.bodyText2.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSignUpButton(
    AuthState authState,
    AuthController authController,
  ) {
    return CustomButton.primary(
      text: 'Create Account',
      isLoading: authState.isLoading,
      onPressed: _acceptTerms ? () => _handleSignUp(authController) : null,
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
      text: 'Sign up with Google',
      isLoading: authState.isLoading,
      onPressed: () => _handleGoogleSignIn(authController),
    );
  }

  Widget _buildLoginPrompt() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Already have an account? ',
          style: AppTextStyles.bodyText2.copyWith(color: AppColors.grey),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(
            'Sign In',
            style: AppTextStyles.bodyText2.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  void _handleSignUp(AuthController authController) {
    if (_formKey.currentState!.validate()) {
      if (!_acceptTerms) {
        _showErrorSnackBar(
          context,
          'Please accept the Terms of Service and Privacy Policy',
        );
        return;
      }

      authController.signUpWithEmailAndPassword(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    }
  }

  void _handleGoogleSignIn(AuthController authController) {
    if (!_acceptTerms) {
      _showErrorSnackBar(
        context,
        'Please accept the Terms of Service and Privacy Policy',
      );
      return;
    }

    authController.signInWithGoogle();
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
}
