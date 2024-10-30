import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:panic_button/screens/home_screen.dart';
import 'package:panic_button/screens/login_screen.dart';
import 'package:panic_button/service/auth_service.dart';
import 'package:panic_button/service/permision_service.dart';
import 'package:panic_button/service/background_service.dart';
import 'package:panic_button/service/notification_service.dart';
import 'firebase_options.dart';

@pragma('vm:entry-point')
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    final notificationService = NotificationService();
    await notificationService.initialize();

    final backgroundService = BackgroundService();
    await backgroundService
        .initialize(); // Menginisialisasi layanan latar belakang

    runApp(MyApp());
  } catch (e) {
    debugPrint('Error during initialization: $e');
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Error initializing app: $e'),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatefulWidget {
  final AuthService _authService = AuthService();

  MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final PermissionService _permissionService = PermissionService();
  bool _permissionsChecked = false;

  @override
  void initState() {
    super.initState();
    _checkInitialPermissions();
  }

  Future<void> _checkInitialPermissions() async {
    await Future.delayed(Duration.zero);
    if (mounted) {
      await _permissionService.requestPermissions(context);
      setState(() {
        _permissionsChecked = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Panic Button App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: FutureBuilder<bool>(
        future: widget._authService.checkLoginStatus(),
        builder: (context, snapshot) {
          if (!_permissionsChecked) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          } else if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: Text('Error: ${snapshot.error}'),
              ),
            );
          }

          if (snapshot.data == true) {
            return const HomeScreen();
          } else {
            return const LoginScreen();
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
