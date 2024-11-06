// main.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:panic_button/screens/home_screen.dart';
import 'package:panic_button/screens/login_screen.dart';
import 'package:panic_button/service/auth_service.dart';
import 'package:panic_button/service/firebase_messaging_service.dart';
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
      final messagingService = FirebaseMessagingService();
      await messagingService.initialize();
      await messagingService.subscribeToTopic('panic_alerts');
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
  static const Duration _timeoutDuration = Duration(seconds: 10);

  // Tambahkan konstanta untuk routes
  static const String homeRoute = '/home';
  static const String loginRoute = '/login';

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _checkInitialPermissions();
    } else {
      _permissionsChecked = true;
    }
  }

  Future<void> _checkInitialPermissions() async {
    try {
      if (!kIsWeb && mounted) {
        if (mounted) {
          setState(() {
            _permissionsChecked = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mendapatkan izin: $e')),
        );
      }
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
        future:
            widget._authService.checkLoginStatus().timeout(_timeoutDuration),
        builder: (context, snapshot) {
          if (!kIsWeb && !_permissionsChecked) {
            return const _LoadingScreen();
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _LoadingScreen();
          }

          if (snapshot.hasError) {
            return _ErrorScreen(error: snapshot.error.toString());
          }

          return snapshot.data == true
              ? const HomeScreen()
              : const LoginScreen();
        },
      ),
      routes: {
        homeRoute: (context) => const HomeScreen(),
        loginRoute: (context) => const LoginScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

// Widgets pembantu untuk mengurangi duplikasi
class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  final String error;

  const _ErrorScreen({required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text('Error: $error'),
      ),
    );
  }
}
