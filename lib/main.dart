
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_theme.dart';
import 'splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://chjfrgxlirmdpenngpoh.supabase.co',
    publishableKey:'sb_publishable_CbqJbdnLWkQZRnTAWK_kQw_Kf_sSZHb',
  );

  runApp(const CuttingEdgeApp());
}

// Use this client anywhere in your application.
final supabase = Supabase.instance.client;

class CuttingEdgeApp extends StatelessWidget {
  const CuttingEdgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cutting Edge Salon',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const SplashScreen(),
    );
  }
}
