import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:screenshot/screenshot.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

class VisitorCard extends StatefulWidget {
  final File profileImage;
  final String name;
  final String email;
  final String phone;
  final String purpose;
  final String department;
  final String visitedToDisplay;
  final String visitedToUsername;
  final String visitedType;

  const VisitorCard({
    Key? key,
    required this.profileImage,
    required this.name,
    required this.email,
    required this.phone,
    required this.purpose,
    required this.department,
    required this.visitedToDisplay,
    required this.visitedToUsername,
    required this.visitedType,
  }) : super(key: key);

  @override
  State<VisitorCard> createState() => _VisitorCardState();
}

class _VisitorCardState extends State<VisitorCard> with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _fadeController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  final ScreenshotController screenshotController = ScreenshotController();
  late final String timestamp;

  bool _isConfirmed = false;
  bool _isLoading = false;

  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();

    timestamp = DateTime.now().toLocal().toString().substring(0, 19);

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _scaleController.forward();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<String> _uploadScreenshotToSupabase(Uint8List imageBytes,
      String fileName) async {
    try {
      // Upload using the new API without .execute()
      await supabase.storage
          .from('visitor-passes')
          .uploadBinary(
        'passes/$fileName.png',
        imageBytes,
        fileOptions: const FileOptions(
          cacheControl: '3600',
          upsert: true,
          contentType: 'image/png',
        ),
      );

      // Get public URL of the uploaded image
      final publicUrl = supabase.storage
          .from('visitor-passes')
          .getPublicUrl('passes/$fileName.png');

      return publicUrl;
    } catch (e) {
      throw Exception('Upload failed: $e');
    }
  }

  Future<String> _uploadProfileImageToSupabase(File profileImage, String fileName) async {
    try {
      // Read the profile image file as bytes
      final imageBytes = await profileImage.readAsBytes();

      // Upload to visitor-profile bucket with proper error handling
      final response = await supabase.storage
          .from('visitor-profile')
          .uploadBinary(
        'profiles/$fileName.jpg',
        imageBytes,
        fileOptions: const FileOptions(
          cacheControl: '3600',
          upsert: true,
          contentType: 'image/jpeg',
        ),
      );

      // Get public URL of the uploaded profile image
      final publicUrl = supabase.storage
          .from('visitor-profile')
          .getPublicUrl('profiles/$fileName.jpg');

      return publicUrl;
    } on StorageException catch (e) {
      // Handle specific storage exceptions
      if (e.statusCode == '403') {
        throw Exception('Permission denied. Please check bucket policies.');
      }
      throw Exception('Profile image upload failed: ${e.message}');
    } catch (e) {
      throw Exception('Profile image upload failed: $e');
    }
  }

  Future<void> _confirmAndSave() async {
    if (_isConfirmed || _isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Generate unique filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Upload profile image to Supabase
      final profileImageUrl = await _uploadProfileImageToSupabase(
          widget.profileImage,
          'profile_${timestamp}'
      );

      // Capture screenshot image
      final imageBytes = await screenshotController.capture();
      if (imageBytes == null) throw Exception('Failed to capture screenshot.');

      // Upload screenshot to Supabase Storage using binary data directly
      final fileName = 'visitor_card_${timestamp}';
      final publicImageUrl = await _uploadScreenshotToSupabase(
          imageBytes, fileName);

      // ✅ Upload visitor data to Firebase Firestore with both URLs
      await FirebaseFirestore.instance.collection('visitors').add({
        'name': widget.name,
        'email': widget.email,
        'phone': widget.phone,
        'purpose': widget.purpose,
        'department': widget.department,
        'visited_to_display': widget.visitedToDisplay,
        'visited_to_username': widget.visitedToUsername,
        'registered_at': DateTime.now().toIso8601String(),
        'visitor_pass_url': publicImageUrl,
        'profile_image_url': profileImageUrl,
        'status': 'pending', // ✅ Add this line
      });


      setState(() {
        _isConfirmed = true;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Visitor registration saved to Firestore with profile image!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isConfirmed = false;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  Future<void> _captureAndShareCard() async {
    try {
      final image = await screenshotController.capture();
      if (image != null) {
        final directory = await getTemporaryDirectory();
        final imagePath = await File('${directory.path}/visitor_card_${DateTime
            .now()
            .millisecondsSinceEpoch}.png').create();
        await imagePath.writeAsBytes(image);

        await Share.shareXFiles(
          [XFile(imagePath.path)],
          text: "My Visitor Pass 📇",
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0A1A2F),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40), // Add some top spacing
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.4),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          CupertinoIcons.checkmark_alt,
                          size: 28,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Registration Complete!',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w300,
                        color: Colors.white,
                        letterSpacing: 1.0,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Your visitor pass has been generated.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.85),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),


                    Screenshot(
                      controller: screenshotController,
                      child: Container(
                        height: 580,
                        width: 320,
                        margin: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          // Professional navy blue gradient
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF1e3c72), // Deep navy
                              const Color(0xFF2a5298), // Royal blue
                              const Color(0xFF1e3c72), // Back to navy
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1e3c72).withOpacity(0.3),
                              blurRadius: 25,
                              offset: const Offset(0, 12),
                              spreadRadius: -3,
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 15,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                ),
                                child: SingleChildScrollView(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Compact Header
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                            colors: [
                                              const Color(0xFF1e3c72),
                                              const Color(0xFF2a5298),
                                            ],
                                          ),
                                          borderRadius: const BorderRadius.only(
                                            bottomLeft: Radius.circular(16),
                                            bottomRight: Radius.circular(16),
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            // Compact Logo
                                            Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Image.asset(
                                                'assets/logo.png',
                                                height: 45,
                                                width: 150,
                                                fit: BoxFit.contain,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            const Text(
                                              'VISITOR PASS',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                                letterSpacing: 1.0,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(height: 16),

                                      // Compact Profile Picture
                                      Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: LinearGradient(
                                            colors: [
                                              const Color(0xFF1e3c72),
                                              const Color(0xFF2a5298),
                                            ],
                                          ),
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: const BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                          ),
                                          child: CircleAvatar(
                                            radius: 81,
                                            backgroundImage: FileImage(widget.profileImage),
                                            backgroundColor: Colors.grey.shade100,
                                          ),
                                        ),
                                      ),

                                      const SizedBox(height: 14),

                                      // Compact Name and Visitor Type
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        child: Column(
                                          children: [
                                            Text(
                                              widget.name.toUpperCase(),
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF1e3c72),
                                                letterSpacing: 0.8,
                                                height: 1.1,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              widget.visitedType.toUpperCase(),
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF666666),
                                                letterSpacing: 0.8,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(height: 16),

                                      // Compact Information Section
                                      Container(
                                        margin: const EdgeInsets.symmetric(horizontal: 12),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8F9FA),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: const Color(0xFF1e3c72).withOpacity(0.1),
                                            width: 1,
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            _compactInfoRow("PHONE", widget.phone),
                                            const SizedBox(height: 8),
                                            _compactInfoRow("PURPOSE", widget.purpose),
                                            const SizedBox(height: 8),
                                            _compactInfoRow("DEPARTMENT", widget.department),
                                            const SizedBox(height: 8),
                                            _compactInfoRow("VISITING", widget.visitedToDisplay),

                                          ],
                                        ),
                                      ),

                                      const SizedBox(height: 12),

                                      // Compact Registration Time
                                      Container(
                                        margin: const EdgeInsets.symmetric(horizontal: 12),
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1e3c72).withOpacity(0.05),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'Registered: $timestamp',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF1e3c72),
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ),

                                      const SizedBox(height: 12),

                                      // Compact Footer
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        child: Column(
                                          children: [
                                            Container(
                                              height: 2,
                                              width: 40,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF1e3c72),
                                                borderRadius: BorderRadius.circular(1),
                                              ),
                                            ),

                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),



                    SizedBox(height: 30),

                    SizedBox(
                      width: double.infinity,
                      child: _isConfirmed
                          ? Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              CupertinoIcons.check_mark_circled_solid,
                              color: Colors.white,
                              size: 24,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Confirmed & Saved',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                          : ElevatedButton(
                        onPressed: _isLoading ? null : _confirmAndSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF667eea),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 8,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF667eea)),
                          ),
                        )
                            : const Text(
                          'Confirm',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: _captureAndShareCard,
                        icon: const Icon(Icons.share, color: Colors.white),
                        label: const Text(
                          'Share Visitor Pass',
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.popUntil(context, (route) => route.isFirst);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF667eea),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 2,
                        ),
                        child: const Text(
                          'Back to Home',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 40), // Add bottom spacing
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  Widget _compactInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1e3c72),
              letterSpacing: 0.2,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }

}