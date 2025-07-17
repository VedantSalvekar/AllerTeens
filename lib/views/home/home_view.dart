import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../controllers/auth_controller.dart';
import '../../models/scenario_models.dart';
import '../../models/training_assessment.dart';
import '../../data/scenario_data.dart';
import '../../services/progress_tracking_service.dart';
import '../auth/login_screen.dart';
import '../integrated_conversation/integrated_conversation_screen.dart';

/// Home screen with custom navigation and greeting
class HomeView extends ConsumerStatefulWidget {
  const HomeView({super.key});

  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView> {
  int _selectedIndex = 0;
  final GlobalKey<_ScenarioSelectionContentState> _scenarioContentKey =
      GlobalKey();

  // Method to refresh progress data (can be called externally)
  void refreshProgressData() {
    _scenarioContentKey.currentState?.refreshProgressData();
  }

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
      body: _buildCurrentPage(firstName),
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

  Widget _buildCurrentPage(String firstName) {
    switch (_selectedIndex) {
      case 0:
        return _buildHomePage(firstName);
      case 1:
        return _buildAIPage();
      case 2:
        return _buildLogPage();
      default:
        return _buildHomePage(firstName);
    }
  }

  Widget _buildHomePage(String firstName) {
    return SafeArea(
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
    );
  }

  Widget _buildAIPage() {
    return Container(
      color: AppColors.primary, // Set background to teal
      child: ScenarioSelectionContent(key: _scenarioContentKey),
    );
  }

  Widget _buildLogPage() {
    return SafeArea(
      child: Container(
        color: AppColors.background,
        child: const Center(
          child: Text(
            'Training Logs',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
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

        // Refresh progress data when switching to AI tab
        if (index == 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scenarioContentKey.currentState?.refreshProgressData();
          });
        }
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
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.grey,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            // Profile option
            ListTile(
              leading: const Icon(Icons.person, color: AppColors.primary),
              title: const Text('Profile'),
              onTap: () {
                Navigator.pop(context);
                // Navigate to profile screen
              },
            ),
            // Settings option
            ListTile(
              leading: const Icon(Icons.settings, color: AppColors.primary),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                // Navigate to settings screen
              },
            ),
            // Logout option
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.error),
              title: const Text('Logout'),
              onTap: () {
                Navigator.pop(context);
                // Sign out and let auth state listener handle navigation
                ref.read(authControllerProvider.notifier).signOut();
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Create a content-only version of the scenario selection screen
class ScenarioSelectionContent extends ConsumerStatefulWidget {
  const ScenarioSelectionContent({super.key});

  @override
  ConsumerState<ScenarioSelectionContent> createState() =>
      _ScenarioSelectionContentState();
}

class _ScenarioSelectionContentState
    extends ConsumerState<ScenarioSelectionContent>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  final ProgressTrackingService _progressService = ProgressTrackingService();

  // Add a key to force refresh of progress data
  int _refreshKey = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Refresh progress data when app returns to foreground
      _refreshProgressData();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Method to refresh progress data
  void refreshProgressData() {
    setState(() {
      _refreshKey++;
    });
  }

  // Private method for internal use
  void _refreshProgressData() {
    refreshProgressData();
  }

  @override
  Widget build(BuildContext context) {
    final userScore = 0; // Only restaurant should be unlocked

    return SafeArea(
      child: Column(
        children: [
          // Header without greeting
          _buildHeader(context),

          // Difficulty filter tabs
          _buildDifficultyTabs(),

          // Scenarios grid with refresh indicator
          Expanded(
            child: Container(
              color: AppColors.background,
              child: RefreshIndicator(
                onRefresh: () async {
                  _refreshProgressData();
                  // Wait a moment for the refresh to complete
                  await Future.delayed(const Duration(milliseconds: 500));
                },
                child: _buildScenariosGrid(userScore),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title only
          Text(
            'AI Training Scenarios',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Choose a scenario to practice safe allergy communication',
            style: TextStyle(
              color: AppColors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDifficultyTabs() {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        labelPadding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 4,
        ), // Reduced padding
        tabs: const [
          Tab(child: Text('All', style: TextStyle(fontSize: 12))),
          Tab(child: Text('Beginner', style: TextStyle(fontSize: 12))),
          Tab(child: Text('Intermediate', style: TextStyle(fontSize: 12))),
          Tab(child: Text('Advanced', style: TextStyle(fontSize: 12))),
        ],
        indicator: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        labelColor: AppColors.white,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
      ),
    );
  }

  Widget _buildScenariosGrid(int userScore) {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildScenarioList(ScenarioDataProvider.getAllScenarios(), userScore),
        _buildScenarioList(
          ScenarioDataProvider.getScenariosByDifficulty(
            DifficultyLevel.beginner,
          ),
          userScore,
        ),
        _buildScenarioList(
          ScenarioDataProvider.getScenariosByDifficulty(
            DifficultyLevel.intermediate,
          ),
          userScore,
        ),
        _buildScenarioList(
          ScenarioDataProvider.getScenariosByDifficulty(
            DifficultyLevel.advanced,
          ),
          userScore,
        ),
      ],
    );
  }

  Widget _buildScenarioList(List<TrainingScenario> scenarios, int userScore) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: ListView.builder(
        itemCount: scenarios.length,
        itemBuilder: (context, index) {
          final scenario = scenarios[index];
          final isUnlocked =
              scenario.id == 'restaurant_beginner' ||
              userScore >= scenario.requiredScore;
          return Padding(
            padding: const EdgeInsets.only(bottom: 16), // Spacing between cards
            child: _buildScenarioCard(scenario, isUnlocked),
          );
        },
      ),
    );
  }

  Widget _buildScenarioCard(TrainingScenario scenario, bool isUnlocked) {
    return FutureBuilder<Map<String, dynamic>>(
      key: ValueKey(
        '${scenario.id}_$_refreshKey',
      ), // Use refresh key to force rebuild
      future: _getScenarioProgress(scenario.id),
      builder: (context, snapshot) {
        final progressData = snapshot.data ?? _getMockProgress(scenario.id);
        return _buildScenarioCardWithProgress(
          scenario,
          isUnlocked,
          progressData,
        );
      },
    );
  }

  Widget _buildScenarioCardWithProgress(
    TrainingScenario scenario,
    bool isUnlocked,
    Map<String, dynamic> progressData,
  ) {
    return GestureDetector(
      onTap: isUnlocked ? () => _navigateToScenario(scenario) : null,
      child: Container(
        height: 210, // Reduced height to prevent overflow
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top image section
            Container(
              height: 120, // Reduced image height
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                image: DecorationImage(
                  image: AssetImage(
                    'assets/images/backgrounds/restaurant_dining_card_image.jpeg',
                  ),
                  fit: BoxFit.fill,
                ),
              ),
              child: Stack(
                children: [
                  // Overlay for better text visibility
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.1),
                          Colors.black.withOpacity(0.3),
                        ],
                      ),
                    ),
                  ),

                  // Progress ring for unlocked scenarios
                  if (isUnlocked && progressData['attempts'] > 0)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: _buildProgressRing(
                        progress: progressData['bestScore'] / 100.0,
                        size: 36,
                        strokeWidth: 3,
                        color: AppColors.white,
                      ),
                    ),

                  // Difficulty badge
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _getDifficultyText(scenario.difficulty),
                        style: TextStyle(
                          color: scenario.accentColor,
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  // Lock icon for locked scenarios
                  if (!isUnlocked)
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                        color: Colors.black.withOpacity(0.6),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.lock,
                          color: AppColors.white,
                          size: 28,
                        ),
                      ),
                    ),

                  // Score badges at bottom of image
                  if (isUnlocked && progressData['attempts'] > 0)
                    Positioned(
                      bottom: 6,
                      left: 8,
                      right: 8,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Achievement level badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  progressData['bestScore'] >= 90
                                      ? Icons.star
                                      : progressData['bestScore'] >= 70
                                      ? Icons.thumb_up
                                      : Icons.trending_up,
                                  size: 10,
                                  color: scenario.accentColor,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  progressData['bestScore'] >= 90
                                      ? 'Mastered'
                                      : progressData['bestScore'] >= 70
                                      ? 'Skilled'
                                      : 'Learning',
                                  style: TextStyle(
                                    color: scenario.accentColor,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Attempt counter
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Try #${progressData['attempts']}',
                              style: TextStyle(
                                color: scenario.accentColor,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Bottom content section
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12), // Reduced padding
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title with completion indicator
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            scenario.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isUnlocked
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isUnlocked && progressData['isCompleted'])
                          Icon(
                            Icons.check_circle,
                            size: 14,
                            color: AppColors.primary,
                          ),
                      ],
                    ),

                    const SizedBox(height: 2),

                    // Description
                    Text(
                      scenario.description,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 8),

                    // Status area at bottom
                    if (!isUnlocked) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.play_circle_filled,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Unlock with ${scenario.requiredScore} points',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Icon(
                            _getStatusIcon(
                              progressData['bestScore'],
                              progressData['improvement'],
                            ),
                            size: 14,
                            color: _getStatusColor(
                              progressData['bestScore'],
                              progressData['improvement'],
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _getStatusMessage(
                                progressData['bestScore'],
                                progressData['improvement'],
                              ),
                              style: TextStyle(
                                fontSize: 10,
                                color: _getStatusColor(
                                  progressData['bestScore'],
                                  progressData['improvement'],
                                ),
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to build progress ring
  Widget _buildProgressRing({
    required double progress,
    required double size,
    required double strokeWidth,
    required Color color,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          // Background circle
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: strokeWidth,
              color: color.withOpacity(0.3),
              backgroundColor: Colors.transparent,
            ),
          ),
          // Progress circle
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: strokeWidth,
              color: color,
              backgroundColor: Colors.transparent,
            ),
          ),
          // Score text in center
          Center(
            child: Text(
              '${(progress * 100).round()}',
              style: TextStyle(
                color: color,
                fontSize: size * 0.25,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build skill badge
  Widget _buildSkillBadge(String skill) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        skill,
        style: TextStyle(
          fontSize: 8,
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // Get real progress data from Firestore
  Future<Map<String, dynamic>> _getScenarioProgress(String scenarioId) async {
    try {
      final authState = ref.read(authControllerProvider);
      if (authState.user == null) {
        return _getMockProgress(scenarioId);
      }

      final progress = await _progressService.getScenarioProgress(
        authState.user!.id,
        scenarioId,
      );

      if (progress == null) {
        return _getMockProgress(scenarioId);
      }

      return {
        'attempts': progress.totalAttempts,
        'bestScore': progress.bestScore,
        'isCompleted': progress.isCompleted,
        'improvement': progress.improvementRate.round(),
        'masteredSkills': progress.masteredSkills,
      };
    } catch (e) {
      debugPrint('Error getting scenario progress: $e');
      return _getMockProgress(scenarioId);
    }
  }

  // Mock progress data for immediate display (fallback)
  Map<String, dynamic> _getMockProgress(String scenarioId) {
    // Return empty progress data for all scenarios to show real data only
    return {
      'attempts': 0,
      'bestScore': 0,
      'isCompleted': false,
      'improvement': 0,
      'masteredSkills': <String>[],
    };
  }

  String _getDifficultyText(DifficultyLevel difficulty) {
    switch (difficulty) {
      case DifficultyLevel.beginner:
        return 'BEGINNER';
      case DifficultyLevel.intermediate:
        return 'INTERMEDIATE';
      case DifficultyLevel.advanced:
        return 'ADVANCED';
      case DifficultyLevel.expert:
        return 'EXPERT';
    }
  }

  // Helper methods for status display
  IconData _getStatusIcon(int bestScore, int improvement) {
    if (bestScore >= 90) {
      return Icons.star; // Excellent performance
    } else if (bestScore >= 70) {
      return Icons.trending_up; // Good performance
    } else if (improvement > 0) {
      return Icons.trending_up; // Improving
    } else {
      return Icons.refresh; // Needs practice
    }
  }

  Color _getStatusColor(int bestScore, int improvement) {
    if (bestScore >= 90) {
      return const Color(0xFFFFD700); // Gold for excellent
    } else if (bestScore >= 70) {
      return AppColors.primary; // Primary for good
    } else if (improvement > 0) {
      return AppColors.primary; // Primary for improving
    } else {
      return AppColors.textSecondary; // Secondary for needs practice
    }
  }

  String _getStatusMessage(int bestScore, int improvement) {
    if (bestScore == 0) {
      return 'Start your first attempt!';
    } else if (bestScore >= 90) {
      return 'Perfect performance!';
    } else if (improvement > 0) {
      return '+${improvement}% improvement';
    } else if (bestScore >= 70) {
      return 'Great work! Keep it up!';
    } else {
      return 'Keep practicing to improve!';
    }
  }

  void _navigateToScenario(TrainingScenario scenario) {
    // Show scenario details dialog first
    showDialog(
      context: context,
      builder: (context) => _buildScenarioDetailsDialog(scenario),
    );
  }

  Widget _buildScenarioDetailsDialog(TrainingScenario scenario) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: EdgeInsets.zero,
      content: Container(
        width: 300,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: scenario.accentColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    scenario.title,
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    scenario.description,
                    style: TextStyle(
                      color: AppColors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Learning objectives
                  Text(
                    'Learning Objectives:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...scenario.learningObjectives.map(
                    (objective) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 14,
                            color: scenario.accentColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              objective,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Cancel',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    IntegratedConversationScreen(),
                              ),
                            ).then((_) {
                              // Refresh progress data when returning from training
                              refreshProgressData();
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: scenario.accentColor,
                            foregroundColor: AppColors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Start Training'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
