import 'package:flutter/material.dart';

/// Constants for AllerTeens application
class AppConstants {
  // App information
  static const String appName = 'allerteens';
  static const String appVersion = '1.0.0';
  static const String appDescription =
      'A mobile app for adolescents with severe food allergies';

  // Animation durations
  static const Duration defaultAnimationDuration = Duration(milliseconds: 300);
  static const Duration longAnimationDuration = Duration(milliseconds: 500);
  static const Duration shortAnimationDuration = Duration(milliseconds: 150);

  // Spacing constants
  static const double defaultPadding = 16.0;
  static const double largePadding = 24.0;
  static const double smallPadding = 8.0;
  static const double extraSmallPadding = 4.0;

  // Border radius
  static const double defaultBorderRadius = 12.0;
  static const double largeBorderRadius = 16.0;
  static const double smallBorderRadius = 8.0;

  // Icon sizes
  static const double defaultIconSize = 24.0;
  static const double largeIconSize = 32.0;
  static const double smallIconSize = 16.0;

  // Button heights
  static const double defaultButtonHeight = 56.0;
  static const double smallButtonHeight = 40.0;
  static const double largeButtonHeight = 64.0;

  // Form validation - More teen-friendly
  static const int minimumPasswordLength = 6;
  static const int maximumPasswordLength = 128;
  static const int minimumNameLength = 2;
  static const int maximumNameLength = 50;
}

/// Validation patterns and utilities
class ValidationPatterns {
  // Email validation pattern
  static const String emailPattern =
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';

  // Password validation pattern for teens (at least 6 characters, at least one letter and one number)
  static const String passwordPattern =
      r'^(?=.*[a-zA-Z])(?=.*\d)[a-zA-Z\d@$!%*?&_.-]{6,}$';

  // Name validation pattern (letters, spaces, hyphens, apostrophes only)
  static const String namePattern = r"^[a-zA-Z\s\-']+$";

  /// Validate email address
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email address is required';
    }

    final emailRegExp = RegExp(emailPattern);
    if (!emailRegExp.hasMatch(value)) {
      return 'Please enter a valid email address';
    }

    return null;
  }

  /// Validate password
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }

    if (value.length < AppConstants.minimumPasswordLength) {
      return 'Password must be at least ${AppConstants.minimumPasswordLength} characters';
    }

    if (value.length > AppConstants.maximumPasswordLength) {
      return 'Password must be less than ${AppConstants.maximumPasswordLength} characters';
    }

    final passwordRegExp = RegExp(passwordPattern);
    if (!passwordRegExp.hasMatch(value)) {
      return 'Password must contain at least one letter and one number';
    }

    return null;
  }

  /// Validate confirm password
  static String? validateConfirmPassword(
    String? value,
    String? originalPassword,
  ) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }

    if (value != originalPassword) {
      return 'Passwords do not match';
    }

    return null;
  }

  /// Validate name
  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Name is required';
    }

    if (value.length < AppConstants.minimumNameLength) {
      return 'Name must be at least ${AppConstants.minimumNameLength} characters';
    }

    if (value.length > AppConstants.maximumNameLength) {
      return 'Name must be less than ${AppConstants.maximumNameLength} characters';
    }

    final nameRegExp = RegExp(namePattern);
    if (!nameRegExp.hasMatch(value)) {
      return 'Name can only contain letters, spaces, hyphens, and apostrophes';
    }

    return null;
  }

  /// Validate required field
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }
}

/// Error messages
class ErrorMessages {
  // Authentication errors
  static const String authenticationFailed =
      'Authentication failed. Please try again.';
  static const String invalidCredentials = 'Invalid email or password.';
  static const String emailAlreadyInUse =
      'An account with this email already exists.';
  static const String weakPassword =
      'Password is too weak. Please choose a stronger password.';
  static const String userNotFound =
      'No account found with this email address.';
  static const String userDisabled = 'This account has been disabled.';
  static const String tooManyAttempts =
      'Too many login attempts. Please try again later.';
  static const String networkError =
      'Network error. Please check your connection and try again.';
  static const String unknownError =
      'An unexpected error occurred. Please try again.';

  // Form validation errors
  static const String fieldRequired = 'This field is required';
  static const String invalidEmailFormat = 'Please enter a valid email address';
  static const String passwordTooShort =
      'Password must be at least 6 characters';
  static const String passwordsDoNotMatch = 'Passwords do not match';
  static const String invalidName = 'Please enter a valid name';

  // Google Sign-In errors
  static const String googleSignInCancelled = 'Google Sign-In was cancelled';
  static const String googleSignInFailed =
      'Google Sign-In failed. Please try again.';

  // Email verification errors
  static const String emailVerificationFailed =
      'Failed to send verification email. Please try again.';
  static const String emailNotVerified =
      'Please verify your email address before continuing.';

  // Password reset errors
  static const String passwordResetFailed =
      'Failed to send password reset email. Please try again.';
  static const String invalidEmailForReset =
      'No account found with this email address.';
}

/// Success messages
class SuccessMessages {
  static const String accountCreated =
      'Account created successfully! Please check your email for verification.';
  static const String loginSuccessful = 'Login successful!';
  static const String logoutSuccessful = 'Logged out successfully.';
  static const String passwordResetSent =
      'Password reset email sent. Please check your inbox.';
  static const String emailVerificationSent =
      'Verification email sent. Please check your inbox.';
  static const String profileUpdated = 'Profile updated successfully.';
}

/// Route names
class RouteNames {
  static const String splash = '/splash';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String allergySelection = '/allergy-selection';
  static const String home = '/home';
  static const String profile = '/profile';
  static const String forgotPassword = '/forgot-password';
  static const String emailVerification = '/email-verification';
}

/// Asset paths
class AssetPaths {
  static const String logoPath = 'assets/images/logo.png';
  static const String googleLogoPath = 'assets/images/google_logo.png';
  static const String placeholderImagePath = 'assets/images/placeholder.png';
}

/// AllerTeens Color Palette
class AppColors {
  // Primary colors from your palette
  static const Color primary = Color(0xFF007C91); // Teal #007C91
  static const Color primaryDark = Color(0xFF005A68); // Darker teal
  static const Color primaryLight = Color(0xFF4AA5AD); // Lighter teal

  // Background colors from your palette
  static const Color background = Color(0xFFF6F6F6); // Light gray #F6F6F6
  static const Color surface = Color(0xFFFFFFFF); // Pure white
  static const Color surfaceVariant = Color(0xFFF6F6F6); // Light gray

  // Text colors from your palette
  static const Color textPrimary = Color(0xFF505665); // Dark gray #505665
  static const Color textSecondary = Color(0xFF939596); // Medium gray #939596
  static const Color onPrimary = Color(0xFFFFFFFF); // White on primary
  static const Color onBackground = Color(
    0xFF505665,
  ); // Dark gray on background
  static const Color onSurface = Color(0xFF505665); // Dark gray on surface

  // Neutral colors from your palette
  static const Color grey = Color(0xFF939596); // Medium gray #939596
  static const Color lightGrey = Color(0xFFF6F6F6); // Light gray #F6F6F6
  static const Color darkGrey = Color(0xFF505665); // Dark gray #505665

  // Secondary colors (using primary as secondary)
  static const Color secondary = Color(0xFF007C91); // Teal
  static const Color secondaryDark = Color(0xFF005A68); // Darker teal
  static const Color secondaryLight = Color(0xFF4AA5AD); // Lighter teal

  // Status colors
  static const Color success = Color(0xFF007C91); // Using primary teal
  static const Color warning = Color(0xFFF57C00); // Orange for warnings
  static const Color error = Color(0xFFD32F2F); // Red for errors
  static const Color info = Color(0xFF007C91); // Using primary teal

  // Basic colors
  static const Color white = Color(0xFFFFFFFF); // Pure white
  static const Color black = Color(
    0xFF505665,
  ); // Using dark gray instead of pure black

  // Legacy colors for compatibility
  static const Color accent = Color(0xFF007C91); // Teal
  static const Color accentLight = Color(0xFF4AA5AD); // Light teal
}

/// Text styles
class AppTextStyles {
  static const TextStyle headline1 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const TextStyle headline2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const TextStyle headline3 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyText1 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyText2 = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
  );

  static const TextStyle buttonText = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.white,
  );
}
