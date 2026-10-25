/*
===========================================================
PROJECT: Cutting Edge Salon
STUDENT DETAILS:
-----------------------------------------------------------
Name                  | Student Number
-----------------------------------------------------------
Goitse Kgwele         | 221050663
Thabang Zitha         | 223007074
Yamkela Mazamani      | 224007421
Nyakallo Pali         | 223060226
Bennet Linda          | 224004294
===========================================================
*/

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_theme.dart';    // Imports the custom dark/gold theme
import 'splash_screen.dart'; // The first screen that appears when the app opens

/// The entry point of the Flutter application.
/// It initializes essential services (like Supabase) before starting the app.
Future<void> main() async {
  // Ensures that Flutter engine bindings are initialized before calling native code (like Supabase)
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the Supabase client with the project URL and API Key.
  // The app will not function without this connection being established.
  await Supabase.initialize(
    url: 'https://chjfrgxlirmdpenngpoh.supabase.co',
    publishableKey: 'sb_publishable_CbqJbdnLWkQZRnTAWK_kQw_Kf_sSZHb',
  );

  // Start the application by running the main widget
  runApp(const CuttingEdgeApp());
}

// A globally accessible instance of the Supabase client.
// This allows any screen or widget in the app to easily query the database.
final supabase = Supabase.instance.client;

/// The root widget of the application.
/// It configures the app's title, theme, and sets the initial screen.
class CuttingEdgeApp extends StatelessWidget {
  const CuttingEdgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // The name of the app (used by the OS task switcher)
      title: 'Cutting Edge Salon',
      
      // Hides the red "DEBUG" banner in the top right corner during development
      debugShowCheckedModeBanner: false,
      
      // Applies the custom dark/gold theme defined in app_theme.dart
      theme: AppTheme.dark,
      
      // Sets the SplashScreen as the very first screen the user sees
      home: const SplashScreen(),
    );
  }
}