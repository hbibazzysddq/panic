import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    if (kIsWeb) {
      print(
          'Notification Service: Web platform detected, skipping initialization');
      return;
    }

    if (Platform.isAndroid || Platform.isIOS) {
      // Create notification channel for Android
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'panic_button_channel',
        'Panic Button Notifications',
        importance: Importance.max,
        enableVibration: true,
        playSound: true,
        showBadge: true,
        enableLights: true,
      );

      // Request permissions for iOS
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

      // Initialize notification settings
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@drawable/sanur');

      final DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestSoundPermission: true,
        requestBadgePermission: true,
        requestAlertPermission: true,
        onDidReceiveLocalNotification: (id, title, body, payload) async {
          // Handle iOS notification when app is in foreground
        },
      );

      final InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          // Handle notification tap
          print('Notification tapped: ${response.payload}');
        },
      );

      // Create the notification channel for Android
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      await _ensureDeviceIdentifierExists();

      // Initialize background service
      await initializeService();
    }
  }

  Future<void> initializeService() async {
    if (kIsWeb) return;

    if (Platform.isAndroid || Platform.isIOS) {
      final service = FlutterBackgroundService();

      await service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: onStart,
          autoStart: true,
          isForegroundMode: true,
          foregroundServiceNotificationId: 888,
          initialNotificationTitle: 'Panic Button Service',
          initialNotificationContent: 'Monitoring panic buttons',
        ),
        iosConfiguration: IosConfiguration(
          autoStart: true,
          onForeground: onStart,
          onBackground: onIosBackground,
        ),
      );

      await service.startService();
    }
  }

  Future<void> _ensureDeviceIdentifierExists() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('device_identifier')) {
      final identifier = DateTime.now().millisecondsSinceEpoch.toString();
      await prefs.setString('device_identifier', identifier);
    }
  }

  Future<String?> _getDeviceIdentifier() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('device_identifier');
  }

  Future<void> showNotification(String title, String body,
      {String? payload, int? notificationId}) async {
    if (kIsWeb) return;

    if (Platform.isAndroid || Platform.isIOS) {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'panic_button_channel',
        'Panic Button Notifications',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        icon: '@drawable/sanur',
        largeIcon: DrawableResourceAndroidBitmap('@drawable/sanur'),
      );

      final DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      await flutterLocalNotificationsPlugin.show(
        notificationId ?? 0,
        title,
        body,
        platformChannelSpecifics,
        payload: payload,
      );
    }
  }

  Future<void> cancelAllNotifications() async {
    if (kIsWeb) return;
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  Future<void> cancelNotification(int id) async {
    if (kIsWeb) return;
    await flutterLocalNotificationsPlugin.cancel(id);
  }

  Future<void> fetchDataAndNotify() async {
    if (kIsWeb) return;

    final deviceId = await _getDeviceIdentifier();
    final url =
        Uri.parse('http://202.157.187.108:3000/data?device_id=$deviceId');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['alert'] == true) {
          await showNotification(
            'Panic Button Alert',
            'A panic button has been activated!',
            notificationId: DateTime.now().millisecond,
          );
        }
      }
    } catch (e) {
      print('Error fetching data: $e');
    }
  }
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final notificationService = NotificationService();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // Periodic task every 1 minute
  Timer.periodic(const Duration(minutes: 1), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        // Update foreground notification
        service.setForegroundNotificationInfo(
          title: "Panic Button Service Active",
          content: "Last check: ${DateTime.now().toString()}",
        );
      }
    }

    try {
      await notificationService.fetchDataAndNotify();
      // Send data to UI if needed
      service.invoke(
        'update',
        {
          "current_date": DateTime.now().toIso8601String(),
          "last_check": DateTime.now().toString(),
        },
      );
    } catch (e) {
      print('Background task error: $e');
    }
  });
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  return true;
}
