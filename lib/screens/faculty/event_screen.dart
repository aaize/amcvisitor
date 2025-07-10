import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EventDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> event;

  const EventDetailsScreen({Key? key, required this.event}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final eventName = event['event_name'] ?? 'Untitled Event';
    final description = event['description'] ?? 'No description available';
    final imageUrl = event['image_url'] ?? '';

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('Event Details', style: GoogleFonts.poppins()),
        previousPageTitle: 'Back',
        backgroundColor: CupertinoColors.systemPurple,
        border: null,
      ),
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (imageUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        imageUrl,
                        height: 300,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          eventName,
                          style: GoogleFonts.poppins(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: CupertinoColors.activeBlue,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          description,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: CupertinoColors.label,
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
      ),
    );
  }
}
