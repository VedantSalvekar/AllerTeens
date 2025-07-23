import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../models/symptom_log.dart';
import '../../models/pen_reminder_response.dart';
import '../../controllers/symptom_log_controller.dart';
import '../../controllers/pen_reminder_controller.dart';
import 'symptom_form_screen.dart';

class LogsScreen extends ConsumerStatefulWidget {
  const LogsScreen({super.key});

  @override
  ConsumerState<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends ConsumerState<LogsScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();

    // Load logs and pen reminders when screen is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(symptomLogControllerProvider.notifier).loadLogs();
      ref.read(penReminderControllerProvider.notifier).loadResponses();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(symptomLogStateProvider);
    final datesWithLogs = ref.watch(datesWithLogsProvider);
    final reminderState = ref.watch(penReminderStateProvider);
    final datesWithPenCarried = ref.watch(datesWithPenCarriedProvider);
    final datesWithoutPenCarried = ref.watch(datesWithoutPenCarriedProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Exposure Logs',
          style: AppTextStyles.headline3.copyWith(color: AppColors.white),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(symptomLogControllerProvider.notifier).loadLogs();
              ref.read(penReminderControllerProvider.notifier).loadResponses();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Calendar Section
          _buildCalendarSection(
            datesWithLogs,
            datesWithPenCarried,
            datesWithoutPenCarried,
          ),

          // Selected Day Details
          Expanded(child: _buildSelectedDayDetails(state, reminderState)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SymptomFormScreen(
                selectedDate: _selectedDay ?? DateTime.now(),
              ),
            ),
          );
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: AppColors.white),
      ),
    );
  }

  Widget _buildCalendarSection(
    List<DateTime> datesWithLogs,
    List<DateTime> datesWithPenCarried,
    List<DateTime> datesWithoutPenCarried,
  ) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      child: TableCalendar<SymptomLog>(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        calendarFormat: _calendarFormat,
        selectedDayPredicate: (day) {
          return isSameDay(_selectedDay, day);
        },
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
        },
        onFormatChanged: (format) {
          setState(() {
            _calendarFormat = format;
          });
        },
        onPageChanged: (focusedDay) {
          _focusedDay = focusedDay;
        },
        eventLoader: (day) {
          // Return logs for this day to show event markers
          final log = ref
              .read(symptomLogControllerProvider.notifier)
              .getLogForDate(day);
          return log != null ? [log] : [];
        },
        startingDayOfWeek: StartingDayOfWeek.monday,
        calendarStyle: CalendarStyle(
          outsideDaysVisible: false,
          weekendTextStyle: AppTextStyles.bodyText1.copyWith(
            color: AppColors.textSecondary,
          ),
          holidayTextStyle: AppTextStyles.bodyText1.copyWith(
            color: AppColors.textSecondary,
          ),
          // Remove default decorations since we're using custom builders
          selectedDecoration: const BoxDecoration(color: Colors.transparent),
          todayDecoration: const BoxDecoration(color: Colors.transparent),
          markerDecoration: const BoxDecoration(color: Colors.transparent),
          markersMaxCount: 1,
          markersAnchor: 1.0,
          markerSize: 20,
        ),
        headerStyle: HeaderStyle(
          formatButtonVisible: true,
          titleCentered: true,
          formatButtonShowsNext: false,
          formatButtonDecoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(AppConstants.smallBorderRadius),
          ),
          formatButtonTextStyle: AppTextStyles.bodyText2.copyWith(
            color: AppColors.white,
          ),
        ),
        calendarBuilders: CalendarBuilders(
          markerBuilder: (context, day, events) {
            return _buildMultipleMarkers(day, events);
          },
          todayBuilder: (context, day, focusedDay) {
            return Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.6),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${day.day}',
                  style: TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          },
          selectedBuilder: (context, day, focusedDay) {
            return Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${day.day}',
                  style: TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEventMarker(SymptomLog log) {
    Color markerColor;
    IconData markerIcon;
    switch (log.severity) {
      case 'mild':
        markerColor = AppColors.success;
        markerIcon = Icons.circle;
        break;
      case 'moderate':
        markerColor = AppColors.warning;
        markerIcon = Icons.warning;
        break;
      case 'severe':
        markerColor = AppColors.error;
        markerIcon = Icons.priority_high;
        break;
      default:
        markerColor = AppColors.primary;
        markerIcon = Icons.circle;
    }

    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: AppColors.white,
        shape: BoxShape.circle,
        border: Border.all(color: markerColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: markerColor.withOpacity(0.3),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Icon(markerIcon, size: 12, color: markerColor),
    );
  }

  Widget _buildPenReminderMarker(bool penCarried) {
    final markerColor = penCarried ? Colors.green : Colors.red;
    final markerIcon = penCarried ? Icons.check : Icons.close;

    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: markerColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: markerColor.withOpacity(0.3),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Icon(markerIcon, size: 10, color: Colors.white),
    );
  }

  Widget? _buildMultipleMarkers(DateTime day, List<SymptomLog> events) {
    final hasSymptomLog = events.isNotEmpty;
    final penReminderResponse = ref
        .read(penReminderControllerProvider.notifier)
        .getResponseForDate(day);

    if (!hasSymptomLog && penReminderResponse == null) {
      return null;
    }

    return Positioned.fill(
      child: Stack(
        children: [
          // Symptom log marker (bottom right)
          if (hasSymptomLog)
            Positioned(
              right: 2,
              bottom: 2,
              child: _buildEventMarker(events.first),
            ),
          // Pen reminder marker (top left)
          if (penReminderResponse != null)
            Positioned(
              left: 2,
              top: 2,
              child: _buildPenReminderMarker(penReminderResponse.penCarried),
            ),
        ],
      ),
    );
  }

  Widget _buildSelectedDayDetails(
    SymptomLogState state,
    PenReminderState reminderState,
  ) {
    if (state.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              'Error loading logs',
              style: AppTextStyles.headline3.copyWith(color: AppColors.error),
            ),
            const SizedBox(height: 8),
            Text(
              state.error!,
              style: AppTextStyles.bodyText2,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.read(symptomLogControllerProvider.notifier).loadLogs();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_selectedDay == null) {
      return const Center(
        child: Text(
          'Select a date to view logs',
          style: AppTextStyles.bodyText1,
        ),
      );
    }

    final selectedLog = state.getLogForDate(_selectedDay!);
    final penReminderResponse = reminderState.getResponseForDate(_selectedDay!);
    final formattedDate = DateFormat('EEEE, MMM d, yyyy').format(_selectedDay!);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date Header
          _buildDateHeader(formattedDate),

          const SizedBox(height: AppConstants.defaultPadding),

          // Pen Reminder Section
          if (penReminderResponse != null) ...[
            _buildPenReminderSection(penReminderResponse),
            const SizedBox(height: AppConstants.defaultPadding),
          ],

          // Log Details or Empty State
          if (selectedLog != null)
            _buildLogDetails(selectedLog)
          else if (penReminderResponse == null)
            _buildEmptyState()
          else
            _buildOnlyPenReminderState(),
        ],
      ),
    );
  }

  Widget _buildDateHeader(String formattedDate) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_today, color: AppColors.primary, size: 24),
          const SizedBox(width: 12),
          Text(
            formattedDate,
            style: AppTextStyles.headline3.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogDetails(SymptomLog log) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Food Eaten Card
        if (log.foodEaten.isNotEmpty) ...[
          SymptomLogCard(
            title: 'Food Eaten',
            icon: Icons.restaurant,
            child: Text(log.foodEaten, style: AppTextStyles.bodyText1),
          ),
          const SizedBox(height: AppConstants.defaultPadding),
        ],

        // Symptoms Card
        if (log.symptoms.isNotEmpty) ...[
          SymptomLogCard(
            title: 'Symptoms',
            icon: Icons.medical_services,
            child: _buildSymptomsDisplay(log.symptoms),
          ),
          const SizedBox(height: AppConstants.defaultPadding),
        ],

        // Severity Card
        SymptomLogCard(
          title: 'Severity',
          icon: Icons.priority_high,
          child: _buildSeverityDisplay(log.severity),
        ),
        const SizedBox(height: AppConstants.defaultPadding),

        // Time to First Symptom Card
        if (log.timeToFirstSymptom.isNotEmpty) ...[
          SymptomLogCard(
            title: 'Time to First Symptom',
            icon: Icons.access_time,
            child: Text(log.timeToFirstSymptom, style: AppTextStyles.bodyText1),
          ),
          const SizedBox(height: AppConstants.defaultPadding),
        ],

        // Treatment Time Card
        if (log.treatmentTime.isNotEmpty) ...[
          SymptomLogCard(
            title: 'Treatment Time',
            icon: Icons.schedule,
            child: Text(log.treatmentTime, style: AppTextStyles.bodyText1),
          ),
          const SizedBox(height: AppConstants.defaultPadding),
        ],

        // Medication Used Card
        if (log.medicationUsed.isNotEmpty) ...[
          SymptomLogCard(
            title: 'Medication Used',
            icon: Icons.medication,
            child: Text(log.medicationUsed, style: AppTextStyles.bodyText1),
          ),
          const SizedBox(height: AppConstants.defaultPadding),
        ],

        // Notes Card
        if (log.notes.isNotEmpty) ...[
          const SizedBox(height: AppConstants.defaultPadding),
          SymptomLogCard(
            title: 'Notes',
            icon: Icons.note,
            child: Text(log.notes, style: AppTextStyles.bodyText1),
          ),
        ],

        const SizedBox(height: AppConstants.largePadding),

        // Action Buttons
        _buildActionButtons(log),
      ],
    );
  }

  Widget _buildSymptomsDisplay(List<String> symptoms) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: symptoms.map((symptom) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppConstants.smallBorderRadius),
          ),
          child: Text(
            symptom,
            style: AppTextStyles.bodyText2.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSeverityDisplay(String severity) {
    Color severityColor;
    IconData severityIcon;

    switch (severity) {
      case 'mild':
        severityColor = AppColors.success;
        severityIcon = Icons.sentiment_satisfied;
        break;
      case 'moderate':
        severityColor = AppColors.warning;
        severityIcon = Icons.sentiment_neutral;
        break;
      case 'severe':
        severityColor = AppColors.error;
        severityIcon = Icons.sentiment_very_dissatisfied;
        break;
      default:
        severityColor = AppColors.textSecondary;
        severityIcon = Icons.help_outline;
    }

    return Row(
      children: [
        Icon(severityIcon, color: severityColor, size: 24),
        const SizedBox(width: 8),
        Text(
          severity.toUpperCase(),
          style: AppTextStyles.bodyText1.copyWith(
            color: severityColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildMedicationDisplay(bool tookMedication) {
    return Row(
      children: [
        Icon(
          tookMedication ? Icons.check_circle : Icons.cancel,
          color: tookMedication ? AppColors.success : AppColors.error,
          size: 24,
        ),
        const SizedBox(width: 8),
        Text(
          tookMedication ? 'Medication taken' : 'No medication taken',
          style: AppTextStyles.bodyText1.copyWith(
            color: tookMedication ? AppColors.success : AppColors.error,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(SymptomLog log) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SymptomFormScreen(
                    selectedDate: log.date,
                    existingLog: log,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.edit),
            label: const Text('Edit'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: BorderSide(color: AppColors.primary),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _showDeleteConfirmation(log),
            icon: const Icon(Icons.delete),
            label: const Text('Delete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(AppConstants.largePadding),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(
              AppConstants.defaultBorderRadius,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(Icons.event_note, size: 64, color: AppColors.textSecondary),
              const SizedBox(height: 16),
              Text(
                'No exposure logged',
                style: AppTextStyles.headline3.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap the + button to log an accidental exposure for this date',
                style: AppTextStyles.bodyText2,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          SymptomFormScreen(selectedDate: _selectedDay!),
                    ),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('Log Exposure'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showDeleteConfirmation(SymptomLog log) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Exposure Log'),
        content: Text(
          'Are you sure you want to delete the exposure log for ${DateFormat('MMM d, yyyy').format(log.date)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              final success = await ref
                  .read(symptomLogControllerProvider.notifier)
                  .deleteLog(log.id);

              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Exposure log deleted successfully'),
                    backgroundColor: AppColors.success,
                  ),
                );
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to delete exposure log'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildPenReminderSection(PenReminderResponse response) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        border: Border.all(
          color: response.penCarried ? Colors.green : Colors.red,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (response.penCarried ? Colors.green : Colors.red)
                .withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.medication,
                color: response.penCarried ? Colors.green : Colors.red,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Adrenaline Pen Check',
                style: AppTextStyles.headline3.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: response.penCarried ? Colors.green : Colors.red,
                  borderRadius: BorderRadius.circular(
                    AppConstants.smallBorderRadius,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      response.penCarried ? Icons.check : Icons.close,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      response.penCarried ? 'Carried' : 'Forgot',
                      style: AppTextStyles.bodyText2.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                'Responded at ${DateFormat('h:mm a').format(response.respondedAt)}',
                style: AppTextStyles.bodyText2.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOnlyPenReminderState() {
    return Column(
      children: [
        const SizedBox(height: AppConstants.largePadding),
        Icon(
          Icons.medical_services_outlined,
          size: 64,
          color: AppColors.textSecondary,
        ),
        const SizedBox(height: 16),
        Text(
          'No exposure incidents recorded',
          style: AppTextStyles.headline3.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'But you did check in about your adrenaline pen!',
          style: AppTextStyles.bodyText2.copyWith(
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppConstants.largePadding),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SymptomFormScreen(
                  selectedDate: _selectedDay ?? DateTime.now(),
                ),
              ),
            );
          },
          icon: const Icon(Icons.add),
          label: const Text('Log Exposure'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ],
    );
  }
}

/// Reusable card widget for symptom log details
class SymptomLogCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const SymptomLogCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppConstants.defaultBorderRadius),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: AppTextStyles.headline3.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
