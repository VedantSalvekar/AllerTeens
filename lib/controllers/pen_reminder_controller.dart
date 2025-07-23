import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/pen_reminder_response.dart';
import '../controllers/auth_controller.dart';
import '../services/pen_reminder_notification_service.dart';

/// State class for pen reminder management
class PenReminderState {
  final List<PenReminderResponse> responses;
  final bool isLoading;
  final String? error;
  final PenReminderResponse? todayResponse;

  const PenReminderState({
    this.responses = const [],
    this.isLoading = false,
    this.error,
    this.todayResponse,
  });

  PenReminderState copyWith({
    List<PenReminderResponse>? responses,
    bool? isLoading,
    String? error,
    PenReminderResponse? todayResponse,
  }) {
    return PenReminderState(
      responses: responses ?? this.responses,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      todayResponse: todayResponse ?? this.todayResponse,
    );
  }

  /// Get response for a specific date
  PenReminderResponse? getResponseForDate(DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    return responses.cast<PenReminderResponse?>().firstWhere(
      (response) => response != null && _isSameDate(response.date, dateOnly),
      orElse: () => null,
    );
  }

  /// Check if date has a response
  bool hasResponseForDate(DateTime date) {
    return getResponseForDate(date) != null;
  }

  /// Get dates with responses for calendar markers
  List<DateTime> get datesWithResponses {
    return responses.map((response) => response.date).toList();
  }

  /// Get dates where user carried pen (green markers)
  List<DateTime> get datesWithPenCarried {
    return responses
        .where((response) => response.penCarried)
        .map((response) => response.date)
        .toList();
  }

  /// Get dates where user didn't carry pen (red markers)
  List<DateTime> get datesWithoutPenCarried {
    return responses
        .where((response) => !response.penCarried)
        .map((response) => response.date)
        .toList();
  }

  /// Get recent responses (last 7 days)
  List<PenReminderResponse> get recentResponses {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    return responses
        .where((response) => response.date.isAfter(weekAgo))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  /// Get compliance rate for last 30 days
  double get monthlyComplianceRate {
    final now = DateTime.now();
    final monthAgo = now.subtract(const Duration(days: 30));
    final monthlyResponses = responses
        .where((response) => response.date.isAfter(monthAgo))
        .toList();

    if (monthlyResponses.isEmpty) return 0.0;

    final compliantDays = monthlyResponses
        .where((response) => response.penCarried)
        .length;

    return compliantDays / monthlyResponses.length;
  }

  /// Check if two dates are the same day
  bool _isSameDate(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }
}

/// Controller for pen reminder management
class PenReminderController extends StateNotifier<PenReminderState> {
  final FirebaseFirestore _firestore;
  final Ref _ref;

  PenReminderController(this._firestore, this._ref)
    : super(const PenReminderState());

  /// Get user ID from auth controller
  String? get _userId {
    final authState = _ref.read(authControllerProvider);
    return authState.user?.id;
  }

  /// Get collection reference for user's pen reminder responses
  CollectionReference? get _responsesCollection {
    final userId = _userId;
    if (userId == null) return null;
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('pen_reminder_responses');
  }

  /// Initialize pen reminders (call on app start when user is signed in)
  Future<void> initialize() async {
    if (_userId == null) return;

    // Initialize notification service
    await PenReminderNotificationService.instance.initialize();

    // Load existing responses
    await loadResponses();

    // Check today's response
    await _checkTodayResponse();

    // Schedule daily reminder if not already done
    // TODO: Uncomment this for production use
    // await PenReminderNotificationService.instance.scheduleDailyReminder();

    // For testing: Show notification immediately
    await showTestNotification();
  }

  /// Show test notification (for development/testing)
  Future<void> showTestNotification() async {
    await PenReminderNotificationService.instance.showTestNotification();
  }

  /// Load all pen reminder responses for the current user
  Future<void> loadResponses() async {
    if (_userId == null) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final collection = _responsesCollection;
      if (collection == null) throw Exception('User not authenticated');

      final snapshot = await collection.orderBy('date', descending: true).get();
      final responses = snapshot.docs
          .map((doc) => PenReminderResponse.fromFirestore(doc))
          .toList();

      state = state.copyWith(responses: responses, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load pen reminder responses: ${e.toString()}',
      );
    }
  }

  /// Save user's response to today's reminder
  Future<bool> saveResponse(bool penCarried) async {
    if (_userId == null) return false;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final collection = _responsesCollection;
      if (collection == null) throw Exception('User not authenticated');

      final response = PenReminderResponse.createForToday(
        penCarried: penCarried,
      );
      await collection.doc(response.id).set(response.toFirestore());

      // Update local state
      final updatedResponses = [...state.responses];
      final existingIndex = updatedResponses.indexWhere(
        (r) => r.id == response.id,
      );

      if (existingIndex >= 0) {
        updatedResponses[existingIndex] = response;
      } else {
        updatedResponses.add(response);
      }

      // Sort by date (newest first)
      updatedResponses.sort((a, b) => b.date.compareTo(a.date));

      state = state.copyWith(
        responses: updatedResponses,
        todayResponse: response,
        isLoading: false,
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to save response: ${e.toString()}',
      );
      return false;
    }
  }

  /// Check if user has already responded today
  Future<void> _checkTodayResponse() async {
    final today = DateTime.now();
    final todayResponse = state.getResponseForDate(today);
    state = state.copyWith(todayResponse: todayResponse);
  }

  /// Get response for a specific date
  PenReminderResponse? getResponseForDate(DateTime date) {
    return state.getResponseForDate(date);
  }

  /// Check if date has a response
  bool hasResponseForDate(DateTime date) {
    return state.hasResponseForDate(date);
  }

  /// Get compliance statistics
  Map<String, dynamic> getComplianceStats() {
    final totalResponses = state.responses.length;
    if (totalResponses == 0) {
      return {
        'total_days': 0,
        'compliant_days': 0,
        'compliance_rate': 0.0,
        'monthly_rate': 0.0,
      };
    }

    final compliantDays = state.responses
        .where((response) => response.penCarried)
        .length;

    final overallRate = compliantDays / totalResponses;
    final monthlyRate = state.monthlyComplianceRate;

    return {
      'total_days': totalResponses,
      'compliant_days': compliantDays,
      'compliance_rate': overallRate,
      'monthly_rate': monthlyRate,
    };
  }

  /// Listen to real-time updates
  void startListening() {
    if (_userId == null) return;

    final collection = _responsesCollection;
    if (collection == null) return;

    collection
        .orderBy('date', descending: true)
        .snapshots()
        .listen(
          (snapshot) {
            final responses = snapshot.docs
                .map((doc) => PenReminderResponse.fromFirestore(doc))
                .toList();

            final today = DateTime.now();
            final todayResponse = responses
                .cast<PenReminderResponse?>()
                .firstWhere(
                  (response) =>
                      response != null && _isSameDate(response.date, today),
                  orElse: () => null,
                );

            state = state.copyWith(
              responses: responses,
              todayResponse: todayResponse,
              isLoading: false,
            );
          },
          onError: (error) {
            state = state.copyWith(
              isLoading: false,
              error:
                  'Failed to listen to pen reminder responses: ${error.toString()}',
            );
          },
        );
  }

  /// Clear any error state
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Enable/disable daily reminders
  Future<void> setDailyRemindersEnabled(bool enabled) async {
    if (enabled) {
      await PenReminderNotificationService.instance.scheduleDailyReminder();
    } else {
      await PenReminderNotificationService.instance.cancelDailyReminder();
    }
  }

  /// Check if two dates are the same day
  bool _isSameDate(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }
}

/// Provider for pen reminder controller
final penReminderControllerProvider =
    StateNotifierProvider<PenReminderController, PenReminderState>((ref) {
      return PenReminderController(FirebaseFirestore.instance, ref);
    });

/// Provider for pen reminder state
final penReminderStateProvider = Provider<PenReminderState>((ref) {
  return ref.watch(penReminderControllerProvider);
});

/// Provider for response for a specific date
final responseForDateProvider = Provider.family<PenReminderResponse?, DateTime>(
  (ref, date) {
    final state = ref.watch(penReminderStateProvider);
    return state.getResponseForDate(date);
  },
);

/// Provider for checking if a date has a response
final hasResponseForDateProvider = Provider.family<bool, DateTime>((ref, date) {
  final state = ref.watch(penReminderStateProvider);
  return state.hasResponseForDate(date);
});

/// Provider for dates with responses (for calendar markers)
final datesWithResponsesProvider = Provider<List<DateTime>>((ref) {
  final state = ref.watch(penReminderStateProvider);
  return state.datesWithResponses;
});

/// Provider for dates where pen was carried (green markers)
final datesWithPenCarriedProvider = Provider<List<DateTime>>((ref) {
  final state = ref.watch(penReminderStateProvider);
  return state.datesWithPenCarried;
});

/// Provider for dates where pen was not carried (red markers)
final datesWithoutPenCarriedProvider = Provider<List<DateTime>>((ref) {
  final state = ref.watch(penReminderStateProvider);
  return state.datesWithoutPenCarried;
});

/// Provider for today's response
final todayResponseProvider = Provider<PenReminderResponse?>((ref) {
  final state = ref.watch(penReminderStateProvider);
  return state.todayResponse;
});

/// Provider for recent responses
final recentResponsesProvider = Provider<List<PenReminderResponse>>((ref) {
  final state = ref.watch(penReminderStateProvider);
  return state.recentResponses;
});

/// Provider for compliance statistics
final complianceStatsProvider = Provider<Map<String, dynamic>>((ref) {
  final controller = ref.watch(penReminderControllerProvider.notifier);
  return controller.getComplianceStats();
});
