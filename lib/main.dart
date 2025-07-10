import 'package:face_camera/face_camera.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login.dart';
import 'splash.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FaceCamera.initialize(); // Initialize face camera
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
  );
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://lwwdgwlmdeunhumlbvhm.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx3d2Rnd2xtZGV1bmh1bWxidmhtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIxMzI2OTIsImV4cCI6MjA2NzcwODY5Mn0.qgLNd1Tx6oaVd5H5P-LJcFf7SzrLdp7fR0WH-W9g7so',
  );

  runApp(const MyApp());

}

class MyApp extends StatelessWidget {
  const MyApp({super.key});


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Visitor Management',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0A1A2F),
      ),
      home: const SplashScreen(),
    );
  }
}