import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'notification_service.dart';

// Main entry point untuk background service
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  print('Background service starting...');

  // Initialize notification service
  final notificationService = NotificationService();
  await notificationService.initialize();

  if (service is AndroidServiceInstance) {
    await _setupForegroundService(service);
  }

  // Periodic task
  Timer.periodic(const Duration(seconds: 5), (timer) async {
    await _performPeriodicTask(service, notificationService);
  });
}

Future<void> _setupForegroundService(AndroidServiceInstance service) async {
  try {
    await service.setForegroundNotificationInfo(
      title: 'Panic Button Active',
      content: 'Service is running...',
    );
    await service.setAsForegroundService();
    print('Service set as foreground');
  } catch (e) {
    print('Error setting foreground service: $e');
  }
}

Future<void> _performPeriodicTask(
    ServiceInstance service, NotificationService notificationService) async {
  if (service is AndroidServiceInstance) {
    if (await service.isForegroundService()) {
      await service.setForegroundNotificationInfo(
        title: 'Panic Button Active',
        content: 'Last check: ${DateTime.now()}',
      );
    }
  }

  try {
    final url = Uri.parse('http://202.157.187.108:3000/data');
    final response = await http.get(
      url,
      headers: {'Content-Type': 'application/json'},
    ).timeout(const Duration(seconds: 5));

    print('API Response status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final decodedData = json.decode(response.body);
      final devices = _processResponseData(decodedData);

      for (var device in devices) {
        if (device is Map<String, dynamic>) {
          await _checkDeviceAlert(device, notificationService);
        }
      }
    } else {
      print('Error: Received status code ${response.statusCode}');
    }
  } catch (e) {
    print('Error in background task: $e');
  }

  service.invoke(
    'update',
    {
      'current_date': DateTime.now().toIso8601String(),
      'is_running': true,
    },
  );
}

Future<void> _checkDeviceAlert(Map<String, dynamic> device,
    NotificationService notificationService) async {
  final deviceId = device['end_device_ids']?['device_id'];
  final alertValue =
      device['uplink_message']?['decoded_payload']?['device_alert'];

  if (deviceId != null && alertValue == true) {
    await notificationService.showNotification(
      'PANIC BUTTON ALERT!',
      'Emergency alert from device $deviceId!',
      payload: json.encode({
        'deviceId': deviceId,
        'alert': alertValue,
        'timestamp': DateTime.now().toIso8601String(),
      }),
    );
  }
}

List<dynamic> _processResponseData(dynamic decodedData) {
  if (decodedData is Map<String, dynamic>) {
    return decodedData['data'] is List
        ? decodedData['data']
        : [decodedData['data']];
  } else if (decodedData is List) {
    return decodedData;
  }
  return [];
}

class BackgroundService {
  static final BackgroundService _instance = BackgroundService._internal();
  factory BackgroundService() => _instance;
  BackgroundService._internal();

  Future<void> initialize() async {
    final service = FlutterBackgroundService();

    await service.configure(
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        foregroundServiceNotificationId: 888,
        initialNotificationTitle: 'Panic Button Service',
        initialNotificationContent: 'Initializing...',
        autoStartOnBoot: true,
      ),
    );

    print('Background service configured');

    if (!await service.isRunning()) {
      print('Starting background service');
      await service.startService();
    }
  }

  Future<void> stop() async {
    final service = FlutterBackgroundService();
    service.invoke('stopService');
  }
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}
