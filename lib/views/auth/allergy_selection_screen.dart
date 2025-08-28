import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../controllers/allergy_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../shared/widgets/allergen_tag.dart';
import '../../core/constants.dart';
import 'medical_info_screen.dart';

class AllergySelectionScreen extends ConsumerStatefulWidget {
  const AllergySelectionScreen({super.key});

  @override
  ConsumerState<AllergySelectionScreen> createState() =>
      _AllergySelectionScreenState();
}

class _AllergySelectionScreenState
    extends ConsumerState<AllergySelectionScreen> {
  /// Controller for the search text field
  final TextEditingController _searchController = TextEditingController();

  /// Focus node for the search text field
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    // Add listener to search controller to update filter
    _searchController.addListener(() {
      ref
          .read(allergyControllerProvider.notifier)
          .updateSearchQuery(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allergyState = ref.watch(allergyControllerProvider);
    final authState = ref.watch(authControllerProvider);

    // Get user's first name for welcome message
    final userFirstName = authState.user?.name?.split(' ').first ?? 'User';

    return Scaffold(
      backgroundColor: AppColors.surface, // White background
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation Bar
            _buildTopNavigationBar(context),

            // Main Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 40),

                    // Welcome Message
                    _buildWelcomeMessage(userFirstName),

                    const SizedBox(height: 32),

                    // Allergen Selection Label
                    _buildAllergenSelectionLabel(),

                    const SizedBox(height: 20),

                    // Search Bar
                    _buildSearchBar(allergyState),

                    const SizedBox(height: 24),

                    // Allergen Selection Area
                    Expanded(child: _buildAllergenSelectionArea(allergyState)),

                    // Bottom Continue Button
                    _buildBottomActions(allergyState),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build the top navigation bar with only Skip button
  Widget _buildTopNavigationBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Skip Button
          TextButton(
            onPressed: () => _handleSkipPressed(context),
            child: Text(
              'Skip',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build the welcome message section
  Widget _buildWelcomeMessage(String firstName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Welcome heading with bold name
        RichText(
          text: TextSpan(
            text: 'Welcome ',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.normal,
              color: AppColors.textSecondary,
            ),
            children: [
              TextSpan(
                text: '$firstName!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Subheading
        Text(
          "Let's get to know your allergies",
          style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  /// Build the allergen selection label
  Widget _buildAllergenSelectionLabel() {
    return Text(
      'Pick what allergens you have',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }

  /// Build the search bar
  Widget _buildSearchBar(AllergySelectionState allergyState) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.grey.withOpacity(0.3), width: 1),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        decoration: InputDecoration(
          hintText: 'Search for allergens',
          hintStyle: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          prefixIcon: Icon(
            HugeIcons.strokeRoundedSearch01,
            size: 20,
            color: AppColors.textSecondary,
          ),
          suffixIcon: allergyState.searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    HugeIcons.strokeRoundedCancel01,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    ref.read(allergyControllerProvider.notifier).clearSearch();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
      ),
    );
  }

  /// Build the allergen selection area with tags
  Widget _buildAllergenSelectionArea(AllergySelectionState allergyState) {
    if (allergyState.filteredAllergens.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              HugeIcons.strokeRoundedSearch01,
              size: 48,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              'No allergens found',
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search term',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: allergyState.filteredAllergens.map((allergen) {
          final isSelected = allergyState.selectedAllergens.contains(allergen);
          return AllergenTag(
            allergenName: allergen,
            isSelected: isSelected,
            onTap: () => ref
                .read(allergyControllerProvider.notifier)
                .toggleAllergen(allergen),
          );
        }).toList(),
      ),
    );
  }

  /// Build the bottom actions (Continue button)
  Widget _buildBottomActions(AllergySelectionState allergyState) {
    return Row(
      children: [
        // Spacer to push button to the right
        const Spacer(),

        // Continue Button
        SizedBox(
          width: 120,
          height: 48,
          child: ElevatedButton(
            onPressed: allergyState.isLoading
                ? null
                : () => _handleContinuePressed(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: allergyState.isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.white,
                      ),
                    ),
                  )
                : Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.white,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  void _handleSkipPressed(BuildContext context) {
    _navigateToHome(context);
  }

  Future<void> _handleContinuePressed(BuildContext context) async {
    final allergyController = ref.read(allergyControllerProvider.notifier);
    final allergyState = ref.read(allergyControllerProvider);

    if (allergyState.isLoading) {
      return;
    }

    try {
      final success = await allergyController.saveSelectedAllergens();

      if (success) {
        _navigateToHome(context);
      } else {
        print('❌ [ALLERGY_SCREEN] Failed to save allergens');
        final errorMessage =
            allergyState.error ?? 'Failed to save allergens. Please try again.';
        _showErrorSnackBar(context, errorMessage);
      }
    } catch (e) {
      print('💥 [ALLERGY_SCREEN] Exception during save: $e');
      _showErrorSnackBar(
        context,
        'An unexpected error occurred. Please try again.',
      );
    }
  }

  /// Navigate to medical info screen
  void _navigateToHome(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const MedicalInfoScreen()),
      (route) => false,
    );
  }

  /// Show error snackbar
  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
