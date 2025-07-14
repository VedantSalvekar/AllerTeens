import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../controllers/auth_controller.dart';
import '../auth/login_screen.dart';

/// Home screen with custom navigation and greeting
class HomeView extends ConsumerStatefulWidget {
  const HomeView({super.key});

  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    // Show loading if auth state is not initialized
    if (!authState.isInitialized || authState.isLoading) {
      return Scaffold(
        backgroundColor: AppColors.white,
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final firstName = authState.user?.name.split(' ').first ?? 'User';

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Custom App Bar with notification and profile icons
            Padding(
              padding: const EdgeInsets.all(AppConstants.defaultPadding),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Notification icon
                  Container(
                    width: 35,
                    height: 35,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.transparent,
                    ),
                    child: Image.asset(
                      'assets/icons/notification-02.png',
                      width: 20,
                      height: 20,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Profile icon
                  GestureDetector(
                    onTap: () => _showProfileMenu(context),
                    child: Container(
                      width: 35,
                      height: 35,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.transparent,
                      ),
                      child: Image.asset(
                        'assets/icons/Vector.png',
                        width: 20,
                        height: 20,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Greeting Section
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.only(
                  left: 12,
                  right: AppConstants.defaultPadding,
                  top: 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Greeting text
                    Container(
                      alignment: Alignment.centerLeft,
                      child: RichText(
                        textAlign: TextAlign.left,
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'Hey ',
                              style: TextStyle(
                                fontSize: 24,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                            TextSpan(
                              text: '$firstName,',
                              style: TextStyle(
                                fontSize: 24,
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Subtitle
                    Container(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Ready to take charge today?',
                        textAlign: TextAlign.left,
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ),
                    // Rest of the screen content can go here
                    const Expanded(child: SizedBox()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // Bottom Navigation Bar
      bottomNavigationBar: Container(
        height: 90,
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(
              0,
              'assets/icons/home-03.png',
              'Home',
              isSpecial: false,
            ),
            _buildNavItem(
              1,
              'assets/icons/chat-bot.png',
              'AI',
              isSpecial: true,
            ),
            _buildNavItem(
              2,
              'assets/icons/calendar-03.png',
              'Log',
              isSpecial: false,
            ),
          ],
        ),
      ),
    );
  }

  /// Build navigation item
  Widget _buildNavItem(
    int index,
    String iconPath,
    String label, {
    bool isSpecial = false,
  }) {
    final isSelected = _selectedIndex == index;
    final iconSize = isSpecial ? 36.0 : 24.0;
    final containerSize = isSpecial ? 40.0 : 32.0;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: containerSize,
              height: containerSize,
              child: Image.asset(
                iconPath,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
                width: iconSize,
                height: iconSize,
              ),
            ),
            const SizedBox(height: 4),
            // Label
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Show profile menu
  void _showProfileMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              onTap: () {
                Navigator.pop(context);
                // Navigate to profile screen
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                // Navigate to settings screen
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign Out'),
              onTap: () {
                Navigator.pop(context);
                _handleSignOut();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Handle sign out
  void _handleSignOut() {
    ref.read(authControllerProvider.notifier).signOut();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }
}
