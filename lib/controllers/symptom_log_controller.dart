import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/symptom_log.dart';
import '../controllers/auth_controller.dart';

/// State class for symptom log management
class SymptomLogState {
  final List<SymptomLog> logs;
  final bool isLoading;
  final String? error;
  final SymptomLog? selectedLog;

  const SymptomLogState({
    this.logs = const [],
    this.isLoading = false,
    this.error,
    this.selectedLog,
  });

  SymptomLogState copyWith({
    List<SymptomLog>? logs,
    bool? isLoading,
    String? error,
    SymptomLog? selectedLog,
  }) {
    return SymptomLogState(
      logs: logs ?? this.logs,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      selectedLog: selectedLog ?? this.selectedLog,
    );
  }

  /// Get logs for a specific date
  List<SymptomLog> getLogsForDate(DateTime date) {
    return logs.where((log) {
      return log.date.year == date.year &&
          log.date.month == date.month &&
          log.date.day == date.day;
    }).toList();
  }

  /// Get log for specific date (single log per day)
  SymptomLog? getLogForDate(DateTime date) {
    final logsForDate = getLogsForDate(date);
    return logsForDate.isNotEmpty ? logsForDate.first : null;
  }

  /// Check if date has any logs
  bool hasLogForDate(DateTime date) {
    return getLogForDate(date) != null;
  }

  /// Get dates with logs for calendar markers
  List<DateTime> get datesWithLogs {
    return logs.map((log) => log.date).toList();
  }

  /// Get today's log
  SymptomLog? get todayLog {
    final today = DateTime.now();
    return getLogForDate(today);
  }

  /// Get recent logs (last 7 days)
  List<SymptomLog> get recentLogs {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    return logs.where((log) => log.date.isAfter(weekAgo)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  /// Get logs with symptoms (filtering empty logs)
  List<SymptomLog> get logsWithSymptoms {
    return logs.where((log) => log.hasSymptoms).toList();
  }
}

/// Controller for symptom log management
class SymptomLogController extends StateNotifier<SymptomLogState> {
  final FirebaseFirestore _firestore;
  final Ref _ref;

  SymptomLogController(this._firestore, this._ref)
    : super(const SymptomLogState());

  /// Get user ID from auth controller
  String? get _userId {
    final authState = _ref.read(authControllerProvider);
    return authState.user?.id;
  }

  /// Get collection reference for user's symptom logs
  CollectionReference? get _logsCollection {
    final userId = _userId;
    if (userId == null) return null;
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('symptom_logs');
  }

  /// Load all symptom logs for the current user
  Future<void> loadLogs() async {
    if (_userId == null) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final collection = _logsCollection;
      if (collection == null) throw Exception('User not authenticated');

      final snapshot = await collection.orderBy('date', descending: true).get();
      final logs = snapshot.docs
          .map((doc) => SymptomLog.fromFirestore(doc))
          .toList();

      state = state.copyWith(logs: logs, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load symptom logs: ${e.toString()}',
      );
    }
  }

  /// Save a new symptom log
  Future<bool> saveLog(SymptomLog log) async {
    if (_userId == null) return false;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final collection = _logsCollection;
      if (collection == null) throw Exception('User not authenticated');

      await collection.doc(log.id).set(log.toFirestore());

      // Add to local state
      final updatedLogs = [...state.logs];
      final existingIndex = updatedLogs.indexWhere((l) => l.id == log.id);

      if (existingIndex >= 0) {
        updatedLogs[existingIndex] = log;
      } else {
        updatedLogs.add(log);
      }

      // Sort by date (newest first)
      updatedLogs.sort((a, b) => b.date.compareTo(a.date));

      state = state.copyWith(logs: updatedLogs, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to save symptom log: ${e.toString()}',
      );
      return false;
    }
  }

  /// Update an existing symptom log
  Future<bool> updateLog(SymptomLog log) async {
    if (_userId == null) return false;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final collection = _logsCollection;
      if (collection == null) throw Exception('User not authenticated');

      final updatedLog = log.copyWith(updatedAt: DateTime.now());
      await collection.doc(log.id).update(updatedLog.toFirestore());

      // Update local state
      final updatedLogs = state.logs
          .map((l) => l.id == log.id ? updatedLog : l)
          .toList();
      state = state.copyWith(logs: updatedLogs, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to update symptom log: ${e.toString()}',
      );
      return false;
    }
  }

  /// Delete a symptom log
  Future<bool> deleteLog(String logId) async {
    if (_userId == null) return false;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final collection = _logsCollection;
      if (collection == null) throw Exception('User not authenticated');

      await collection.doc(logId).delete();

      // Remove from local state
      final updatedLogs = state.logs.where((l) => l.id != logId).toList();
      state = state.copyWith(logs: updatedLogs, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to delete symptom log: ${e.toString()}',
      );
      return false;
    }
  }

  /// Get log for a specific date
  SymptomLog? getLogForDate(DateTime date) {
    return state.getLogForDate(date);
  }

  /// Check if date has log
  bool hasLogForDate(DateTime date) {
    return state.hasLogForDate(date);
  }

  /// Set selected log for viewing details
  void setSelectedLog(SymptomLog? log) {
    state = state.copyWith(selectedLog: log);
  }

  /// Clear any error state
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Get symptom statistics
  Map<String, int> getSymptomStats() {
    final stats = <String, int>{};

    for (final log in state.logs) {
      for (final symptom in log.symptoms) {
        stats[symptom] = (stats[symptom] ?? 0) + 1;
      }
    }

    return stats;
  }

  /// Get severity distribution
  Map<String, int> getSeverityStats() {
    final stats = <String, int>{};

    for (final log in state.logs) {
      if (log.hasSymptoms) {
        stats[log.severity] = (stats[log.severity] ?? 0) + 1;
      }
    }

    return stats;
  }

  /// Get medication usage stats
  Map<String, int> getMedicationStats() {
    int withMedication = 0;
    int withoutMedication = 0;

    for (final log in state.logs) {
      if (log.hasSymptoms) {
        if (log.tookMedication) {
          withMedication++;
        } else {
          withoutMedication++;
        }
      }
    }

    return {
      'with_medication': withMedication,
      'without_medication': withoutMedication,
    };
  }

  /// Listen to real-time updates
  void startListening() {
    if (_userId == null) return;

    final collection = _logsCollection;
    if (collection == null) return;

    collection
        .orderBy('date', descending: true)
        .snapshots()
        .listen(
          (snapshot) {
            final logs = snapshot.docs
                .map((doc) => SymptomLog.fromFirestore(doc))
                .toList();
            state = state.copyWith(logs: logs, isLoading: false);
          },
          onError: (error) {
            state = state.copyWith(
              isLoading: false,
              error: 'Failed to listen to symptom logs: ${error.toString()}',
            );
          },
        );
  }

  /// Stop listening to updates
  void stopListening() {
    // StreamSubscription management would go here if needed
  }
}

/// Provider for symptom log controller
final symptomLogControllerProvider =
    StateNotifierProvider<SymptomLogController, SymptomLogState>((ref) {
      return SymptomLogController(FirebaseFirestore.instance, ref);
    });

/// Provider for symptom log state
final symptomLogStateProvider = Provider<SymptomLogState>((ref) {
  return ref.watch(symptomLogControllerProvider);
});

/// Provider for logs for a specific date
final logsForDateProvider = Provider.family<SymptomLog?, DateTime>((ref, date) {
  final state = ref.watch(symptomLogStateProvider);
  return state.getLogForDate(date);
});

/// Provider for checking if a date has logs
final hasLogForDateProvider = Provider.family<bool, DateTime>((ref, date) {
  final state = ref.watch(symptomLogStateProvider);
  return state.hasLogForDate(date);
});

/// Provider for dates with logs (for calendar markers)
final datesWithLogsProvider = Provider<List<DateTime>>((ref) {
  final state = ref.watch(symptomLogStateProvider);
  return state.datesWithLogs;
});

/// Provider for today's log
final todayLogProvider = Provider<SymptomLog?>((ref) {
  final state = ref.watch(symptomLogStateProvider);
  return state.todayLog;
});

/// Provider for recent logs
final recentLogsProvider = Provider<List<SymptomLog>>((ref) {
  final state = ref.watch(symptomLogStateProvider);
  return state.recentLogs;
});

/// Provider for symptom statistics
final symptomStatsProvider = Provider<Map<String, int>>((ref) {
  final controller = ref.watch(symptomLogControllerProvider.notifier);
  return controller.getSymptomStats();
});

/// Provider for severity statistics
final severityStatsProvider = Provider<Map<String, int>>((ref) {
  final controller = ref.watch(symptomLogControllerProvider.notifier);
  return controller.getSeverityStats();
});

/// Provider for medication statistics
final medicationStatsProvider = Provider<Map<String, int>>((ref) {
  final controller = ref.watch(symptomLogControllerProvider.notifier);
  return controller.getMedicationStats();
});
