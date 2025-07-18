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
      _tookMedication = log.tookMedication;
      _severity = log.severity;
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.existingLog != null ? 'Edit Symptom Log' : 'Track Symptoms',
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

              // Symptoms Section
              _buildSymptomsSection(),

              const SizedBox(height: AppConstants.largePadding),

              // Severity Section
              _buildSeveritySection(),

              const SizedBox(height: AppConstants.largePadding),

              // Medication Section
              _buildMedicationSection(),

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
                    ? 'Symptom log updated successfully!'
                    : 'Symptom log saved successfully!',
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
              content: Text('Failed to save symptom log. Please try again.'),
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
