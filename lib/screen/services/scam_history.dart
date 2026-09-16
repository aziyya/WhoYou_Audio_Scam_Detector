class ScamHistory {
  final String text;
  final double scamScore;
  final Map<String, int> keywords;
  final String language;
  final DateTime timestamp;

  ScamHistory({
    required this.text,
    required this.scamScore,
    required this.keywords,
    required this.language,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      "text": text,
      "scamScore": scamScore,
      "keywords": keywords,
      "language": language,
      "timestamp": timestamp.toIso8601String(),
    };
  }

  factory ScamHistory.fromJson(Map<String, dynamic> json) {
    return ScamHistory(
      text: json["text"],
      scamScore: (json["scamScore"] as num).toDouble(),
      keywords: Map<String, int>.from(json["keywords"]),
      language: json["language"],
      timestamp: DateTime.parse(json["timestamp"]),
    );
  }
}
