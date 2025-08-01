import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../controllers/auth_controller.dart';
import '../../core/constants.dart';
import '../home/home_view.dart';

/// Medical Information Screen for AllerWise
///
/// This screen appears after allergy selection to collect:
/// - Medication information (name, dosage, frequency)
/// - Emergency contact information (name, phone, relationship)
class MedicalInfoScreen extends ConsumerStatefulWidget {
  const MedicalInfoScreen({super.key});

  @override
  ConsumerState<MedicalInfoScreen> createState() => _MedicalInfoScreenState();
}

class _MedicalInfoScreenState extends ConsumerState<MedicalInfoScreen> {
  /// Form key for validation
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  /// Controllers for form fields
  final TextEditingController _emergencyContactNameController =
      TextEditingController();
  final TextEditingController _emergencyContactPhoneController =
      TextEditingController();
  final TextEditingController _emergencyContactRelationshipController =
      TextEditingController();

  /// Selected values for dropdowns
  String? _selectedMedication;
  String? _selectedDosage;

  /// Focus nodes for form fields
  final FocusNode _emergencyContactNameFocus = FocusNode();
  final FocusNode _emergencyContactPhoneFocus = FocusNode();
  final FocusNode _emergencyContactRelationshipFocus = FocusNode();

  @override
  void dispose() {
    _emergencyContactNameController.dispose();
    _emergencyContactPhoneController.dispose();
    _emergencyContactRelationshipController.dispose();

    _emergencyContactNameFocus.dispose();
    _emergencyContactPhoneFocus.dispose();
    _emergencyContactRelationshipFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final userFirstName = authState.user?.name?.split(' ').first ?? 'User';

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation Bar
            _buildTopNavigationBar(context),

            // Main Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 40),

                      // Welcome Message
                      _buildWelcomeMessage(userFirstName),

                      const SizedBox(height: 32),

                      // Scrollable content
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Medication Section
                              _buildMedicationSection(),

                              const SizedBox(height: 40),

                              // Emergency Contact Section
                              _buildEmergencyContactSection(),

                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ),

                      // Bottom Continue Button
                      _buildBottomActions(authState),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build the top navigation bar with Skip button
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
            text: 'Great job ',
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
          "Let's add your medical information",
          style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  /// Build the medication section
  Widget _buildMedicationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.medical_services,
                size: 20,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Medication Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Medication name dropdown
        _buildDropdownField(
          label: 'Adrenaline Pen Type',
          value: _selectedMedication,
          items: const ['EpiPen', 'Jext', 'Emerade', 'Neffy'],
          onChanged: (value) {
            setState(() {
              _selectedMedication = value;
            });
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select an adrenaline pen type';
            }
            return null;
          },
        ),

        const SizedBox(height: 16),

        // Medication dosage dropdown
        _buildDropdownField(
          label: 'Dosage',
          value: _selectedDosage,
          items: const ['0.15mg', '0.3mg', '0.5mg'],
          onChanged: (value) {
            setState(() {
              _selectedDosage = value;
            });
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select a dosage';
            }
            return null;
          },
        ),
      ],
    );
  }

  /// Build the emergency contact section
  Widget _buildEmergencyContactSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                HugeIcons.strokeRoundedUser,
                size: 20,
                color: AppColors.error,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Emergency Contact',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Emergency contact name field
        _buildTextField(
          controller: _emergencyContactNameController,
          focusNode: _emergencyContactNameFocus,
          label: 'Contact Name',
          //hint: 'e.g., Mom, Dad, Guardian',
          // icon: HugeIcons.strokeRoundedUser,
          validator: (value) =>
              ValidationPatterns.validateRequired(value, 'Contact name'),
        ),

        const SizedBox(height: 16),

        // Emergency contact phone field
        _buildTextField(
          controller: _emergencyContactPhoneController,
          focusNode: _emergencyContactPhoneFocus,
          label: 'Phone Number',
          //hint: 'e.g., (555) 123-4567',
          //   icon: HugeIcons.strokeRoundedUser,
          keyboardType: TextInputType.phone,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Phone number is required';
            }
            // Basic phone validation
            final phoneRegex = RegExp(r'^[\+]?[1-9][\d]{0,15}$');
            final cleanPhone = value.replaceAll(RegExp(r'[^\d+]'), '');
            if (!phoneRegex.hasMatch(cleanPhone)) {
              return 'Please enter a valid phone number';
            }
            return null;
          },
        ),

        const SizedBox(height: 16),

        // Emergency contact relationship field
        _buildTextField(
          controller: _emergencyContactRelationshipController,
          focusNode: _emergencyContactRelationshipFocus,
          label: 'Relationship',
          //hint: 'e.g., Parent, Guardian, Friend',
          // icon: HugeIcons.strokeRoundedUser,
          validator: (value) =>
              ValidationPatterns.validateRequired(value, 'Relationship'),
        ),
      ],
    );
  }

  /// Build a styled dropdown field
  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.grey.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: DropdownButtonFormField<String>(
            value: value,
            items: items.map((String item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(
                  item,
                  style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
                ),
              );
            }).toList(),
            onChanged: onChanged,
            validator: validator,
            decoration: InputDecoration(
              hintText: 'Select $label',
              hintStyle: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
            dropdownColor: AppColors.background,
            icon: Icon(
              Icons.keyboard_arrow_down,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  /// Build a styled text field
  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    // required String hint,
    // required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: focusNode.hasFocus
                  ? AppColors.primary
                  : AppColors.grey.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: TextFormField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: keyboardType,
            validator: validator,
            decoration: InputDecoration(
              //hintText: hint,
              hintStyle: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              // prefixIcon: Icon(icon, size: 20, color: AppColors.textSecondary),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
          ),
        ),
      ],
    );
  }

  /// Build the bottom actions (Continue button)
  Widget _buildBottomActions(AuthState authState) {
    return Row(
      children: [
        // Spacer to push button to the right
        const Spacer(),

        // Continue Button
        SizedBox(
          width: 120,
          height: 48,
          child: ElevatedButton(
            onPressed: authState.isLoading
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
            child: authState.isLoading
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
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authController = ref.read(authControllerProvider.notifier);
    final authState = ref.read(authControllerProvider);

    if (authState.isLoading || authState.user == null) {
      return;
    }

    try {
      // Get fresh user data from Firestore to preserve allergies
      final authService = ref.read(authServiceProvider);
      final freshUser = await authService.getCurrentUserModel();

      if (freshUser == null) {
        throw Exception('Unable to get current user data');
      }

      // Prepare medical information
      final medicalInfo = {
        'medication': {
          'name': _selectedMedication ?? '',
          'dosage': _selectedDosage ?? '',
          'frequency': 'As needed', // Default frequency for adrenaline pens
        },
        'emergencyContact': {
          'name': _emergencyContactNameController.text.trim(),
          'phone': _emergencyContactPhoneController.text.trim(),
          'relationship': _emergencyContactRelationshipController.text.trim(),
        },
      };

      // Update user model with medical information, preserving allergies
      final updatedUser = freshUser.copyWith(
        medicalInfo: medicalInfo,
        updatedAt: DateTime.now(),
      );

      await authController.updateUserProfile(updatedUser);
      _navigateToHome(context);
    } catch (e) {
      _showErrorSnackBar(
        context,
        'An unexpected error occurred. Please try again.',
      );
    }
  }

  /// Navigate to home screen
  void _navigateToHome(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const HomeView()),
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
