import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alumni_system/core/config/supabase_config.dart';
import 'package:alumni_system/features/auth/presentation/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!SupabaseConfig.isConfigured) {
    throw StateError(
      'Supabase is not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY.',
    );
  }
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.anonKey,
  );

  runApp(const MyApp());
}

/// Shared Supabase client for services.
SupabaseClient get supabase => Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Alumni Portal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF090A4F)),
        useMaterial3: true,
      ),
      // AuthGate restores an existing Supabase session (if any) before Login.
      home: const AuthGate(),
    );
  }
}
