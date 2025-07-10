import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visimgnt/screens/admin/admin_home.dart';
import 'package:visimgnt/screens/admin/admin_navbar.dart';
import 'package:visimgnt/screens/faculty/faculty_home.dart';
import 'package:visimgnt/screens/faculty/faculty_navbar.dart';
import 'package:visimgnt/screens/security/security_home.dart';
import 'package:visimgnt/screens/security/security_navbar.dart';

import 'login.dart';


class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.7, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();

    _navigateAfterDelay();
  }

  Future<void> _navigateAfterDelay() async {
    await Future.delayed(const Duration(seconds: 2));
    final prefs = await SharedPreferences.getInstance();
    final savedUsername = prefs.getString('savedUsername') ?? '';

    Widget nextScreen;

    if (savedUsername.toLowerCase() == 'security') {
      nextScreen = SecurityNavbar(userId: savedUsername);
    } else if (savedUsername.toLowerCase() == 'admin') {
      nextScreen = AdminNavbar(userId: savedUsername);
    } else if (savedUsername.toUpperCase().startsWith('MCA')) {
      nextScreen = FacultyNavbar(userId: savedUsername);
    } else {
      nextScreen = const LoginScreen();
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => nextScreen,
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.2),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    }
  }




  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1A2F),
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: Image.asset(
                'assets/amclogo.png',
                width: 180,
                height: 180,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}