import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../controllers/profile_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../models/user_model.dart';
import '../../core/constants.dart';
import '../auth/onboarding_screen.dart';

/// ProfileScreen for displaying and editing user profile information
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  // Controllers for text fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _medicationsController = TextEditingController();
  final TextEditingController _emergencyNameController =
      TextEditingController();
  final TextEditingController _emergencyRelationController =
      TextEditingController();
  final TextEditingController _emergencyPhoneController =
      TextEditingController();

  // Form keys for validation
  final GlobalKey<FormState> _basicInfoFormKey = GlobalKey<FormState>();

  // State variables

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Refresh profile data from server to ensure we have latest data
      ref.read(profileControllerProvider.notifier).refreshProfile();
      _initializeUserData();
      // Show any error messages from the profile state
      final profileState = ref.read(profileControllerProvider);
      if (profileState.error != null) {
        _showSnackBar(profileState.error!);
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _medicationsController.dispose();
    _emergencyNameController.dispose();
    _emergencyRelationController.dispose();
    _emergencyPhoneController.dispose();
    super.dispose();
  }

  void _initializeUserData() {
    final user = ref.read(profileControllerProvider).user;
    if (user != null) {
      _nameController.text = user.name;

      final medicalInfo = user.medicalInfo ?? <String, dynamic>{};

      // Initialize medications field - show empty if no medications stored
      final storedMedications = (medicalInfo['medications'] as String?) ?? '';
      _medicationsController.text = storedMedications;

      final emergencyContact =
          medicalInfo['emergencyContact'] as Map<String, dynamic>?;
      if (emergencyContact != null) {
        _emergencyNameController.text =
            (emergencyContact['name'] as String?) ?? '';
        _emergencyRelationController.text =
            (emergencyContact['relation'] as String?) ?? '';
        _emergencyPhoneController.text =
            (emergencyContact['phone'] as String?) ?? '';
      } else {
        // Clear emergency contact fields if no data
        _emergencyNameController.text = '';
        _emergencyRelationController.text = '';
        _emergencyPhoneController.text = '';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileControllerProvider);
    final authState = ref.watch(authControllerProvider);
    final user = profileState.user ?? authState.user;

    // Listen for auth state changes to refresh profile data
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (previous?.user != next.user && next.user != null) {
        // User data changed, refresh UI
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _initializeUserData();
        });
      }

      // Also listen for allergen updates specifically
      if (previous?.user?.allergies != next.user?.allergies &&
          next.user != null) {
        print('[PROFILE_SCREEN] Allergen data updated, refreshing UI');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              // Force UI rebuild with new allergen data
            });
          }
        });
      }
    });

    // Listen for state changes and show messages
    ref.listen<ProfileState>(profileControllerProvider, (previous, next) {
      if (next.error != null && previous?.error != next.error) {
        _showSnackBar(next.error!);
      }
      if (next.successMessage != null &&
          previous?.successMessage != next.successMessage) {
        _showSnackBar(next.successMessage!, isError: false);

        // Force UI refresh after successful update
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              // Trigger UI rebuild with updated data
            });
          }
        });
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: profileState.isLoading || user == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: RefreshIndicator(
                onRefresh: () async {
                  await ref
                      .read(profileControllerProvider.notifier)
                      .refreshProfile();
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header Section
                          _buildHeaderSection(user),

                          const SizedBox(height: 32),

                          // Allergies Section
                          _buildAllergySection(user),

                          const SizedBox(height: 24),

                          // Medications Section
                          _buildMedicationsSection(user),

                          const SizedBox(height: 24),

                          // Emergency Contact Section
                          _buildEmergencyContactSection(user),

                          const SizedBox(height: 32),

                          // Logout Button
                          _buildLogoutSection(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildHeaderSection(UserModel user) {
    return Column(
      children: [
        // Profile Picture
        Stack(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: AppColors.primary.withOpacity(0.1),
              backgroundImage: user.photoUrl != null
                  ? NetworkImage(user.photoUrl!)
                  : null,
              child: user.photoUrl == null
                  ? Icon(Icons.person, size: 50, color: AppColors.primary)
                  : null,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: _pickProfileImage,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.edit, color: Colors.white, size: 14),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 32),

        // Basic Info Form
        Form(
          key: _basicInfoFormKey,
          child: Column(
            children: [
              // Full Name Field
              _buildStyledTextField(
                controller: _nameController,
                label: 'Full Name',
                hintText: 'Enter your full name',
                onChanged: (_) => _saveBasicInfo(),
                validator: ValidationPatterns.validateName,
              ),

              const SizedBox(height: 16),

              // Email Field (Read-only)
              _buildStyledTextField(
                initialValue: user.email,
                label: 'Email Address',
                enabled: false,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Helper method to build styled text fields with consistent design
  Widget _buildStyledTextField({
    TextEditingController? controller,
    String? initialValue,
    required String label,
    String? hintText,
    bool enabled = true,
    Widget? suffixIcon,
    Widget? prefixIcon,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          initialValue: initialValue,
          enabled: enabled,
          validator: validator,
          onChanged: onChanged,
          maxLines: maxLines,
          style: TextStyle(
            fontSize: 16,
            color: enabled ? AppColors.textPrimary : AppColors.textSecondary,
            fontWeight: FontWeight.w400,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              color: AppColors.textSecondary.withOpacity(0.6),
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
            suffixIcon: suffixIcon,
            prefixIcon: prefixIcon,
            filled: true,
            fillColor: enabled
                ? AppColors.surface
                : AppColors.lightGrey.withOpacity(0.2),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.lightGrey.withOpacity(0.5),
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.lightGrey.withOpacity(0.5),
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primary, width: 2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.lightGrey.withOpacity(0.3),
                width: 1,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.error, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.error, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 18,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAllergySection(UserModel user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Allergies',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.1,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => _showAllergySelectionDialog(),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.edit, color: Colors.white, size: 14),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        if (user.allergies.isEmpty) ...[
          Text(
            'No allergies selected',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
        ] else ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: user.allergies.map((allergen) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  allergen,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildMedicationsSection(UserModel user) {
    // Get medications from user profile and handle both data structures
    final medicalInfo = user.medicalInfo ?? <String, dynamic>{};

    String currentMedications = '';

    // Handle both old structure (medication map) and new structure (medications string)
    if (medicalInfo.containsKey('medication') &&
        medicalInfo['medication'] is Map) {
      // Old structure from signup: medicalInfo.medication.name
      final medicationMap = medicalInfo['medication'] as Map<String, dynamic>;
      final name = medicationMap['name'] as String? ?? '';
      final dosage = medicationMap['dosage'] as String? ?? '';
      if (name.isNotEmpty) {
        currentMedications = dosage.isNotEmpty ? '$name ($dosage)' : name;
      }
    } else if (medicalInfo.containsKey('medications')) {
      // New structure: medicalInfo.medications (string)
      currentMedications = (medicalInfo['medications'] as String?) ?? '';
    }

    // Update controller if it's different from what's stored
    if (_medicationsController.text != currentMedications) {
      _medicationsController.text = currentMedications;
    }

    return _buildStyledTextField(
      controller: _medicationsController,
      label: 'Medications',
      hintText: 'e.g., Inhaler, EpiPen, Antihistamines...',
      maxLines: 3,
      onChanged: (_) => _saveMedications(),
    );
  }

  Widget _buildEmergencyContactSection(UserModel user) {
    final medicalInfo = user.medicalInfo ?? {};
    final emergencyContact =
        medicalInfo['emergencyContact'] as Map<String, dynamic>?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Emergency Contact',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.1,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => _showEmergencyContactDialog(),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.edit, color: Colors.white, size: 14),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        if (emergencyContact == null || emergencyContact.isEmpty) ...[
          Text(
            'No emergency contact added',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
        ] else ...[
          _buildContactInfo('Name', emergencyContact['name']?.toString() ?? ''),
          const SizedBox(height: 8),
          _buildContactInfo(
            'Relationship',
            (emergencyContact['relation']?.toString() ??
                emergencyContact['relationship']?.toString() ??
                ''),
          ),
          const SizedBox(height: 8),
          _buildContactInfo(
            'Phone',
            emergencyContact['phone']?.toString() ?? '',
          ),
        ],
      ],
    );
  }

  Widget _buildContactInfo(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const Text(': '),
        Expanded(
          child: Text(
            value.isEmpty ? 'Not specified' : value,
            style: TextStyle(
              fontSize: 13,
              color: value.isEmpty
                  ? AppColors.textSecondary
                  : AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogoutSection() {
    return Center(
      child: TextButton(
        onPressed: _showLogoutDialog,
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout, color: AppColors.error),
            const SizedBox(width: 12),
            Text(
              'Log Out',
              style: TextStyle(fontSize: 14, color: AppColors.error),
            ),
          ],
        ),
      ),
    );
  }

  // Emergency contact dialog
  void _showEmergencyContactDialog() {
    final currentUser = ref.read(profileControllerProvider).user;
    final medicalInfo = currentUser?.medicalInfo ?? {};
    final emergencyContact =
        medicalInfo['emergencyContact'] as Map<String, dynamic>?;

    final nameController = TextEditingController(
      text: emergencyContact?['name']?.toString() ?? '',
    );
    final relationController = TextEditingController(
      text:
          (emergencyContact?['relation']?.toString() ??
          emergencyContact?['relationship']?.toString() ??
          ''),
    );
    final existingPhoneRaw = emergencyContact?['phone']?.toString() ?? '';
    String initialPhone;
    if (existingPhoneRaw.trim().isEmpty) {
      initialPhone = '+353 ';
    } else {
      final existingTrimmed = existingPhoneRaw.trim();
      if (existingTrimmed.startsWith('+')) {
        initialPhone = existingTrimmed;
      } else {
        final digitsOnly = existingTrimmed.replaceAll(RegExp(r'[^\d]'), '');
        if (digitsOnly.startsWith('353')) {
          initialPhone = '+$digitsOnly';
        } else if (digitsOnly.startsWith('0')) {
          initialPhone = '+353${digitsOnly.substring(1)}';
        } else {
          initialPhone = '+353$digitsOnly';
        }
      }
    }
    final phoneController = TextEditingController(text: initialPhone);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Emergency Contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: relationController,
              decoration: const InputDecoration(
                labelText: 'Relationship',
                hintText: 'e.g., Parent, Guardian, Spouse',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Normalize phone to ensure +353 prefix
              String normalized = phoneController.text.trim();
              if (!normalized.startsWith('+')) {
                final digitsOnly = normalized.replaceAll(RegExp(r'[^\d]'), '');
                if (digitsOnly.startsWith('353')) {
                  normalized = '+$digitsOnly';
                } else if (digitsOnly.startsWith('0')) {
                  normalized = '+353${digitsOnly.substring(1)}';
                } else {
                  normalized = '+353$digitsOnly';
                }
              }

              ref
                  .read(profileControllerProvider.notifier)
                  .updateEmergencyContact(
                    name: nameController.text.trim(),
                    relation: relationController.text.trim(),
                    phone: normalized,
                  );
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // Allergy selection dialog
  void _showAllergySelectionDialog() {
    final commonAllergies = [
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

    final currentUser = ref.read(profileControllerProvider).user;
    final selectedAllergies = Set<String>.from(currentUser?.allergies ?? []);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Select Allergies'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: commonAllergies.map((allergy) {
                  final isSelected = selectedAllergies.contains(allergy);
                  return CheckboxListTile(
                    title: Text(allergy),
                    value: isSelected,
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          selectedAllergies.add(allergy);
                        } else {
                          selectedAllergies.remove(allergy);
                        }
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: AppColors.primary,
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                ref
                    .read(profileControllerProvider.notifier)
                    .updateAllergies(selectedAllergies.toList());
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  // Action methods
  Future<void> _pickProfileImage() async {
    // Show dialog explaining the feature is coming soon
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.camera_alt, color: AppColors.primary),
            const SizedBox(width: 12),
            const Text('Profile Photo'),
          ],
        ),
        content: const Text(
          'Profile photo upload feature is coming soon! You can update your profile picture in a future update.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveBasicInfo() async {
    if (!_basicInfoFormKey.currentState!.validate()) return;

    await ref
        .read(profileControllerProvider.notifier)
        .updateBasicInfo(name: _nameController.text.trim());
  }

  Future<void> _saveMedications() async {
    await ref
        .read(profileControllerProvider.notifier)
        .updateMedicalInfo(medications: _medicationsController.text.trim());
  }

  void _showLogoutDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.logout, color: AppColors.error),
            const SizedBox(width: 12),
            const Text('Log Out'),
          ],
        ),
        content: const Text(
          'Are you sure you want to log out? You will need to sign in again to access your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              // Sign out
              await ref.read(authControllerProvider.notifier).signOut();

              // Navigate to onboarding
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
