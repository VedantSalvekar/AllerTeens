import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

/// List of the 14 major EU allergens
///
/// This list contains the 14 allergens that must be declared
/// by law in the EU and UK food labeling regulations.
class AllergenConstants {
  static const List<String> majorAllergens = [
    'Peanuts',
    'Tree nuts',
    'Milk',
    'Eggs',
    'Soya',
    'Wheat',
    'Sesame',
    'Celery',
    'Mustard',
    'Fish',
    'Crustaceans',
    'Molluscs',
    'Lupin',
    'Sulphites',
  ];
}

/// State for allergy selection
///
/// Manages the current state of allergen selection including
/// selected allergens, filtered allergens based on search,
/// and loading states for save operations.
class AllergySelectionState {
  /// Set of currently selected allergens
  final Set<String> selectedAllergens;

  /// Current search query for filtering allergens
  final String searchQuery;

  /// Whether a save operation is in progress
  final bool isLoading;

  /// Error message if save operation failed
  final String? error;

  /// List of allergens filtered by search query
  final List<String> filteredAllergens;

  const AllergySelectionState({
    this.selectedAllergens = const {},
    this.searchQuery = '',
    this.isLoading = false,
    this.error,
    this.filteredAllergens = AllergenConstants.majorAllergens,
  });

  /// Create a copy with updated fields
  AllergySelectionState copyWith({
    Set<String>? selectedAllergens,
    String? searchQuery,
    bool? isLoading,
    String? error,
    List<String>? filteredAllergens,
  }) {
    return AllergySelectionState(
      selectedAllergens: selectedAllergens ?? this.selectedAllergens,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      filteredAllergens: filteredAllergens ?? this.filteredAllergens,
    );
  }

  /// Clear error state
  AllergySelectionState clearError() {
    return copyWith(error: null);
  }

  @override
  String toString() {
    return 'AllergySelectionState(selectedAllergens: $selectedAllergens, searchQuery: $searchQuery, isLoading: $isLoading, error: $error)';
  }
}

/// Controller for managing allergy selection
///
/// This controller handles the state management for allergen selection,
/// including filtering allergens based on search queries and saving
/// the selected allergens to the user's profile in Firebase.
class AllergyController extends StateNotifier<AllergySelectionState> {
  final AuthService _authService;

  AllergyController(this._authService) : super(const AllergySelectionState()) {
    _loadUserAllergens();
  }

  /// Load existing user allergens from the current user profile
  Future<void> _loadUserAllergens() async {
    try {
      final user = await _authService.getCurrentUserModel();
      if (user != null && user.allergies.isNotEmpty) {
        state = state.copyWith(
          selectedAllergens: Set<String>.from(user.allergies),
        );
      }
    } catch (e) {
      print('⚠️ [ALLERGY] Failed to load user allergens: $e');
      // Don't show error for this - just continue with empty selection
    }
  }

  /// Toggle selection of an allergen
  ///
  /// Adds the allergen to selected set if not already selected,
  /// removes it if already selected.
  void toggleAllergen(String allergen) {
    print('🔵 [ALLERGY] Toggling allergen: $allergen');

    final newSelectedAllergens = Set<String>.from(state.selectedAllergens);

    if (newSelectedAllergens.contains(allergen)) {
      newSelectedAllergens.remove(allergen);
      print('➖ [ALLERGY] Removed allergen: $allergen');
    } else {
      newSelectedAllergens.add(allergen);
      print('➕ [ALLERGY] Added allergen: $allergen');
    }

    state = state.copyWith(
      selectedAllergens: newSelectedAllergens,
      error: null,
    );

    print('🔍 [ALLERGY] Current selection: $newSelectedAllergens');
  }

  /// Update search query and filter allergens
  ///
  /// Filters the list of allergens based on the search query.
  /// Search is case-insensitive and matches partial strings.
  void updateSearchQuery(String query) {
    print('🔍 [ALLERGY] Updating search query: "$query"');

    final filteredAllergens = AllergenConstants.majorAllergens
        .where(
          (allergen) => allergen.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();

    state = state.copyWith(
      searchQuery: query,
      filteredAllergens: filteredAllergens,
    );

    print('📋 [ALLERGY] Filtered allergens: $filteredAllergens');
  }

  /// Clear search query and reset filter
  void clearSearch() {
    print('🧹 [ALLERGY] Clearing search query');
    state = state.copyWith(
      searchQuery: '',
      filteredAllergens: AllergenConstants.majorAllergens,
    );
  }

  /// Save selected allergens to user profile
  ///
  /// Updates the user's profile in Firebase with the selected allergens.
  /// Returns true if successful, false otherwise.
  Future<bool> saveSelectedAllergens() async {
    print(
      '💾 [ALLERGY] Starting to save selected allergens: ${state.selectedAllergens}',
    );

    // Don't save if already saving
    if (state.isLoading) {
      print('⚠️ [ALLERGY] Already saving allergens, skipping...');
      return false;
    }

    if (state.selectedAllergens.isEmpty) {
      print('⚠️ [ALLERGY] No allergens selected, proceeding without saving');
      return true; // Allow users to proceed without selecting allergens
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      // Get current user with retry logic
      UserModel? currentUser = await _authService.getCurrentUserModel();

      // Retry if user not found (race condition)
      if (currentUser == null) {
        print('⚠️ [ALLERGY] User not found, retrying...');
        await Future.delayed(const Duration(milliseconds: 500));
        currentUser = await _authService.getCurrentUserModel();
      }

      if (currentUser == null) {
        throw Exception('No authenticated user found after retry');
      }

      // Update user with selected allergens
      final updatedUser = currentUser.copyWith(
        allergies: state.selectedAllergens.toList(),
        updatedAt: DateTime.now(),
      );

      // Save to Firebase
      final result = await _authService.updateUserProfile(updatedUser);

      if (!result.isSuccess) {
        throw Exception(result.error ?? 'Failed to update user profile');
      }

      state = state.copyWith(isLoading: false, error: null);

      print(
        '✅ [ALLERGY] Successfully saved allergens: ${state.selectedAllergens}',
      );
      return true;
    } catch (e) {
      print('❌ [ALLERGY] Failed to save allergens: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to save allergens: $e',
      );
      return false;
    }
  }

  /// Clear all selected allergens
  void clearSelection() {
    print('🧹 [ALLERGY] Clearing all selected allergens');
    state = state.copyWith(selectedAllergens: const {}, error: null);
  }

  /// Reset the entire state
  void resetState() {
    print('🔄 [ALLERGY] Resetting allergy selection state');
    state = const AllergySelectionState();
  }

  /// Get user's first name from current user
  String? getUserFirstName() {
    try {
      // This will get the cached user from auth service
      final user = _authService.currentUser;
      if (user?.displayName != null) {
        return user!.displayName!.split(' ').first;
      }
      return null;
    } catch (e) {
      print('⚠️ [ALLERGY] Failed to get user first name: $e');
      return null;
    }
  }
}

/// Provider for the allergy controller
///
/// This provider creates and manages the AllergyController instance
/// and automatically disposes it when no longer needed.
final allergyControllerProvider =
    StateNotifierProvider<AllergyController, AllergySelectionState>((ref) {
      final authService = ref.watch(authServiceProvider);
      return AllergyController(authService);
    });

/// Provider for the auth service
///
/// This provider provides the AuthService instance needed by the
/// AllergyController for user profile operations.
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});
