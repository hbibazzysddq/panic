import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    if (kIsWeb) return;

    if (Platform.isAndroid || Platform.isIOS) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'panic_button_channel',
        'Panic Button Notifications',
        description: 'Notifications for Panic Button alerts',
        importance: Importance.max,
        enableVibration: true,
        playSound: true,
        showBadge: true,
        enableLights: true,
      );

      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      final DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
        onDidReceiveLocalNotification: (id, title, body, payload) async {
          // Handle iOS foreground notifications
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
          print('Notification tapped: ${details.payload}');
          // Tambahkan handling ketika notifikasi di tap
          if (details.payload != null) {
            // Handle payload jika ada
            handleNotificationTap(details.payload!);
          }
        },
      );

      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // Request permissions untuk iOS
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
      await _initializeService();
    }
  }

  void handleNotificationTap(String payload) {
    // Implementasi handling ketika notifikasi di tap
    print('Handling notification tap with payload: $payload');
  }

  Future<void> _initializeService() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        foregroundServiceNotificationId: 888,
        initialNotificationTitle: 'Panic Button Service Active',
        initialNotificationContent: 'Monitoring panic buttons',
        autoStartOnBoot: true,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );

    if (await service.isRunning()) {
      print("Service is already running");
    } else {
      print("Starting service...");
      await service.startService();
    }
  }

  Future<void> _ensureDeviceIdentifierExists() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('device_identifier')) {
      final identifier = DateTime.now().millisecondsSinceEpoch.toString();
      await prefs.setString('device_identifier', identifier);
      print('New device identifier created: $identifier');
    }
  }

  Future<void> showNotification(String title, String body,
      {String? payload}) async {
    if (kIsWeb) return;

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'panic_button_channel',
      'Panic Button Notifications',
      channelDescription: 'Notifications for Panic Button alerts',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      styleInformation: BigTextStyleInformation(''),
      fullScreenIntent: true,
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      badgeNumber: 1,
      threadIdentifier: 'panic_button_thread',
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    try {
      await flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecond,
        title,
        body,
        platformChannelSpecifics,
        payload: payload,
      );
      print('Notification shown successfully');
    } catch (e) {
      print('Error showing notification: $e');
    }
  }

  Future<void> fetchDataAndNotify() async {
    if (kIsWeb) return;

    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString('device_identifier');
    final url =
        Uri.parse('http://202.157.187.108:3000/data?device_id=$deviceId');

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          // Tambahkan headers lain jika diperlukan
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Received data: $data'); // Untuk debugging

        // Simpan data terakhir untuk perbandingan
        String? lastAlert = prefs.getString('last_alert');
        String currentAlert = json.encode(data);

        if (data['alert'] == true && lastAlert != currentAlert) {
          await showNotification(
            'Panic Button Alert',
            'A panic button has been activated!',
            payload: currentAlert,
          );
          // Update last alert
          await prefs.setString('last_alert', currentAlert);
        }
      } else {
        print('Server returned status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching data: $e');
    }
  }

  // Method untuk membersihkan resources
  Future<void> dispose() async {
    final service = FlutterBackgroundService();
    service.invoke('stopService');
  }
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final notificationService = NotificationService();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) async {
      await service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) async {
      await service.setAsBackgroundService();
    });
  }

  Timer? timer;

  void startTimer() {
    timer?.cancel();

    timer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      if (service is AndroidServiceInstance) {
        if (await service.isForegroundService()) {
          await service.setForegroundNotificationInfo(
            title: 'Panic Button Service Active',
            content: 'Last check: ${DateTime.now().toString()}',
          );
        }
      }

      try {
        await notificationService.fetchDataAndNotify();
        service.invoke(
          'update',
          {
            "current_date": DateTime.now().toIso8601String(),
            "is_running": true,
            "last_check": DateTime.now().toString(),
          },
        );
      } catch (e) {
        print('Background task error: $e');
      }
    });
  }

  startTimer();

  // Handle service stop
  service.on('stopService').listen((event) async {
    print('Stopping service...');
    timer?.cancel();
    await service.stopSelf();
  });

  // Handle service restart
  service.on('restart').listen((event) {
    print('Restarting service...');
    startTimer();
  });

  // Handle error reporting
  service.on('error').listen((event) {
    print('Service error: $event');
  });
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}
