import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:alumni_system/firebase_options.dart';
import 'package:alumni_system/screens/login_screen.dart';

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
      title: 'Alumni Portal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF090A4F)),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}
