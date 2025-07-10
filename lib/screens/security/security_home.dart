import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:visimgnt/screens/security/visitor_details.dart';
import 'dart:io';
import 'camera_module.dart';
class SecurityHome extends StatefulWidget {
  final String userId;

  const SecurityHome({Key? key, required this.userId}) : super(key: key);

  @override
  State<SecurityHome> createState() => _SecurityHomeState();
}

class _SecurityHomeState extends State<SecurityHome> with TickerProviderStateMixin {
  File? _profileImage;
  bool _hasCapturedImage = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
    _hasCapturedImage = false;
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  // Photo handling methods
  void _onPhotoTaken(File? image) {
    if (image != null) {
      setState(() {
        _profileImage = image;
        _hasCapturedImage = true;
      });
    }
  }

  void _retakePhoto() {
    setState(() {
      _profileImage = null;
      _hasCapturedImage = false;
    });
  }

  void _proceedWithImage() {
    if (_profileImage != null) {
      // Navigate to next screen with the captured image
      Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (context) => VisitorDetails(profileImage: _profileImage!),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1A2F),
      appBar: AppBar(
        backgroundColor: Color(0xFF0A1A2F),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Security Portal',
          style: TextStyle(
            color: Colors.white60,
            fontSize: 20,
            fontWeight: FontWeight.w400,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              children: [
                const SizedBox(height: 20),

                // AMCEC Logo at top center
                Center(
                  child: Image.asset(
                    'assets/amclogo.png',
                    height: 140,
                    width: 220,
                  ),
                ),

                // Spacer to push face capture to center
                const Spacer(flex: 1),

                // Face capture widget in center
                Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: _hasCapturedImage && _profileImage != null
                        ? Image.file(_profileImage!, fit: BoxFit.cover)
                        : CircularFaceCaptureWidget(onPhotoTaken: _onPhotoTaken),
                  ),
                ),

                const SizedBox(height: 30),

                // Status text
                Text(
                  _hasCapturedImage
                      ? 'Face captured successfully!'
                      : 'Position your face in the circle above',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 40),

                // Action buttons (only show when image is captured)
                if (_hasCapturedImage) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildActionButton(
                        icon: CupertinoIcons.refresh,
                        label: 'Retake',
                        onTap: _retakePhoto,
                        isPrimary: false,
                      ),
                      _buildActionButton(
                        icon: CupertinoIcons.checkmark_alt,
                        label: 'Continue',
                        onTap: _proceedWithImage,
                        isPrimary: true,
                        color: Colors.green,
                      ),
                    ],
                  ),
                ],

                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isPrimary,
    Color? color,
  }) {
    final backgroundColor = color ?? (isPrimary ? Colors.white : Colors.white.withOpacity(0.2));
    final iconTextColor = color != null
        ? Colors.white
        : (isPrimary ? const Color(0xFF0A1A2F) : Colors.white);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconTextColor, size: 18),
            if (label.isNotEmpty) const SizedBox(width: 8),
            if (label.isNotEmpty)
              Text(
                label,
                style: TextStyle(
                  color: iconTextColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

