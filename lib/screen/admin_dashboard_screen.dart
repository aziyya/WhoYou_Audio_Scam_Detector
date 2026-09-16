import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';
import 'keyword_management_screen.dart';
import 'package:whoyou/widgets/app_header.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const _DashboardTab(),
    const KeywordManagementScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: _pages[_currentIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A3A6B),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _navItem(Icons.dashboard_outlined, 'Dashboard', 0),
              _navItem(Icons.label_outline, 'Keywords', 1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isActive ? Colors.white : Colors.white54),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white54,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Dashboard Tab
// ─────────────────────────────────────────────
class _DashboardTab extends StatefulWidget {
  const _DashboardTab();

  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  final GlobalKey<_TopKeywordsCardState> _topKeywordsKey = GlobalKey();
  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2A3A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Log Out', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'Are you sure you want to log out?',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Log Out',
              style: TextStyle(color: Color(0xFFFFFFFF)),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Container(
          color: const Color(0xFF0D1B2A),
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 12,
            left: 20,
            right: 20,
            bottom: 12,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const AppHeader(dark: true),
              IconButton(
                onPressed: () => _logout(context),
                icon: const Icon(Icons.logout, color: Colors.redAccent),
                tooltip: 'Log Out',
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),

              // Welcome message
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(FirebaseAuth.instance.currentUser?.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  final name =
                      (snapshot.data?.data() as Map?)?['name'] ?? 'Admin';
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back,',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                          color: Color.fromARGB(255, 255, 255, 255),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  );
                },
              ),

              // 🔹 Stats Cards — Row 1: Keywords + Users (side by side)
              IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.label_outline,
                        label: 'Total Keywords',
                        color: const Color.fromARGB(255, 138, 185, 255),
                        stream: FirebaseFirestore.instance
                            .collection('scam_keywords')
                            .snapshots()
                            .map((s) => s.docs.length),
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: const Color(0xFF1A2A3A),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              title: const Row(
                                children: [
                                  Icon(
                                    Icons.report_outlined,
                                    color: Color(0xFFE65100),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'All Reports',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                              content: SizedBox(
                                width: double.maxFinite,
                                height: 520,
                                child: ReportsDialog(),
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
                          icon: Icons.report_outlined,
                          label: 'Total Reports',
                          color: const Color(0xFFE65100),
                          stream: FirebaseFirestore.instance
                              .collection('reports')
                              .snapshots()
                              .map((s) => s.docs.length),
                          tappable: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // 🔹 Total Users — full width
              GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: const Color(0xFF1A2A3A),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      title: const Row(
                        children: [
                          Icon(Icons.people_outline, color: Color(0xFF1A3A6B)),
                          SizedBox(width: 8),
                          Text(
                            'All Users',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                      content: SizedBox(
                        width: double.maxFinite,
                        height: 520,
                        child: UsersDialog(),
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
                  icon: Icons.people_outline,
                  label: 'Total Users',
                  color: const Color(0xFF2E7D32),
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .where('role', isEqualTo: 'user')
                      .snapshots()
                      .map((s) => s.docs.length),
                  tappable: true,
                ),
              ),

              const SizedBox(height: 12),

              // 🔹 Most Detected Keywords
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Most Detected Keywords',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    onPressed: () => _topKeywordsKey.currentState?._refresh(),
                    icon: const Icon(
                      Icons.refresh,
                      size: 18,
                      color: Colors.white70,
                    ),
                    tooltip: 'Refresh',
                  ),
                ],
              ),
              const SizedBox(height: 5),
              _TopKeywordsCard(key: _topKeywordsKey),

              const SizedBox(height: 20),

              // 🔹 Recent Keywords
              const Text(
                'Recent Keywords',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 10),

              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('scam_keywords')
                    .orderBy('createdAt', descending: true)
                    .limit(5)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data?.docs ?? [];

                  if (docs.isEmpty) {
                    return _emptyCard('No keywords added yet.');
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A2A3A),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 6,
                          color: Colors.black.withOpacity(0.05),
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: docs.asMap().entries.map((entry) {
                        final index = entry.key;
                        final doc = entry.value;
                        final keyword = doc['keyword'] as String;
                        final createdAt = doc['createdAt'] as Timestamp?;

                        return Column(
                          children: [
                            ListTile(
                              leading: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF1A3A6B,
                                  ).withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.label_outline,
                                  size: 18,
                                  color: Color.fromARGB(255, 255, 255, 255),
                                ),
                              ),
                              title: Text(
                                keyword,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                  color: Colors.white,
                                ),
                              ),
                              trailing: Text(
                                createdAt != null
                                    ? _formatDate(createdAt.toDate())
                                    : '',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                            ),
                            if (index < docs.length - 1)
                              const Divider(
                                height: 1,
                                indent: 16,
                                color: Color(0xFF2A3A4A),
                              ),
                          ],
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyCard(String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2A3A),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Text(
          message,
          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}

// ─────────────────────────────────────────────
// Stat Card Widget
// ─────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Stream<int> stream;
  final bool tappable;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.stream,
    this.tappable = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2A3A),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            blurRadius: 6,
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 12),
          StreamBuilder<int>(
            stream: stream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text(
                  'Error',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade300,
                  ),
                );
              }
              final count = snapshot.data ?? 0;
              return Text(
                '$count',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              );
            },
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade400,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (tappable) ...[
            const SizedBox(height: 4),
            Text(
              'Tap to view list',
              style: TextStyle(
                fontSize: 10,
                color: color.withOpacity(0.6),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Users Dialog (paginated)
// ─────────────────────────────────────────────
class UsersDialog extends StatefulWidget {
  const UsersDialog({super.key});

  @override
  State<UsersDialog> createState() => _UsersDialogState();
}

class _UsersDialogState extends State<UsersDialog> {
  final _firestore = FirebaseFirestore.instance;
  final List<QueryDocumentSnapshot> _allDocs = [];
  List<QueryDocumentSnapshot> _filteredDocs = [];
  bool _loading = false;
  bool _hasMore = true;
  static const int _pageSize = 30;
  QueryDocumentSnapshot? _lastDoc;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

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
      _filterUsers();
    });
  }

  void _filterUsers() {
    if (_searchQuery.isEmpty) {
      _filteredDocs = List.from(_allDocs);
    } else {
      _filteredDocs = _allDocs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final name = (data['name'] ?? '').toString().toLowerCase();
        final email = (data['email'] ?? '').toString().toLowerCase();
        return name.contains(_searchQuery) || email.contains(_searchQuery);
      }).toList();
    }

    // Sort alphabetically by name
    _filteredDocs.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>;
      final bData = b.data() as Map<String, dynamic>;
      final aName = (aData['name'] ?? aData['email'] ?? '')
          .toString()
          .toLowerCase();
      final bName = (bData['name'] ?? bData['email'] ?? '')
          .toString()
          .toLowerCase();
      return aName.compareTo(bName);
    });
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
      Query query = _firestore
          .collection('users')
          .where('role', isEqualTo: 'user')
          .orderBy('createdAt', descending: true)
          .limit(_pageSize);
      if (_lastDoc != null) query = query.startAfterDocument(_lastDoc!);

      final snap = await query.get();
      if (snap.docs.isNotEmpty) {
        setState(() {
          _allDocs.addAll(snap.docs);
          _filterUsers();
          _lastDoc = snap.docs.last;
          if (snap.docs.length < _pageSize) _hasMore = false;
        });
      } else {
        setState(() => _hasMore = false);
      }
    } catch (e) {
      setState(() => _hasMore = false);
    }

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search by name or email...',
              hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: Colors.grey.shade500),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFF0D1B2A),
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

        // User list
        Expanded(child: _buildUserList()),
      ],
    );
  }

  Widget _buildUserList() {
    if (_allDocs.isEmpty && _loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_filteredDocs.isEmpty && !_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _searchQuery.isNotEmpty ? Icons.search_off : Icons.people_outline,
              size: 48,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No users found'
                  : 'No users registered yet',
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
          // Loading indicator at the end
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final doc = _filteredDocs[index];
        final data = doc.data() as Map<String, dynamic>;
        final name = (data['name'] ?? '') as String;
        final email = (data['email'] ?? '') as String;
        final initial = name.isNotEmpty
            ? name[0].toUpperCase()
            : email.isNotEmpty
            ? email[0].toUpperCase()
            : '?';

        return Column(
          children: [
            ListTile(
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF1A3A6B),
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              title: Text(
                name.isNotEmpty ? name : '(No name)',
                style: const TextStyle(fontSize: 14, color: Colors.white),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    email,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 10,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        () {
                          final createdAt = data['createdAt'] as Timestamp?;
                          if (createdAt == null) return 'Unknown join date';
                          final dt = createdAt.toDate();
                          final months = [
                            'Jan',
                            'Feb',
                            'Mar',
                            'Apr',
                            'May',
                            'Jun',
                            'Jul',
                            'Aug',
                            'Sep',
                            'Oct',
                            'Nov',
                            'Dec',
                          ];
                          return 'Joined ${dt.day} ${months[dt.month - 1]} ${dt.year}';
                        }(),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
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

class _TopKeywordsCard extends StatefulWidget {
  const _TopKeywordsCard({super.key});
  @override
  State<_TopKeywordsCard> createState() => _TopKeywordsCardState();
}

class _TopKeywordsCardState extends State<_TopKeywordsCard> {
  late final Stream<Map<String, int>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = FirebaseFirestore.instance
        .collection('history')
        .snapshots()
        .map(_countKeywords);
  }

  // The stream already updates live on its own; this just gives the
  // existing refresh button something to do (re-subscribes the widget).
  void _refresh() => setState(() {});

  Map<String, int> _countKeywords(QuerySnapshot snapshot) {
    final Map<String, int> counts = {};
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final keywords = data['keywords'];
      if (keywords is Map) {
        keywords.forEach((key, value) {
          final k = key.toString().toLowerCase();
          counts[k] = (counts[k] ?? 0) + 1;
        });
      }
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, int>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2A3A),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                'Could not load keyword data.',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              ),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2A3A),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                'No detection data yet.',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              ),
            ),
          );
        }

        // Sort by count descending, take top 10
        final sorted = snapshot.data!.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final top = sorted.take(10).toList();
        final maxCount = top.first.value;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A2A3A),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                blurRadius: 6,
                color: Colors.black.withOpacity(0.05),
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: top.asMap().entries.map((entry) {
              final rank = entry.key;
              final keyword = entry.value.key;
              final count = entry.value.value;
              final ratio = count / maxCount;

              final Color barColor = rank == 0
                  ? const Color(0xFFD32F2F)
                  : rank == 1
                  ? const Color(0xFFF57C00)
                  : rank == 2
                  ? const Color(0xFFF9A825)
                  : const Color.fromARGB(255, 102, 117, 139);

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Rank badge
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: barColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(
                            child: Text(
                              '${rank + 1}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: barColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            keyword,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color.fromARGB(255, 255, 255, 255),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '$count detection${count == 1 ? '' : 's'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade400,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 6,
                        backgroundColor: const Color(0xFF2A3A4A),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          barColor.withOpacity(0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class ReportsDialog extends StatefulWidget {
  const ReportsDialog({super.key});

  @override
  State<ReportsDialog> createState() => _ReportsDialogState();
}

class _ReportsDialogState extends State<ReportsDialog> {
  final _firestore = FirebaseFirestore.instance;
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
      final description = (data['description'] as String? ?? '').trim();

      final matchesDescription =
          _selectedDescription == 'All' || description == _selectedDescription;
      final matchesSearch =
          _searchQuery.isEmpty ||
          description.toLowerCase().contains(_searchQuery.toLowerCase());

      return matchesDescription && matchesSearch;
    }).toList();
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
      Query query = _firestore
          .collection('reports')
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
    } catch (e) {
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
              hintText: 'Search by description...',
              hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: Colors.grey.shade500),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFF0D1B2A),
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
              _searchQuery.isNotEmpty ? 'No reports found' : 'No reports yet',
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
                  color: const Color(0xFFE65100).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.phone_outlined,
                  size: 18,
                  color: Color(0xFFE65100),
                ),
              ),
              title: Text(
                phone.isNotEmpty ? phone : '(No phone number)',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color.fromARGB(255, 255, 255, 255),
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  description.isNotEmpty ? description : '(No description)',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ),
              trailing: Text(
                timeLabel,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              isThreeLine: true,
            ),
            if (index < _filteredDocs.length - 1)
              const Divider(height: 1, indent: 16, color: Color(0xFF2A3A4A)),
          ],
        );
      },
    );
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
        color: const Color(0xFF0D1B2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A3A4A)),
      ),
      child: DropdownButton<String>(
        value: _selectedDescription,
        isExpanded: true,
        underline: const SizedBox(),
        dropdownColor: const Color(0xFF1A2A3A),
        style: const TextStyle(color: Colors.white, fontSize: 13),
        icon: const Icon(
          Icons.keyboard_arrow_down,
          size: 20,
          color: Color.fromARGB(255, 157, 157, 157),
        ),
        hint: const Text('Filter by description'),
        items: options
            .map(
              (desc) => DropdownMenuItem(
                value: desc,
                child: Text(
                  desc,
                  style: const TextStyle(fontSize: 13, color: Colors.white),
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
}
