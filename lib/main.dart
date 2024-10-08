import 'package:flutter/material.dart';
import 'package:sanurbali/page/map_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Location Flutter',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MapPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
