import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'login_portal_page.dart';

// Application entry point.
//
// The app depends on values stored in the root `.env` file, especially
// API_BASE_URL for backend requests. Because Flutter assets are loaded
// asynchronously, main() waits for dotenv before creating the widget tree.
// That keeps login, dashboard, customer, and product screens from reading an
// empty API configuration during their first build.
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
    // MaterialApp holds app-wide configuration:
    // - debugShowCheckedModeBanner removes the Flutter debug ribbon.
    // - title names the application for platform/task-switcher surfaces.
    // - theme centralizes the app's main navy color, font, and Material 3 use.
    // - home starts the workflow on the login portal.
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
