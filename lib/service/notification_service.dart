import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@drawable/sanur');
    final InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    await _ensureDeviceIdentifierExists();

    Workmanager().initialize(callbackDispatcher);
    Workmanager().registerPeriodicTask(
      "fetch-data-task",
      "fetchDataTask",
      frequency: Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
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

  Future<void> showNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'panic_button_channel',
      'Panic Button Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      platformChannelSpecifics,
    );
  }

  Future<void> fetchDataAndNotify() async {
    final deviceId = await _getDeviceIdentifier();
    final url =
        Uri.parse('http://202.157.187.108:3000/data?device_id=$deviceId');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Proses data dan tampilkan notifikasi jika diperlukan
        if (data['alert'] == true) {
          await showNotification(
            'Panic Button Alert',
            'A panic button has been activated!',
          );
        }
      }
    } catch (e) {
      print('Error fetching data: $e');
    }
  }
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final notificationService = NotificationService();
    await notificationService.fetchDataAndNotify();
    return Future.value(true);
  });
}
