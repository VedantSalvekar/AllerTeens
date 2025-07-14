import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'controllers/auth_controller.dart';
import 'views/auth/login_screen.dart';
import 'views/home/home_view.dart';
import 'views/splash/splash_screen.dart';
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// Wrapper widget that handles authentication state
class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    // Show loading screen while initializing
    if (!authState.isInitialized) {
      return const LoadingScreen();
    }

    // Show appropriate screen based on auth state
    return authState.isAuthenticated ? const HomeView() : const LoginScreen();
  }
}

/// Loading screen shown during Firebase initialization
class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Logo
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(
                  AppConstants.largeBorderRadius,
                ),
              ),
              child: const Icon(
                Icons.medical_services,
                size: 60,
                color: AppColors.white,
              ),
            ),
            const SizedBox(height: 32),

            // App Name
            Text(
              AppConstants.appName,
              style: AppTextStyles.headline1.copyWith(color: AppColors.primary),
            ),
            const SizedBox(height: 8),

            // App Description
            Text(
              AppConstants.appDescription,
              style: AppTextStyles.bodyText1.copyWith(color: AppColors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),

            // Loading Indicator
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
            const SizedBox(height: 24),

            // Loading Text
            Text(
              'Initializing AllerWise...',
              style: AppTextStyles.bodyText1.copyWith(color: AppColors.grey),
            ),
          ],
        ),
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
