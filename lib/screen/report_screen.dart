import 'package:flutter/material.dart';
import 'services/firestore_service.dart';
import '../widgets/app_header.dart';
import 'services/report_type.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();
  bool _isSubmitting = false;
  ReportType? _selectedReportType;
  String? _currentUserId;
  Stream<QuerySnapshot>? _reportStream;
  // Add this state variable at the top of _ReportScreenState
  String? _phoneError;
  String? _validatePhone(String phone) {
    if (phone.isEmpty) return 'Please enter a phone number.';

    // No spaces, dashes, or special characters
    if (!RegExp(r'^\d+$').hasMatch(phone)) {
      return 'Digits only — no dashes, spaces, or special characters.';
    }

    // Must not start with 0 (trunk prefix) or 60 (country code)
    if (phone.startsWith('0')) {
      return 'Remove the leading "0".\nExample: 0123456789 → enter 123456789';
    }
    if (phone.startsWith('60')) {
      return 'Remove the country code "+60".\nExample: 60123456789 → enter 123456789';
    }

    // Malaysian mobile prefixes (after removing trunk 0):
    // 10, 11, 12, 13, 14, 15, 16, 17, 18, 19
    final isMobile = RegExp(r'^1[0-9]').hasMatch(phone);

    // Malaysian landline area codes (after removing trunk 0):
    // 2 (KL/Selangor), 3 (KL), 4 (Kedah/Perlis/Penang),
    // 5 (Perak), 6 (NS/Melaka), 7 (Johor),
    // 8 (Pahang/Kelantan/Terengganu/Sabah/Sarawak), 9 (Pahang/Kelantan)
    final isLandline = RegExp(r'^[2-9]').hasMatch(phone);

    if (!isMobile && !isLandline) {
      return 'Invalid Malaysian number prefix.';
    }

    // Mobile: 9-10 digits (e.g. 123456789 or 1234567890)
    if (isMobile && (phone.length < 9 || phone.length > 10)) {
      return 'Mobile number must be 9–10 digits after removing "0".\nExample: 123456789';
    }

    // Landline: 7-9 digits (e.g. 31234567 or 312345678)
    if (isLandline && (phone.length < 7 || phone.length > 9)) {
      return 'Landline number must be 7–9 digits after removing "0".\nExample: 31234567';
    }

    return null; // valid
  }

  @override
  void initState() {
    super.initState();
    _selectedReportType = ReportTypes.all.first;
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (_currentUserId != null) {
      _reportStream = FirebaseFirestore.instance
          .collection('reports')
          .where('userId', isEqualTo: _currentUserId)
          .snapshots();
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Container(
          color: const Color(0xFFF5F7FB),
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 12,
            left: 20,
            right: 20,
            bottom: 12,
          ),
          child: const AppHeader(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            _buildTitleSection(),

            const SizedBox(height: 16),
            if (_currentUserId != null && _reportStream != null)
              _UserReportStats(
                key: const ValueKey('user_report_stats'),
                userId: _currentUserId!,
                stream: _reportStream!,
              ),

            const SizedBox(height: 24),
            _buildPhoneInput(),

            const SizedBox(height: 24),
            _buildReportTypeButtons(),

            const SizedBox(height: 32),
            _buildSubmitButton(context),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleSection() {
    return const Text(
      "Report Suspicious Number",
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1A1A1A),
      ),
    );
  }

  Widget _buildPhoneInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _phoneError != null
                  ? Colors.redAccent
                  : Colors.grey.shade300,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFFD0D9EE),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(11),
                    bottomLeft: Radius.circular(11),
                  ),
                ),
                child: const Text(
                  '+60',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A3A6B),
                  ),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  onChanged: (val) {
                    setState(() {
                      // Clear error once user starts fixing
                      if (_phoneError != null) {
                        _phoneError = _validatePhone(val.trim());
                      }
                    });
                  },
                  decoration: const InputDecoration(
                    hintText: 'e.g. 123456789',
                    hintStyle: TextStyle(fontSize: 12, color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ),
              // Live check icon
              if (_phoneController.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Icon(
                    _phoneError == null && _phoneController.text.isNotEmpty
                        ? Icons.check_circle_outline
                        : Icons.error_outline,
                    size: 18,
                    color:
                        _phoneError == null && _phoneController.text.isNotEmpty
                        ? Colors.green
                        : Colors.redAccent,
                  ),
                ),
            ],
          ),
        ),

        // Error message
        if (_phoneError != null) ...[
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, size: 13, color: Colors.redAccent),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _phoneError!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.redAccent,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],

        // Format hint
        if (_phoneError == null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.info_outline, size: 12, color: Colors.grey.shade400),
              const SizedBox(width: 4),
              Text(
                'Enter without "0" or "+60" · digits only\nMobile: 123456789 · Landline: 31234567',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade400,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildReportTypeButtons() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: ReportTypes.all.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.2,
      ),
      itemBuilder: (context, index) {
        final type = ReportTypes.all[index];
        final isSelected = type == _selectedReportType;

        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _selectedReportType = type),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF1A3A6B).withOpacity(0.08)
                  : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF1A3A6B)
                    : Colors.grey.shade300,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      type.icon,
                      size: 20,
                      color: isSelected
                          ? const Color(0xFF1A3A6B)
                          : Colors.black87,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        type.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Icon(
                      isSelected ? Icons.check_circle : Icons.circle_outlined,
                      size: 18,
                      color: isSelected ? const Color(0xFF1A3A6B) : Colors.grey,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Text(
                    type.shortDescription,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubmitButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1A3A6B),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: _isSubmitting ? null : () => _handleSubmit(context),
        child: _isSubmitting
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                "Submit Report",
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
      ),
    );
  }

  Future<void> _handleSubmit(BuildContext context) async {
    final phone = _phoneController.text.trim();
    final desc = _selectedReportType?.name ?? 'Other';

    setState(() {
      _phoneError = _validatePhone(phone);
    });

    final phoneError = _validatePhone(phone);
    if (phoneError != null) {
      _showPopupMessage(
        context,
        title: "Invalid Phone Number",
        message: phoneError,
        isSuccess: false,
      );
      return;
    }

    if (_currentUserId == null) {
      _showPopupMessage(
        context,
        title: "Not Signed In",
        message: "Please sign in to submit a report.",
        isSuccess: false,
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _firestoreService.submitReport(
        phoneNumber: phone,
        description: desc,
        userId: _currentUserId!,
      );

      _phoneController.clear();
      setState(() => _selectedReportType = ReportTypes.all.first);

      _showPopupMessage(
        context,
        title: "Report Submitted",
        message: "Thank you for helping protect the community.",
        isSuccess: true,
      );
    } catch (e) {
      _showPopupMessage(
        context,
        title: "Submission Failed",
        message: "Please try again later.",
        isSuccess: false,
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _showPopupMessage(
    BuildContext context, {
    required String title,
    required String message,
    required bool isSuccess,
  }) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSuccess ? Icons.check_circle : Icons.error,
                size: 50,
                color: isSuccess ? Colors.green : Colors.red,
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSuccess
                      ? const Color(0xFF1A3A6B)
                      : Colors.redAccent,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('OK', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// User Report Stats Card (stable, no rebuild)
// ─────────────────────────────────────────────
class _UserReportStats extends StatefulWidget {
  final String userId;
  final Stream<QuerySnapshot> stream;

  const _UserReportStats({
    super.key,
    required this.userId,
    required this.stream,
  });

  @override
  State<_UserReportStats> createState() => _UserReportStatsState();
}

class _UserReportStatsState extends State<_UserReportStats>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return StreamBuilder<QuerySnapshot>(
      stream: widget.stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final total = snapshot.data?.docs.length ?? 0;

        return GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                title: const Row(
                  children: [
                    Icon(Icons.history, color: Color(0xFF1A3A6B)),
                    SizedBox(width: 8),
                    Text('My Reports'),
                  ],
                ),
                content: SizedBox(
                  width: double.maxFinite,
                  height: 520,
                  child: UserReportsDialog(userId: widget.userId),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Close',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
            );
          },
          child: _StatCard(
            label: "Total Reports Submitted",
            value: "$total",
            icon: Icons.analytics_outlined,
            iconColor: const Color.fromARGB(255, 14, 65, 29),
            bgColor: const Color.fromARGB(110, 207, 255, 213),
            tappable: true,
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// Stat Card
// ─────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final bool tappable;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    this.tappable = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (tappable) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Tap to view list',
                    style: TextStyle(
                      fontSize: 10,
                      color: iconColor.withOpacity(0.7),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// User Reports Dialog
// ─────────────────────────────────────────────
class UserReportsDialog extends StatefulWidget {
  final String userId;
  const UserReportsDialog({super.key, required this.userId});

  @override
  State<UserReportsDialog> createState() => _UserReportsDialogState();
}

class _UserReportsDialogState extends State<UserReportsDialog> {
  final List<QueryDocumentSnapshot> _allDocs = [];
  List<QueryDocumentSnapshot> _filteredDocs = [];
  bool _loading = false;
  bool _hasMore = true;
  static const int _pageSize = 30;
  QueryDocumentSnapshot? _lastDoc;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedDescription = 'All';

  @override
  void initState() {
    super.initState();
    _loadNextPage();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _filterReports();
    });
  }

  void _filterReports() {
    _filteredDocs = _allDocs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final phone = (data['phone_number'] as String? ?? '').toLowerCase();
      final description = (data['description'] as String? ?? '').toLowerCase();

      final matchesSearch =
          _searchQuery.isEmpty ||
          phone.contains(_searchQuery) ||
          description.contains(_searchQuery);

      final matchesDescription =
          _selectedDescription == 'All' ||
          (data['description'] as String? ?? '') == _selectedDescription;

      return matchesSearch && matchesDescription;
    }).toList();
  }

  List<String> _getDescriptionOptions() {
    final descriptions =
        _allDocs
            .map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return (data['description'] as String? ?? '').trim();
            })
            .where((d) => d.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return ['All', ...descriptions];
  }

  Widget _buildDescriptionDropdown() {
    final options = _getDescriptionOptions();
    if (!options.contains(_selectedDescription)) _selectedDescription = 'All';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButton<String>(
        value: _selectedDescription,
        isExpanded: true,
        underline: const SizedBox(),
        icon: Icon(
          Icons.keyboard_arrow_down,
          size: 20,
          color: Colors.grey.shade500,
        ),
        items: options
            .map(
              (desc) => DropdownMenuItem(
                value: desc,
                child: Text(
                  desc,
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        onChanged: (value) {
          setState(() {
            _selectedDescription = value ?? 'All';
            _filterReports();
          });
        },
      ),
    );
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      _loadNextPage();
    }
  }

  Future<void> _loadNextPage() async {
    if (!_hasMore || _loading) return;
    setState(() => _loading = true);

    try {
      Query query = FirebaseFirestore.instance
          .collection('reports')
          .where('userId', isEqualTo: widget.userId)
          .orderBy('timestamp', descending: true)
          .limit(_pageSize);
      if (_lastDoc != null) query = query.startAfterDocument(_lastDoc!);

      final snap = await query.get();
      if (snap.docs.isNotEmpty) {
        setState(() {
          _allDocs.addAll(snap.docs);
          _filterReports();
          _lastDoc = snap.docs.last;
          if (snap.docs.length < _pageSize) _hasMore = false;
        });
      } else {
        setState(() => _hasMore = false);
      }
    } on FirebaseException catch (e) {
      debugPrint('Firestore error: ${e.code} — ${e.message}');
      // If missing index, fall back to query without orderBy
      if (e.code == 'failed-precondition') {
        try {
          final snap = await FirebaseFirestore.instance
              .collection('reports')
              .where('userId', isEqualTo: widget.userId)
              .limit(_pageSize)
              .get();
          if (snap.docs.isNotEmpty) {
            // Sort manually by timestamp
            final sorted = snap.docs.toList()
              ..sort((a, b) {
                final aTs = (a.data() as Map)['timestamp'] as Timestamp?;
                final bTs = (b.data() as Map)['timestamp'] as Timestamp?;
                if (aTs == null || bTs == null) return 0;
                return bTs.compareTo(aTs);
              });
            setState(() {
              _allDocs.addAll(sorted);
              _filterReports();
              _hasMore = false;
            });
          } else {
            setState(() => _hasMore = false);
          }
        } catch (e2) {
          debugPrint('Fallback query error: $e2');
          setState(() => _hasMore = false);
        }
      } else {
        setState(() => _hasMore = false);
      }
    } catch (e) {
      debugPrint('Unknown error: $e');
      setState(() => _hasMore = false);
    }

    setState(() => _loading = false);
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by phone or description...',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: Colors.grey.shade400),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFFF5F6FA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
        ),

        // Description filter dropdown
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildDescriptionDropdown(),
        ),

        // List
        Expanded(child: _buildList()),
      ],
    );
  }

  Widget _buildList() {
    if (_allDocs.isEmpty && _loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_filteredDocs.isEmpty && !_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _searchQuery.isNotEmpty
                  ? Icons.search_off
                  : Icons.report_outlined,
              size: 48,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No reports found'
                  : 'No reports submitted yet',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount:
          _filteredDocs.length + (_hasMore && _searchQuery.isEmpty ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _filteredDocs.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final doc = _filteredDocs[index];
        final data = doc.data() as Map<String, dynamic>;
        final phone = (data['phone_number'] as String? ?? '');
        final description = (data['description'] as String? ?? '');
        final ts = data['timestamp'] as Timestamp?;
        final timeLabel = ts != null ? _formatDate(ts.toDate()) : '';

        return Column(
          children: [
            ListTile(
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A3A6B).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.phone_outlined,
                  size: 18,
                  color: Color(0xFF1A3A6B),
                ),
              ),
              title: Text(
                phone.isNotEmpty ? '+60$phone' : '(No phone number)',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  description.isNotEmpty ? description : '(No description)',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
              trailing: Text(
                timeLabel,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
              ),
              isThreeLine: true,
            ),
            if (index < _filteredDocs.length - 1)
              const Divider(height: 1, indent: 16),
          ],
        );
      },
    );
  }
}
