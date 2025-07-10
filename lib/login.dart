import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visimgnt/screens/admin/admin_home.dart';
import 'package:visimgnt/screens/admin/admin_navbar.dart';
import 'package:visimgnt/screens/faculty/faculty_home.dart';
import 'package:visimgnt/screens/faculty/faculty_navbar.dart';
import 'package:visimgnt/screens/security/security_home.dart';
import 'package:visimgnt/screens/security/security_navbar.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _departmentController = TextEditingController();
  final _designationController = TextEditingController();

  String _selectedRole = 'faculty';
  String? _selectedDepartment;
  String? _selectedDesignation;

  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;

  final _firestore = FirebaseFirestore.instance;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final List<String> departments = ['MCA', 'BBA', 'BCA', 'MTech'];
  final List<String> designations = ['Professor', 'Assistant Professor','Associate Professor'];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  Future<void> _performLogin(String username, String password) async {
    setState(() => _isLoading = true);
    try {
      DocumentSnapshot doc;
      DocumentReference userRef;

      // Assume faculty if ID starts with uppercase letters
      if (username.contains(RegExp(r'^[A-Z]+[0-9]+'))) {
        String prefix = username.replaceAll(RegExp(r'\d'), '');

        userRef = _firestore
            .collection('users')
            .doc('faculty')
            .collection(prefix)
            .doc(username);

        doc = await userRef.get();

        if (!doc.exists) throw Exception('User not found');
      } else {
        // Admin/Security
        userRef = _firestore.collection('users').doc(username);
        doc = await userRef.get();

        if (!doc.exists) throw Exception('User not found');
      }

      if (doc['password'] != password) throw Exception('Incorrect password');

      await _saveCredentials(username, password);

      final role = doc['role'] ?? 'faculty';
      if (role == 'security') {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => SecurityNavbar(userId: username)));
      } else if (role == 'admin') {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => AdminNavbar(userId: username)));
      } else {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => FacultyNavbar(userId: username)));
      }
    } catch (e) {
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }




  Future<void> _saveCredentials(String username, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('savedUsername', username);
    await prefs.setString('savedPassword', password);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (_isLogin) {
      await _performLogin(username, password);
    } else {
      setState(() => _isLoading = true);
      try {
        DocumentReference userRef;
        DocumentSnapshot doc;

        if (_selectedRole == 'faculty') {
          final department = _selectedDepartment;
          if (department == null || department.isEmpty) throw Exception('Department not selected');

          userRef = _firestore
              .collection('users')
              .doc('faculty')
              .collection(department)
              .doc(username);
          doc = await userRef.get();
        } else {
          userRef = _firestore.collection('users').doc(username);
          doc = await userRef.get();
        }

        if (doc.exists) throw Exception('Username already exists');

        await userRef.set({
          'username': username,
          'password': password,
          'role': _selectedRole,
          'createdAt': FieldValue.serverTimestamp(),
          if (_selectedRole == 'faculty') ...{
            'name': _nameController.text.trim(),
            'department': _selectedDepartment ?? '',
            'designation': _selectedDesignation ?? '',
          },
        });

        await _saveCredentials(username, password);

        if (_selectedRole == 'security') {
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (_) => SecurityNavbar(userId: username)));
        } else if (_selectedRole == 'admin') {
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (_) => AdminNavbar(userId: username)));
        } else {
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (_) => FacultyNavbar(userId: username)));
        }
      } catch (e) {
        _showError(e.toString().replaceFirst('Exception: ', ''));
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1A2F),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  SizedBox(
                    height: 130,
                    width: 220,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(25),
                      child: Image.asset('assets/amclogo.png', fit: BoxFit.contain),
                    ),
                  ),
                  const SizedBox(height: 100),
                  Text(
                    _isLogin ? 'Sign In' : 'Register Account',
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isLogin ? 'Sign in to continue' : 'Create an account to proceed',
                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16),
                  ),
                  const SizedBox(height: 40),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _buildInputField(_usernameController, 'Username', Icons.person),
                        const SizedBox(height: 20),
                        _buildInputField(_passwordController, 'Password', Icons.lock, isPassword: true),
                        if (!_isLogin)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 20),
                              DropdownButtonFormField<String>(
                                value: _selectedRole,
                                dropdownColor: const Color(0xFF1F2C44),
                                decoration: _dropdownDecoration("Select Role"),
                                style: const TextStyle(color: Colors.white),
                                onChanged: (val) => setState(() {
                                  _selectedRole = val!;
                                  _selectedDepartment = null;
                                  _selectedDesignation = null;
                                }),
                                items: const [
                                  DropdownMenuItem(value: 'faculty', child: Text('Faculty')),
                                  DropdownMenuItem(value: 'security', child: Text('Security')),
                                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                                ],
                              ),
                              const SizedBox(height: 20),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 400),
                                child: _selectedRole == 'faculty'
                                    ? Column(
                                  key: const ValueKey('facultyFields'),
                                  children: [
                                    _buildInputField(_nameController, 'Name', Icons.person),
                                    const SizedBox(height: 16),
                                    DropdownButtonFormField<String>(
                                      value: _selectedDepartment,
                                      decoration: _dropdownDecoration("Select Department"),
                                      dropdownColor: const Color(0xFF1F2C44),
                                      style: const TextStyle(color: Colors.white),
                                      items: departments
                                          .map((dep) =>
                                          DropdownMenuItem(value: dep, child: Text(dep)))
                                          .toList(),
                                      onChanged: (val) => setState(() => _selectedDepartment = val),
                                      validator: (value) =>
                                      value == null ? 'Select department' : null,
                                    ),
                                    const SizedBox(height: 16),
                                    DropdownButtonFormField<String>(
                                      value: _selectedDesignation,
                                      decoration: _dropdownDecoration("Select Designation"),
                                      dropdownColor: const Color(0xFF1F2C44),
                                      style: const TextStyle(color: Colors.white),
                                      items: designations
                                          .map((des) =>
                                          DropdownMenuItem(value: des, child: Text(des)))
                                          .toList(),
                                      onChanged: (val) => setState(() => _selectedDesignation = val),
                                      validator: (value) =>
                                      value == null ? 'Select designation' : null,
                                    ),
                                  ],
                                )
                                    : const SizedBox.shrink(key: ValueKey('empty')),
                              ),
                            ],
                          ),
                        const SizedBox(height: 35),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleSubmit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF0A1A2F),
                              elevation: 8,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: _isLoading
                                ? const CupertinoActivityIndicator(color: Color(0xFF0A1A2F))
                                : Text(
                              _isLogin ? 'Sign In' : 'Register',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextButton(
                          onPressed: () {
                            setState(() => _isLogin = !_isLogin);
                            _animationController.forward(from: 0);
                          },
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 15),
                              children: [
                                TextSpan(
                                  text: _isLogin ? "Don't have an account? " : "Already registered? ",
                                ),
                                TextSpan(
                                  text: _isLogin ? 'Register' : 'Sign In',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _dropdownDecoration(String label) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Colors.white),
    filled: true,
    fillColor: Colors.white.withOpacity(0.1),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
  );

  Widget _buildInputField(
      TextEditingController controller,
      String hint,
      IconData icon, {
        bool isPassword = false,
      }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword ? _obscurePassword : false,
      validator: (value) => value!.isEmpty ? 'Enter $hint' : null,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        prefixIcon: Icon(icon, color: Colors.white70),
        suffixIcon: isPassword
            ? IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility : Icons.visibility_off,
            color: Colors.white70,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        )
            : null,
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        errorStyle: TextStyle(color: Colors.red.shade300),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _departmentController.dispose();
    _designationController.dispose();
    super.dispose();
  }
}
