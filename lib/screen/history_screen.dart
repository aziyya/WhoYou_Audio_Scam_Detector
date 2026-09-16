import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:whoyou/widgets/app_header.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedRisk = 'All';
  String _selectedLanguage = 'All';
  String _selectedSource = 'All';

  static const List<String> _riskOptions = [
    'All',
    'Safe',
    'Low',
    'Medium',
    'High',
  ];

  static const List<String> _languageOptions = ['All', 'English', 'Malay'];

  static const List<String> _sourceOptions = [
    'All',
    'Microphone',
    'Media File',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Risk helpers ──────────────────────────────────────────────────────────
  Color _riskColor(double score) {
    if (score >= 60) return const Color(0xFFD32F2F);
    if (score >= 30) return const Color(0xFFF57C00);
    if (score > 0) return const Color(0xFFF9A825);
    return const Color(0xFF2E7D32);
  }

  String _riskLabel(double score) {
    if (score >= 60) return "HIGH RISK";
    if (score >= 30) return "MEDIUM RISK";
    if (score > 0) return "LOW RISK";
    return "SAFE";
  }

  IconData _riskIcon(double score) {
    if (score >= 60) return Icons.dangerous_outlined;
    if (score >= 30) return Icons.warning_amber_rounded;
    if (score > 0) return Icons.info_outline;
    return Icons.verified_user_outlined;
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _formatFullTimestamp(DateTime dt) {
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
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}  $h:$m';
  }

  bool _matchesSearchQuery(String text) {
    if (_searchQuery.isEmpty) return true;
    return text.toLowerCase().contains(_searchQuery.toLowerCase());
  }

  bool _matchesRiskFilter(double score) {
    switch (_selectedRisk) {
      case 'Safe':
        return score == 0;
      case 'Low':
        return score > 0 && score < 30;
      case 'Medium':
        return score >= 30 && score < 60;
      case 'High':
        return score >= 60;
      default:
        return true;
    }
  }

  bool _matchesLanguageFilter(String language) {
    switch (_selectedLanguage) {
      case 'English':
        return language.toLowerCase().startsWith('en');
      case 'Malay':
        return language.toLowerCase().startsWith('ms');
      default:
        return true; // 'All' and 'auto' both show everything
    }
  }

  bool _matchesSourceFilter(String source) {
    switch (_selectedSource) {
      case 'Microphone':
        return source == 'microphone';
      case 'Media File':
        return source == 'media_file';
      default:
        return true;
    }
  }

  Widget _buildFilterDropdown(
    String currentValue,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButton<String>(
        value: currentValue,
        items: options
            .map(
              (option) => DropdownMenuItem(
                value: option,
                child: Text(option, style: const TextStyle(fontSize: 12)),
              ),
            )
            .toList(),
        onChanged: onChanged,
        underline: const SizedBox(),
        icon: const Icon(Icons.keyboard_arrow_down, size: 20),
        isDense: true,
      ),
    );
  }

  // ── Highlighted transcript ────────────────────────────────────────────────
  Widget _buildHighlightedText(
    String text,
    Map<String, dynamic> keywords,
    Color riskColor,
  ) {
    if (keywords.isEmpty) {
      return Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          height: 1.6,
          color: Colors.black87,
        ),
      );
    }

    final lower = text.toLowerCase();
    final List<Map<String, dynamic>> spans = [];
    int cursor = 0;

    List<_Match> matches = [];
    for (final keyword in keywords.keys) {
      int idx = 0;
      while (true) {
        idx = lower.indexOf(keyword, idx);
        if (idx == -1) break;
        matches.add(_Match(idx, idx + keyword.length));
        idx += keyword.length;
      }
    }
    matches.sort((a, b) => a.start.compareTo(b.start));

    for (final match in matches) {
      if (match.start < cursor) continue;
      if (match.start > cursor) {
        spans.add({
          'text': text.substring(cursor, match.start),
          'highlight': false,
        });
      }
      spans.add({
        'text': text.substring(match.start, match.end),
        'highlight': true,
      });
      cursor = match.end;
    }
    if (cursor < text.length) {
      spans.add({'text': text.substring(cursor), 'highlight': false});
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 15,
          height: 1.6,
          color: Colors.black87,
        ),
        children: spans.map((s) {
          if (!(s['highlight'] as bool)) {
            return TextSpan(text: s['text'] as String);
          }
          return TextSpan(
            text: s['text'] as String,
            style: TextStyle(
              backgroundColor: riskColor.withOpacity(0.18),
              color: riskColor,
              fontWeight: FontWeight.bold,
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Bottom sheet detail dialog ────────────────────────────────────────────
  void _showDetail(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
  ) {
    final score = (data['scamScore'] as num?)?.toDouble() ?? 0.0;
    final color = _riskColor(score);
    final text = data['text'] as String? ?? '';
    final keywords = (data['keywords'] as Map<String, dynamic>?) ?? {};
    final source = data['source'] as String? ?? 'microphone';
    final fileName = data['fileName'] as String?;
    final language = data['language'] as String? ?? 'en-US';
    final langLabel = language.startsWith('ms') ? 'Malay' : 'English';
    final ts = data['timestamp'] as Timestamp?;
    final isFile = source == 'media_file';
    final wordCount = text
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF5F6FA),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // ── Drag handle ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ── Sheet header ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
                child: Row(
                  children: [
                    Icon(_riskIcon(score), color: color, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _riskLabel(score),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const Spacer(),
                    // Copy button
                    IconButton(
                      icon: const Icon(Icons.copy_outlined, size: 20),
                      color: const Color(0xFF1A3A6B),
                      tooltip: 'Copy transcript',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: text));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Row(
                              children: [
                                Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                SizedBox(width: 8),
                                Text('Transcript copied'),
                              ],
                            ),
                            backgroundColor: const Color(0xFF1A3A6B),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                    // Delete button
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: Colors.red.shade400,
                      ),
                      tooltip: 'Delete',
                      onPressed: () => _confirmDelete(ctx, context, docId),
                    ),
                    // Close button
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      color: Colors.grey,
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),

              // ── Scrollable content ──────────────────────────────────────
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  children: [
                    // ── Risk gauge ────────────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: color.withOpacity(0.4),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${score.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 32,
                                  color: color,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _riskLabel(score),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: score / 100,
                              minHeight: 10,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation<Color>(color),
                            ),
                          ),
                          const SizedBox(height: 14),
                          // Meta chips
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              _metaChip(
                                isFile ? Icons.attach_file : Icons.mic,
                                isFile
                                    ? (fileName ?? 'Media File')
                                    : 'Microphone',
                                Colors.indigo,
                              ),
                              _metaChip(Icons.language, langLabel, Colors.teal),
                              _metaChip(
                                Icons.crisis_alert,
                                '${keywords.length} keyword${keywords.length == 1 ? '' : 's'}',
                                color,
                              ),
                              _metaChip(
                                Icons.text_fields,
                                '$wordCount words',
                                Colors.blueGrey,
                              ),
                              if (ts != null)
                                _metaChip(
                                  Icons.access_time,
                                  _formatFullTimestamp(ts.toDate()),
                                  Colors.grey,
                                ),
                            ],
                          ),

                          // Keyword chips
                          if (keywords.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            const Divider(height: 1, color: Color(0xFFEEEEEE)),
                            const SizedBox(height: 12),
                            const Text(
                              'DETECTED KEYWORDS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.black45,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: keywords.entries.map((e) {
                                final val = (e.value as num).toInt();
                                final Color chipColor = val >= 6
                                    ? const Color(0xFFD32F2F)
                                    : val >= 3
                                    ? const Color(0xFFF57C00)
                                    : const Color(0xFFF9A825);
                                final String tag = val >= 6
                                    ? 'High'
                                    : val >= 3
                                    ? 'Med'
                                    : 'Low';
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: chipColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: chipColor.withOpacity(0.4),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        e.key,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: chipColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 5,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: chipColor,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Text(
                                          tag,
                                          style: const TextStyle(
                                            fontSize: 9,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ── Full transcript ───────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.article_outlined,
                                size: 15,
                                color: Colors.black45,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'FULL TRANSCRIPT',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black45,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Divider(height: 1, color: Color(0xFFEEEEEE)),
                          const SizedBox(height: 14),
                          text.isEmpty
                              ? Text(
                                  'No transcript available.',
                                  style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 14,
                                  ),
                                )
                              : _buildHighlightedText(text, keywords, color),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ── NLP Analysis ─────────────────────────────────
                    Builder(
                      builder: (context) {
                        final nlpSummary =
                            (data['nlpSummary'] as String?) ?? '';
                        final nlpTactics = List<String>.from(
                          (data['nlpTactics'] as List?) ?? [],
                        );
                        final nlpRedFlags = List<String>.from(
                          (data['nlpRedFlags'] as List?) ?? [],
                        );
                        final nlpActions = List<String>.from(
                          (data['nlpActions'] as List?) ?? [],
                        );

                        if (nlpSummary.isEmpty &&
                            nlpTactics.isEmpty &&
                            nlpRedFlags.isEmpty &&
                            nlpActions.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'NLP Analysis',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 10),
                              if (nlpSummary.isNotEmpty) ...[
                                Text(
                                  nlpSummary,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                    height: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              if (nlpTactics.isNotEmpty) ...[
                                const Text(
                                  'Tactics',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: nlpTactics.map((t) {
                                    final label = t
                                        .replaceAll('_', ' ')
                                        .split(' ')
                                        .map(
                                          (w) => w.isEmpty
                                              ? ''
                                              : '${w[0].toUpperCase()}${w.substring(1)}',
                                        )
                                        .join(' ');
                                    return Chip(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      backgroundColor: Colors.grey.shade100,
                                      label: Text(
                                        label,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 12),
                              ],
                              if (nlpRedFlags.isNotEmpty) ...[
                                const Text(
                                  'Red Flags',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: nlpRedFlags.map((rf) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            margin: const EdgeInsets.only(
                                              top: 6,
                                            ),
                                            width: 6,
                                            height: 6,
                                            decoration: BoxDecoration(
                                              color: color,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              rf,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: Colors.black87,
                                                height: 1.5,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 12),
                              ],
                              if (nlpActions.isNotEmpty) ...[
                                const Text(
                                  'Recommended Actions',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: nlpActions.take(3).map((act) {
                                    return ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        side: BorderSide(
                                          color: color.withOpacity(0.12),
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                        ),
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                      ),
                                      onPressed: () {},
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.check_circle_outline,
                                            size: 14,
                                            color: color,
                                          ),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Text(
                                              act,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey.shade800,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Delete confirmation ───────────────────────────────────────────────────
  void _confirmDelete(
    BuildContext sheetCtx,
    BuildContext screenCtx,
    String docId,
  ) {
    showDialog(
      context: sheetCtx,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Entry',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to delete this entry? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx); // close confirm dialog
              Navigator.pop(sheetCtx); // close bottom sheet
              await FirebaseFirestore.instance
                  .collection('history')
                  .doc(docId)
                  .delete();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _metaChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
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
          child: const AppHeader(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() {
                    _searchQuery = value.trim();
                  }),
                  decoration: InputDecoration(
                    hintText: 'Search transcript text',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                                _searchController.clear();
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                ), // ← TextField closed here
                // ── NLP Analysis Details ───────────────────────────
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 120,
                        child: _buildFilterDropdown(
                          _selectedRisk,
                          _riskOptions,
                          (value) {
                            setState(() {
                              _selectedRisk = value ?? 'All';
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 120,
                        child: _buildFilterDropdown(
                          _selectedLanguage,
                          _languageOptions,
                          (value) {
                            setState(() {
                              _selectedLanguage = value ?? 'All';
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 120,
                        child: _buildFilterDropdown(
                          _selectedSource,
                          _sourceOptions,
                          (value) {
                            setState(() {
                              _selectedSource = value ?? 'All';
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('history')
                  .where(
                    'userId',
                    isEqualTo: FirebaseAuth.instance.currentUser?.uid,
                  )
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF1A3A6B)),
                  );
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final docs = snapshot.data!.docs;
                final filteredDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final text = (data['text'] as String? ?? '');
                  final score = (data['scamScore'] ?? 0).toDouble();
                  final source = data['source'] as String? ?? 'microphone';
                  final language = (data['language'] as String? ?? 'en-US');

                  return _matchesSearchQuery(text) &&
                      _matchesRiskFilter(score) &&
                      _matchesSourceFilter(source) &&
                      _matchesLanguageFilter(language);
                }).toList();

                final total = filteredDocs.length;
                final scams = filteredDocs.where((d) {
                  final score = ((d.data() as Map)['scamScore'] ?? 0)
                      .toDouble();
                  return score >= 30;
                }).length;

                return Column(
                  children: [
                    // ── Stats banner ────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          _StatCard(
                            label: "Total Analyses",
                            value: "$total",
                            icon: Icons.analytics_outlined,
                            iconColor: const Color(0xFF1A3A6B),
                            bgColor: const Color(0xFFE8EEF8),
                          ),
                          const SizedBox(width: 12),
                          _StatCard(
                            label: "Scams Detected",
                            value: "$scams",
                            icon: Icons.gpp_bad_outlined,
                            iconColor: const Color(0xFFD32F2F),
                            bgColor: const Color(0xFFFDECEC),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── List ────────────────────────────────────────────
                    Expanded(
                      child: filteredDocs.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.filter_alt_off,
                                    size: 48,
                                    color: Colors.grey.shade300,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    docs.isEmpty
                                        ? "No history yet"
                                        : "No matching records",
                                    style: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    docs.isEmpty
                                        ? "Saved analyses will appear here"
                                        : "Try a different search or filter.",
                                    style: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              itemCount: filteredDocs.length,
                              itemBuilder: (context, index) {
                                final doc = filteredDocs[index];
                                final data = doc.data() as Map<String, dynamic>;
                                final score = (data['scamScore'] ?? 0)
                                    .toDouble();
                                final color = _riskColor(score);
                                final ts = data['timestamp'] as Timestamp?;
                                final timeLabel = ts != null
                                    ? _formatTime(ts.toDate())
                                    : '';
                                final source =
                                    data['source'] as String? ?? 'microphone';
                                final fileName = data['fileName'] as String?;
                                final language =
                                    data['language'] as String? ?? 'en-US';
                                final langLabel = language.startsWith('ms')
                                    ? 'Malay'
                                    : 'English';
                                final isFile = source == 'media_file';
                                final keywords =
                                    (data['keywords'] as Map?) ?? {};

                                return GestureDetector(
                                  onTap: () =>
                                      _showDetail(context, doc.id, data),
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: color.withOpacity(0.25),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.04),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Card header
                                        Container(
                                          padding: const EdgeInsets.fromLTRB(
                                            14,
                                            12,
                                            14,
                                            10,
                                          ),
                                          decoration: BoxDecoration(
                                            color: color.withOpacity(0.05),
                                            borderRadius:
                                                const BorderRadius.vertical(
                                                  top: Radius.circular(12),
                                                ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                _riskIcon(score),
                                                color: color,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                _riskLabel(score),
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: color,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              const Spacer(),
                                              Text(
                                                '${score.toStringAsFixed(1)}%',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: color,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Icon(
                                                Icons.chevron_right,
                                                size: 18,
                                                color: color.withOpacity(0.5),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Transcript preview
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            14,
                                            10,
                                            14,
                                            10,
                                          ),
                                          child: Text(
                                            data['text'] ?? '',
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ),
                                        // Footer
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            14,
                                            0,
                                            14,
                                            12,
                                          ),
                                          child: Row(
                                            children: [
                                              _MetaBadge(
                                                icon: isFile
                                                    ? Icons.attach_file
                                                    : Icons.mic,
                                                label: isFile
                                                    ? (fileName ?? 'File')
                                                    : 'Microphone',
                                                color: Colors.indigo,
                                              ),
                                              const SizedBox(width: 6),
                                              _MetaBadge(
                                                icon: Icons.language,
                                                label: langLabel,
                                                color: Colors.teal,
                                              ),
                                              const SizedBox(width: 6),
                                              _MetaBadge(
                                                icon: Icons.key,
                                                label: '${keywords.length} kw',
                                                color: Colors.blueGrey,
                                              ),
                                              const Spacer(),
                                              if (timeLabel.isNotEmpty)
                                                Text(
                                                  timeLabel,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reusable widgets ──────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color bgColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MetaBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 90),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _Match {
  final int start;
  final int end;
  _Match(this.start, this.end);
}
