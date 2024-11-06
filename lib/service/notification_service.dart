import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final Map<String, String> _lastDeviceAlerts = {};
  final Map<String, DateTime> _lastNotificationTimes = {};
  static const Duration _minimumNotificationInterval = Duration(seconds: 5);
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized || kIsWeb) return;

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
          AndroidInitializationSettings('@drawable/sanur');

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
          print('Notification tapped: ${details.payload}');
          if (details.payload != null) {
            handleNotificationTap(details.payload!);
          }
        },
      );

      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

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
      _isInitialized = true;
    }
  }

  void handleNotificationTap(String payload) {
    try {
      final Map<String, dynamic> data = json.decode(payload);
      print('Handling notification tap with data: $data');
      // Implementasi penanganan tap sesuai kebutuhan
    } catch (e) {
      print('Error handling notification tap: $e');
    }
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

  Future<void> fetchAndCheckData() async {
    if (kIsWeb) return;

    final url = Uri.parse('http://202.157.187.108:3000/data');
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final dynamic decodedData = json.decode(response.body);
        List<dynamic> devices = [];

        if (decodedData is Map<String, dynamic>) {
          if (decodedData.containsKey('data')) {
            final dynamic data = decodedData['data'];
            devices = data is List ? data : [data];
          } else {
            devices = [decodedData];
          }
        } else if (decodedData is List) {
          devices = decodedData;
        }

        if (devices.isNotEmpty) {
          print('Processing ${devices.length} devices');
          await _processDevicesData(devices);
        } else {
          print('No devices to process');
        }
      } else {
        print('Server returned status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching data: $e');
    }
  }

  Future<void> _processDevicesData(List<dynamic> devices) async {
    for (var device in devices) {
      try {
        if (device is Map<String, dynamic>) {
          await _processDeviceAlert(device);
        } else {
          print('Invalid device data format: $device');
        }
      } catch (e) {
        print('Error processing device: $e');
      }
    }
  }

  Future<void> _processDeviceAlert(Map<String, dynamic> device) async {
    try {
      final endDeviceIds = device['end_device_ids'];
      if (endDeviceIds == null || endDeviceIds is! Map<String, dynamic>) {
        print('Invalid end_device_ids format');
        return;
      }

      final String? deviceId = endDeviceIds['device_id'];
      if (deviceId == null) {
        print('Device ID is null');
        return;
      }

      final deviceNumber = deviceId.split('-').last;
      final String? receivedAt = device['received_at'];
      if (receivedAt == null) {
        print('Missing received_at timestamp');
        return;
      }

      final receivedTime = DateTime.parse(receivedAt);
      final now = DateTime.now();

      // Throttle check
      if (_lastNotificationTimes.containsKey(deviceId)) {
        final lastNotificationTime = _lastNotificationTimes[deviceId]!;
        if (now.difference(lastNotificationTime) <
            _minimumNotificationInterval) {
          print('Throttling notification for device $deviceId');
          return;
        }
      }

      // Skip old data
      if (now.difference(receivedTime).inMinutes > 5) {
        print('Skipping old data for device $deviceId');
        return;
      }

      final uplinkMessage = device['uplink_message'];
      if (uplinkMessage == null || uplinkMessage is! Map<String, dynamic>) {
        print('Invalid uplink_message');
        return;
      }

      final decodedPayload = uplinkMessage['decoded_payload'];
      if (decodedPayload == null || decodedPayload is! Map<String, dynamic>) {
        print('Invalid decoded_payload');
        return;
      }

      final alertValue = decodedPayload['device_alert'];
      if (alertValue == null) {
        print('Missing device_alert');
        return;
      }

      // Generate unique alert identifier with more precise timing
      final currentAlert =
          '$deviceId:$alertValue:${now.microsecondsSinceEpoch}';

      // Duplicate check
      if (_lastDeviceAlerts[deviceId] != currentAlert) {
        String coordinates = '';
        final rxMetadata = uplinkMessage['rx_metadata'];
        if (rxMetadata is List && rxMetadata.isNotEmpty) {
          final firstMetadata = rxMetadata[0];
          if (firstMetadata is Map<String, dynamic>) {
            final double? latitude = firstMetadata['location']?['latitude'];
            final double? longitude = firstMetadata['location']?['longitude'];
            if (latitude != null && longitude != null) {
              coordinates = 'at $latitude, $longitude';
            }
          }
        }

        Future<DateTime?> _getLastDataTime(String deviceId) async {
          final prefs = await SharedPreferences.getInstance();
          final lastTimeStr = prefs.getString('last_data_time_$deviceId');
          return lastTimeStr != null ? DateTime.parse(lastTimeStr) : null;
        }

        // Show notification
        Future<void> showNotification(String title, String body,
            {required int notificationId, String? payload}) async {
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

          const NotificationDetails platformChannelSpecifics =
              NotificationDetails(android: androidPlatformChannelSpecifics);

          try {
            await flutterLocalNotificationsPlugin.show(
              notificationId, // Menggunakan ID yang diberikan
              title,
              body,
              platformChannelSpecifics,
              payload: payload,
            );
            print('Notification shown successfully with ID: $notificationId');
          } catch (e) {
            print('Error showing notification: $e');
          }
        }

        // Update tracking data
        _lastDeviceAlerts[deviceId] = currentAlert;
        _lastNotificationTimes[deviceId] = now;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_alert_$deviceId', currentAlert);
        await prefs.setString(
            'last_notification_time_$deviceId', now.toIso8601String());
      } else {
        print('Duplicate alert detected for device $deviceId');
      }
    } catch (e, stackTrace) {
      print('Error processing device alert: $e');
      print('Stack trace: $stackTrace');
    }
  }

  Future<void> cleanOldData() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    final keys = prefs.getKeys();
    for (String key in keys) {
      if (key.startsWith('last_alert_') ||
          key.startsWith('last_notification_time_')) {
        try {
          final String? value = prefs.getString(key);
          if (value != null) {
            DateTime timestamp;
            if (key.startsWith('last_alert_')) {
              final parts = value.split(':');
              if (parts.length >= 3) {
                timestamp =
                    DateTime.fromMicrosecondsSinceEpoch(int.parse(parts[2]));
              } else {
                continue;
              }
            } else {
              timestamp = DateTime.parse(value);
            }

            if (now.difference(timestamp).inHours > 24) {
              await prefs.remove(key);
              if (key.startsWith('last_alert_')) {
                final deviceId = key.replaceFirst('last_alert_', '');
                _lastDeviceAlerts.remove(deviceId);
                _lastNotificationTimes.remove(deviceId);
              }
            }
          }
        } catch (e) {
          print('Error cleaning old data for key $key: $e');
        }
      }
    }
  }

  Future<void> clearAllNotificationData() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().toList();

    for (final key in keys) {
      if (key.startsWith('last_alert_') ||
          key.startsWith('last_notification_time_')) {
        await prefs.remove(key);
      }
    }
    _lastDeviceAlerts.clear();
    _lastNotificationTimes.clear();
    print('All notification data cleared');
  }

  Future<void> initializeWithPeriodicCheck() async {
    await initialize();
    await clearAllNotificationData();

    Timer.periodic(const Duration(seconds: 1), (timer) async {
      await fetchAndCheckData();
    });

    Timer.periodic(const Duration(minutes: 30), (timer) async {
      await cleanOldData();
    });
  }

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
    timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (service is AndroidServiceInstance) {
        if (await service.isForegroundService()) {
          await service.setForegroundNotificationInfo(
            title: 'Panic Button Service Active',
            content: 'Monitoring: ${DateTime.now().toString()}',
          );
        }
      }

      try {
        await notificationService.fetchAndCheckData();
        service.invoke(
          'update',
          {
            "current_date": DateTime.now().toIso8601String(),
            "is_running": true,
          },
        );
      } catch (e) {
        print('Background task error: $e');
      }
    });
  }

  startTimer();

  service.on('stopService').listen((event) async {
    print('Stopping service...');
    timer?.cancel();
    await service.stopSelf();
  });

  service.on('restart').listen((event) {
    print('Restarting service...');
    startTimer();
  });

  service.on('error').listen((event) {
    print('Service error: $event');
  });
}

// Entry point untuk background service iOS
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}
