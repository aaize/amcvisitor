import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SecurityVisitors extends StatefulWidget {
  const SecurityVisitors({super.key});

  @override
  State<SecurityVisitors> createState() => _SecurityVisitorsState();
}

class _SecurityVisitorsState extends State<SecurityVisitors> {
  bool isLoading = false;
  String selectedTab = 'pending'; // Changed default to 'pending'

  // Date filtering variables
  DateTime? fromDate;
  DateTime? toDate;
  bool isFilterExpanded = false;

  // Search variables
  String searchQuery = '';
  TextEditingController searchController = TextEditingController();

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
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
      searchQuery = '';
      searchController.clear();
    });
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Query _buildQuery() {
    String collection;
    String dateField;

    switch (selectedTab) {
      case 'pending':
        collection = 'visitors';
        dateField = 'registered_at';
        break;
      case 'visited':
        collection = 'visitors-met';
        dateField = 'met_at';
        break;
      case 'cancelled':
        collection = 'visitors-cancelled';
        dateField = 'cancelled_at';
        break;
      default:
        collection = 'visitors-registered';
        dateField = 'registered_at';
    }

    Query query = FirebaseFirestore.instance.collection(collection);

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

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: TextField(
        controller: searchController,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search by name, phone, or host...',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
          prefixIcon: const Icon(Icons.search, color: Colors.white54),
          suffixIcon: searchQuery.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.clear, color: Colors.white54),
            onPressed: () {
              setState(() {
                searchQuery = '';
                searchController.clear();
              });
            },
          )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
        onChanged: (value) {
          setState(() {
            searchQuery = value.toLowerCase();
          });
        },
      ),
    );
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

  List<QueryDocumentSnapshot> _filterResults(List<QueryDocumentSnapshot> docs) {
    if (searchQuery.isEmpty) return docs;

    return docs.where((doc) {
      final visitor = doc.data()! as Map<String, dynamic>;
      final name = (visitor['name'] ?? '').toString().toLowerCase();
      final phone = (visitor['phone'] ?? '').toString().toLowerCase();
      final hostUsername = (visitor['visited_to_username'] ?? '').toString().toLowerCase();
      final purpose = (visitor['purpose'] ?? '').toString().toLowerCase();

      return name.contains(searchQuery) ||
          phone.contains(searchQuery) ||
          hostUsername.contains(searchQuery) ||
          purpose.contains(searchQuery);
    }).toList();
  }

  Widget _buildHistoryList(AsyncSnapshot<QuerySnapshot> snapshot, String type) {
    if (snapshot.hasError) {
      return Text(
        'Error: ${snapshot.error}',
        style: const TextStyle(color: Colors.white),
      );
    }

    if (!snapshot.hasData) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredDocs = _filterResults(snapshot.data!.docs);

    if (filteredDocs.isEmpty) {
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
              type == 'pending' ? Icons.schedule :
              type == 'visited' ? Icons.check_circle_outline : Icons.cancel_outlined,
              size: 48,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              searchQuery.isNotEmpty
                  ? 'No ${type} visitors match your search'
                  : fromDate != null || toDate != null
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
              searchQuery.isNotEmpty
                  ? 'Try adjusting your search terms'
                  : fromDate != null || toDate != null
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
      itemCount: filteredDocs.length,
      itemBuilder: (context, index) {
        final doc = filteredDocs[index];
        final visitor = doc.data()! as Map<String, dynamic>;

        DateTime? registeredAt;
        DateTime? actionAt;

        try {
          registeredAt = DateTime.parse(visitor['registered_at']);
        } catch (_) {
          registeredAt = null;
        }

        try {
          String actionField = type == 'pending' ? 'registered_at' :
          type == 'visited' ? 'met_at' : 'cancelled_at';
          actionAt = DateTime.parse(visitor[actionField]);
        } catch (_) {
          actionAt = null;
        }

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.08),
                Colors.white.withOpacity(0.03),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
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
                      height: 590,
                      width: 320,
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
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // Large Profile Image - Updated to use visitor's profile image
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _buildVisitorAvatar(visitor),
                  ),

                  const SizedBox(width: 20),

                  // Visitor Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name and Status Badge Row
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                visitor['name'] ?? 'Unknown Visitor',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.1,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Status Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: type == 'pending'
                                      ? [
                                    Colors.amber.withOpacity(0.3),
                                    Colors.amber.withOpacity(0.5),
                                  ]
                                      : type == 'visited'
                                      ? [
                                    Colors.green.withOpacity(0.8),
                                    Colors.green.withOpacity(0.6),
                                  ]
                                      : [
                                    Colors.orange.withOpacity(0.8),
                                    Colors.orange.withOpacity(0.6),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: [
                                  BoxShadow(
                                    color: (type == 'pending' ? Colors.amber :
                                    type == 'visited' ? Colors.green : Colors.orange).withOpacity(0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    type == 'pending' ? Icons.schedule :
                                    type == 'visited' ? Icons.check_circle : Icons.cancel,
                                    color: Colors.amber,
                                    size: 12,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    type == 'pending' ? 'Pending' :
                                    type == 'visited' ? 'Visited' : 'Cancelled',
                                    style: const TextStyle(
                                      color: Colors.amber,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Purpose
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.blue.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.work_outline,
                                color: Colors.blue.shade300,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  visitor['purpose'] ?? 'General Visit',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.blue.shade200,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Host Information
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              color: Colors.white60,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${visitor['visited_to_username'] ?? 'Unknown'}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withOpacity(0.75),
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Icon(CupertinoIcons.building_2_fill,
                            color: Colors.white60,
                            size: 14,),
                            const SizedBox(width: 6),
                            Expanded(child: Text(
                              '${visitor['department'] ?? 'Unknown'}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.75),
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            ),

                          ],

                        ),

                        const SizedBox(height: 4),

                        // Phone
                        Row(
                          children: [
                            Icon(
                              Icons.phone_outlined,
                              color: Colors.white60,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                visitor['phone'] ?? 'No phone provided',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withOpacity(0.75),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 4),

                        // Registration and Action Time
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (registeredAt != null)
                              Row(
                                children: [
                                  Icon(
                                    Icons.login,
                                    color: Colors.white60,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Registered: ${_formatDateTime(registeredAt)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white54,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            if (actionAt != null && type != 'pending') ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(
                                    type == 'visited' ? Icons.check_circle_outline : Icons.cancel_outlined,
                                    color: type == 'visited' ? Colors.green : Colors.orange,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${type == 'visited' ? 'Visited' : 'Cancelled'}: ${_formatDateTime(actionAt)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: type == 'visited' ? Colors.green.shade300 : Colors.orange.shade300,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Updated method to build visitor avatar with proper image handling
  Widget _buildVisitorAvatar(Map<String, dynamic> visitor) {
    final profileImageUrl = visitor['profile_image_url'] ?? '';
    final visitorPassUrl = visitor['visitor_pass_url'] ?? '';

    // Priority: profile_image_url > visitor_pass_url > fallback
    String imageUrl = profileImageUrl.isNotEmpty ? profileImageUrl : visitorPassUrl;

    if (imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          imageUrl,
          width: 80,
          height: 80,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildFallbackAvatar();
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              return child;
            }
            return Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              ),
            );
          },
        ),
      );
    } else {
      return _buildFallbackAvatar();
    }
  }

  Widget _buildFallbackAvatar() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.withOpacity(0.3),
            Colors.blue.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.blue.withOpacity(0.4),
          width: 2,
        ),
      ),
      child: const Icon(
        Icons.person,
        color: Colors.blue,
        size: 40,
      ),
    );
  }

  // Helper method for date formatting
  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return 'Today ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      isLoading = true;
    });
    // Add a small delay to show refresh indicator
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1A2F),
      appBar: CupertinoNavigationBar(
        backgroundColor: const Color(0xFF0A1A2F),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.back, color: CupertinoColors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        middle: const Text(
          'Security Dashboard',
          style: TextStyle(
            color: CupertinoColors.white,
            fontSize: 20,
            fontWeight: FontWeight.w400,
          ),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.refresh, color: CupertinoColors.white),
          onPressed: _refreshData,

        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        backgroundColor: const Color(0xFF1A2332),
        color: Colors.blue,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tab Navigation
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
                            selectedTab = 'pending';
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: selectedTab == 'pending'
                                ? Colors.amber.withOpacity(0.5)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.schedule,
                                color: selectedTab == 'pending' ? Colors.amber : Colors.white54,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Pending',
                                style: TextStyle(
                                  color: selectedTab == 'pending' ? Colors.amber : Colors.white54,
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
                            selectedTab = 'visited';
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: selectedTab == 'visited'
                                ? Colors.green.withOpacity(0.3)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: selectedTab == 'visited' ? Colors.green : Colors.white54,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Visited',
                                style: TextStyle(
                                  color: selectedTab == 'visited' ? Colors.green : Colors.white54,
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
                                ? Colors.orange.withOpacity(0.3)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.cancel,
                                color: selectedTab == 'cancelled' ? Colors.orange : Colors.white54,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Cancelled',
                                style: TextStyle(
                                  color: selectedTab == 'cancelled' ? Colors.orange : Colors.white54,
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

              // Search Bar
              _buildSearchBar(),

              // Filter Section
              _buildFilterSection(),

              // Visitors List
              StreamBuilder<QuerySnapshot>(
                stream: _buildQuery().snapshots(),
                builder: (context, snapshot) {
                  if (isLoading) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                        ),
                      ),
                    );
                  }

                  return _buildHistoryList(snapshot, selectedTab);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}