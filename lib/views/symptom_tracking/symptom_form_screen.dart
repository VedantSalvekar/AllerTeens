import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../models/symptom_log.dart';
import '../../controllers/symptom_log_controller.dart';

class SymptomFormScreen extends ConsumerStatefulWidget {
  final DateTime? selectedDate;
  final SymptomLog? existingLog;

  const SymptomFormScreen({super.key, this.selectedDate, this.existingLog});

  @override
  ConsumerState<SymptomFormScreen> createState() => _SymptomFormScreenState();
}

class _SymptomFormScreenState extends ConsumerState<SymptomFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final _foodEatenController = TextEditingController();
  final _timeToFirstSymptomController = TextEditingController();
  final _treatmentTimeController = TextEditingController();
  final _medicationUsedController = TextEditingController();

  late DateTime _selectedDate;
  final Set<String> _selectedSymptoms = {};
  bool _tookMedication = false;
  String _severity = 'mild';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.selectedDate ?? DateTime.now();

    // If editing existing log, populate form
    if (widget.existingLog != null) {
      final log = widget.existingLog!;
      _selectedSymptoms.addAll(log.symptoms);
      _notesController.text = log.notes;
      _foodEatenController.text = log.foodEaten;
      _timeToFirstSymptomController.text = log.timeToFirstSymptom;
      _treatmentTimeController.text = log.treatmentTime;
      _medicationUsedController.text = log.medicationUsed;
      _tookMedication = log.tookMedication;
      _severity = log.severity;
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _foodEatenController.dispose();
    _timeToFirstSymptomController.dispose();
    _treatmentTimeController.dispose();
    _medicationUsedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.existingLog != null
              ? 'Edit Accidental Exposure'
              : 'Accidental Exposure',
          style: AppTextStyles.headline3.copyWith(color: AppColors.white),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date Section
              _buildDateSection(),

              const SizedBox(height: AppConstants.largePadding),

              // Food Eaten Section
              _buildFoodEatenSection(),

              const SizedBox(height: AppConstants.largePadding),

              // Symptoms Section
              _buildSymptomsSection(),

              const SizedBox(height: AppConstants.largePadding),

              // Severity Section
              _buildSeveritySection(),

              const SizedBox(height: AppConstants.largePadding),

              // Time from Eating to First Symptom Section
              _buildTimeToFirstSymptomSection(),

              const SizedBox(height: AppConstants.largePadding),

              // Treatment Time Section
              _buildTreatmentTimeSection(),

              const SizedBox(height: AppConstants.largePadding),

              // Medication Used Section
              _buildMedicationUsedSection(),

              const SizedBox(height: AppConstants.largePadding),

              // Notes Section
              _buildNotesSection(),

              const SizedBox(height: AppConstants.largePadding * 2),

              // Submit Button
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Date',
              style: AppTextStyles.headline3.copyWith(
                color: AppColors.textPrimary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: AppConstants.smallPadding),

            InkWell(
              onTap: _selectDate,
              child: Container(
                padding: const EdgeInsets.all(AppConstants.defaultPadding),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.lightGrey),
                  borderRadius: BorderRadius.circular(
                    AppConstants.defaultBorderRadius,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('EEEE, MMM d, yyyy').format(_selectedDate),
                      style: AppTextStyles.bodyText1,
                    ),
                    Icon(Icons.calendar_today, color: AppColors.primary),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSymptomsSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Symptoms',
              style: AppTextStyles.headline3.copyWith(
                color: AppColors.textPrimary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: AppConstants.smallPadding),

            Text(
              'Select all symptoms you experienced today:',
              style: AppTextStyles.bodyText2.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppConstants.defaultPadding),

            // Symptom checkboxes
            SymptomCheckboxList(
              symptoms: CommonSymptoms.allSymptoms,
              selectedSymptoms: _selectedSymptoms,
              onSymptomToggled: _toggleSymptom,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeveritySection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Severity',
              style: AppTextStyles.headline3.copyWith(
                color: AppColors.textPrimary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: AppConstants.smallPadding),

            Text(
              'How severe were your symptoms?',
              style: AppTextStyles.bodyText2.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppConstants.defaultPadding),

            // Severity selection
            SeveritySelector(
              selectedSeverity: _severity,
              onSeverityChanged: (severity) {
                setState(() {
                  _severity = severity;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicationSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Medication',
              style: AppTextStyles.headline3.copyWith(
                color: AppColors.textPrimary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: AppConstants.smallPadding),

            Row(
              children: [
                Expanded(
                  child: Text(
                    'Did you take any allergy medication today?',
                    style: AppTextStyles.bodyText2.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Switch(
                  value: _tookMedication,
                  onChanged: (value) {
                    setState(() {
                      _tookMedication = value;
                    });
                  },
                  activeColor: AppColors.primary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notes',
              style: AppTextStyles.headline3.copyWith(
                color: AppColors.textPrimary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: AppConstants.smallPadding),

            Text(
              'Any additional details about your symptoms?',
              style: AppTextStyles.bodyText2.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppConstants.defaultPadding),

            TextFormField(
              controller: _notesController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Enter any additional notes...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    AppConstants.defaultBorderRadius,
                  ),
                ),
                filled: true,
                fillColor: AppColors.surface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFoodEatenSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Food Eaten',
              style: AppTextStyles.headline3.copyWith(
                color: AppColors.textPrimary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: AppConstants.smallPadding),

            Text(
              'What food did you eat that caused the reaction?',
              style: AppTextStyles.bodyText2.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppConstants.defaultPadding),

            TextFormField(
              controller: _foodEatenController,
              decoration: InputDecoration(
                hintText: 'Enter the food that caused the reaction...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    AppConstants.defaultBorderRadius,
                  ),
                ),
                filled: true,
                fillColor: AppColors.surface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeToFirstSymptomSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Time to First Symptom',
              style: AppTextStyles.headline3.copyWith(
                color: AppColors.textPrimary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: AppConstants.smallPadding),

            Text(
              'How much time passed from eating to first symptom?',
              style: AppTextStyles.bodyText2.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppConstants.defaultPadding),

            QuickSelectField(
              controller: _timeToFirstSymptomController,
              hintText: 'e.g., 15 minutes, 2 hours...',
              quickOptions: const [
                '1 minute',
                '2 minutes',
                '5 minutes',
                '10 minutes',
                '15 minutes',
                '30 minutes',
                '45 minutes',
                '1 hour',
                '1.5 hours',
                '2 hours',
                '3 hours',
                '4+ hours',
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTreatmentTimeSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Treatment Time',
              style: AppTextStyles.headline3.copyWith(
                color: AppColors.textPrimary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: AppConstants.smallPadding),

            Text(
              'When did you receive or take treatment?',
              style: AppTextStyles.bodyText2.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppConstants.defaultPadding),

            QuickSelectField(
              controller: _treatmentTimeController,
              hintText: 'e.g., 30 minutes after symptoms, immediately...',
              quickOptions: const [
                '1 minute',
                '2 minutes',
                '5 minutes',
                '10 minutes',
                '15 minutes',
                '30 minutes',
                '45 minutes',
                '1 hour',
                '1.5 hours',
                '2 hours',
                '3 hours',
                '4+ hours',
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicationUsedSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Medication Used',
              style: AppTextStyles.headline3.copyWith(
                color: AppColors.textPrimary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: AppConstants.smallPadding),

            Text(
              'What medication did you take?',
              style: AppTextStyles.bodyText2.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppConstants.defaultPadding),

            QuickSelectField(
              controller: _medicationUsedController,
              hintText: 'e.g., Cetirizine, Loratadine, Piriton...',
              quickOptions: const [
                'Cetirizine (Zyrtec)',
                'Loratadine (Claritin)',
                'Fexofenadine (Allegra)',
                'Chlorphenamine (Piriton)',
                'Diphenhydramine (Benadryl)',
                'Promethazine (Phenergan)',
                'Desloratadine (Neoclarityn)',
                'Levocetirizine (Xyzal)',
                'No antihistamine taken',
                'Other antihistamine',
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitForm,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              AppConstants.defaultBorderRadius,
            ),
          ),
        ),
        child: _isSubmitting
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: AppColors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                widget.existingLog != null ? 'Update Log' : 'Save Log',
                style: AppTextStyles.buttonText,
              ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _toggleSymptom(String symptom) {
    setState(() {
      if (_selectedSymptoms.contains(symptom)) {
        _selectedSymptoms.remove(symptom);
      } else {
        _selectedSymptoms.add(symptom);
      }
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final log = SymptomLog.create(
        date: _selectedDate,
        symptoms: _selectedSymptoms.toList(),
        notes: _notesController.text.trim(),
        tookMedication: _tookMedication,
        severity: _severity,
        foodEaten: _foodEatenController.text.trim(),
        timeToFirstSymptom: _timeToFirstSymptomController.text.trim(),
        treatmentTime: _treatmentTimeController.text.trim(),
        medicationUsed: _medicationUsedController.text.trim(),
      );

      final controller = ref.read(symptomLogControllerProvider.notifier);
      bool success;

      if (widget.existingLog != null) {
        success = await controller.updateLog(
          log.copyWith(id: widget.existingLog!.id),
        );
      } else {
        success = await controller.saveLog(log);
      }

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.existingLog != null
                    ? 'Accidental exposure updated successfully!'
                    : 'Accidental exposure saved successfully!',
              ),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to save accidental exposure. Please try again.',
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}

/// Widget for selecting symptoms with checkboxes
class SymptomCheckboxList extends StatelessWidget {
  final List<String> symptoms;
  final Set<String> selectedSymptoms;
  final Function(String) onSymptomToggled;

  const SymptomCheckboxList({
    super.key,
    required this.symptoms,
    required this.selectedSymptoms,
    required this.onSymptomToggled,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: symptoms.map((symptom) {
        return CheckboxListTile(
          title: Text(symptom, style: AppTextStyles.bodyText1),
          value: selectedSymptoms.contains(symptom),
          onChanged: (bool? value) {
            onSymptomToggled(symptom);
          },
          controlAffinity: ListTileControlAffinity.leading,
          dense: true,
          contentPadding: EdgeInsets.zero,
        );
      }).toList(),
    );
  }
}

/// Widget for selecting severity level
class SeveritySelector extends StatelessWidget {
  final String selectedSeverity;
  final Function(String) onSeverityChanged;

  const SeveritySelector({
    super.key,
    required this.selectedSeverity,
    required this.onSeverityChanged,
  });

  @override
  Widget build(BuildContext context) {
    final severityLevels = [
      {'value': 'mild', 'label': 'Mild', 'color': AppColors.success},
      {'value': 'moderate', 'label': 'Moderate', 'color': AppColors.warning},
      {'value': 'severe', 'label': 'Severe', 'color': AppColors.error},
    ];

    return Row(
      children: severityLevels.map((level) {
        final isSelected = selectedSeverity == level['value'];

        return Expanded(
          child: GestureDetector(
            onTap: () => onSeverityChanged(level['value'] as String),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? (level['color'] as Color).withOpacity(0.1)
                    : AppColors.surface,
                border: Border.all(
                  color: isSelected
                      ? (level['color'] as Color)
                      : AppColors.lightGrey,
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(
                  AppConstants.defaultBorderRadius,
                ),
              ),
              child: Center(
                child: Text(
                  level['label'] as String,
                  style: AppTextStyles.bodyText1.copyWith(
                    color: isSelected
                        ? (level['color'] as Color)
                        : AppColors.textSecondary,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Widget for input with dropdown quick selection and manual entry
class QuickSelectField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final List<String> quickOptions;

  const QuickSelectField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.quickOptions,
  });

  @override
  State<QuickSelectField> createState() => _QuickSelectFieldState();
}

class _QuickSelectFieldState extends State<QuickSelectField> {
  bool _showDropdown = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: widget.controller,
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppConstants.defaultBorderRadius,
                    ),
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showDropdown
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: AppColors.primary,
                    ),
                    onPressed: () {
                      setState(() {
                        _showDropdown = !_showDropdown;
                      });
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_showDropdown) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(
                AppConstants.defaultBorderRadius,
              ),
              border: Border.all(color: AppColors.lightGrey),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(
                        AppConstants.defaultBorderRadius,
                      ),
                      topRight: Radius.circular(
                        AppConstants.defaultBorderRadius,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        color: AppColors.primary,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Quick Select',
                        style: AppTextStyles.bodyText2.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Wrap(
                  children: widget.quickOptions.map((option) {
                    return Padding(
                      padding: const EdgeInsets.all(4),
                      child: InkWell(
                        onTap: () {
                          widget.controller.text = option;
                          setState(() {
                            _showDropdown = false;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            option,
                            style: AppTextStyles.bodyText2.copyWith(
                              color: AppColors.primary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
