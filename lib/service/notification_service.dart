import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final Map<String, String> _lastDeviceAlerts = {};
  final Map<String, DateTime> _lastNotificationTimes = {};
  static const Duration _minimumNotificationInterval = Duration(seconds: 1);
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized || kIsWeb) return;

    if (Platform.isAndroid || Platform.isIOS) {
      // Request notification permissions
      if (Platform.isAndroid) {
        await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      }

      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'panic_button_critical_channel',
        'Critical Alerts',
        description: 'Critical alerts for panic button',
        importance: Importance.max,
        enableVibration: true,
        playSound: true,
        showBadge: true,
        enableLights: true,
      );

      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      final DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
        onDidReceiveLocalNotification: (id, title, body, payload) async {
          print('Received iOS notification: $title');
        },
      );

      final InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (details) async {
          if (details.payload != null) {
            handleNotificationTap(details.payload!);
          }
        },
      );

      if (Platform.isIOS) {
        await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            );
      }

      await _ensureDeviceIdentifierExists();
      _isInitialized = true;
    }
  }

  void handleNotificationTap(String payload) {
    try {
      final Map<String, dynamic> data = json.decode(payload);
      print('Handling notification tap with data: $data');
    } catch (e) {
      print('Error handling notification tap: $e');
    }
  }

  Future<void> _ensureDeviceIdentifierExists() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('device_identifier')) {
      final identifier = DateTime.now().millisecondsSinceEpoch.toString();
      await prefs.setString('device_identifier', identifier);
    }
  }

  Future<void> showNotification(String title, String body,
      {String? payload}) async {
    if (kIsWeb) return;

    if (!_isInitialized) {
      await initialize();
    }

    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'panic_button_critical_channel',
        'Critical Alerts',
        channelDescription: 'Critical alerts for panic button',
        importance: Importance.max,
        priority: Priority.max,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        visibility: NotificationVisibility.public,
      );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        badgeNumber: 1,
        threadIdentifier: 'panic_button_thread',
        interruptionLevel: InterruptionLevel.critical,
      );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      final int notificationId =
          DateTime.now().millisecondsSinceEpoch.remainder(100000);

      await flutterLocalNotificationsPlugin.show(
        notificationId,
        title,
        body,
        platformChannelSpecifics,
        payload: payload,
      );
    } catch (e) {
      print('Error showing notification: $e');
    }
  }

  bool canShowNotification(String deviceId) {
    final now = DateTime.now();
    if (_lastNotificationTimes.containsKey(deviceId)) {
      final lastTime = _lastNotificationTimes[deviceId]!;
      return now.difference(lastTime) >= _minimumNotificationInterval;
    }
    return true;
  }

  void updateNotificationTracking(String deviceId, String alert) {
    final now = DateTime.now();
    _lastDeviceAlerts[deviceId] = alert;
    _lastNotificationTimes[deviceId] = now;
  }
}
