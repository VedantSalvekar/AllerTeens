import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

/// Authentication state
class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? error;
  final bool isInitialized;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
    this.isInitialized = false,
  });

  /// Check if user is authenticated
  bool get isAuthenticated => user != null;

  /// Copy with updated fields
  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    String? error,
    bool? isInitialized,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }

  /// Clear error state
  AuthState clearError() {
    return copyWith(error: null);
  }

  @override
  String toString() {
    return 'AuthState(user: $user, isLoading: $isLoading, error: $error, isInitialized: $isInitialized)';
  }
}

/// Authentication controller using Riverpod StateNotifier
class AuthController extends StateNotifier<AuthState> {
  final AuthService _authService;

  AuthController(this._authService) : super(const AuthState()) {
    _initialize();
  }

  /// Initialize authentication state
  Future<void> _initialize() async {
    state = state.copyWith(isLoading: true);

    try {
      // Listen to auth state changes
      _authService.authStateChanges.listen((User? user) async {
        print(
          '🔄 [AUTH_CONTROLLER] Auth state changed: ${user?.email ?? 'null'}',
        );
        if (user != null) {
          // Get user model from Firestore with retry logic
          UserModel? userModel = await _authService.getCurrentUserModel();

          // Retry if user not found (might be a race condition)
          if (userModel == null) {
            print('⚠️ [AUTH_CONTROLLER] User model not found, retrying...');
            await Future.delayed(const Duration(milliseconds: 1000));
            userModel = await _authService.getCurrentUserModel();
          }

          // If still null, create a basic user model from Firebase Auth
          if (userModel == null) {
            print(
              '⚠️ [AUTH_CONTROLLER] Creating basic user model from Firebase Auth...',
            );
            userModel = UserModel.fromFirebaseUser(
              uid: user.uid,
              email: user.email!,
              displayName: user.displayName,
              photoUrl: user.photoURL,
              isEmailVerified: user.emailVerified,
            );
          }

          state = state.copyWith(
            user: userModel,
            isLoading: false,
            error: null,
            isInitialized: true,
          );
        } else {
          print('🔄 [AUTH_CONTROLLER] User signed out, updating state...');
          state = state.copyWith(
            user: null,
            isLoading: false,
            error: null,
            isInitialized: true,
          );
          print('✅ [AUTH_CONTROLLER] State updated for logout');
        }
      });
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to initialize authentication: $e',
        isInitialized: true,
      );
    }
  }

  /// Sign up with email and password
  Future<void> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
  }) async {
    print('🔵 [AUTH] Starting sign up process for email: $email, name: $name');

    // Validate inputs
    if (email.isEmpty || password.isEmpty || name.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        error: 'Please fill in all required fields',
      );
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      print('🔵 [AUTH] Calling auth service sign up...');
      final result = await _authService.signUpWithEmailAndPassword(
        email: email,
        password: password,
        name: name,
      );

      if (result.isSuccess) {
        print(
          '✅ [AUTH] Sign up successful for user: ${result.user?.name} (${result.user?.email})',
        );
        state = state.copyWith(
          user: result.user,
          isLoading: false,
          error: null,
        );
      } else {
        print('❌ [AUTH] Sign up failed with error: ${result.error}');
        state = state.copyWith(isLoading: false, error: result.error);
      }
    } on Exception catch (e) {
      print('💥 [AUTH] Sign up exception: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Sign up failed: ${e.toString()}',
      );
    } catch (e) {
      print('💥 [AUTH] Unexpected sign up error: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'An unexpected error occurred. Please try again.',
      );
    }
  }

  /// Sign in with email and password
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    print('🔵 [AUTH] Starting sign in process for email: $email');
    state = state.copyWith(isLoading: true, error: null);

    try {
      print('🔵 [AUTH] Calling auth service sign in...');
      final result = await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.isSuccess) {
        print(
          '✅ [AUTH] Sign in successful for user: ${result.user?.name} (${result.user?.email})',
        );

        // Update state immediately for loading state
        state = state.copyWith(isLoading: false, error: null);

        // The Firebase auth state listener will handle setting the user
        // This ensures proper navigation triggering
      } else {
        print('❌ [AUTH] Sign in failed with error: ${result.error}');
        state = state.copyWith(isLoading: false, error: result.error);
      }
    } catch (e) {
      print('💥 [AUTH] Sign in exception: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'An unexpected error occurred: $e',
      );
    }
  }

  /// Sign in with Google
  Future<void> signInWithGoogle() async {
    print('🔵 [AUTH] Starting Google Sign In process...');
    state = state.copyWith(isLoading: true, error: null);

    try {
      print('🔵 [AUTH] Calling auth service Google sign in...');
      final result = await _authService.signInWithGoogle();

      if (result.isSuccess) {
        print(
          '✅ [AUTH] Google Sign In successful for user: ${result.user?.name} (${result.user?.email})',
        );
        state = state.copyWith(
          user: result.user,
          isLoading: false,
          error: null,
        );
      } else {
        // Don't show error for user cancellation
        if (result.error?.contains('cancelled') == true) {
          print('⚠️ [AUTH] Google Sign In was cancelled by user');
          state = state.copyWith(isLoading: false, error: null);
        } else {
          print('❌ [AUTH] Google Sign In failed with error: ${result.error}');
          state = state.copyWith(isLoading: false, error: result.error);
        }
      }
    } catch (e) {
      print('💥 [AUTH] Google Sign In exception: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'An unexpected error occurred: $e',
      );
    }
  }

  /// Sign out
  Future<void> signOut() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      print('🔵 [AUTH] Calling auth service sign out...');
      await _authService.signOut();
      state = state.copyWith(
        error: null,
        isLoading: false,
        user: null,
        isInitialized: true,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to sign out: $e');
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _authService.sendPasswordResetEmail(email);

      if (result.isSuccess) {
        state = state.copyWith(isLoading: false, error: null);
      } else {
        state = state.copyWith(isLoading: false, error: result.error);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to send password reset email: $e',
      );
    }
  }

  /// Send email verification
  Future<void> sendEmailVerification() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _authService.sendEmailVerification();

      if (result.isSuccess) {
        state = state.copyWith(isLoading: false, error: null);
      } else {
        state = state.copyWith(isLoading: false, error: result.error);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to send email verification: $e',
      );
    }
  }

  /// Update user profile
  Future<void> updateUserProfile(UserModel userModel) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _authService.updateUserProfile(userModel);

      if (result.isSuccess) {
        state = state.copyWith(
          user: result.user,
          isLoading: false,
          error: null,
        );
      } else {
        state = state.copyWith(isLoading: false, error: result.error);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to update profile: $e',
      );
    }
  }

  /// Delete user account
  Future<void> deleteAccount() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _authService.deleteAccount();

      if (result.isSuccess) {
        state = state.copyWith(user: null, isLoading: false, error: null);
      } else {
        state = state.copyWith(isLoading: false, error: result.error);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to delete account: $e',
      );
    }
  }

  /// Check email verification status
  Future<void> checkEmailVerification() async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) return;

      // Reload user to get latest verification status
      await currentUser.reload();
      final updatedUser = _authService.currentUser;

      if (updatedUser != null && updatedUser.emailVerified) {
        // Update user model with verified status
        final userModel = await _authService.getCurrentUserModel();
        if (userModel != null) {
          final verifiedUserModel = userModel.copyWith(
            isEmailVerified: true,
            updatedAt: DateTime.now(),
          );
          await _authService.updateUserProfile(verifiedUserModel);

          state = state.copyWith(
            user: verifiedUserModel,
            isLoading: false,
            error: null,
          );
        }
      }
    } catch (e) {
      print('Error checking email verification: $e');
    }
  }

  /// Bypass email verification (Development/Testing only)
  Future<void> bypassEmailVerification() async {
    try {
      final currentUser = state.user;
      if (currentUser == null) return;

      print(
        '🔓 [AUTH_CONTROLLER] Bypassing email verification for development...',
      );

      // Update user model with verified status
      final verifiedUserModel = currentUser.copyWith(
        isEmailVerified: true,
        updatedAt: DateTime.now(),
      );

      // Update in Firestore
      await _authService.updateUserProfile(verifiedUserModel);

      // Update local state
      state = state.copyWith(
        user: verifiedUserModel,
        isLoading: false,
        error: null,
      );

      print('✅ [AUTH_CONTROLLER] Email verification bypassed successfully');
    } catch (e) {
      print('❌ [AUTH_CONTROLLER] Error bypassing email verification: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to bypass email verification: $e',
      );
    }
  }

  /// Clear error state
  void clearError() {
    state = state.clearError();
  }
}

/// Auth service provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

/// Auth controller provider
final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) {
    final authService = ref.watch(authServiceProvider);
    return AuthController(authService);
  },
);

/// Convenience provider for current user
final currentUserProvider = Provider<UserModel?>((ref) {
  final authState = ref.watch(authControllerProvider);
  return authState.user;
});

/// Convenience provider for authentication status
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authControllerProvider);
  return authState.isAuthenticated;
});

/// Convenience provider for loading state
final isLoadingProvider = Provider<bool>((ref) {
  final authState = ref.watch(authControllerProvider);
  return authState.isLoading;
});

/// Convenience provider for error state
final authErrorProvider = Provider<String?>((ref) {
  final authState = ref.watch(authControllerProvider);
  return authState.error;
});

/// Convenience provider for initialization state
final isInitializedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authControllerProvider);
  return authState.isInitialized;
});
