import 'dart:io';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:visimgnt/screens/security/visitor_card.dart';

class VisitorDetails extends StatefulWidget {
  final File? profileImage;

  const VisitorDetails({Key? key, required this.profileImage}) : super(key: key);

  @override
  State<VisitorDetails> createState() => _VisitorDetailsState();
}

class _VisitorDetailsState extends State<VisitorDetails> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _purposeController = TextEditingController();

  bool _isPhoneVerified = false;
  bool _phoneVerificationAttempted = false;
  bool _isPhoneEditable = true;
  final TextEditingController _otpController = TextEditingController();
  bool _showOTPField = false;
  String _verificationId = '';
  bool _isSubmitting = false;
  bool _phoneVerificationFailed = false;

  String? _selectedDepartment;
  String? _selectedPurpose;
  String? _selectedVisitedTo;
  String? _selectedVisitorType;

  List<String> _departments = [];
  List<Map<String, dynamic>> _facultyMembers = [];
  bool _isLoadingDepartments = true;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  final Map<TextEditingController, FocusNode> _focusNodes = {};
  final FocusNode _phoneFocusNode = FocusNode();

  final List<String> _visitorTypes = ['PARENT', 'DELIVERY', 'STUDENT', 'OTHER'];
  final List<String> _purposes = [
    'To meet the Principal',
    'To visit Admin Block',
    'To attend a seminar/workshop',
    'To collect certificates/documents',
    'To inquire about admissions',
    'To meet a faculty member',
    'To attend an interview',
    'For an academic project discussion',
    'To visit the library',
    'Others'
  ];
  final List<String> _department = [
    'MCA',
    'MBA',
    'Others'
  ];

  @override
  void initState() {
    super.initState();
    _loadDepartments();
    _initializeAnimations();
    _setupFocusNodes();

  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    _fadeController.forward();
    _slideController.forward();
  }

  void _setupFocusNodes() {
    _phoneFocusNode.addListener(() {
      setState(() {});
    });
  }

  Future<void> _loadDepartments() async {
    try {
      final firestore = FirebaseFirestore.instance;

      // Step 1: Get list of department names from 'departments' collection
      final departmentsSnapshot = await firestore.collection('departments').get();
      final List<String> departmentNames = ['MCA', 'MBA', 'BBA', 'MTECH', 'BCA'];

      Set<String> departmentSet = {};
      List<Map<String, dynamic>> facultyList = [];

      // Step 2: Load faculty members for each department
      for (String department in departmentNames) {
        final querySnapshot = await firestore
            .collection('users')
            .doc('faculty')
            .collection(department)
            .get();

        departmentSet.add(department);

        for (var doc in querySnapshot.docs) {
          final data = doc.data();
          facultyList.add({
            'name': data['name'] ?? 'Unknown',
            'department': department,
            'userId': doc.id,
          });
        }
      }

      // Step 3: Update state
      setState(() {
        _departments = departmentSet.toList()..sort();
        _facultyMembers = facultyList;
        _isLoadingDepartments = false;
      });
    } catch (e) {
      print('Error loading departments: $e');
      setState(() {
        _isLoadingDepartments = false;
      });
    }
  }



  List<Map<String, dynamic>> _getFacultyByDepartment(String department) {
    return _facultyMembers
        .where((faculty) => faculty['department'] == department)
        .toList();
  }


  double _getProgressPercentage() {
    int filledFields = 0;
    int totalFields = 6; // name, phone, email, visitor type, purpose, department

    if (_nameController.text.isNotEmpty) filledFields++;
    if (_isPhoneVerified) filledFields++;
    if (_emailController.text.isNotEmpty) filledFields++;
    if (_selectedVisitorType != null) filledFields++;
    if (_selectedPurpose != null) filledFields++;
    if (_selectedDepartment != null) filledFields++;

    return filledFields / totalFields;
  }

  bool _isAllFieldsFilled() {
    return _nameController.text.isNotEmpty &&
        _isPhoneVerified &&
        _selectedVisitorType != null &&
        _selectedPurpose != null &&
        _selectedDepartment != null &&
        (_selectedPurpose == 'To meet the Principal' || _selectedVisitedTo != null);
  }

  void _moveToNextScreen() {
    if (_selectedPurpose == 'To meet the Principal') {
      // Direct navigation for Principal meeting
      Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (context) => VisitorCard(
            profileImage: widget.profileImage!,
            name: _nameController.text,
            email: _emailController.text,
            phone: _phoneController.text,
            purpose: _selectedPurpose ?? '',
            department: _selectedDepartment!,
            visitedToDisplay: 'Principal',
            visitedToUsername: 'PRINCIPAL',
            visitedType: _selectedVisitorType!,
          ),
        ),
      );
    } else {
      _submitForm();
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _purposeController.dispose();
    _phoneFocusNode.dispose();
    _focusNodes.values.forEach((node) => node.dispose());
    super.dispose();
  }

  Future<void> _sendOTP() async {
    final phoneNumber = _phoneController.text.trim();
    if (phoneNumber.isEmpty || !RegExp(r'^[6-9]\d{9}$').hasMatch(phoneNumber)) {
      _showSnackBar('Please enter a valid phone number', Colors.red);
      return;
    }

    try {
      setState(() {
        _showOTPField = true;
      });

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: '+91$phoneNumber',
        verificationCompleted: (PhoneAuthCredential credential) async {
          await FirebaseAuth.instance.signInWithCredential(credential);
          setState(() {
            _isPhoneVerified = true;
            _phoneVerificationAttempted = true;
            _showOTPField = false;
            _isPhoneEditable = false;
          });
        },
        verificationFailed: (FirebaseAuthException e) {
          _showSnackBar('Verification failed: ${e.message}', Colors.red);
          setState(() {
            _phoneVerificationAttempted = true;
            _isPhoneVerified = false;
            _showOTPField = false;
          });
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      _showSnackBar('Error sending OTP: $e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _submitForm() async {
    if (!_isPhoneVerified) {
      _showSnackBar('Please verify your phone number before proceeding.', Colors.red);
      return;
    }

    if (_formKey.currentState!.validate() && _selectedDepartment != null) {
      setState(() {
        _isSubmitting = true;
      });

      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });

        _showSnackBar('Registration Successful! Welcome, ${_nameController.text}', Colors.green);

        final selectedFaculty = _facultyMembers.firstWhere(
              (f) => f['userId'] == _selectedVisitedTo,
          orElse: () => {'name': 'Unknown', 'userId': _selectedVisitedTo},
        );

        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => VisitorCard(
              profileImage: widget.profileImage!,
              name: _nameController.text,
              email: _emailController.text,
              phone: _phoneController.text,
              purpose: _selectedPurpose ?? '',
              department: _selectedDepartment!,
              visitedToDisplay: selectedFaculty['name'],       // show display name
              visitedToUsername: selectedFaculty['userId'],    // use userId for backend
              visitedType: _selectedVisitorType!,
            ),
          ),
        );

      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Column(
              children: [
                _buildAppBar(),
                _buildProgressBar(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _buildProfileSection(),
                          const SizedBox(height: 32),
                          _buildInputField(
                            controller: _nameController,
                            label: 'Full Name',
                            icon: Icons.person_outline,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your full name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          _buildPhoneField(),
                          const SizedBox(height: 24),
                          _buildInputField(
                            controller: _emailController,
                            label: 'Email Address',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            isOptional: true,
                            validator: (value) {
                              if (value != null && value.isNotEmpty) {
                                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                  return 'Please enter a valid email address';
                                }
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          _buildDropdown(
                            value: _selectedVisitorType,
                            items: _visitorTypes,
                            label: 'Select Visitor Type',
                            icon: Icons.person_pin_outlined,
                            onChanged: (value) => setState(() => _selectedVisitorType = value),
                          ),
                          const SizedBox(height: 24),
                          _buildDropdown(
                            value: _selectedPurpose,
                            items: _purposes,
                            label: 'Purpose of Visit',
                            icon: Icons.business_outlined,
                            onChanged: (value) {
                              setState(() {
                                _selectedPurpose = value;
                                if (value == 'To meet the Principal') {
                                  _selectedVisitedTo = null;
                                }
                              });
                            },
                          ),
                          const SizedBox(height: 24),
                          _buildDepartmentDropdown(),
                          const SizedBox(height: 24),
                          if (_selectedPurpose != 'To meet the Principal' && _selectedDepartment != null)
                            _buildFacultyDropdown(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(CupertinoIcons.back, size: 19,
            color: Colors.black,),
          ),
          const Expanded(
            child: Text(
              'Complete Your Profile',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w400,
                color: Colors.black,
              ),
            ),
          ),
          if (_isAllFieldsFilled())
            IconButton(
              onPressed: _moveToNextScreen,
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progress',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${(_getProgressPercentage() * 100).round()}%',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.blue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: _getProgressPercentage(),
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSection() {
    return Column(
      children: [
        if (widget.profileImage != null)
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey[500]!, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipOval(
              child: Image.file(
                widget.profileImage!,
                fit: BoxFit.cover,

              ),
            ),
          ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.green.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified, color: Colors.green, size: 16),
              const SizedBox(width: 8),
              Text(
                'Face Verified',
                style: TextStyle(
                  color: Colors.green[700],
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    bool isOptional = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        onChanged: (_) => setState(() {}),
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.grey[600]),
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[600]),
          suffixText: isOptional ? 'Optional' : null,
          suffixStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildPhoneField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          TextFormField(
            controller: _phoneController,
            enabled: _isPhoneEditable,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.phone_outlined, color: Colors.grey[600]),
              labelText: 'Phone Number',
              labelStyle: TextStyle(color: Colors.grey[600]),
              suffixIcon: _isPhoneVerified
                  ? const Icon(Icons.verified, color: Colors.green)
                  : IconButton(
                onPressed: () => _sendOTP(),
                icon: const Icon(Icons.send, color: Colors.blue),
              ),
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Please enter phone number';
              if (!RegExp(r'^[6-9][0-9]{9}$').hasMatch(value)) return 'Enter valid 10-digit number';
              return null;
            },
          ),
          if (_showOTPField && !_isPhoneVerified) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextFormField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.lock_outline, color: Colors.grey[600]),
                      labelText: 'Enter OTP',
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final otp = _otpController.text.trim();
                        if (otp.length == 6) {
                          try {
                            final credential = PhoneAuthProvider.credential(
                              verificationId: _verificationId,
                              smsCode: otp,
                            );
                            await FirebaseAuth.instance.signInWithCredential(credential);
                            setState(() {
                              _isPhoneVerified = true;
                              _showOTPField = false;
                              _isPhoneEditable = false;
                            });
                            _showSnackBar('Phone number verified!', Colors.green);
                          } catch (e) {
                            _showSnackBar('Invalid OTP', Colors.red);
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Verify OTP',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required List<String> items,
    required String label,
    required IconData icon,
    required Function(String?) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.grey[600]),
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[600]),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        items: items.map((item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(item, style: const TextStyle(fontSize: 16)),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildDepartmentDropdown() {
    if (_isLoadingDepartments) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        padding: const EdgeInsets.all(16),
        child: const Row(
          children: [
            Icon(Icons.school_outlined, color: Colors.grey),
            SizedBox(width: 16),
            Text('Loading departments...'),
            Spacer(),
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ),
      );
    }

    if (_departments.isEmpty) {
      return const Text("No departments found.");
    }

    return _buildDropdown(
      value: _selectedDepartment,
      items: _departments,
      label: 'Select Department',
      icon: Icons.school_outlined,
      onChanged: (value) {
        setState(() {
          _selectedDepartment = value;
          _selectedVisitedTo = null; // Reset faculty selection
        });
      },
    );
  }


  Widget _buildFacultyDropdown() {
    final faculty = _getFacultyByDepartment(_selectedDepartment!);

    if (faculty.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        padding: const EdgeInsets.all(16),
        child: const Row(
          children: [
            Icon(Icons.person_outline, color: Colors.grey),
            SizedBox(width: 16),
            Text('No faculty found for this department'),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: DropdownButtonFormField<String>(
        value: faculty.any((f) => f['userId'] == _selectedVisitedTo)
            ? _selectedVisitedTo
            : null,
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.person_outline, color: Colors.grey[600]),
          labelText: 'Select Faculty Member',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        items: faculty.map((f) {
          return DropdownMenuItem<String>(
            value: f['userId'],
            child: Text(f['name']),
          );
        }).toList(),
        onChanged: (value) => setState(() => _selectedVisitedTo = value),
      ),
    );
  }



  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isSubmitting || !_isAllFieldsFilled() ? null : _moveToNextScreen,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          disabledBackgroundColor: Colors.grey[300],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: _isSubmitting
            ? const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Submitting...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        )
            : const Text(
          'Complete Registration',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}