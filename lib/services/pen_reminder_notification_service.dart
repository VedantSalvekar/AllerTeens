import 'dart:math';
import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

/// Service for managing pen reminder notifications
class PenReminderNotificationService {
  static const int _notificationId = 1000;
  static const String _channelId = 'pen_reminder_channel';
  static const String _channelName = 'Pen Reminders';
  static const String _channelDescription =
      'Daily reminders to carry your adrenaline pen';

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static PenReminderNotificationService? _instance;

  PenReminderNotificationService._();

  static PenReminderNotificationService get instance {
    _instance ??= PenReminderNotificationService._();
    return _instance!;
  }

  /// Initialize the notification service
  Future<void> initialize() async {
    // Initialize timezone data
    tz.initializeTimeZones();

    // Request permissions
    await _requestPermissions();

    // Initialize local notifications
    await _initializeLocalNotifications();

    // Initialize alarm manager (Android only)
    if (Platform.isAndroid) {
      await AndroidAlarmManager.initialize();
    }
  }

  /// Request necessary permissions
  Future<void> _requestPermissions() async {
    // Request notification permission
    await Permission.notification.request();

    // For Android 12+, request exact alarm permission
    if (await Permission.scheduleExactAlarm.isDenied) {
      await Permission.scheduleExactAlarm.request();
    }

    // Request system alert window permission for overlay
    if (await Permission.systemAlertWindow.isDenied) {
      await Permission.systemAlertWindow.request();
    }
  }

  /// Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for Android
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
      showBadge: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(androidChannel);
  }

  /// Handle notification tap - this will trigger the Yes/No dialog
  static void _onNotificationTapped(NotificationResponse response) {
    // This will be handled by the PenReminderController
    // The controller will show the Yes/No dialog
    print('Pen reminder notification tapped: ${response.payload}');
  }

  /// Show immediate notification for testing
  Future<void> showTestNotification() async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      styleInformation: BigTextStyleInformation(
        'Quick check-in! Did you remember to bring your adrenaline pen today?',
      ),
      ticker: 'Pen Reminder',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      subtitle: 'Daily Check-in',
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      _notificationId,
      '💉 Pen Check!',
      'Quick check-in! Did you remember to bring your adrenaline pen today?',
      details,
      payload: 'pen_reminder_test',
    );
  }

  /// Schedule daily reminder at random time between 8 AM and 6 PM
  Future<void> scheduleDailyReminder() async {
    // Cancel existing reminder
    await cancelDailyReminder();

    // Generate random time between 8 AM (8:00) and 6 PM (18:00)
    final random = Random();
    final hour = 8 + random.nextInt(10); // 8 to 17 (6 PM)
    final minute = random.nextInt(60); // 0 to 59

    print(
      'Scheduling daily pen reminder at $hour:${minute.toString().padLeft(2, '0')}',
    );

    if (Platform.isAndroid) {
      // Android: Use alarm manager for persistence across reboots
      await AndroidAlarmManager.periodic(
        const Duration(days: 1),
        _notificationId,
        _dailyReminderCallback,
        startAt: DateTime.now().copyWith(
          hour: hour,
          minute: minute,
          second: 0,
          millisecond: 0,
        ),
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true,
      );
    } else if (Platform.isIOS) {
      // iOS: Use flutter_local_notifications scheduling
      await _scheduleIOSReminder(hour, minute);
    }
  }

  /// Schedule iOS reminder using flutter_local_notifications
  Future<void> _scheduleIOSReminder(int hour, int minute) async {
    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month, now.day, hour, minute);

    // If the time has passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      styleInformation: BigTextStyleInformation(
        'Quick check-in! Did you remember to bring your adrenaline pen today?',
      ),
      ticker: 'Daily Pen Reminder',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      subtitle: 'Daily Check-in',
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Schedule the notification
    await _notifications.zonedSchedule(
      _notificationId,
      '💉 Daily Pen Check!',
      'Quick check-in! Did you remember to bring your adrenaline pen today?',
      tz.TZDateTime.from(scheduledDate, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Callback function for daily reminder (must be static for alarm manager)
  @pragma('vm:entry-point')
  static void _dailyReminderCallback() async {
    // Initialize notifications if not already done
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const settings = InitializationSettings(android: androidSettings);

    await _notifications.initialize(settings);

    // Show the notification
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      styleInformation: BigTextStyleInformation(
        'Quick check-in! Did you remember to bring your adrenaline pen today?',
      ),
      ticker: 'Daily Pen Reminder',
    );

    const details = NotificationDetails(android: androidDetails);

    await _notifications.show(
      _notificationId,
      '💉 Daily Pen Check!',
      'Quick check-in! Did you remember to bring your adrenaline pen today?',
      details,
      payload: 'pen_reminder_daily',
    );

    // Schedule next day's reminder at a different random time
    final instance = PenReminderNotificationService.instance;
    await instance.scheduleDailyReminder();
  }

  /// Cancel daily reminder
  Future<void> cancelDailyReminder() async {
    if (Platform.isAndroid) {
      await AndroidAlarmManager.cancel(_notificationId);
    }
    await _notifications.cancel(_notificationId);
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    final permission = await Permission.notification.status;
    return permission == PermissionStatus.granted;
  }

  /// Open app notification settings
  Future<void> openNotificationSettings() async {
    await Permission.notification.request();
  }

  /// Get next scheduled notification time (for debugging)
  DateTime getNextRandomReminderTime() {
    final random = Random();
    final hour = 8 + random.nextInt(10); // 8 AM to 5 PM
    final minute = random.nextInt(60);

    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return tomorrow.copyWith(
      hour: hour,
      minute: minute,
      second: 0,
      millisecond: 0,
    );
  }

  /// Clear all notifications
  Future<void> clearAllNotifications() async {
    await _notifications.cancelAll();
    if (Platform.isAndroid) {
      await AndroidAlarmManager.cancel(_notificationId);
    }
  }
}
