import 'package:panic_button/screens/home_screen.dart';
import 'package:panic_button/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

/*************  ✨ Codeium Command ⭐  *************/
/// Initializes the app.
///
/// Ensures that the Flutter binding is initialized, then initializes
/// Firebase using the current platform's configuration. Finally, runs
/// the app using the [MyApp] widget as the root widget.
/******  ee61dd5e-ecbd-4e93-9423-0bb81b7d3cc9  *******/
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Location Flutter',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const LoginPage(),
      routes: {
        '/home': (context) => const HomeScreen(), // Definisikan rute "/home"
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
