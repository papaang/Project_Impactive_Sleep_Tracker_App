import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  // Handle background actions if needed
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const int sleepDiaryReminderId = 889;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init(Function(NotificationResponse) onForegroundResponse) async {
    tz.initializeTimeZones();
    
    // 1. Get Real Timezone
    try {
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      debugPrint("Timezone error: $e");
      try { tz.setLocalLocation(tz.getLocation('Europe/Berlin')); } catch (_) {}
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: onForegroundResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // 2. Create Channels (V2 to force reset)
    const AndroidNotificationChannel reminderChannel = AndroidNotificationChannel(
      'sleep_diary_reminder_v2', // NEW ID
      'Daily Sleep Reminder',
      description: 'Daily reminder to complete sleep diary',
      importance: Importance.high,
      playSound: true,
    );
    
    const AndroidNotificationChannel trackingChannel = AndroidNotificationChannel(
      'sleep_tracker_controls',
      'Quick Controls',
      description: 'Persistent notification for quick actions',
      importance: Importance.low, 
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(reminderChannel);

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(trackingChannel);

    if (Platform.isAndroid) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
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
        const AndroidNotificationAction('add_meds', '💊 Meds', showsUserInterface: true),
        const AndroidNotificationAction('add_caffeine', '☕ Caffeine', showsUserInterface: true),
        const AndroidNotificationAction('add_exercise', '🏋️ Exercise', showsUserInterface: true),
        isSleeping 
            ? const AndroidNotificationAction('wake_up', '☀️ Wake', showsUserInterface: true) 
            : const AndroidNotificationAction('sleep', '🌙 Sleep', showsUserInterface: true),
      ],
    );

    await flutterLocalNotificationsPlugin.show(
      888,
      isSleeping ? 'Sleep Mode Active' : 'Sleep Tracker',
      isSleeping ? 'Tap "Wake" to end session' : 'Quick Actions Available',
      NotificationDetails(android: androidPlatformChannelSpecifics),
    );
  }

  Future<void> scheduleDailySleepDiaryReminder({required int hour, required int minute}) async {
    // Re-verify timezone
    try {
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (_) {}

    final now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledTime = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    debugPrint("🕒 Scheduling V2 Alarm for: $scheduledTime");

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'sleep_diary_reminder_v2', // Must match channel ID above
      'Daily Sleep Reminder',
      channelDescription: 'Daily reminder to complete sleep diary',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
    );

    await flutterLocalNotificationsPlugin.zonedSchedule(
      sleepDiaryReminderId,
      'Sleep diary reminder',
      'Please remember to complete your sleep diary.',
      scheduledTime,
      const NotificationDetails(android: androidDetails),
      // Inexact Mode to bypass Android 14 restrictions
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelSleepDiaryReminder() async {
    await flutterLocalNotificationsPlugin.cancel(sleepDiaryReminderId);
  }

  Future<void> cancelAll() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }
}