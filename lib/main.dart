import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'controllers/auth_controller.dart';
import 'models/user_model.dart';
import 'views/auth/login_screen.dart';
import 'views/auth/onboarding_screen.dart';
import 'views/auth/email_verification_screen.dart';
import 'views/auth/allergy_selection_screen.dart';
import 'views/home/home_view.dart';
import 'views/splash/splash_screen.dart';
import 'views/integrated_conversation/integrated_conversation_screen.dart';
import 'core/theme/app_theme.dart';
import 'core/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
  } catch (e) {
    print('Firebase initialization failed: $e');
  }

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    // ✅ LISTEN: React to auth state changes and navigate accordingly
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      print(
        '🔄 [MY_APP] Auth state changed: ${previous?.isAuthenticated ?? 'null'} -> ${next.isAuthenticated}',
      );
      print(
        '🔄 [MY_APP] Auth state details: prev=${previous?.user?.email ?? 'null'}, next=${next.user?.email ?? 'null'}, initialized=${next.isInitialized}',
      );

      // ✅ CHECK: Force navigation on any meaningful auth change
      final shouldNavigate =
          next.isInitialized &&
          (previous?.isAuthenticated != next.isAuthenticated ||
              previous?.user?.email != next.user?.email ||
              (previous?.user?.isEmailVerified != next.user?.isEmailVerified) ||
              (previous?.user?.allergies.length !=
                  next.user?.allergies.length));

      if (shouldNavigate) {
        final navigator = navigatorKey.currentState;
        if (navigator != null) {
          print('🔄 [MY_APP] Triggering navigation due to auth state change');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // Clear the entire stack and navigate to appropriate screen
            if (next.isAuthenticated && next.user != null) {
              final user = next.user!;
              print('🔄 [MY_APP] User authenticated: ${user.email}');

              // Determine which screen to navigate to
              Widget targetScreen;
              if (!user.isEmailVerified) {
                print(
                  '🔄 [MY_APP] Email not verified, navigating to EmailVerificationScreen',
                );
                targetScreen = const EmailVerificationScreen();
              } else if (user.allergies.isEmpty) {
                print(
                  '🔄 [MY_APP] No allergies set, navigating to AllergySelectionScreen',
                );
                targetScreen = const AllergySelectionScreen();
              } else {
                print('🔄 [MY_APP] User fully set up, navigating to HomeView');
                targetScreen = const HomeView();
              }

              navigator.pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => targetScreen),
                (route) => false,
              );
            } else {
              print(
                '🔄 [MY_APP] User not authenticated, navigating to OnboardingScreen',
              );
              navigator.pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                (route) => false,
              );
            }
          });
        }
      } else {
        print('🔄 [MY_APP] No navigation needed - conditions not met');
      }
    });

    return MaterialApp(
      title: AppConstants.appName,
      theme: AppTheme.lightTheme,
      navigatorKey: navigatorKey,
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// Wrapper widget that shows the initial screen based on auth state
class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    // ✅ DEBUG: Log auth state changes for debugging
    print(
      '🔄 [AUTH_WRAPPER] Building with state: isAuth=${authState.isAuthenticated}, isInit=${authState.isInitialized}, isLoading=${authState.isLoading}, user=${authState.user?.email ?? 'null'}',
    );

    // Show loading screen while initializing
    if (!authState.isInitialized) {
      print('🔄 [AUTH_WRAPPER] Showing loading screen - not initialized');
      return const LoadingScreen();
    }

    // Handle initial screen based on auth state
    if (!authState.isAuthenticated) {
      print('🔄 [AUTH_WRAPPER] Showing onboarding - not authenticated');
      return const OnboardingScreen();
    }

    final user = authState.user!;
    print(
      '🔄 [AUTH_WRAPPER] User authenticated: ${user.email}, emailVerified=${user.isEmailVerified}, allergies=${user.allergies.length}',
    );

    // User is authenticated, determine which screen to show
    if (!user.isEmailVerified) {
      print('🔄 [AUTH_WRAPPER] Showing email verification screen');
      return const EmailVerificationScreen();
    }

    if (user.allergies.isEmpty) {
      print('🔄 [AUTH_WRAPPER] Showing allergy selection screen');
      return const AllergySelectionScreen();
    }

    print('🔄 [AUTH_WRAPPER] Showing home view');
    return const HomeView();
  }
}

/// Loading screen shown during Firebase initialization
class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }
}

/// Error screen shown when Firebase initialization fails
class ErrorScreen extends StatelessWidget {
  final String error;

  const ErrorScreen({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.largePadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Error Icon
              const Icon(Icons.error_outline, size: 80, color: AppColors.error),
              const SizedBox(height: 24),

              // Error Title
              Text(
                'Initialization Failed',
                style: AppTextStyles.headline2.copyWith(color: AppColors.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Error Message
              Text(
                error,
                style: AppTextStyles.bodyText1.copyWith(
                  color: AppColors.darkGrey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Retry Button
              ElevatedButton(
                onPressed: () {
                  // Restart the app
                  main();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppConstants.defaultBorderRadius,
                    ),
                  ),
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
