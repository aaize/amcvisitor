// Full Admin Home page with event_date display

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({Key? key}) : super(key: key);

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  Color backgroundColor = const Color(0xFF6A5ACD);

  Future<void> _approveEvent(DocumentSnapshot doc) async {
    final data = doc.data()! as Map<String, dynamic>;

    try {
      await FirebaseFirestore.instance.collection('events-ready').add({
        'event_name': data['event_name'],
        'description': data['description'],
        'image_url': data['image_url'],
        'timestamp': FieldValue.serverTimestamp(),
        'event_date': data['event_date'],
      });

      await doc.reference.delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Event approved and moved to events-ready'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Error approving event'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<void> _denyEvent(DocumentSnapshot doc) async {
    try {
      await doc.reference.delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Event denied and removed'),
          backgroundColor: Colors.red,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Error denying event'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Widget _buildEventCard(DocumentSnapshot doc) {
    final data = doc.data()! as Map<String, dynamic>;

    String formattedDate = 'No date';
    if (data['event_date'] is Timestamp) {
      formattedDate = DateFormat.yMMMMd().add_jm().format(data['event_date'].toDate());
    } else if (data['event_date'] is String) {
      try {
        formattedDate = DateFormat.yMMMMd().add_jm().format(DateTime.parse(data['event_date']));
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (data['image_url'] != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                data['image_url'],
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          const SizedBox(height: 12),
          Text(
            data['event_name'] ?? 'Untitled Event',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: backgroundColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Event Date: $formattedDate',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  color: CupertinoColors.activeGreen,
                  borderRadius: BorderRadius.circular(10),
                  child: const Text('Approve', style: TextStyle(color: Colors.white)),
                  onPressed: () => _approveEvent(doc),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  color: CupertinoColors.systemRed,
                  borderRadius: BorderRadius.circular(10),
                  child: const Text('Deny', style: TextStyle(color: Colors.white)),
                  onPressed: () => _denyEvent(doc),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('admin')
                .doc('event_permission')
                .collection('events')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CupertinoActivityIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No pending events'));
              }

              return ListView.builder(
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) => _buildEventCard(snapshot.data!.docs[index]),
              );
            },
          ),
        ),
      ),
    );
  }
}
