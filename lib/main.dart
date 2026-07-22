import 'package:flutter/material.dart';

import 'login_portal_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'OrderX Login',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF073A75)),
        fontFamily: 'Arial',
        scaffoldBackgroundColor: const Color(0xFF9AA1AE),
        useMaterial3: true,
      ),
      home: const LoginPortalPage(),
    );
  }
}
