import 'package:flutter/material.dart';
import '../models/article.dart';
import '../services/config_service.dart';
import '../services/rss_service.dart';

class FeedController extends ChangeNotifier {
  final ConfigService _configService = ConfigService();
  final RssService _rssService = RssService();

  List<Article> articles = [];
  bool isLoading = false;
  String? errorMessage;

  Future<void> syncFeed() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final sources = await _configService.fetchSources();
      if (sources.isEmpty) {
        errorMessage = "NO SOURCES CONFIG FOUND.";
        isLoading = false;
        notifyListeners();
        return;
      }

      List<Article> allArticles = [];
      for (var source in sources) {
        final sourceId = source['id'] ?? '';
        final sourceName = source['name'] ?? 'Unknown';
        final url = source['url'] ?? '';

        if (url.isNotEmpty) {
          final fetched = await _rssService.fetchArticles(
            sourceId,
            sourceName,
            url,
          );
          allArticles.addAll(fetched);
        }
      }

      // Sort chronological: Newest at the top
      allArticles.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

      // Defensive Programming: Cap the list at 50 to prevent memory bloat
      articles = allArticles.take(50).toList();
    } catch (e) {
      errorMessage = "SYSTEM SYNC FAILED.";
      debugPrint("Controller Error: $e");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
