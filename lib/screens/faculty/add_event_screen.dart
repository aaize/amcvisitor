import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddEventScreen extends StatefulWidget {
  const AddEventScreen({super.key});

  @override
  State<AddEventScreen> createState() => _AddEventScreenState();
}

class _AddEventScreenState extends State<AddEventScreen>
    with TickerProviderStateMixin {
  final TextEditingController _eventNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  File? _selectedImage;
  bool _isSubmitting = false;
  DateTime? _selectedDate;
  final supabase = Supabase.instance.client;
  final FocusNode _eventNameFocus = FocusNode();
  final FocusNode _descriptionFocus = FocusNode();
  TimeOfDay? _selectedTime;




  // Animation controllers
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late AnimationController _scaleController;

  // Animations
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Initialize animations
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));

    // Start initial animations
    _slideController.forward();
    _fadeController.forward();
    _scaleController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    _eventNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });

      // Animate the image selection
      _scaleController.reset();
      _scaleController.forward();
    }
  }

  void _showDatePicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => SafeArea(
        child: Container(
          height: 300, // Prevent overflow
          color: CupertinoColors.systemGroupedBackground,
          child: Column(
            children: [
              SizedBox(
                height: 200,
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: (_selectedDate != null && _selectedDate!.isAfter(DateTime.now()))
                      ? _selectedDate!
                      : DateTime.now(),
                  onDateTimeChanged: (DateTime newDate) {
                    setState(() => _selectedDate = newDate);
                  },
                ),
              ),
              CupertinoButton(
                child: const Text('Done'),
                onPressed: () {
                  Navigator.pop(context);
                  _descriptionFocus.unfocus();
                  _eventNameFocus.unfocus();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitEvent() async {
    if (_eventNameController.text.isEmpty ||
        _descriptionController.text.isEmpty ||
        _selectedImage == null ||
        _selectedDate == null) {
      _showCupertinoDialog('Please fill all fields, pick a date, and select an image.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final fileBytes = await _selectedImage!.readAsBytes();
      final fileName = 'event_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Upload to Supabase Storage
      final uploadResult = await supabase.storage
          .from('events')
          .uploadBinary(
        fileName,
        fileBytes,
        fileOptions: const FileOptions(
          contentType: 'image/jpeg',
          upsert: true,
        ),
      );

      if (uploadResult.isEmpty) {
        throw Exception('Image upload failed.');
      }

      // Get Public URL
      final imageUrl = supabase.storage
          .from('events')
          .getPublicUrl(fileName);

      // Add to Firestore
      await FirebaseFirestore.instance
          .collection('admin')
          .doc('event_permission')
          .collection('events')
          .add({
        'event_name': _eventNameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'image_url': imageUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'event_date': Timestamp.fromDate(
          DateTime(
            _selectedDate!.year,
            _selectedDate!.month,
            _selectedDate!.day,
            _selectedTime?.hour ?? 0,
            _selectedTime?.minute ?? 0,
          ),
        ),
      });

      if (mounted) {
        if (context.mounted) {
          FocusScope.of(context).unfocus();
          _eventNameFocus.unfocus();
          _descriptionFocus.unfocus();
          final result = await showCupertinoModalPopup<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => const EventSuccessPopup(),
          );

          if (result == true) {
            _clearFields();
          }
        }
        _clearFields();

      }
    } catch (e) {
      _showCupertinoDialog('Error submitting event: $e');
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }



  void _clearFields() {
    _eventNameController.clear();
    _descriptionController.clear();
    _selectedDate = null;
    _selectedTime =null;
    _selectedImage =null;
  }


  void _showCupertinoDialog(String message) {
    showCupertinoDialog(
      context: context,
      builder: (_) =>
          CupertinoAlertDialog(
            title: const Text('Event Status'),
            content: Text(message),
            actions: [
              CupertinoDialogAction(
                isDefaultAction: true,
                child: const Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
    );
  }
  void _showTimePicker() {

    showCupertinoModalPopup(
      context: context,
      builder: (_) => SafeArea(
        child: Container(
          height: 300,
          color: CupertinoColors.systemGroupedBackground,
          child: Column(
            children: [
              SizedBox(
                height: 200,
                child: CupertinoTimerPicker(
                  mode: CupertinoTimerPickerMode.hm,
                  initialTimerDuration: _selectedTime != null
                      ? Duration(
                    hours: _selectedTime!.hour,
                    minutes: _selectedTime!.minute,
                  )
                      : const Duration(hours: 12),
                  onTimerDurationChanged: (Duration newDuration) {
                    setState(() {
                      _selectedTime = TimeOfDay(
                        hour: newDuration.inHours,
                        minute: newDuration.inMinutes.remainder(60),
                      );
                    });
                  },
                ),
              ),
              CupertinoButton(
                child: const Text('Done'),
                onPressed: () {
                  Navigator.of(context).pop();
                  _descriptionFocus.unfocus();
                  _eventNameFocus.unfocus();// Hide keyboard

                }
              ),
            ],
          ),
        ),
      ),
    );
  }






  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFF0A1A2F),
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Add Event',
        style: TextStyle(fontWeight: FontWeight.w400,
        color: Colors.white),),
        backgroundColor: CupertinoColors.white,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: CupertinoColors.systemGrey.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Create New Event',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Event Name Field
                    CupertinoTextField(
                      controller: _eventNameController,
                      focusNode: _eventNameFocus,
                      placeholder: 'Event Name',
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: CupertinoColors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade400,
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Description Field
                    CupertinoTextField(
                      controller: _descriptionController,
                      focusNode: _descriptionFocus,
                      placeholder: 'Event Description',
                      maxLines: 3,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: CupertinoColors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade400,
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Date Picker
                    GestureDetector(
                      onTap: _showDatePicker,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: CupertinoColors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.shade400,
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _selectedDate != null
                                  ? '${_selectedDate!.day}/${_selectedDate!
                                  .month}/${_selectedDate!.year}'
                                  : 'Select Event Date',
                              style: const TextStyle(
                                color: CupertinoColors.black,
                                fontSize: 16,
                              ),
                            ),
                            const Icon(CupertinoIcons.calendar),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: _showTimePicker,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        margin: const EdgeInsets.only(top: 20),
                        decoration: BoxDecoration(
                          color: CupertinoColors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.shade400,
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _selectedTime != null
                                  ? _selectedTime!.format(context)
                                  : 'Select Event Time',
                              style: const TextStyle(
                                color: CupertinoColors.black,
                                fontSize: 16,
                              ),
                            ),
                            const Icon(CupertinoIcons.time),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Image Picker
                    _selectedImage == null
                        ? Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: CupertinoColors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: CupertinoColors.systemGrey4,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            children: const [
                              Icon(
                                CupertinoIcons.photo_on_rectangle,
                                size: 40,
                                color: CupertinoColors.activeBlue,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Pick Image',
                                style: TextStyle(
                                  color: CupertinoColors.systemGrey,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                        : ScaleTransition(
                      scale: _scaleAnimation,
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                CupertinoIcons.check_mark_circled_solid,
                                color: CupertinoColors.activeGreen,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Image Selected',
                                style: TextStyle(
                                  color: CupertinoColors.activeGreen,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: _pickImage,
                                child: const Icon(
                                  CupertinoIcons.refresh_thick,
                                  color: CupertinoColors.activeBlue,
                                  size: 18,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              decoration: BoxDecoration(
                                boxShadow: [
                                  BoxShadow(
                                    color: CupertinoColors.systemGrey
                                        .withOpacity(0.2),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Image.file(
                                _selectedImage!,
                                height: 140,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: CupertinoButton(
                        borderRadius: BorderRadius.circular(12),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        color: const Color(0xFF4A90E2),
                        onPressed: _isSubmitting ? null : _submitEvent,
                        child: _isSubmitting
                            ? const CupertinoActivityIndicator(
                            color: CupertinoColors.white)
                            : const Text(
                          'Add Event',
                          style: TextStyle(
                            color: CupertinoColors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Cancel Button
                    SizedBox(
                      width: double.infinity,
                      child: CupertinoButton(
                        borderRadius: BorderRadius.circular(12),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        color: CupertinoColors.white,
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: CupertinoColors.systemGrey,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
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
    );
  }
}

// Success Popup Widget
class EventSuccessPopup extends StatefulWidget {
  const EventSuccessPopup({super.key});

  @override
  State<EventSuccessPopup> createState() => _EventSuccessPopupState();
}

class _EventSuccessPopupState extends State<EventSuccessPopup>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _checkmarkController;
  late AnimationController _fadeController;

  late Animation<double> _scaleAnimation;
  late Animation<double> _checkmarkAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _checkmarkController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));

    _checkmarkAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _checkmarkController,
      curve: Curves.easeInOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    // Start animations
    _scaleController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _checkmarkController.forward();
    });

    // Auto dismiss after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      _dismissPopup();
    });
  }

  void _dismissPopup() async {
    await _fadeController.forward();
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _checkmarkController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        color: CupertinoColors.black.withOpacity(0.7),
        child: Center(
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: CupertinoColors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: CupertinoColors.black.withOpacity(0.25),
                    blurRadius: 25,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Calendar Icon
                  Container(
                    width: 80,
                    height: 80,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A90E2),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4A90E2).withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      CupertinoIcons.calendar_badge_plus,
                      color: CupertinoColors.white,
                      size: 40,
                    ),
                  ),

                  // Success Title
                  const Text(
                    'Event Created Successfully!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: CupertinoColors.black,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Success Description
                  const Text(
                    'Your event has been created and saved to your calendar. You can now view and manage it from your events list.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: CupertinoColors.systemGrey,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Animated Checkmark
                  AnimatedBuilder(
                    animation: _checkmarkAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _checkmarkAnimation.value,
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: CupertinoColors.activeGreen,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: CupertinoColors.activeGreen.withOpacity(0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: const Icon(
                            CupertinoIcons.check_mark,
                            color: CupertinoColors.white,
                            size: 30,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}