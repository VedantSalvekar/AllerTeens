import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

/// Service for managing pen reminder notifications
@pragma('vm:entry-point')
class PenReminderNotificationService {
  static const int _notificationId = 1000;
  static const String _channelId = 'pen_reminder_channel';
  static const String _channelName = 'Pen Reminders';
  static const String _channelDescription =
      'Daily reminders to carry your adrenaline pen';

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static PenReminderNotificationService? _instance;

  // Navigation callback for when notification is tapped
  static Function(BuildContext)? _onNotificationTapCallback;

  // Store pending notification tap for when app launches
  static bool _pendingNotificationTap = false;
  static String? _pendingNotificationPayload;

  PenReminderNotificationService._();

  static PenReminderNotificationService get instance {
    _instance ??= PenReminderNotificationService._();
    return _instance!;
  }

  /// Initialize the notification service
  Future<void> initialize({GlobalKey<NavigatorState>? navigatorKey}) async {
    // Store navigator key for accessing context (only if provided)
    if (navigatorKey != null) {
      _navigatorKey = navigatorKey;
      print('Notification service initialized with navigator key: true');
    } else {
      print(
        'Notification service: No navigator key provided, keeping existing: ${_navigatorKey != null}',
      );
    }

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
      requestCriticalPermission: false,
      requestProvisionalPermission: false,
      onDidReceiveLocalNotification: _onDidReceiveLocalNotificationIOS,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    print('[SERVICE] Local notifications initialized');

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

  /// Set the callback for when notification is tapped
  static void setNotificationTapCallback(Function(BuildContext) callback) {
    _onNotificationTapCallback = callback;
  }

  /// Handle notification tap - this will trigger the Yes/No dialog
  static void _onNotificationTapped(NotificationResponse response) {
    print('Pen reminder notification tapped: ${response.payload}');
    print('Callback set: ${_onNotificationTapCallback != null}');
    print('Navigator key: ${_navigatorKey != null}');
    print('Current context: ${_navigatorKey?.currentContext != null}');

    // Store that a notification was tapped
    _pendingNotificationTap = true;
    _pendingNotificationPayload = response.payload;

    // If we have a context available, show dialog immediately
    if (_onNotificationTapCallback != null &&
        _navigatorKey?.currentContext != null) {
      final context = _navigatorKey!.currentContext!;
      print('App is open - showing dialog immediately');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showPenReminderDialog(context);
      });
    } else {
      print('App was closed - dialog will show when app opens');
      // Dialog will be shown when app fully loads and checkPendingNotification is called
    }
  }

  /// Check if there's a pending notification tap and show dialog
  static void checkPendingNotificationTap(BuildContext context) {
    if (_pendingNotificationTap) {
      print('Found pending notification tap - showing dialog');
      _pendingNotificationTap = false;
      _pendingNotificationPayload = null;
      _showPenReminderDialog(context);
    }
  }

  /// Show the pen reminder dialog
  static void _showPenReminderDialog(BuildContext context) {
    if (_onNotificationTapCallback != null) {
      _onNotificationTapCallback!(context);
    }
  }

  /// Handle iOS local notification when app is in foreground
  static void _onDidReceiveLocalNotificationIOS(
    int id,
    String? title,
    String? body,
    String? payload,
  ) {
    print('[iOS] Received local notification: $title');
    // For iOS, show dialog immediately if app is in foreground
    if (_onNotificationTapCallback != null &&
        _navigatorKey?.currentContext != null) {
      final context = _navigatorKey!.currentContext!;
      _showPenReminderDialog(context);
    }
  }

  // Navigator key to access current context
  static GlobalKey<NavigatorState>? _navigatorKey;

  /// Show immediate notification for testing
  Future<void> showTestNotification() async {
    print('[SERVICE] Attempting to show test notification...');

    // iOS DEMO FIX: Show dialog directly since iOS doesn't show notifications when app is in foreground
    if (Platform.isIOS) {
      print('[iOS] App in foreground - showing dialog directly for demo');
      await Future.delayed(
        const Duration(milliseconds: 500),
      ); // Small delay for better UX

      if (_onNotificationTapCallback != null &&
          _navigatorKey?.currentContext != null) {
        final context = _navigatorKey!.currentContext!;
        _onNotificationTapCallback!(context);
        print('[iOS] Dialog shown directly for demo');
        return;
      } else {
        print('[iOS] No context available for dialog');
        return;
      }
    }

    // Android: Show actual notification
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

    const details = NotificationDetails(
      android: androidDetails,
      iOS: null, // Not used for iOS in demo
    );

    try {
      await _notifications.show(
        _notificationId,
        '💉 Pen Check!',
        'Quick check-in! Did you remember to bring your adrenaline pen today?',
        details,
        payload: 'pen_reminder_test',
      );
      print('[Android] Test notification sent successfully');
    } catch (e) {
      print('[SERVICE] Error showing notification: $e');
    }
  }

  /// Request notification permissions (especially important for iOS)
  Future<bool> _requestNotificationPermissions() async {
    if (Platform.isIOS) {
      final bool? result = await _notifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
            critical: false,
            provisional: false,
          );
      print('[iOS] Notification permissions result: $result');
      return result ?? false;
    }
    return true; // Android permissions handled elsewhere
  }

  /// Schedule daily reminder at random time between 8 AM and 6 PM
  Future<void> scheduleDailyReminderRandom() async {
    // Cancel existing reminder
    await cancelDailyReminder();

    // Generate random time between 8 AM (8:00) and 6 PM (18:00)
    final random = Random();
    final hour = 8 + random.nextInt(10); // 8 to 17 (6 PM)
    final minute = random.nextInt(60); // 0 to 59

    print(
      'Scheduling daily pen reminder at RANDOM time: $hour:${minute.toString().padLeft(2, '0')}',
    );

    await _scheduleReminder(hour, minute);
  }

  /// Schedule daily reminder at fixed time for testing
  Future<void> scheduleDailyReminderFixed({
    int hour = 10,
    int minute = 0,
  }) async {
    print(
      '🔔 [SERVICE] Starting to schedule notification for $hour:${minute.toString().padLeft(2, '0')}',
    );

    // Cancel existing reminder first
    await cancelDailyReminder();

    print(
      'Scheduling daily pen reminder at FIXED time: $hour:${minute.toString().padLeft(2, '0')}',
    );

    await _scheduleReminder(hour, minute);
  }

  /// Internal method to schedule reminder at specific time
  Future<void> _scheduleReminder(int hour, int minute) async {
    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month, now.day, hour, minute);

    // If time has passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
      print('⏰ Time has passed today, scheduling for tomorrow: $scheduledDate');
    } else {
      print('⏰ Scheduling for today: $scheduledDate');
    }

    print('⏰ Current time: $now');
    print('⏰ Scheduled time: $scheduledDate');
    print('⏰ Time difference: ${scheduledDate.difference(now)}');

    // Use flutter_local_notifications for more reliable scheduling
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
      payload: 'pen_reminder_scheduled',
    );

    print('Notification scheduled with flutter_local_notifications');
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

    // Do not reschedule here when using periodic alarms (Android handles repeat)
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
