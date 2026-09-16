import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:whoyou/widgets/app_header.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vibration/vibration.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:whoyou/config/api_keys.dart';

enum InputMode { microphone, mediaFile }

// ── NLP result model ──────────────────────────────────────────────────────────
class NlpResult {
  final double nlpScore;
  final String riskLevel;
  final List<String> tactics;
  final List<String> recommendedActions;
  final String summary;
  final List<String> redFlags;

  const NlpResult({
    required this.nlpScore,
    required this.riskLevel,
    required this.tactics,
    required this.recommendedActions,
    required this.summary,
    required this.redFlags,
  });

  factory NlpResult.empty() => const NlpResult(
    nlpScore: 0,
    riskLevel: 'SAFE',
    tactics: [],
    recommendedActions: [],
    summary: '',
    redFlags: [],
  );
}

class DetectionScreen extends StatefulWidget {
  const DetectionScreen({super.key});

  @override
  State<DetectionScreen> createState() => _DetectionScreenState();
}

class _DetectionScreenState extends State<DetectionScreen>
    with SingleTickerProviderStateMixin {
  late stt.SpeechToText _speech;
  bool _isListening = false;

  InputMode _inputMode = InputMode.microphone;
  File? _selectedFile;
  String? _selectedFileName;
  bool _isTranscribingFile = false;
  double _transcribeProgress = 0.0;
  String? _fileType;

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _audioDuration = Duration.zero;
  Duration _audioPosition = Duration.zero;

  String _text = "Press the microphone button to start...";
  Map<String, int> scamKeywords = {};
  Map<String, int> detectedKeywords = {};

  // ── Keyword score (fast pass) ─────────────────────────────────────────────
  double keywordScore = 0.0;
  int totalWords = 0;

  // Prevent duplicate vibration for the same analysis
  bool _vibrationTriggered = false;

  // ── NLP score (Groq LLM deep pass) ───────────────────────────────────────
  NlpResult? _nlpResult;
  bool _isAnalyzingNlp = false;

  // ── Final combined score ──────────────────────────────────────────────────
  double scamScore = 0.0;

  // ── Save state ────────────────────────────────────────────────────────────
  bool _isSaved = false;
  bool _isSaving = false;

  // String _selectedLanguage = "en-US";
  // final Map<String, String> _languages = {
  //   "English": "en-US",
  //   "Malay": "ms-MY",
  //   "Mixed (MY)": "ms-MY", // Whisper handles mixed better with ms locale
  // };

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    fetchKeywords();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _audioPlayer.durationStream.listen((d) {
      if (d != null) setState(() => _audioDuration = d);
    });
    _audioPlayer.positionStream.listen((p) {
      setState(() => _audioPosition = p);
    });
    _audioPlayer.playerStateStream.listen((state) {
      setState(() => _isPlaying = state.playing);
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _speech.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  // ── Save to Firebase ──────────────────────────────────────────────────────
  Future<void> _saveToFirebase() async {
    if (_text.isEmpty || _isSaved || _isSaving) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance.collection('history').add({
        "text": _text,
        "scamScore": scamScore,
        "keywordScore": keywordScore,
        "nlpScore": _nlpResult?.nlpScore ?? 0,
        "keywords": detectedKeywords,
        "nlpTactics": _nlpResult?.tactics ?? [],
        "nlpActions": _nlpResult?.recommendedActions ?? [],
        "nlpRedFlags": _nlpResult?.redFlags ?? [],
        "nlpSummary": _nlpResult?.summary ?? '',
        "language": "auto",
        "source": _inputMode == InputMode.mediaFile
            ? "media_file"
            : "microphone",
        "fileName": _selectedFileName,
        "userId": user.uid,
        "timestamp": FieldValue.serverTimestamp(),
      });

      setState(() {
        _isSaved = true;
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text("Saved to history"),
              ],
            ),
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to save: $e"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _resetSaveState() => setState(() {
    _isSaved = false;
    _isSaving = false;
    _vibrationTriggered = false;
  });

  Future<void> fetchKeywords() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('scam_keywords')
        .get();
    setState(() {
      scamKeywords = {
        for (var doc in snapshot.docs)
          doc['keyword']
              .toString()
              .toLowerCase(): (doc.data().containsKey('weight')
              ? (doc['weight'] as num).toInt()
              : 1),
      };
    });
  }

  // ── Microphone ────────────────────────────────────────────────────────────
  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            setState(() => _isListening = false);
            // Run NLP after mic stops if keyword score warrants it
            if (_text.isNotEmpty && keywordScore >= 10) {
              _runNlpAnalysis(_text);
            }
          }
        },
        onError: (error) => debugPrint('ERROR: $error'),
      );

      if (available) {
        _resetSaveState();
        setState(() {
          _isListening = true;
          _text = "";
          detectedKeywords = {};
          scamScore = 0.0;
          keywordScore = 0.0;
          totalWords = 0;
          _nlpResult = null;
        });

        _speech.listen(
          // No localeId = device default, but Whisper handles the rest
          listenMode: stt.ListenMode.dictation,
          partialResults: true,
          onResult: (result) {
            setState(() => _text = result.recognizedWords);
            _analyzeKeywords(_text);
          },
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  // ── Media File Picker ─────────────────────────────────────────────────────
  Future<void> _pickMediaFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'mp3',
        'wav',
        'opus',
        'm4a',
        'aac',
        'mp4',
        'mov',
        'mkv',
        'avi',
      ],
    );

    if (result == null || result.files.single.path == null) return;

    final path = result.files.single.path!;
    final name = result.files.single.name;
    final ext = name.split('.').last.toLowerCase();
    final isVideo = ['mp4', 'mov', 'mkv', 'avi'].contains(ext);

    _resetSaveState();
    setState(() {
      _selectedFile = File(path);
      _selectedFileName = name;
      _fileType = isVideo ? 'video' : 'audio';
      _text = "";
      detectedKeywords = {};
      scamScore = 0.0;
      keywordScore = 0.0;
      totalWords = 0;
      _nlpResult = null;
      _audioPosition = Duration.zero;
      _audioDuration = Duration.zero;
    });

    if (!isVideo) {
      try {
        await _audioPlayer.setFilePath(path);
      } catch (e) {
        debugPrint("Audio player error: $e");
      }
    }
  }

  // ── Transcribe ────────────────────────────────────────────────────────────
  Future<void> _transcribeFile() async {
    if (_selectedFile == null) return;

    _resetSaveState();
    setState(() {
      _isTranscribingFile = true;
      _transcribeProgress = 0.0;
      _text = "";
      detectedKeywords = {};
      scamScore = 0.0;
      keywordScore = 0.0;
      totalWords = 0;
      _nlpResult = null;
    });

    try {
      File audioFile = _selectedFile!;

      if (_fileType == 'video') {
        setState(() => _transcribeProgress = 0.15);
        audioFile = await _extractAudioFromVideo(_selectedFile!);
      }

      setState(() => _transcribeProgress = 0.35);
      final transcription = await _groqTranscribe(audioFile);
      setState(() => _transcribeProgress = 0.7);

      if (transcription != null && transcription.isNotEmpty) {
        setState(() => _text = transcription);
        _analyzeKeywords(transcription);

        // Run NLP after transcription
        setState(() => _transcribeProgress = 0.85);
        await _runNlpAnalysis(transcription);
      } else {
        setState(
          () => _text = "Could not transcribe the file. Please try another.",
        );
      }
    } catch (e) {
      setState(() => _text = "Transcription error: $e");
    } finally {
      setState(() {
        _isTranscribingFile = false;
        _transcribeProgress = 1.0;
      });
    }
  }

  Future<File> _extractAudioFromVideo(File videoFile) async {
    final dir = await getTemporaryDirectory();
    final outputPath =
        '${dir.path}/extracted_audio_${DateTime.now().millisecondsSinceEpoch}.wav';
    final session = await FFmpegKit.execute(
      '-i "${videoFile.path}" -vn -acodec pcm_s16le -ar 16000 -ac 1 "$outputPath" -y',
    );
    final returnCode = await session.getReturnCode();
    if (!ReturnCode.isSuccess(returnCode)) {
      final logs = await session.getAllLogsAsString();
      throw Exception("FFmpeg failed: $logs");
    }
    return File(outputPath);
  }

  Future<String?> _groqTranscribe(File audioFile) async {
    final uri = Uri.parse(
      'https://api.groq.com/openai/v1/audio/transcriptions',
    );

    final ext = audioFile.path.split('.').last.toLowerCase();
    MediaType mimeType;
    switch (ext) {
      case 'mp3':
        mimeType = MediaType('audio', 'mpeg');
        break;
      case 'opus':
        // WhatsApp voice notes use the OPUS codec typically in an Ogg container
        mimeType = MediaType('audio', 'ogg');
        break;
      case 'm4a':
        mimeType = MediaType('audio', 'mp4');
        break;
      case 'aac':
        mimeType = MediaType('audio', 'aac');
        break;
      default:
        mimeType = MediaType('audio', 'wav');
    }

    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $groqApiKey'
      ..fields['model'] = 'whisper-large-v3-turbo'
      ..fields['response_format'] = 'text'
      // No language field = Whisper auto-detects
      ..fields['prompt'] =
          'This may be a Malaysian phone conversation in English, '
          'Malay, or mixed Malay-English (Manglish). '
          'Common mixed phrases: okay lah, boleh ke, transfer duit, '
          'akaun bank, nombor IC, OTP number, verify account, '
          'polis akan tangkap, lucky draw menang, akaun kena freeze.'
      ..files.add(
        await http.MultipartFile.fromPath(
          'file',
          audioFile.path,
          contentType: mimeType,
        ),
      );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode == 200) return response.body.trim();
    throw Exception("Groq transcription error: ${response.statusCode}");
  }

  // ── STEP 1: Keyword analysis (fast, always runs) ──────────────────────────
  void _analyzeKeywords(String text) {
    if (text.trim().isEmpty) return;

    final words = text
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    totalWords = words.length;

    Map<String, int> found = {};
    for (final entry in scamKeywords.entries) {
      final keyword = entry.key;
      final weight = entry.value;
      if (text.toLowerCase().contains(keyword)) {
        int count = 0;
        int idx = 0;
        while (true) {
          idx = text.toLowerCase().indexOf(keyword, idx);
          if (idx == -1) break;
          count++;
          idx += keyword.length;
        }
        found[keyword] = weight * count;
      }
    }

    double rawScore = 0;
    if (totalWords > 0) {
      final weightedHits = found.values.fold<int>(0, (sum, val) => sum + val);
      rawScore = (weightedHits / totalWords) * 100;
      if (rawScore > 100) rawScore = 100;
    }

    setState(() {
      detectedKeywords = found;
      keywordScore = rawScore;
      // Before NLP runs, combined score = keyword score only
      if (_nlpResult == null) scamScore = rawScore;
    });

    // Trigger NLP only if keyword score crosses threshold (saves Groq quota)
    // NLP runs once when listening stops (for mic) or after transcription (for file)
    if (rawScore >= 30 && found.isNotEmpty) {
      if (!_vibrationTriggered) {
        Vibration.vibrate(duration: 500);
        _vibrationTriggered = true;
      }
    }
  }

  // ── STEP 2: NLP analysis via Groq LLM (runs after keyword threshold met) ──
  Future<void> _runNlpAnalysis(String text) async {
    if (text.trim().isEmpty || text.split(' ').length < 5) return;

    setState(() => _isAnalyzingNlp = true);

    try {
      final uri = Uri.parse('https://api.groq.com/openai/v1/chat/completions');

      const langNote =
          'The transcript may be in English, Malay, or mixed Malay-English (Manglish), '
          'which is common in Malaysian phone conversations. '
          'Analyse all languages equally. '
          'Common mixed scam phrases: "transfer duit sekarang", '
          '"akaun you kena freeze", "OTP jangan bagi sesiapa", '
          '"lucky draw you menang", "polis akan tangkap you".';

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $groqApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'llama-3.3-70b-versatile',
          'temperature': 0.1,
          'max_tokens': 500,
          'messages': [
            {
              'role': 'system',
              'content':
                  '''You are an expert scam detection AI specialising in Malaysian phone scams (Macau scam, bank scam, parcel scam, love scam, investment scam, PDRM/SPRM/LHDN impersonation).
  $langNote
  Analyse the transcript and return ONLY a valid JSON object with NO extra text, markdown, or explanation:
  {
    "nlpScore": <0-100 integer, likelihood this is a scam call>,
    "riskLevel": <"SAFE" | "LOW" | "MEDIUM" | "HIGH">,
    "tactics": [<list of detected tactics from: urgency, impersonation, threats, prize_scam, investment_fraud, loan_scam, love_scam, authority_impersonation, otp_request, bank_transfer_request, personal_info_request, fear_induction, isolation_tactic>],
    "summary": <one sentence summary of what the call is about>,
    "redFlags": [<up to 5 specific phrases or behaviours that indicate a scam>],
    "recommendedActions": [<up to 3 concise recommended actions the user should take, e.g. "Block number", "Do not transfer money", "Verify with bank via official channels">]
  }
  If the transcript is too short or clearly not a scam, return nlpScore 0, riskLevel SAFE, empty arrays, summary "No scam indicators detected.", and an empty recommendedActions array.''',
            },
            {'role': 'user', 'content': 'Analyse this transcript:\n\n$text'},
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String;

        // Strip any accidental markdown fences
        final cleaned = content.replaceAll(RegExp(r'```json|```'), '').trim();
        final parsed = jsonDecode(cleaned);

        final nlpResult = NlpResult(
          nlpScore: (parsed['nlpScore'] as num).toDouble(),
          riskLevel: parsed['riskLevel'] as String,
          tactics: List<String>.from(parsed['tactics'] ?? []),
          recommendedActions: List<String>.from(
            parsed['recommendedActions'] ?? [],
          ),
          summary: parsed['summary'] as String? ?? '',
          redFlags: List<String>.from(parsed['redFlags'] ?? []),
        );

        // ── Combine keyword + NLP scores (60% NLP, 40% keyword) ──────────
        final combined = (nlpResult.nlpScore * 0.6) + (keywordScore * 0.4);

        setState(() {
          _nlpResult = nlpResult;
          scamScore = combined.clamp(0, 100);
        });

        if (combined >= 30 && !_vibrationTriggered) {
          Vibration.vibrate(duration: 600);
          _vibrationTriggered = true;
        }
      } else {
        debugPrint("NLP error ${response.statusCode}: ${response.body}");
      }
    } catch (e) {
      debugPrint("NLP analysis error: $e");
    } finally {
      setState(() => _isAnalyzingNlp = false);
    }
  }

  // ── Risk helpers (use combined scamScore) ─────────────────────────────────
  Color get _riskColor {
    if (scamScore >= 60) return const Color(0xFFD32F2F);
    if (scamScore >= 30) return const Color(0xFFF57C00);
    if (scamScore > 0) return const Color(0xFFF9A825);
    return const Color(0xFF2E7D32);
  }

  String get _riskLabel {
    if (scamScore >= 60) return 'HIGH RISK';
    if (scamScore >= 30) return 'MEDIUM RISK';
    if (scamScore > 0) return 'LOW RISK';
    return 'SAFE';
  }

  IconData get _riskIcon {
    if (scamScore >= 60) return Icons.dangerous_outlined;
    if (scamScore >= 30) return Icons.warning_amber_rounded;
    if (scamScore > 0) return Icons.info_outline;
    return Icons.verified_user_outlined;
  }

  bool get _hasContent =>
      _text.isNotEmpty &&
      _text != "Press the microphone button to start..." &&
      _text != "Pick an audio or video file to analyse." &&
      !_text.startsWith("Language switched") &&
      !_text.startsWith("Could not") &&
      !_text.startsWith("Transcription error");

  // ── Tactic label formatter ────────────────────────────────────────────────
  String _formatTactic(String tactic) {
    return tactic
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
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
            left: 16,
            right: 16,
            bottom: 12,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const AppHeader(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A3A6B).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.language, size: 14, color: Color(0xFF1A3A6B)),
                    SizedBox(width: 6),
                    Text(
                      'Auto-detect language',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF1A3A6B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            _buildModeToggle(),
            const SizedBox(height: 12),

            if (_inputMode == InputMode.microphone) ...[
              _buildMicListenButton(),
              const SizedBox(height: 12),
            ],

            if (_inputMode == InputMode.mediaFile) ...[
              _buildMediaFilePanel(),
              const SizedBox(height: 10),
            ],

            // ── Transcription Box ─────────────────────────────────────────
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                padding: const EdgeInsets.all(16),
                width: double.infinity,
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
                  children: [
                    if (_hasContent)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
                        child: Row(
                          children: [
                            Icon(
                              Icons.article_outlined,
                              size: 15,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _inputMode == InputMode.mediaFile &&
                                        _selectedFileName != null
                                    ? _selectedFileName!
                                    : 'Transcription',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Save button
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              child: _isSaved
                                  ? Container(
                                      key: const ValueKey('saved'),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF2E7D32,
                                        ).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.check_circle,
                                            size: 14,
                                            color: Color(0xFF2E7D32),
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'Saved',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF2E7D32),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : GestureDetector(
                                      key: const ValueKey('save'),
                                      onTap: _isSaving ? null : _saveToFirebase,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1A3A6B),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: _isSaving
                                            ? const SizedBox(
                                                width: 14,
                                                height: 14,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                              )
                                            : const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.save_alt,
                                                    size: 14,
                                                    color: Colors.white,
                                                  ),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    'Save',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.white,
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

                    if (_hasContent)
                      Divider(
                        height: 14,
                        thickness: 1,
                        color: Colors.grey.shade100,
                      ),

                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
                        child: SingleChildScrollView(
                          child: _text.isEmpty
                              ? Center(
                                  child: Text(
                                    _inputMode == InputMode.microphone
                                        ? 'Listening...'
                                        : 'Transcription will appear here...',
                                    style: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 15,
                                    ),
                                  ),
                                )
                              : _hasContent
                              ? _buildHighlightedText()
                              : Text(
                                  _text,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Scam Risk Gauge ──────────────────────────────────────────
            if (_hasContent)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    final shouldPulse = scamScore >= 60 && _isListening;
                    return Transform.scale(
                      scale: shouldPulse ? _pulseAnimation.value : 1.0,
                      child: child,
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 400),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _riskColor.withOpacity(0.4),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _riskColor.withOpacity(0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Score row ──────────────────────────────────
                          Row(
                            children: [
                              Icon(_riskIcon, color: _riskColor, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Scam Risk: $_riskLabel',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: _riskColor,
                                ),
                              ),
                              const Spacer(),
                              // NLP loading indicator
                              if (_isAnalyzingNlp) ...[
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF1A3A6B),
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                '${scamScore.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 22,
                                  color: _riskColor,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: scamScore / 100,
                              minHeight: 10,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _riskColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // ── Stat chips ─────────────────────────────────
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              _statChip(
                                Icons.text_fields,
                                '$totalWords words',
                                Colors.blueGrey,
                              ),
                              _statChip(
                                Icons.crisis_alert,
                                '${detectedKeywords.length} keyword${detectedKeywords.length == 1 ? "" : "s"}',
                                _riskColor,
                              ),
                              _statChip(
                                _inputMode == InputMode.mediaFile
                                    ? Icons.attach_file
                                    : Icons.mic,
                                _inputMode == InputMode.mediaFile
                                    ? 'File'
                                    : 'Mic',
                                Colors.indigo,
                              ),
                            ],
                          ),

                          // ── NLP Summary ────────────────────────────────
                          if (_nlpResult != null &&
                              _nlpResult!.summary.isNotEmpty &&
                              _nlpResult!.summary !=
                                  'No scam indicators detected.') ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF6A1B9A,
                                ).withOpacity(0.06),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(
                                    0xFF6A1B9A,
                                  ).withOpacity(0.2),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.psychology,
                                    size: 14,
                                    color: Color(0xFF6A1B9A),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _nlpResult!.summary,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF4A148C),
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 12),

                          Center(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1A3A6B),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                              ),
                              onPressed: _nlpResult == null
                                  ? null
                                  : _showAnalysisPopup,
                              icon: const Icon(
                                Icons.analytics,
                                size: 16,
                                color: Colors.white,
                              ),
                              label: const Text(
                                "See Analysis Details",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),

                          // ── NLP loading state ──────────────────────────
                          if (_isAnalyzingNlp) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF6A1B9A,
                                ).withOpacity(0.06),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Row(
                                children: [
                                  SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF6A1B9A),
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Running NLP analysis...',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF4A148C),
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            if (_hasContent) const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // ── Analysis Details Popup ─────────────────────────────────────────
  void _showAnalysisPopup() {
    if (_nlpResult == null) return;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Container(
              color: const Color(0xFFF5F6FA),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              constraints: const BoxConstraints(maxHeight: 520),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: _riskColor.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(_riskIcon, color: _riskColor, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Analysis Details',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Deep insights from the transcript',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 22),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  _riskColor.withOpacity(0.18),
                                  _riskColor.withOpacity(0.05),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(18),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${scamScore.toStringAsFixed(1)}% Scam Risk',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: _riskColor,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _riskLabel,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: _riskColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _riskColor.withOpacity(0.14),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    _riskLabel,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: _riskColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Quick Summary',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _nlpResult!.summary.isNotEmpty
                                      ? _nlpResult!.summary
                                      : 'No scam indicators detected.',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                    height: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _detailBadge(
                                      icon: _inputMode == InputMode.mediaFile
                                          ? Icons.attach_file
                                          : Icons.mic,
                                      label: _inputMode == InputMode.mediaFile
                                          ? 'Media File'
                                          : 'Microphone',
                                      color: Colors.indigo,
                                    ),
                                    _detailBadge(
                                      icon: Icons.text_snippet,
                                      label: '$totalWords words',
                                      color: Colors.blueGrey,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (_nlpResult!.tactics.isNotEmpty) ...[
                      const Text(
                        'Tactics identified',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _nlpResult!.tactics.map((tactic) {
                          return Chip(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            backgroundColor: _riskColor.withOpacity(0.1),
                            label: Text(
                              _formatTactic(tactic),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _riskColor,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 18),
                    ],
                    if (_nlpResult!.redFlags.isNotEmpty) ...[
                      const Text(
                        'Red flags detected',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _nlpResult!.redFlags.map((flag) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: _riskColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    flag,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black87,
                                      height: 1.6,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 18),
                    ],
                    if (detectedKeywords.isNotEmpty) ...[
                      const Text(
                        'Keywords detected',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: detectedKeywords.entries.map((e) {
                          final weight = scamKeywords[e.key] ?? 1;
                          return _keywordChip(e.key, weight);
                        }).toList(),
                      ),
                      const SizedBox(height: 18),
                    ],
                    if (_nlpResult!.recommendedActions.isNotEmpty) ...[
                      const Text(
                        'Suggested actions',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _nlpResult!.recommendedActions
                            .take(3)
                            .map(
                              (act) => ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  side: BorderSide(
                                    color: _riskColor.withOpacity(0.12),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
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
                                      color: _riskColor,
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
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 18),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _detailBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ── Widgets ───────────────────────────────────────────────────────────────
  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Widget _buildMicListenButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _listen,
          icon: Icon(
            _isListening ? Icons.mic_off : Icons.mic,
            color: Colors.white,
          ),
          label: Text(
            _isListening ? 'Stop Listening' : 'Start Listening',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _isListening
                ? Colors.red
                : const Color(0xFF1A3A6B),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildModeToggle() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          _modeTab(InputMode.microphone, Icons.mic, 'Microphone'),
          _modeTab(InputMode.mediaFile, Icons.attach_file, 'Media File'),
        ],
      ),
    );
  }

  Widget _modeTab(InputMode mode, IconData icon, String label) {
    final selected = _inputMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_isListening) {
            _speech.stop();
            setState(() => _isListening = false);
          }
          _resetSaveState();
          setState(() {
            _inputMode = mode;
            _text = mode == InputMode.microphone
                ? "Press the microphone button to start..."
                : _selectedFile == null
                ? "Pick an audio or video file to analyse."
                : _text;
            if (mode == InputMode.microphone) {
              detectedKeywords = {};
              scamScore = 0.0;
              keywordScore = 0.0;
              totalWords = 0;
              _nlpResult = null;
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF1A3A6B) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : Colors.grey,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaFilePanel() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          GestureDetector(
            onTap: _isTranscribingFile ? null : _pickMediaFile,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _selectedFile != null
                      ? const Color(0xFF1A3A6B).withOpacity(0.4)
                      : Colors.grey.shade300,
                  width: 1.5,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: _selectedFile == null
                  ? Column(
                      children: [
                        Icon(
                          Icons.upload_file,
                          size: 40,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Upload audio or video file',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Supports: MP3, WAV, M4A, AAC, OPUS, MP4, MOV, MKV, AVI',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A3A6B).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _fileType == 'video'
                                ? Icons.videocam_outlined
                                : Icons.audio_file_outlined,
                            color: const Color(0xFF1A3A6B),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedFileName ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                _fileType == 'video'
                                    ? 'Video file — audio will be extracted'
                                    : 'Audio file',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: _isTranscribingFile ? null : _pickMediaFile,
                          child: const Icon(
                            Icons.swap_horiz,
                            color: Color(0xFF1A3A6B),
                          ),
                        ),
                      ],
                    ),
            ),
          ),

          if (_selectedFile != null && _fileType == 'audio') ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: const Color(0xFF1A3A6B),
                    ),
                    onPressed: () async {
                      if (_isPlaying) {
                        await _audioPlayer.pause();
                      } else {
                        await _audioPlayer.play();
                      }
                    },
                  ),
                  Expanded(
                    child: Slider(
                      value: _audioPosition.inSeconds.toDouble().clamp(
                        0,
                        _audioDuration.inSeconds.toDouble(),
                      ),
                      max: _audioDuration.inSeconds.toDouble().clamp(
                        1,
                        double.infinity,
                      ),
                      activeColor: const Color(0xFF1A3A6B),
                      inactiveColor: Colors.grey.shade200,
                      onChanged: (v) =>
                          _audioPlayer.seek(Duration(seconds: v.toInt())),
                    ),
                  ),
                  Text(
                    '${_formatDuration(_audioPosition)} / ${_formatDuration(_audioDuration)}',
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ],

          if (_selectedFile != null) ...[
            const SizedBox(height: 10),
            if (_isTranscribingFile)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF1A3A6B),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _transcribeProgress < 0.7
                              ? (_fileType == 'video'
                                    ? 'Extracting audio & transcribing...'
                                    : 'Transcribing audio...')
                              : 'Running NLP analysis...',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: _transcribeProgress,
                        minHeight: 6,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF1A3A6B),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _transcribeFile,
                  icon: const Icon(Icons.transcribe, color: Colors.white),
                  label: const Text(
                    'Transcribe & Analyse',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A3A6B),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildHighlightedText() {
    if (detectedKeywords.isEmpty) {
      return Text(_text, style: const TextStyle(fontSize: 16));
    }
    final lower = _text.toLowerCase();
    List<TextSpan> spans = [];
    int cursor = 0;
    List<_Match> matches = [];
    for (final keyword in detectedKeywords.keys) {
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
        spans.add(TextSpan(text: _text.substring(cursor, match.start)));
      }
      spans.add(
        TextSpan(
          text: _text.substring(match.start, match.end),
          style: TextStyle(
            backgroundColor: _riskColor.withOpacity(0.18),
            color: _riskColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
      cursor = match.end;
    }
    if (cursor < _text.length) {
      spans.add(TextSpan(text: _text.substring(cursor)));
    }
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 16, color: Colors.black87),
        children: spans,
      ),
    );
  }

  Widget _statChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _keywordChip(String keyword, int weight) {
    final Color chipColor = weight >= 3
        ? const Color(0xFFD32F2F)
        : weight == 2
        ? const Color(0xFFF57C00)
        : const Color(0xFFF9A825);
    final String weightLabel = weight >= 3
        ? 'High'
        : weight == 2
        ? 'Med'
        : 'Low';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: chipColor.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            keyword,
            style: TextStyle(
              fontSize: 12,
              color: chipColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: chipColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              weightLabel,
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
  }
}

class _Match {
  final int start;
  final int end;
  const _Match(this.start, this.end);
}
