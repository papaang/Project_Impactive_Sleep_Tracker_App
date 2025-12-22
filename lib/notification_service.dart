import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init(Function(NotificationResponse) onForegroundResponse) async {
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
}