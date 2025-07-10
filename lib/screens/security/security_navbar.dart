import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../login.dart';
import 'security_visitors.dart';
import 'security_home.dart';

class SecurityNavbar extends StatefulWidget {
  final String userId;
  const SecurityNavbar({super.key, required this.userId});

  @override
  State<SecurityNavbar> createState() => _SecurityNavbarState();
}

class _SecurityNavbarState extends State<SecurityNavbar> {
  int _selectedIndex = 0;
  bool _showRedDot = false;

  void initState() {
    super.initState();
    _loadNotificationState();
    _listenForNewNotifications();
  }

  Future<void> _loadNotificationState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _showRedDot = prefs.getBool('showRedDot') ?? false;
    });
  }

  Future<void> _saveNotificationState(bool state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showRedDot', state);
  }

  void _listenForNewNotifications() {
    FirebaseFirestore.instance
        .collection('visitors-met')
        .orderBy('met_at', descending: true)
        .snapshots()
        .listen((snapshot) {
      _checkForRecentChanges(snapshot.docs, 'met_at');
    });

    FirebaseFirestore.instance
        .collection('visitors-cancelled')
        .orderBy('cancelled_at', descending: true)
        .snapshots()
        .listen((snapshot) {
      _checkForRecentChanges(snapshot.docs, 'cancelled_at');
    });
  }

  void _checkForRecentChanges(List<DocumentSnapshot> docs, String timeField) {
    final now = DateTime.now();

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final timestampStr = data[timeField];
      final timestamp = DateTime.tryParse(timestampStr ?? '');

      if (timestamp != null && now.difference(timestamp).inMinutes < 2) {
        setState(() {
          _showRedDot = true;
        });
        _saveNotificationState(true);
        break;
      }
    }
  }

  void _onItemTapped(int index) {
    if (index == 3) {
      // Do not change screen index; just show profile options
      _showProfileOptions();
      return;
    }

    setState(() {
      _selectedIndex = index;
    });

    if (index == 2) {
      // Clear red dot when Alerts is tapped
      _showRedDot = false;
      _saveNotificationState(false);
    }
  }


  void _showProfileOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0A1A2F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Profile Options',
              style: TextStyle(
                fontSize: 20,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushAndRemoveUntil(
                  context,
                  CupertinoPageRoute(builder: (context) => const LoginScreen()),
                      (_) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  BottomNavigationBarItem _buildAlertsIcon() {
    return BottomNavigationBarItem(
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(CupertinoIcons.bell),
          if (_showRedDot)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
      label: 'Alerts',
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> _screens = [
      SecurityHome(userId: widget.userId),
      const SecurityVisitors(),
      Center(child: Text("Alerts", style: TextStyle(color: Colors.white))),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0A1A2F),
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: _screens,
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0A1A2F),
          border: const Border(top: BorderSide(color: Colors.white12, width: 0.5)),
        ),
        child: BottomNavigationBar(
          backgroundColor: const Color(0xFF0A1A2F),
          currentIndex: _selectedIndex,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white70,
          selectedFontSize: 12,
          unselectedFontSize: 11,
          elevation: 8,
          onTap: _onItemTapped,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.home),
              label: 'Home',
            ),
            const BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.person_3),
              label: 'Visitors',
            ),
            _buildAlertsIcon(),
            const BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.profile_circled),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
