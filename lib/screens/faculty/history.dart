import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HistoryScreen extends StatefulWidget {
  final String userId;

  const HistoryScreen({super.key, required this.userId});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String? username;
  bool isLoading = true;
  String selectedTab = 'visited'; // 'visited' or 'cancelled'

  // Date filtering variables
  DateTime? fromDate;
  DateTime? toDate;
  bool isFilterExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final userId = widget.userId;
      final department = userId.substring(0, 3); // Extracts 'MCA', 'MBA', etc.

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc('faculty')
          .collection(department)
          .doc(userId)
          .get();

      if (userDoc.exists && userDoc.data() != null) {
        final userData = userDoc.data()!;
        setState(() {
          username = userData['username'] ?? 'Unknown';
          isLoading = false;
        });
      } else {
        print('User document not found.');
        setState(() => isLoading = false);
      }
    } catch (e, stack) {
      print('Error loading user data: $e\n$stack');
      setState(() => isLoading = false);
    }
  }


  Future<void> _selectDate(BuildContext context, bool isFromDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isFromDate ? (fromDate ?? DateTime.now()) : (toDate ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.blue,
              onPrimary: Colors.white,
              surface: Color(0xFF1A2332),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF1A2332),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isFromDate) {
          fromDate = picked;
          // If fromDate is after toDate, clear toDate
          if (toDate != null && fromDate!.isAfter(toDate!)) {
            toDate = null;
          }
        } else {
          // Only allow toDate if fromDate is selected and toDate is after fromDate
          if (fromDate != null && picked.isAfter(fromDate!.subtract(const Duration(days: 1)))) {
            toDate = picked;
          } else if (fromDate == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please select "From Date" first'),
                backgroundColor: Colors.orange,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('To Date must be after From Date'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      });
    }
  }

  void _clearFilters() {
    setState(() {
      fromDate = null;
      toDate = null;
    });
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Query _buildQuery() {
    final collection = selectedTab == 'visited' ? 'visitors-met' : 'visitors-denied';
    final dateField = selectedTab == 'visited' ? 'met_at' : 'denied_at';

    Query query = FirebaseFirestore.instance
        .collection(collection)
        .where('visited_to_username', isEqualTo: username);

    if (fromDate != null) {
      query = query.where(dateField, isGreaterThanOrEqualTo: fromDate!.toIso8601String());
    }

    if (toDate != null) {
      // Add 1 day to include the entire selected date
      final endOfToDate = DateTime(toDate!.year, toDate!.month, toDate!.day, 23, 59, 59);
      query = query.where(dateField, isLessThanOrEqualTo: endOfToDate.toIso8601String());
    }

    return query.orderBy(dateField, descending: true);
  }

  Widget _buildFilterSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: [
          // Filter Header
          GestureDetector(
            onTap: () {
              setState(() {
                isFilterExpanded = !isFilterExpanded;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.filter_list, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Date Filter',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (fromDate != null || toDate != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Active',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Icon(
                    isFilterExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),

          // Filter Content
          if (isFilterExpanded) ...[
            const Divider(color: Colors.white24, height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Date selection buttons
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _selectDate(context, true),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: fromDate != null
                                  ? Colors.blue.withOpacity(0.2)
                                  : Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: fromDate != null ? Colors.blue : Colors.white24,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'From Date',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  fromDate != null ? _formatDate(fromDate!) : 'Select date',
                                  style: TextStyle(
                                    color: fromDate != null ? Colors.blue : Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _selectDate(context, false),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: toDate != null
                                  ? Colors.blue.withOpacity(0.2)
                                  : Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: toDate != null ? Colors.blue : Colors.white24,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'To Date',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  toDate != null ? _formatDate(toDate!) : 'Select date',
                                  style: TextStyle(
                                    color: toDate != null ? Colors.blue : Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Quick filter buttons
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              fromDate = DateTime.now().subtract(const Duration(days: 7));
                              toDate = DateTime.now();
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Last 7 days',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              fromDate = DateTime.now().subtract(const Duration(days: 30));
                              toDate = DateTime.now();
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Last 30 days',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _clearFilters,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.clear,
                            color: Colors.red,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHistoryList(AsyncSnapshot<QuerySnapshot> snapshot, String type) {
    if (snapshot.hasError) {
      return Text(
        'Error: ${snapshot.error}',
        style: const TextStyle(color: Colors.white),
      );
    }

    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          children: [
            Icon(
              type == 'visited' ? Icons.check_circle_outline : Icons.cancel_outlined,
              size: 48,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              fromDate != null || toDate != null
                  ? 'No ${type} visitors in selected date range'
                  : 'No ${type} visitors',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              fromDate != null || toDate != null
                  ? 'Try adjusting your date filter'
                  : 'All ${type} visitors will appear here',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: snapshot.data!.docs.length,
      itemBuilder: (context, index) {
        final doc = snapshot.data!.docs[index];
        final visitor = doc.data()! as Map<String, dynamic>;

        DateTime? registeredAt;
        DateTime? actionAt;

        try {
          registeredAt = DateTime.parse(visitor['registered_at']);
        } catch (_) {
          registeredAt = null;
        }

        try {
          actionAt = DateTime.parse(visitor[type == 'visited' ? 'met_at' : 'denied_at']);
        } catch (_) {
          actionAt = null;
        }

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24),
          ),
          child: GestureDetector(
            onTap: () {
              final imageUrl = visitor['visitor_pass_url'] ?? '';
              if (imageUrl.isNotEmpty) {
                showDialog(
                  context: context,
                  builder: (_) => Dialog(
                    backgroundColor: Colors.transparent,
                    insetPadding: const EdgeInsets.all(10),
                    child: Container(
                      height: 650,
                      width: 340,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        image: DecorationImage(
                          image: NetworkImage(imageUrl),
                          fit: BoxFit.cover,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("No image available for this visitor"),
                  ),
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Profile Picture
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white24,
                            width: 1.5,
                          ),
                        ),
                        child: visitor['profile_image_url'] != null && visitor['profile_image_url'].toString().isNotEmpty
                            ? ClipOval(
                          child: Image.network(
                            visitor['profile_image_url'],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Icon(Icons.person, color: Colors.white54),
                          ),
                        )
                            : CircleAvatar(
                          backgroundColor: Colors.white12,
                          child: Icon(Icons.person, color: Colors.white54),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Visitor Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              visitor['name'] ?? 'Unknown',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: type == 'visited'
                                    ? Colors.green.withOpacity(0.2)
                                    : Colors.orange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                type == 'visited' ? 'VISITED' : 'DENIED',
                                style: TextStyle(
                                  color: type == 'visited' ? Colors.green : Colors.orange,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Optional pass badge
                      if (visitor['visitor_pass_url']?.isNotEmpty ?? false)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Tap for pass',
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  Text(
                    'Purpose: ${visitor['purpose'] ?? 'Not specified'}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Phone: ${visitor['phone'] ?? 'Not provided'}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                  if (registeredAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Registered: ${registeredAt.toLocal().toString().split('.')[0]}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white54,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  if (actionAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${type == 'visited' ? 'Visited' : 'Cancelled'}: ${actionAt.toLocal().toString().split('.')[0]}',
                      style: TextStyle(
                        fontSize: 12,
                        color: type == 'visited' ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _refreshData() async {
    await _loadUserData();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A1A2F),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (username == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A1A2F),
        body: Center(
          child: Text('User not found', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A1A2F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1A2F),
        elevation: 0,
        title: const Text(
          'Visitor History',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshData,
          backgroundColor: const Color(0xFF1A2332),
          color: Colors.white,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // TAB BUTTONS
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedTab = 'visited';
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: selectedTab == 'visited'
                                    ? Colors.green.withOpacity(0.8)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: selectedTab == 'visited'
                                        ? Colors.white
                                        : Colors.green,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Visited',
                                    style: TextStyle(
                                      color: selectedTab == 'visited'
                                          ? Colors.white
                                          : Colors.green,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedTab = 'cancelled';
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: selectedTab == 'cancelled'
                                    ? Colors.orange.withOpacity(0.8)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.cancel,
                                    color: selectedTab == 'cancelled'
                                        ? Colors.white
                                        : Colors.orange,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Cancelled',
                                    style: TextStyle(
                                      color: selectedTab == 'cancelled'
                                          ? Colors.white
                                          : Colors.orange,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // DATE FILTER SECTION
                  _buildFilterSection(),
                  // HISTORY LIST FROM FIRESTORE
                  StreamBuilder<QuerySnapshot>(
                    stream: _buildQuery().snapshots(),
                    builder: (context, snapshot) {
                      // Show loading while fetching data
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Column(
                          children: [
                            // HISTORY LIST TITLE with loading count
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${selectedTab == 'visited' ? 'Visited' : 'Cancelled'} Visitors',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: (selectedTab == 'visited' ? Colors.green : Colors.orange).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: (selectedTab == 'visited' ? Colors.green : Colors.orange).withOpacity(0.3)),
                                  ),
                                  child: SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          selectedTab == 'visited' ? Colors.green : Colors.orange
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Center(child: CircularProgressIndicator()),
                          ],
                        );
                      }

                      // Calculate count from the same data
                      final count = snapshot.hasData ? snapshot.data!.docs.length : 0;

                      return Column(
                        children: [
                          // HISTORY LIST TITLE with count
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '${selectedTab == 'visited' ? 'Visited' : 'Cancelled'} Visitors',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: (selectedTab == 'visited' ? Colors.green : Colors.orange).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: (selectedTab == 'visited' ? Colors.green : Colors.orange).withOpacity(0.3)),
                                ),
                                child: Text(
                                  '$count',
                                  style: TextStyle(
                                    color: selectedTab == 'visited' ? Colors.green : Colors.orange,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // HISTORY LIST CONTENT
                          _buildHistoryList(snapshot, selectedTab),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}