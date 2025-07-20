import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for storing user's daily pen reminder responses
class PenReminderResponse {
  final String id;
  final DateTime date; // Date of the reminder (date only, not time)
  final bool penCarried; // true if user said Yes, false if No
  final DateTime respondedAt; // When user actually responded
  final DateTime createdAt;

  const PenReminderResponse({
    required this.id,
    required this.date,
    required this.penCarried,
    required this.respondedAt,
    required this.createdAt,
  });

  /// Create PenReminderResponse from Firestore document
  factory PenReminderResponse.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PenReminderResponse(
      id: doc.id,
      date: (data['date'] as Timestamp).toDate(),
      penCarried: data['pen_carried'] ?? false,
      respondedAt: (data['responded_at'] as Timestamp).toDate(),
      createdAt: (data['created_at'] as Timestamp).toDate(),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'date': Timestamp.fromDate(date),
      'pen_carried': penCarried,
      'responded_at': Timestamp.fromDate(respondedAt),
      'created_at': Timestamp.fromDate(createdAt),
    };
  }

  /// Create a copy with updated fields
  PenReminderResponse copyWith({
    String? id,
    DateTime? date,
    bool? penCarried,
    DateTime? respondedAt,
    DateTime? createdAt,
  }) {
    return PenReminderResponse(
      id: id ?? this.id,
      date: date ?? this.date,
      penCarried: penCarried ?? this.penCarried,
      respondedAt: respondedAt ?? this.respondedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Generate unique ID for date-based reminder response
  static String generateId(DateTime date) {
    final dateString =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return 'pen_reminder_$dateString';
  }

  /// Create new reminder response for today
  static PenReminderResponse createForToday({required bool penCarried}) {
    final today = DateTime.now();
    final dateOnly = DateTime(today.year, today.month, today.day);

    return PenReminderResponse(
      id: generateId(dateOnly),
      date: dateOnly,
      penCarried: penCarried,
      respondedAt: DateTime.now(),
      createdAt: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'PenReminderResponse(id: $id, date: $date, penCarried: $penCarried, respondedAt: $respondedAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PenReminderResponse &&
        other.id == id &&
        other.date == date &&
        other.penCarried == penCarried;
  }

  @override
  int get hashCode {
    return id.hashCode ^ date.hashCode ^ penCarried.hashCode;
  }
}
