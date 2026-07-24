import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'login_portal_page.dart';

Future<void> main() async {
  // Load the root .env file before the first screen opens.
  // This makes dotenv.env['API_BASE_URL'] available anywhere in the app.
  await dotenv.load(fileName: '.env');

  // Start the Flutter application after the environment configuration is ready.
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // MaterialApp holds the app-level setup: title, theme, debug banner,
    // and the first page shown to the user.
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
