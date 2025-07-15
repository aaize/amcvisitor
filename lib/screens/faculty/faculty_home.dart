import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../login.dart';
import 'event_screen.dart';

class FacultyHome extends StatefulWidget {
  final String userId;
  const FacultyHome({Key? key, required this.userId}) : super(key: key);

  @override
  _FacultyHomeState createState() => _FacultyHomeState();
}

class _FacultyHomeState extends State<FacultyHome> {
  final Color backgroundColor = Color(0xFF6A5ACD);
  final TextEditingController _eventNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  File? _selectedImage;
  bool _isSubmitting = false;
  final supabase = Supabase.instance.client;

  final List<String> denialReasons = [
    'Not in college today',
    'In a meeting',
    'Busy with classes',
    'On leave',
    'Emergency situation',
    'Other commitments'
  ];


  @override
  void initState() {
    super.initState();
    _showWelcomeToast();

  }

  void _showWelcomeToast() {
    Fluttertoast.showToast(
      msg: "Welcome to Your Faculty Dashboard!",
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: backgroundColor,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  Future<DocumentSnapshot?> _getFacultyProfile() async {
    try {
      final allDepartments = ['MCA', 'MBA', 'BCA', 'MTECH'];
      final deptCode = allDepartments.firstWhere(
            (dept) => widget.userId.startsWith(dept),
        orElse: () => '',
      );

      if (deptCode.isEmpty) {
        print('Unknown department code in userId');
        return null;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc('faculty')
          .collection(deptCode)
          .doc(widget.userId)
          .get();

      return doc.exists ? doc : null;
    } catch (e) {
      print('Error fetching faculty profile: $e');
      return null;
    }
  }

  void _showProfileDialog(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) =>
          Dialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            child: Container(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Profile Picture
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: backgroundColor, width: 3),
                    ),
                    child: CircleAvatar(
                      radius: 48,
                      backgroundColor: backgroundColor.withOpacity(0.1),
                      backgroundImage: data['profile_image_url']?.isNotEmpty ==
                          true
                          ? NetworkImage(data['profile_image_url'])
                          : null,
                      child: data['profile_image_url']?.isNotEmpty != true
                          ? Icon(Icons.person, size: 50, color: backgroundColor)
                          : null,
                    ),
                  ),
                  SizedBox(height: 16),

                  // Name
                  Text(
                    data['name'] ?? 'Unknown Faculty',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),

                  // Designation
                  Text(
                    data['designation'] ?? 'No Designation',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),

                  // Details
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildDetailRow(Icons.business, 'Department',
                            data['department'] ?? 'Unknown'),
                        SizedBox(height: 8),
                        _buildDetailRow(Icons.location_on, 'Block',
                            data['block'] ?? 'Unknown'),
                        SizedBox(height: 8),
                        _buildDetailRow(Icons.badge, 'User ID', widget.userId),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),

                  // Close Button
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: backgroundColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.symmetric(
                          horizontal: 32, vertical: 12),
                    ),
                    child: Text(
                      'Close',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildFacultyHeader(Map<String, dynamic> data) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // College Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              image: DecorationImage(
                image: AssetImage('assets/amclogo.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Profile Image
          GestureDetector(
            onTap: () => _showProfileDialog(data),
            child: CircleAvatar(
              radius: 20,
              backgroundImage: data['profile_image_url']?.isNotEmpty == true
                  ? NetworkImage(data['profile_image_url'])
                  : null,
              child: data['profile_image_url']?.isNotEmpty != true
                  ? Icon(Icons.person, size: 20, color: Colors.grey[600])
                  : null,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        SizedBox(width: 12),
        Text(
          '$label: ',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
            fontSize: 14,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlayStoreHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 40, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // AMC Logo
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              image: DecorationImage(
                image: AssetImage('assets/amclogo.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),

          // Profile Picture with notification badge
          FutureBuilder<DocumentSnapshot?>(
            future: _getFacultyProfile(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data == null) {
                return CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.grey[300],
                  child: Icon(Icons.person, size: 20, color: Colors.grey[600]),
                );
              }

              final data = snapshot.data!.data() as Map<String, dynamic>;
              return Stack(
                children: [
                  GestureDetector(
                    //onTap: () => _showProfileDialog(data),

                  ),
                  // Notification badge
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      child: Center(
                        child: Text(
                          '1',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }







  void _handleVisitorAction(DocumentSnapshot doc, bool accept) async {
    if (accept) {
      await _moveVisitorToMet(doc);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Visitor approved'), backgroundColor: Colors.green),
      );
    } else {
      _askForDenialReason(doc); // <-- show reason picker
    }
  }



  Future<List<QueryDocumentSnapshot>> _fetchPremiumEvents() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('events-ready')
        .orderBy('timestamp', descending: true)
        .limit(6)
        .get();
    return snapshot.docs;
  }
  void _showVisitorPassPopup(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Visitor Pass'),
        content: Image.network(
          url,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) =>
              Text('Could not load pass image'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }



  Widget _buildPremiumSliderSection() {
    return FutureBuilder<List<QueryDocumentSnapshot>>(
      future: _fetchPremiumEvents(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return SizedBox(); // or show fallback banner
        }

        return _PremiumEventSlider(events: snapshot.data!);
      },
    );
  }

  Widget _buildPremiumSlider() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events-ready')
          .orderBy('timestamp', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text("No featured events"));
        }

        final docs = snapshot.data!.docs;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 12),
          child: SizedBox(
            height: 290, // Play Store-like card height
            child: PageView.builder(
              itemCount: docs.length,
              controller: PageController(viewportFraction: 0.9),
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                final imageUrl = data['image_url'] ?? '';
                final eventName = data['event_name'] ?? 'Untitled Event';
                final description = data['description'] ?? '';

                return Container(
                  margin: EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    image: imageUrl.isNotEmpty
                        ? DecorationImage(
                      image: NetworkImage(imageUrl),
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(
                        Colors.black.withOpacity(0.4),
                        BlendMode.darken,
                      ),
                    )
                        : null,
                    color: Colors.orange[400],
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 6,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "From the admin",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        eventName,
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                      Spacer(),
                      Text(
                        'See more',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.white,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _askForDenialReason(DocumentSnapshot doc) {
    String? selectedReason = denialReasons.first;

    showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
        height: 300,
        color: Color(0xFF0A1A2F),
        child: Column(
          children: [
            SizedBox(height: 10),
            Text(
              "Select Denial Reason",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                decoration: TextDecoration.none
              ),

            ),
            Expanded(
              child: CupertinoPicker(
                backgroundColor: Color(0xFF0A1A2F),
                itemExtent: 40,
                scrollController: FixedExtentScrollController(initialItem: 0),
                onSelectedItemChanged: (int index) {
                  selectedReason = denialReasons[index];
                },
                children: denialReasons.map((reason) {
                  return Center(
                    child: Text(
                      reason,

                      style: GoogleFonts.poppins(fontSize: 14,color: Colors.white),
                      selectionColor: Colors.white,
                    ),
                  );
                }).toList(),
              ),
            ),
            CupertinoButton(
              color: Color(0xFF0A1A2F),
              child: Text("Confirm"),
              onPressed: () async {
                Navigator.of(context).pop(); // Close the popup

                await _moveVisitorToDenied(doc, selectedReason!);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Visitor denied'), backgroundColor: Colors.red),
                );
              },
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }


  Widget _buildVisitorsList() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 100.0), // Add space for bottom nav
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collectionGroup('visitors')
            .where('visited_to_username', isEqualTo: widget.userId)
            .orderBy('registered_at', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyCard('No Pending Visitors', Icons.people_outline);
          }

          final docs = snapshot.data!.docs;

          // Split into pages of 3
          final pages = <List<DocumentSnapshot>>[];
          for (int i = 0; i < docs.length; i += 3) {
            pages.add(docs.sublist(i, i + 3 > docs.length ? docs.length : i + 3));
          }

          return SizedBox(
            height: 386, // Adjust height as needed
            child: PageView.builder(
              controller: PageController(viewportFraction: 0.9),
              itemCount: pages.length,
              itemBuilder: (context, index) {
                final pageDocs = pages[index];
                return Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: pageDocs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0, right: 12),
                      child: _buildVisitorCard(data, doc),
                    );
                  }).toList(),
                );
              },
            ),
          );
        },
      ),
    );
  }



  Widget _buildVisitorCard(Map<String, dynamic> visitorData, DocumentSnapshot doc) {
    return Container(
      margin: EdgeInsets.only(bottom: 3),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFF0A1A2F).withOpacity(0.6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Visitor Image
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey[200],
                  ),
                  child: visitorData['profile_image_url']?.isNotEmpty == true
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: Image.network(
                      visitorData['profile_image_url'],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Icon(Icons.person, color: Colors.grey[600]),
                    ),
                  )
                      : Icon(Icons.person, color: Colors.grey[600]),
                ),
                SizedBox(width: 16),

                // Visitor Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        visitorData['name'] ?? 'Unknown Visitor',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.phone, size: 14, color: Colors.green),
                          SizedBox(width: 4),
                          Text(
                            visitorData['phone'] ?? 'Unknown',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[300],
                            ),
                          ),
                          Text(' • ', style: TextStyle(color: Colors.amberAccent[300])),
                          Text(
                            'Pending',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.amber[600],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.cases_sharp, size: 14, color: Colors.blue),
                          SizedBox(width: 2),
                          Text(
                            visitorData['purpose'] ?? 'General',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[300],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Action Buttons
                Row(
                  children: [
                    IconButton(
                      onPressed: () => _handleVisitorAction(doc, false),
                      icon: Icon(Icons.close, color: Colors.redAccent, size: 20),
                    ),
                    IconButton(
                      onPressed: () => _handleVisitorAction(doc, true),
                      icon: Icon(Icons.check, color: Colors.greenAccent, size: 20),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _moveVisitorToMet(DocumentSnapshot visitorDoc) async {
    final visitorData = visitorDoc.data()! as Map<String, dynamic>;
    visitorData['met_at'] = DateTime.now().toIso8601String();
    visitorData['status'] = 'met';
    visitorData['accepted_by'] = widget.userId;

    await FirebaseFirestore.instance.collection('visitors-met').add(visitorData);
    await visitorDoc.reference.delete();
  }

  Future<void> _moveVisitorToDenied(DocumentSnapshot visitorDoc, String reason) async {
    final visitorData = visitorDoc.data()! as Map<String, dynamic>;
    visitorData['denied_at'] = DateTime.now().toIso8601String();
    visitorData['status'] = 'denied';
    visitorData['denied_by'] = widget.userId;
    visitorData['denial_reason'] = reason;

    await FirebaseFirestore.instance.collection('visitors-denied').add(visitorData);
    await visitorDoc.reference.delete();
  }

  Widget _buildEmptyCard(String message, IconData icon) {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0A1A2F),
      body: FutureBuilder<DocumentSnapshot?>(
        future: _getFacultyProfile(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return Center(child: Text("Profile not found"));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          return Column(
            children: [
              // 🔹 Custom AppBar with AMC Logo and Profile Image
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // AMC Logo (Left)
                    Image.asset(
                      'assets/amcbgno.png',
                      width: 40,
                      height: 50,
                    ),

                    // Profile Image (Right)
                    GestureDetector(
                      onTap: () => _showProfileDialog(data),
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.grey[300],
                        backgroundImage: data['profile_image_url']?.isNotEmpty == true
                            ? NetworkImage(data['profile_image_url'])
                            : null,
                        child: data['profile_image_url']?.isNotEmpty != true
                            ? Icon(Icons.person, size: 22, color: Colors.grey[600])
                            : null,
                      ),
                    ),
                  ],
                ),
              ),

              // 🔹 Faculty Header

              // 🔹 Main Scrollable Content
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Featured Title
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
                        child: Text(
                          "Featured",
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      // Premium Slider
                      _buildPremiumSliderSection(),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
                        child: Text(
                          "Waiting For You...",
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      // Visitors Section
                      _buildVisitorsList(),
                      SizedBox(height: 80), // space for bottom nav
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }


}
class _PremiumEventSlider extends StatefulWidget {
  final List<QueryDocumentSnapshot> events;

  const _PremiumEventSlider({required this.events});

  @override
  State<_PremiumEventSlider> createState() => _PremiumEventSliderState();
}

class _PremiumEventSliderState extends State<_PremiumEventSlider> {
  late PageController _pageController;
  Timer? _autoScrollTimer;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.9);
    _startAutoScroll();
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    final maxSlides = widget.events.length > 6 ? 6 : widget.events.length;

    _autoScrollTimer = Timer.periodic(Duration(seconds: 4), (timer) {
      if (widget.events.isNotEmpty && _pageController.hasClients) {
        _currentIndex = (_currentIndex + 1) % maxSlides;
        _pageController.animateToPage(
          _currentIndex,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
      }
    });
  }


  String _truncateText(String text, int maxLength) {
    return text.length > maxLength ? '${text.substring(0, maxLength)}...' : text;
  }

  String _formatEventDateTime(Timestamp timestamp) {
    final date = timestamp.toDate().toLocal(); // Convert to local timezone
    return '${_getMonth(date.month)} ${date.day}, ${date.year} at ${_formatTime(date)}';
  }

  String _getMonth(int month) {
    const months = ['January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'];
    return months[month - 1];
  }

  String _formatTime(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final period = date.hour < 12 ? 'AM' : 'PM';
    return '${hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 320,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemCount: widget.events.length,
            itemBuilder: (context, index) {
              final eventData = widget.events[index].data() as Map<String, dynamic>;
              final eventName = eventData['event_name'] as String? ?? 'Untitled Event';
              final imageUrl = eventData['image_url'] as String?;
              final timestamp = eventData['timestamp'] as Timestamp?;

              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => EventDetailsScreen(event: eventData)),
                ),
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),

                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      children: [
                        // Background Image
                        if (imageUrl != null && imageUrl.isNotEmpty)
                          Image.network(
                            imageUrl,
                            height: 320,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              height: 320,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF6A5ACD).withOpacity(0.3),
                                    Color(0xFF9370DB).withOpacity(0.3),
                                  ],
                                ),
                              ),
                              child: Center(
                                child: Icon(Icons.image_not_supported, color: Colors.white, size: 64),
                              ),
                            ),
                          )
                        else
                          Container(
                            height: 320,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF6A5ACD),
                                  Color(0xFF9370DB),
                                ],
                              ),
                            ),
                          ),

                        // Gradient Overlay
                        Container(
                          height: 320,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.3),
                                Colors.black.withOpacity(0.8),
                              ],
                              stops: [0.0, 0.6, 1.0],
                            ),
                          ),
                        ),

                        // Premium Badge
                        Positioned(
                          top: 16,
                          right: 16,
                          child: _buildEventStatusBadge(eventData['event_date']),
                        ),

                        // Event Information
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.8),
                                ],
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Date and Time
                                Row(
                                  children: [
                                    Icon(Icons.calendar_month, size: 16, color: Colors.white70),
                                    SizedBox(width: 8),
                                    Text(
                                      _formatEventDateTime(eventData['event_date']),
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                // Event Name
                                Text(
                                  eventData['event_name'],
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        SizedBox(height: 12),
        // Dot Indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.events.length > 6 ? 6 : widget.events.length, (index) {
            return AnimatedContainer(
              duration: Duration(milliseconds: 300),
              margin: EdgeInsets.symmetric(horizontal: 4),
              width: _currentIndex == index ? 12 : 8,
              height: _currentIndex == index ? 12 : 8,
              decoration: BoxDecoration(
                color: _currentIndex == index ? Color(0xFF6A5ACD) : Colors.grey[400],
                shape: BoxShape.circle,
              ),
            );
          }),
        ),
      ],
    );
  }


  DateTime _parseEventDate(String dateString) {
    try {
      // Handle the "at" and timezone format
      final formattedString = dateString
          .replaceAll(' at ', ' ')
          .replaceAll(' ', ' ') // Replace special space character
          .replaceAll(' UTC+5:30', ''); // Remove timezone

      return DateFormat('MMMM d, y h:mm:ss a').parse(formattedString);
    } catch (e) {
      print('Error parsing date: $e');
      return DateTime.now(); // Fallback to current date
    }
  }

// Updated status badge widget
  Widget _buildEventStatusBadge(dynamic eventDateRaw) {
    if (eventDateRaw == null) return SizedBox.shrink();

    final now = DateTime.now();
    late DateTime eventDate;

    try {
      // If it's a Firestore Timestamp
      if (eventDateRaw is Timestamp) {
        eventDate = eventDateRaw.toDate();
      } else if (eventDateRaw is String) {
        eventDate = DateTime.parse(eventDateRaw);
      } else {
        return SizedBox.shrink(); // unsupported format
      }
    } catch (_) {
      return SizedBox.shrink();
    }

    final isToday = now.year == eventDate.year &&
        now.month == eventDate.month &&
        now.day == eventDate.day;

    final isFuture = eventDate.isAfter(
      DateTime(now.year, now.month, now.day, 23, 59, 59),
    );

    if (!isToday && !isFuture) return SizedBox.shrink(); // Skip past events

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isToday ? Icons.live_tv : Icons.upcoming,
            color: isToday ? Colors.green : Colors.blue,
            size: 16,
          ),
          SizedBox(width: 4),
          Text(
            isToday ? 'LIVE' : 'UPCOMING',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isToday ? Colors.green : Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

}