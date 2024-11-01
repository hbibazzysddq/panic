// main.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:panic_button/screens/home_screen.dart';
import 'package:panic_button/screens/login_screen.dart';
import 'package:panic_button/service/auth_service.dart';
import 'package:panic_button/service/background_service.dart';
import 'package:panic_button/service/notification_service.dart';
import 'package:panic_button/service/permision_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize mobile-specific services
    if (!kIsWeb) {
      final notificationService = NotificationService();
      await notificationService.initialize();

      final backgroundService = BackgroundService();
      await backgroundService.initialize();
    }

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
    if (!kIsWeb) {
      _checkInitialPermissions();
    } else {
      _permissionsChecked = true; // Skip permissions for web
    }
  }

  Future<void> _checkInitialPermissions() async {
    if (!kIsWeb && mounted) {
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
          // Only show loading for permissions on mobile
          if (!kIsWeb && !_permissionsChecked) {
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
