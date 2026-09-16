import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/news_service.dart';
import 'login_screen.dart';
import 'dart:async';
import 'dart:math';
import 'package:whoyou/widgets/app_header.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final NewsService _newsService = NewsService();
  late Future<List<dynamic>> _news;

  final TextEditingController _phoneController = TextEditingController();

  // 🔐 Scam tips
  final List<Map<String, dynamic>> _scamTips = [
    {
      "icon": Icons.link,
      "title": "Avoid Suspicious Links",
      "tip": "Never click unknown links from SMS, WhatsApp, or email.",
    },
    {
      "icon": Icons.lock,
      "title": "Protect Your OTP",
      "tip": "Banks will never ask for your OTP or TAC.",
    },
    {
      "icon": Icons.phone_disabled,
      "title": "Ignore Unknown Calls",
      "tip": "Do not trust urgent demands from unknown callers.",
    },
    {
      "icon": Icons.account_balance,
      "title": "Verify Bank Requests",
      "tip": "Always confirm with official bank numbers.",
    },
    {
      "icon": Icons.warning_amber_rounded,
      "title": "Too Good To Be True",
      "tip": "Be careful of fake prizes or investment schemes.",
    },
    {
      "icon": Icons.verified_user,
      "title": "Check Caller Identity",
      "tip": "Use WhoYou before trusting unknown numbers.",
    },
  ];

  int _currentTipIndex = 0;
  Timer? _tipTimer;

  String? _phoneError;

  String? _validatePhone(String phone) {
    if (phone.isEmpty) return 'Please enter a phone number.';

    if (!RegExp(r'^\d+$').hasMatch(phone)) {
      return 'Digits only — no dashes, spaces, or special characters.';
    }

    if (phone.startsWith('0')) {
      return 'Remove the leading "0".\nExample: 0123456789 → enter 123456789';
    }

    if (phone.startsWith('60')) {
      return 'Remove the country code "+60".\nExample: 60123456789 → enter 123456789';
    }

    final isMobile = RegExp(r'^1[0-9]').hasMatch(phone);
    final isLandline = RegExp(r'^[2-9]').hasMatch(phone);

    if (!isMobile && !isLandline) {
      return 'Invalid Malaysian number prefix.';
    }

    if (isMobile) {
      final isEightDigitSubscriber =
          phone.startsWith('11') || phone.startsWith('15');
      if (isEightDigitSubscriber) {
        if (phone.length != 10) {
          return 'Numbers starting with 11 or 15 must be 10 digits.\nExample: 1112345678';
        }
      } else {
        if (phone.length != 9) {
          return 'Mobile numbers must be 9 digits.\nExample: 123456789';
        }
      }
    }

    if (isLandline && (phone.length < 7 || phone.length > 9)) {
      return 'Landline number must be 7–9 digits after removing "0".\nExample: 31234567';
    }

    return null;
  }

  @override
  void initState() {
    super.initState();
    _news = _newsService.fetchNews();

    _currentTipIndex = Random().nextInt(_scamTips.length);
    _tipTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      setState(() {
        _currentTipIndex =
            (_currentTipIndex + 1) % _scamTips.length; // cycle through tips
      });
    });
  }

  @override
  void dispose() {
    _tipTimer?.cancel();
    _phoneController.dispose();
    super.dispose();
  }

  // 🔗 Open article
  Future<void> _openArticle(String url) async {
    final Uri uri = Uri.parse(url);

    if (!await launchUrl(uri)) {
      throw Exception("Could not launch $url");
    }
  }

  // 🔍 Search Firestore
  Future<List<QueryDocumentSnapshot>> _searchPhone(String phone) async {
    final result = await FirebaseFirestore.instance
        .collection('reports')
        .where('phone_number', isEqualTo: phone)
        .get();

    return result.docs;
  }

  // 🔍 Handle search
  void _handleSearch() async {
    final phone = _phoneController.text.trim();

    final error = _validatePhone(phone);
    setState(() => _phoneError = error);

    if (error != null) return;

    final results = await _searchPhone(phone);

    if (results.isEmpty) {
      _showResultDialog("✅ Safe", "No reports found for this number.");
    } else {
      _showResultDialog(
        "⚠️ Warning",
        "This number has been reported ${results.length} time(s).",
      );
    }
  }

  // 📢 Show result dialog
  void _showResultDialog(String title, String message) {
    final bool isSafe = title.contains("Safe");

    final Color bgColor = isSafe
        ? const Color(0xFFE8F5E9)
        : const Color(0xFFFFF3E0);
    final Color iconBgColor = isSafe
        ? const Color(0xFF2E7D32)
        : const Color(0xFFF57C00);
    final Color titleColor = isSafe
        ? const Color(0xFF1B5E20)
        : const Color(0xFFE65100);
    final Color borderColor = isSafe
        ? const Color(0xFFA5D6A7)
        : const Color(0xFFFFCC80);
    final IconData icon = isSafe
        ? Icons.verified_user_outlined
        : Icons.warning_amber_rounded;
    final String label = isSafe ? "Safe Number" : "Reported Number";

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon circle
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 16),

              // Label badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: iconBgColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: iconBgColor.withOpacity(0.4)),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: iconBgColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Message
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: titleColor, height: 1.5),
              ),
              const SizedBox(height: 24),

              // Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: iconBgColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'OK',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Log Out'),
          ],
        ),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
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
  }

  @override
  Widget build(BuildContext context) {
    final tip = _scamTips[_currentTipIndex];
    final user = FirebaseAuth.instance.currentUser;
    final displayName =
        user?.displayName ?? user?.email?.split('@').first ?? 'there';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Container(
          color: const Color(0xFFF5F6FA),
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 12,
            left: 20,
            right: 20,
            bottom: 12,
          ),
          child: Row(
            children: [
              const AppHeader(),
              const Spacer(),
              IconButton(
                icon: const Icon(
                  Icons.logout,
                  color: Color.fromARGB(255, 255, 0, 0),
                ),
                tooltip: 'Log Out',
                onPressed: _showLogoutDialog,
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 2),
            Text(
              '${_getGreeting()}, $displayName 👋',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),

            SizedBox(
              height: 180,
              width: double.infinity,
              child: Image.asset('assets/media/poster.png', fit: BoxFit.cover),
            ),

            const SizedBox(height: 8),
            const Text(
              'Check a number before you trust it.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color.fromARGB(255, 0, 0, 0),
              ),
            ),
            const SizedBox(height: 12),

            _buildPhoneInput(),
            const SizedBox(height: 20),
            _buildScamTipCard(tip),
            const SizedBox(height: 20), // ← reduced from 20
            _buildNewsSection(),
          ],
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  //  Phone Input + Search
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
                    fontSize: 16,
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
                      if (_phoneError != null) {
                        _phoneError = _validatePhone(val.trim());
                      }
                    });
                  },
                  decoration: const InputDecoration(
                    hintText: 'e.g. 123456789',
                    hintStyle: TextStyle(color: Colors.grey, fontSize: 12),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ),
              if (_phoneController.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Icon(
                    _phoneError == null
                        ? Icons.check_circle_outline
                        : Icons.error_outline,
                    size: 18,
                    color: _phoneError == null
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
              Expanded(
                child: Text(
                  'Enter without "0" or "+60" · digits only\n'
                  'Mobile: 123456789 · Landline: 31234567',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade400,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: 10),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _handleSearch,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A3A6B),
            ),
            child: const Text(
              "Check Number",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  // 💡 Safety Tip
  Widget _buildScamTipCard(Map tip) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Tips",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 12),
        AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A3A6B), Color(0xFF274B87)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(tip['icon'], color: Colors.white, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tip['title'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tip['tip'],
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 📰 News Section (Vertical)
  Widget _buildNewsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Latest News",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        FutureBuilder<List<dynamic>>(
          future: _news,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final articles = snapshot.data ?? [];

            if (articles.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.wifi_off_rounded, color: Colors.grey),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "News unavailable right now. Check back later.",
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              itemCount: articles.length > 5 ? 5 : articles.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                final article = articles[index];
                return GestureDetector(
                  onTap: () {
                    if (article["url"] != null) _openArticle(article["url"]);
                  },
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                          child: Image.network(
                            article["urlToImage"] ??
                                "https://via.placeholder.com/150",
                            height: 160,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              height: 160,
                              color: const Color(0xFFEEF2FA),
                              child: const Center(
                                child: Icon(
                                  Icons.image_not_supported_outlined,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            article["title"] ?? "No title",
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            article["source"]["name"] ?? "",
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
