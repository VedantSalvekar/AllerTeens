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
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthState &&
          runtimeType == other.runtimeType &&
          user == other.user &&
          isLoading == other.isLoading &&
          error == other.error &&
          isInitialized == other.isInitialized;

  @override
  int get hashCode =>
      user.hashCode ^
      isLoading.hashCode ^
      error.hashCode ^
      isInitialized.hashCode;

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
      // Listen to auth state changes with error handling
      _authService.authStateChanges.listen(
        (User? user) async {
          try {
            print(
              '[AUTH_CONTROLLER] Auth state changed: ${user?.email ?? 'null'}',
            );

            if (user != null) {
              print('[AUTH_CONTROLLER] User signed in, updating state...');

              // Create immediate basic model to prevent UI blocking
              UserModel basicUserModel = UserModel.fromFirebaseUser(
                uid: user.uid,
                email: user.email!,
                displayName: user.displayName,
                photoUrl: user.photoURL,
                isEmailVerified: user.emailVerified,
              );

              // Update state immediately for fast UI response
              state = state.copyWith(
                user: basicUserModel,
                isLoading: false,
                error: null,
                isInitialized: true,
              );
              print('[AUTH_CONTROLLER] State updated with basic user info');

              // Try to get enhanced user data from Firestore with retry logic
              _loadUserDataWithRetry(user.uid, basicUserModel);
            } else {
              print('[AUTH_CONTROLLER] User signed out, updating state...');
              final newState = AuthState(
                user: null,
                isLoading: false,
                error: null,
                isInitialized: true,
              );
              state = newState;
              print(
                '[AUTH_CONTROLLER] State updated for logout - new state: $newState',
              );
            }
          } catch (e) {
            print('[AUTH_CONTROLLER] Error in auth state listener: $e');
            state = state.copyWith(
              isLoading: false,
              error: 'Authentication error: $e',
              isInitialized: true,
            );
          }
        },
        onError: (error) {
          print('[AUTH_CONTROLLER] Auth stream error: $error');
          state = state.copyWith(
            isLoading: false,
            error: 'Authentication stream error: $error',
            isInitialized: true,
          );
        },
      );
    } catch (e) {
      print('[AUTH_CONTROLLER] Failed to initialize auth listener: $e');
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
    print('[AUTH] Starting sign up process for email: $email, name: $name');

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
      print('[AUTH] Calling auth service sign up...');
      final result = await _authService.signUpWithEmailAndPassword(
        email: email,
        password: password,
        name: name,
      );

      if (result.isSuccess) {
        print(
          '[AUTH] Sign up successful for user: ${result.user?.name} (${result.user?.email})',
        );
        state = state.copyWith(
          user: result.user,
          isLoading: false,
          error: null,
        );
      } else {
        print('[AUTH] Sign up failed with error: ${result.error}');
        state = state.copyWith(isLoading: false, error: result.error);

        // Auto-clear error after 10 seconds to prevent continuous display
        Future.delayed(Duration(seconds: 10), () {
          if (state.error == result.error) {
            state = state.copyWith(error: null);
          }
        });
      }
    } on Exception catch (e) {
      print('[AUTH] Sign up exception: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Sign up failed: ${e.toString()}',
      );
    } catch (e) {
      print('[AUTH] Unexpected sign up error: $e');
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
    print('[AUTH] Starting sign in process for email: $email');
    state = state.copyWith(isLoading: true, error: null);

    try {
      print('[AUTH] Calling auth service sign in...');
      final result = await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.isSuccess) {
        print(
          '[AUTH] Sign in successful for user: ${result.user?.name} (${result.user?.email})',
        );

        // Update state immediately for loading state
        state = state.copyWith(isLoading: false, error: null);

        // The Firebase auth state listener will handle setting the user
        // This ensures proper navigation triggering
      } else {
        print('[AUTH] Sign in failed with error: ${result.error}');
        state = state.copyWith(isLoading: false, error: result.error);

        // Auto-clear error after 10 seconds to prevent continuous display
        Future.delayed(Duration(seconds: 10), () {
          if (state.error == result.error) {
            state = state.copyWith(error: null);
          }
        });
      }
    } catch (e) {
      print('[AUTH] Sign in exception: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'An unexpected error occurred: $e',
      );
    }
  }

  /// Sign in with Google
  Future<void> signInWithGoogle() async {
    print('[AUTH] Starting Google Sign In process...');
    state = state.copyWith(isLoading: true, error: null);

    try {
      print('[AUTH] Calling auth service Google sign in...');
      final result = await _authService.signInWithGoogle();

      if (result.isSuccess) {
        print(
          '[AUTH] Google Sign In successful for user: ${result.user?.name} (${result.user?.email})',
        );
        state = state.copyWith(
          user: result.user,
          isLoading: false,
          error: null,
        );
      } else {
        // Don't show error for user cancellation
        if (result.error?.contains('cancelled') == true) {
          print('[AUTH] Google Sign In was cancelled by user');
          state = state.copyWith(isLoading: false, error: null);
        } else {
          print('[AUTH] Google Sign In failed with error: ${result.error}');
          state = state.copyWith(isLoading: false, error: result.error);

          // Auto-clear error after 10 seconds to prevent continuous display
          Future.delayed(Duration(seconds: 10), () {
            if (state.error == result.error) {
              state = state.copyWith(error: null);
            }
          });
        }
      }
    } catch (e) {
      print('[AUTH] Google Sign In exception: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'An unexpected error occurred: $e',
      );
    }
  }

  /// Sign out
  Future<void> signOut() async {
    // PREVENT: Don't allow multiple simultaneous logout calls
    if (state.isLoading) {
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      print('[AUTH] Calling auth service sign out...');
      await _authService.signOut();

      await Future.delayed(const Duration(milliseconds: 100));

      print('[AUTH] Sign out completed, waiting for auth state listener...');
    } catch (e) {
      print('[AUTH] Sign out failed: $e');
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
        print('[AUTH_CONTROLLER] Profile update successful, updating state');

        // Force new state object to ensure UI updates
        state = AuthState(
          user: userModel, // Use the input userModel which has the latest data
          isLoading: false,
          error: null,
          isInitialized: true,
        );

        print(
          '[AUTH_CONTROLLER] State updated with new profile data: ${userModel.allergies}',
        );

        // Force refresh from Firestore to ensure data consistency
        await _refreshUserFromFirestore();
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
        '[AUTH_CONTROLLER] Bypassing email verification for development...',
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

      print('[AUTH_CONTROLLER] Email verification bypassed successfully');
    } catch (e) {
      print('[AUTH_CONTROLLER] Error bypassing email verification: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to bypass email verification: $e',
      );
    }
  }

  /// Refresh user data from Firestore to ensure consistency
  Future<void> _refreshUserFromFirestore() async {
    try {
      print('[AUTH_CONTROLLER] Refreshing user data from Firestore...');
      final userModel = await _authService.getCurrentUserModel();

      if (userModel != null) {
        // Force a new state object to trigger UI updates
        state = AuthState(
          user: userModel,
          isLoading: false,
          error: null,
          isInitialized: true,
        );
        print(
          '[AUTH_CONTROLLER] Successfully refreshed user data: ${userModel.allergies}',
        );
      }
    } catch (e) {
      print('[AUTH_CONTROLLER] Failed to refresh user data: $e');
    }
  }

  /// Load user data with retry logic for Firestore failures
  Future<void> _loadUserDataWithRetry(
    String uid,
    UserModel fallbackModel,
  ) async {
    int retryCount = 0;
    const maxRetries = 3;
    const retryDelay = Duration(milliseconds: 1500);

    while (retryCount < maxRetries) {
      try {
        print(
          '[AUTH_CONTROLLER] Attempting to load Firestore data (attempt ${retryCount + 1})',
        );
        final userModel = await _authService.getCurrentUserModel();

        if (userModel != null) {
          // Update state with complete Firestore data
          state = state.copyWith(
            user: userModel,
            isLoading: false,
            error: null,
            isInitialized: true,
          );
          print(
            '[AUTH_CONTROLLER] Successfully loaded complete user data from Firestore',
          );
          return;
        }
      } catch (e) {
        print(
          '[AUTH_CONTROLLER] Firestore load attempt ${retryCount + 1} failed: $e',
        );
        retryCount++;

        if (retryCount < maxRetries) {
          await Future.delayed(retryDelay);
        }
      }
    }

    print(
      '[AUTH_CONTROLLER] All Firestore attempts failed, using fallback model',
    );
    // Keep the fallback model if all retries failed
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
