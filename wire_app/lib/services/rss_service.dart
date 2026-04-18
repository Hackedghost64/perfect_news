import 'dart:io'; // INJECTED: Required for HttpDate
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'package:flutter/foundation.dart';
import '../models/article.dart';
import 'text_rank.dart';

class RssService {
  Future<List<Article>> fetchArticles(
    String sourceId,
    String sourceName,
    String url,
  ) async {
    List<Article> articles = [];

    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint("WARN: Failed to fetch $sourceName");
        return [];
      }

      final document = XmlDocument.parse(response.body);
      final items = document.findAllElements('item');

      for (var item in items) {
        final title =
            item.findElements('title').firstOrNull?.innerText ?? "No Title";
        final link = item.findElements('link').firstOrNull?.innerText ?? "";
        final description =
            item.findElements('description').firstOrNull?.innerText ?? "";
        final pubDateStr =
            item.findElements('pubDate').firstOrNull?.innerText ?? "";

        DateTime pubDate = DateTime.now();
        try {
          pubDate = _parseRssDate(pubDateStr);
        } catch (_) {
          // Silent fail to current time if the RSS feed has a mangled date format
        }

        final bullets = TextRank.summarize(description);

        articles.add(
          Article(
            id: link,
            title: title,
            source: sourceName,
            url: link,
            bulletPoints: bullets,
            publishedAt: pubDate,
          ),
        );
      }
    } catch (e) {
      debugPrint("ERROR: RSS parsing failed for $sourceName -> $e");
    }

    return articles;
  }

  DateTime _parseRssDate(String dateString) {
    try {
      // CORRECTED: Uses native dart:io HttpDate
      return HttpDate.parse(dateString);
    } catch (e) {
      return DateTime.now();
    }
  }
}
