import 'dart:async';
import 'dart:io';

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
      final allDepartments = ['MCA', 'MBA', 'BCA', 'MTECH']; // list all department codes
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


  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (pickedFile != null) {
      setState(() => _selectedImage = File(pickedFile.path));
    }
  }

  Future<void> _submitEvent() async {
    if (_eventNameController.text.isEmpty ||
        _descriptionController.text.isEmpty ||
        _selectedImage == null) {
      _showDialog('Please fill all fields and select an image.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final fileBytes = await _selectedImage!.readAsBytes();
      final fileName = 'event_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await supabase.storage.from('events').uploadBinary(
          fileName,
          fileBytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true)
      );

      final imageUrl = supabase.storage.from('events').getPublicUrl(fileName);

      final formattedEventDate = DateFormat('MMMM d, y h:mm:ss a').format(DateTime.now());


      await FirebaseFirestore.instance
          .collection('admin')
          .doc('event_permission')
          .collection('events')
          .add({
        'event_name': _eventNameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'image_url': imageUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'event_date': formattedEventDate, // ✅ NEW FIELD
      });

      Navigator.pop(context);
      _clearFields();
      _showDialog('Event submitted successfully!');
    } catch (e) {
      _showDialog('Error submitting event: $e');
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _clearFields() {
    _eventNameController.clear();
    _descriptionController.clear();
    setState(() => _selectedImage = null);
  }

  void _showDialog(String message) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: Text('Event Status'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
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

  void _showDenialDialog(DocumentSnapshot visitorDoc) {
    final visitorData = visitorDoc.data()! as Map<String, dynamic>;
    final visitorName = visitorData['name'] ?? 'Unknown';

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Deny Visit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 10),
            Text('Please select a reason for denying $visitorName:'),
            SizedBox(height: 20),
            Container(
              height: 200,
              child: CupertinoPicker(
                itemExtent: 32,
                onSelectedItemChanged: (index) {},
                children: denialReasons.map((reason) => Text(reason)).toList(),
              ),
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            child: Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            child: Text('Deny'),
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(context);
              await _moveVisitorToDenied(visitorDoc, denialReasons[0]);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Visit denied'), backgroundColor: Colors.red),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVisitorCard(DocumentSnapshot visitorDoc) {
    final visitor = visitorDoc.data()! as Map<String, dynamic>;
    DateTime? registeredAt = _parseDateTime(visitor['registered_at']);

    return Container(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: Offset(0, 5))],
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    color: backgroundColor.withOpacity(0.1),
                  ),
                  child: visitor['profile_image_url']?.isNotEmpty ?? false
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.network(
                      visitor['profile_image_url'],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Icon(Icons.person, color: backgroundColor, size: 35),
                    ),
                  )
                      : Icon(Icons.person, color: backgroundColor, size: 35),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        visitor['name'] ?? 'Unknown Visitor',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 4),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: backgroundColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          visitor['purpose'] ?? 'General Visit',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: backgroundColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.phone, size: 14, color: Colors.grey[600]),
                          SizedBox(width: 4),
                          Text(
                            visitor['phone'] ?? 'No phone',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(
              children: [
                Expanded(
                  child: CupertinoButton(
                    onPressed: () => _showDenialDialog(visitorDoc),
                    color: Colors.red.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(15),
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(CupertinoIcons.xmark_circle, size: 18, color: Colors.white),
                        SizedBox(width: 6),
                        Text(
                          'Deny',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: CupertinoButton(
                    onPressed: () async {
                      await _moveVisitorToMet(visitorDoc);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${visitor['name'] ?? 'Visitor'} approved for visit'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    color: Colors.green.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(15),
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(CupertinoIcons.checkmark_circle, size: 18, color: Colors.white),
                        SizedBox(width: 6),
                        Text(
                          'Accept',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventSlider() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events-ready')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingWidget();
        }

        if (snapshot.hasError) return _buildErrorWidget();

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyWidget('No Events Available', 'Check back later for upcoming events', Icons.event_busy);
        }

        final validEvents = _filterRecentEvents(snapshot.data!.docs);
        if (validEvents.isEmpty) {
          return _buildEmptyWidget('No Recent Events', 'No events in the last 10 hours', Icons.event_busy);
        }

        return _PremiumEventSlider(events: validEvents);
      },
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      height: 300,
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(backgroundColor),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.red.shade300),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade600, size: 48),
          SizedBox(height: 16),
          Text('Error Loading Events',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red.shade800)),
          SizedBox(height: 8),
          Text('Please try again later',
              style: TextStyle(fontSize: 14, color: Colors.red.shade600)),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget(String title, String subtitle, IconData icon) {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.grey.shade600, size: 48),
          SizedBox(height: 16),
          Text(title,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
          SizedBox(height: 8),
          Text(subtitle,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
  Future<void> _selectProfilePicture() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);

    if (pickedFile == null) return;

    try {
      final file = File(pickedFile.path);
      final bytes = await file.readAsBytes();
      final extension = pickedFile.path.split('.').last;

      final allDepartments = ['MCA', 'MBA', 'BCA', 'MTECH']; // ✅ Add all departments
      final deptCode = allDepartments.firstWhere(
            (dept) => widget.userId.startsWith(dept),
        orElse: () => '',
      );

      if (deptCode.isEmpty) {
        _showDialog('Department could not be identified from userId.');
        return;
      }

      final fileName = '${widget.userId}_avatar.$extension';

      // Upload to Supabase
      final storageResponse = await supabase.storage
          .from('faculty-images')
          .uploadBinary(fileName, bytes, fileOptions: FileOptions(upsert: true));

      final publicUrl = supabase.storage.from('faculty-images').getPublicUrl(fileName);

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc('faculty')
          .collection(deptCode)
          .doc(widget.userId)
          .update({
        'profile_image_url': publicUrl,
      });

      _showDialog('Profile picture updated successfully!');
    } catch (e) {
      print('Upload error: $e');
      _showDialog('Failed to upload profile picture.');
    }
  }


  Widget _buildVisitorsList() {
    return StreamBuilder<QuerySnapshot>(
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
          return _buildEmptyWidget('No pending visitors', 'All caught up!', Icons.people_outline);
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) => _buildVisitorCard(snapshot.data!.docs[index]),
        );
      },
    );
  }

  List<QueryDocumentSnapshot> _filterRecentEvents(List<QueryDocumentSnapshot> docs) {
    final currentTime = DateTime.now();
    return docs.where((doc) {
      try {
        final data = doc.data() as Map<String, dynamic>;
        final timestamp = data['timestamp'] as Timestamp?;
        if (timestamp == null) return false;

        final eventTime = timestamp.toDate();
        final difference = currentTime.difference(eventTime);
        return difference.inHours < 10;
      } catch (e) {
        return false;
      }
    }).toList();
  }

  DateTime? _parseDateTime(dynamic raw) {
    try {
      if (raw is Timestamp) return raw.toDate();
      if (raw is String) return DateTime.tryParse(raw);
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(
          child: RichText(
            text: TextSpan(
              style: GoogleFonts.gabarito(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              children: [TextSpan(text: "Faculty Home")],
            ),
          ),
        ),
        backgroundColor: backgroundColor,
        elevation: 0,
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 16.0),
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            FutureBuilder<DocumentSnapshot?>(
              future: _getFacultyProfile(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CupertinoActivityIndicator());
                }

                if (!snapshot.hasData || snapshot.data == null || !snapshot.data!.exists) {
                  return Center(
                    child: Text(
                      'Profile not found',
                      style: GoogleFonts.poppins(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }

                final data = snapshot.data!.data() as Map<String, dynamic>;

                final name = data['name'] ?? 'Unnamed Faculty';
                final designation = data['designation'] ?? 'No Designation';
                final department = data['department'] ?? 'Unknown Department';
                final profileUrl = data['profile_image_url']?.toString() ?? '';

                return Container(
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Stack(
                    children: [
                      // Background Image (very faint)
                      Positioned.fill(
                        child: Opacity(
                          opacity: 0.99 , // Adjust for faintness
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.asset(
                              'assets/amclogo.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),

                      // Foreground content
                      Container(
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 12,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: _selectProfilePicture,
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: backgroundColor.withOpacity(0.4),
                                      width: 2,
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    radius: 40,
                                    backgroundColor: backgroundColor.withOpacity(0.2),
                                    backgroundImage:
                                    profileUrl.isNotEmpty ? NetworkImage(profileUrl) : null,
                                    child: profileUrl.isEmpty
                                        ? Icon(Icons.person, size: 40, color: Colors.white)
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    designation,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.grey[800],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    department,
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );

              },
            ),



            SizedBox(height: 8),
            Text(
              'Manage your events and visitor requests efficiently.',
              style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[600]),
            ),
            SizedBox(height: 30),
            Text(
              'Current Events',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: backgroundColor,
              ),
            ),
            SizedBox(height: 16),
            _buildEventSlider(),
            SizedBox(height: 30),
            Text(
              'Pending Visitor Requests',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: backgroundColor,
              ),
            ),
            SizedBox(height: 16),
            _buildVisitorsList(),
          ],
        ),
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
                      boxShadow: [
                  BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                  ),],
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