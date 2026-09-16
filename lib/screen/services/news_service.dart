import 'dart:convert';
import 'package:http/http.dart' as http;

class NewsService {
  final String apiKey = "acde9c706acb40289d109f3cfef7d6f2"; // 🔥 replace this
  final List<String> keywords = [
    "scam",
    "fraud",
    "phishing",
  ]; // keywords to check

  Future<List<dynamic>> fetchNews() async {
    final url = Uri.parse(
      "https://newsapi.org/v2/everything?q=scam OR phishing &language=en&sortBy=publishedAt&apiKey=$apiKey",
    );

    final response = await http.get(url).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final articles = data["articles"] as List<dynamic>;

      return articles.where((article) {
        final title = (article["title"] ?? "").toString().toLowerCase();
        return keywords.any((keyword) => title.contains(keyword.toLowerCase()));
      }).toList();
    } else {
      throw Exception("Failed to load news");
    }
  }
}
