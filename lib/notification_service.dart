import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

// --- BACKGROUND HANDLER (Top-Level) ---
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) async {
  // We mostly handle actions in the foreground now for reliability.
  WidgetsFlutterBinding.ensureInitialized();
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();
  static const int sleepDiaryReminderId = 889; // Unique ID for sleep diary reminder notifications

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init(Function(NotificationResponse) onForegroundResponse) async {
     tz.initializeTimeZones(); // Initialize timezone data for scheduling daily reminder notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    // 1. Define the channel globally so it exists before we try to schedule anything
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'sleep_diary_reminder', // id
      'Sleep Diary Reminder', // title
      description: 'Daily reminder to complete sleep diary', // description
      importance: Importance.high,
    );

    // 2. Create the channel on the device
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: onForegroundResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      await androidImplementation?.requestNotificationsPermission();
    }
  }

  Future<void> showPersistentControls({required bool isSleeping}) async {
    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'sleep_tracker_controls',
      'Quick Controls',
      channelDescription: 'Persistent notification for quick actions',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
      actions: <AndroidNotificationAction>[
        // 1. Add Meds
        const AndroidNotificationAction(
          'add_meds', 
          '💊 Meds',
          showsUserInterface: true, 
        ),
        // 2. Add Caffeine
        const AndroidNotificationAction(
          'add_caffeine', 
          '☕ Caffeine',
          showsUserInterface: true, 
        ),
        // 3. Add Exercise
        const AndroidNotificationAction(
          'add_exercise', 
          '🏋️ Exercise',
          showsUserInterface: true, 
        ),
        
        // 4. Toggle Sleep
        isSleeping 
            ? const AndroidNotificationAction(
                'wake_up', 
                '☀️ Wake', 
                showsUserInterface: true 
              ) 
            : const AndroidNotificationAction(
                'sleep', 
                '🌙 Sleep', 
                showsUserInterface: true 
              ),
      ],
    );

    final NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      888,
      isSleeping ? 'Sleep Mode Active' : 'Sleep Tracker',
      isSleeping ? 'Tap "Wake" to end session' : 'Quick Actions Available',
      platformChannelSpecifics,
    );
  }

  Future<void> cancelAll() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  Future<void> scheduleDailySleepDiaryReminder({
  required int hour,
  required int minute,
}) async {
  final now = tz.TZDateTime.now(tz.local);

  tz.TZDateTime scheduledTime = tz.TZDateTime(
    tz.local,
    now.year,
    now.month,
    now.day,
    hour,
    minute,
  );

  // If the time has already passed today, schedule for tomorrow
  if (scheduledTime.isBefore(now)) {
    scheduledTime = scheduledTime.add(const Duration(days: 1));
  }

  const AndroidNotificationDetails androidDetails =
      AndroidNotificationDetails(
    'sleep_diary_reminder',
    'Sleep Diary Reminder',
    channelDescription: 'Daily reminder to complete sleep diary',
    importance: Importance.high,
    priority: Priority.high,
  );

  const NotificationDetails notificationDetails =
      NotificationDetails(android: androidDetails);

  await flutterLocalNotificationsPlugin.zonedSchedule(
    sleepDiaryReminderId,
    'Sleep diary reminder',
    'Please remember to complete your sleep diary.',
    scheduledTime,
    notificationDetails,
    // REMOVED: androidAllowWhileIdle: true, 
    // ADDED: The new required parameter below
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, 
    matchDateTimeComponents: DateTimeComponents.time,
    uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
  );
} 
Future<void> cancelSleepDiaryReminder() async { // New method to cancel sleep diary reminder when not required
  await flutterLocalNotificationsPlugin.cancel(sleepDiaryReminderId);
}
// --- SANITY CHECK METHOD ---
  Future<void> instantSanityCheck() async {
    // 1. Get the current time according to the plugin
    final now = tz.TZDateTime.now(tz.local);
    
    // 2. Add exactly 10 seconds
    final scheduledTime = now.add(const Duration(seconds: 10));

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'sleep_diary_reminder',
      'Sleep Diary Reminder',
      channelDescription: 'Sanity check test',
      importance: Importance.high,
      priority: Priority.high,
    );

    const NotificationDetails notificationDetails = NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      999, // Unique ID for test
      'Sanity Check',
      'If you see this, the alarm system works!',
      scheduledTime,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}