import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:panic_button/screens/home_screen.dart';
import 'package:panic_button/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:panic_button/service/auth_service.dart';
import 'package:panic_button/service/notification_service.dart';
import 'firebase_options.dart';

void main() async {
  // Pastikan binding diinisialisasi
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Inisialisasi Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Inisialisasi dan mulai notification service
    final notificationService = NotificationService();
    await notificationService
        .initializeWithPeriodicCheck(); // Menggunakan initializeWithPeriodicCheck alih-alih initialize

    runApp(MyApp());
  } catch (e) {
    print('Error during initialization: $e');
    // Tambahkan handling error sesuai kebutuhan
  }
}

class MyApp extends StatelessWidget {
  final AuthService _authService = AuthService();

  MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Panic Button App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: FutureBuilder<bool>(
        future: _authService.checkLoginStatus(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // Tampilkan loading screen yang lebih baik
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          } else if (snapshot.hasError) {
            // Handle error state
            return Scaffold(
              body: Center(
                child: Text('Error: ${snapshot.error}'),
              ),
            );
          } else {
            // Navigate berdasarkan status login
            if (snapshot.data == true) {
              return const HomeScreen();
            } else {
              return const LoginScreen();
            }
          }
        },
      ),
      routes: {
        '/home': (context) => const HomeScreen(),
        '/login': (context) => const LoginScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

// Platform channels setup untuk Android
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  // Handle notification tap when app is in background
  print('Notification tapped in background: ${notificationResponse.payload}');
}
