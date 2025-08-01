import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import 'auth_controller.dart';

/// Profile state for managing user profile data
class ProfileState {
  final UserModel? user;
  final bool isLoading;
  final bool isSaving;
  final String? error;
  final String? successMessage;

  const ProfileState({
    this.user,
    this.isLoading = false,
    this.isSaving = false,
    this.error,
    this.successMessage,
  });

  ProfileState copyWith({
    UserModel? user,
    bool? isLoading,
    bool? isSaving,
    String? error,
    String? successMessage,
  }) {
    return ProfileState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: error,
      successMessage: successMessage,
    );
  }

  ProfileState clearMessages() {
    return copyWith(error: null, successMessage: null);
  }
}

/// Profile controller for managing profile updates
class ProfileController extends StateNotifier<ProfileState> {
  final AuthService _authService;
  final Ref _ref;

  ProfileController(this._authService, this._ref)
    : super(const ProfileState()) {
    _initialize();
  }

  /// Initialize profile state with current user data
  void _initialize() {
    final authState = _ref.read(authControllerProvider);
    if (authState.user != null) {
      state = state.copyWith(user: authState.user);
    }
  }

  /// Update user profile with new data
  Future<bool> updateProfile(UserModel updatedUser) async {
    print(
      '🔵 [PROFILE] Starting profile update for user: ${updatedUser.email}',
    );
    state = state.copyWith(isSaving: true, error: null);

    try {
      // Use AuthController's updateUserProfile method to ensure state consistency
      await _ref
          .read(authControllerProvider.notifier)
          .updateUserProfile(updatedUser);

      // Small delay to ensure Firestore update is complete
      await Future.delayed(const Duration(milliseconds: 300));

      // Check if the update was successful by checking auth state
      final authState = _ref.read(authControllerProvider);
      if (authState.error == null && authState.user != null) {
        state = state.copyWith(
          user: authState.user,
          isSaving: false,
          successMessage: 'Profile updated successfully!',
        );

        // Force refresh from server to ensure data consistency
        await refreshProfile();

        return true;
      } else {
        print('[PROFILE] Profile update failed: ${authState.error}');
        state = state.copyWith(
          isSaving: false,
          error: authState.error ?? 'Failed to update profile',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        error: 'An unexpected error occurred: $e',
      );
      return false;
    }
  }

  /// Update user's basic info (name, email)
  Future<bool> updateBasicInfo({String? name, String? photoUrl}) async {
    final currentUser = state.user;
    if (currentUser == null) return false;

    final updatedUser = currentUser.copyWith(
      name: name,
      photoUrl: photoUrl,
      updatedAt: DateTime.now(),
    );

    return await updateProfile(updatedUser);
  }

  /// Update medical information
  Future<bool> updateMedicalInfo({
    String? bloodType,
    String? conditions,
    String? medications,
    bool? hasAdrenalinePen,
  }) async {
    final currentUser = state.user;
    if (currentUser == null) return false;

    final currentMedicalInfo = currentUser.medicalInfo ?? {};
    final updatedMedicalInfo = Map<String, dynamic>.from(currentMedicalInfo);

    if (bloodType != null) updatedMedicalInfo['bloodType'] = bloodType;
    if (conditions != null) updatedMedicalInfo['conditions'] = conditions;
    if (medications != null) updatedMedicalInfo['medications'] = medications;
    if (hasAdrenalinePen != null)
      updatedMedicalInfo['hasAdrenalinePen'] = hasAdrenalinePen;

    final updatedUser = currentUser.copyWith(
      medicalInfo: updatedMedicalInfo,
      updatedAt: DateTime.now(),
    );

    return await updateProfile(updatedUser);
  }

  /// Update emergency contact information
  Future<bool> updateEmergencyContact({
    String? name,
    String? relation,
    String? phone,
  }) async {
    final currentUser = state.user;
    if (currentUser == null) return false;

    final currentMedicalInfo = currentUser.medicalInfo ?? {};
    final updatedMedicalInfo = Map<String, dynamic>.from(currentMedicalInfo);

    final emergencyContact = <String, dynamic>{};
    if (name != null) emergencyContact['name'] = name;
    if (relation != null) emergencyContact['relation'] = relation;
    if (phone != null) emergencyContact['phone'] = phone;

    updatedMedicalInfo['emergencyContact'] = emergencyContact;

    final updatedUser = currentUser.copyWith(
      medicalInfo: updatedMedicalInfo,
      updatedAt: DateTime.now(),
    );

    return await updateProfile(updatedUser);
  }

  /// Update user allergies
  Future<bool> updateAllergies(List<String> allergies) async {
    final currentUser = state.user;
    if (currentUser == null) {
      return false;
    }

    final updatedUser = currentUser.copyWith(
      allergies: allergies,
      updatedAt: DateTime.now(),
    );

    final success = await updateProfile(updatedUser);

    if (success) {
    } else {}

    return success;
  }

  /// Clear any error or success messages
  void clearMessages() {
    state = state.clearMessages();
  }

  /// Refresh profile data from server
  Future<void> refreshProfile() async {
    state = state.copyWith(isLoading: true);

    try {
      final userModel = await _authService.getCurrentUserModel();
      if (userModel != null) {
        state = state.copyWith(user: userModel, isLoading: false);
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to refresh profile data',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to refresh profile: $e',
      );
    }
  }
}

/// Provider for the profile controller
final profileControllerProvider =
    StateNotifierProvider<ProfileController, ProfileState>((ref) {
      final authService = AuthService();
      return ProfileController(authService, ref);
    });
