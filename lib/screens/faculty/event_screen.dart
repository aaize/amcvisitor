import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class EventDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> event;
  final String userId;
  final String eventDocId; // Unique event ID from Firestore

  const EventDetailsScreen({
    Key? key,
    required this.event,
    required this.userId,
    required this.eventDocId,
  }) : super(key: key);

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _isEnrolling = false;
  bool _isAlreadyEnrolled = false;

  Map<String, dynamic>? facultyProfile;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOut),
    );

    _fadeController.forward();
    _slideController.forward();

    _fetchFacultyProfile();
  }

  Future<void> _fetchFacultyProfile() async {
    try {
      final departments = ['MCA', 'BBA', 'BCA', 'MTech'];
      for (String dept in departments) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc('faculty')
            .collection(dept)
            .doc(widget.userId)
            .get();

        if (doc.exists) {
          setState(() {
            facultyProfile = doc.data();
          });
          await _checkEnrollmentStatus(); // Check enrollment after profile load
          return;
        }
      }
      _showSnackbar("Faculty profile not found.");
    } catch (e) {
      _showSnackbar("Error fetching faculty profile.");
    }
  }

  Future<void> _checkEnrollmentStatus() async {
    if (facultyProfile == null) return;

    try {
      final username = facultyProfile!['username'];
      final department = facultyProfile!['department'];
      final eventId = widget.eventDocId;

      final docRef = FirebaseFirestore.instance
          .collection('events-enrolled')
          .doc('faculty')
          .collection(department)
          .doc(username)
          .collection('events')
          .doc(eventId);

      final docSnapshot = await docRef.get();

      if (mounted) {
        setState(() {
          _isAlreadyEnrolled = docSnapshot.exists;
        });
      }
    } catch (e) {
      print("Error checking enrollment: $e");
    }
  }

  void _showSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _enrollInEvent() async {
    if (facultyProfile == null) {
      _showSnackbar("Faculty profile not loaded yet.");
      return;
    }

    setState(() => _isEnrolling = true);

    try {
      final username = facultyProfile!['username'];
      final name = facultyProfile!['name'];
      final designation = facultyProfile!['designation'];
      final department = facultyProfile!['department'];
      final enrolledAt = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

      final eventId = widget.eventDocId; // Unique event ID from Firestore
      final eventName = widget.event['event_name'] ?? 'Untitled';

      final docRef = FirebaseFirestore.instance
          .collection('events-enrolled')
          .doc('faculty')
          .collection(department)
          .doc(username)
          .collection('events')
          .doc(eventId);

      await docRef.set({
        'eventId': eventId,
        'eventName': eventName,
        'enrolledAt': enrolledAt,
        'username': username,
        'name': name,
        'designation': designation,
        'department': department,
      });

      if (mounted) {
        setState(() {
          _isAlreadyEnrolled = true; // Disable button after enrollment
        });
        _showCupertinoToast("Enrolled successfully!");
      }
    } catch (e) {
      _showSnackbar("Failed to enroll: $e");
    } finally {
      if (mounted) setState(() => _isEnrolling = false);
    }
  }

  void _showCupertinoToast(String message) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (_) => Positioned(
        bottom: 60,
        left: MediaQuery.of(context).size.width * 0.1,
        width: MediaQuery.of(context).size.width * 0.8,
        child: Material(
          color: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                color: Colors.black.withOpacity(0.4), // translucent black for blur visible
                child: Center(
                  child: Text(
                    message,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      decoration: TextDecoration.none,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay?.insert(overlayEntry);
    Future.delayed(const Duration(seconds: 2), () => overlayEntry.remove());
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final eventName = event['event_name'] ?? 'Untitled Event';
    final imageUrl = event['image_url'] ?? '';
    final rawDate = event['timestamp'];
    final formattedDate = rawDate is Timestamp
        ? DateFormat('MMM d, yyyy - hh:mm a').format(rawDate.toDate())
        : 'No date';

    return SafeArea(
      child: Stack(
        children: [
          // Blurred background
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.black.withOpacity(0.5)),
          ),
          Center(
            child: SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF11203E),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Event Title
                        Padding(
                          padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
                          child: Text(
                            eventName,
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Event Image
                        imageUrl.isNotEmpty
                            ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              height: 200,
                              color: Colors.grey[800],
                              child: const Center(
                                child: CupertinoActivityIndicator(),
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) => _buildPlaceholder(),
                        )
                            : _buildPlaceholder(),

                        // Event Date
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'Date: $formattedDate',
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 14,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Description
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            event['description'] ?? 'No additional details provided.',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: Colors.grey[300],
                              height: 1.5,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),

                        // Enroll Button
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: (_isEnrolling || _isAlreadyEnrolled) ? null : _enrollInEvent,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isAlreadyEnrolled
                                    ? Colors.grey
                                    : Colors.greenAccent[700],
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isEnrolling
                                  ? const CupertinoActivityIndicator()
                                  : Text(
                                _isAlreadyEnrolled ? 'Already Enrolled' : 'Enroll',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      height: 200,
      width: double.infinity,
      color: const Color(0xFF1C2A45),
      child: const Center(
        child: Icon(
          CupertinoIcons.photo,
          color: Colors.grey,
          size: 64,
        ),
      ),
    );
  }
}
