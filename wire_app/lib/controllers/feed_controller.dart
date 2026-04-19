import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/article.dart';
import '../services/config_service.dart';
import '../services/rss_service.dart';

class FeedController extends ChangeNotifier {
  final ConfigService _configService = ConfigService();
  final RssService _rssService = RssService();

  List<Article> articles = [];
  bool isLoading = false;
  String? errorMessage;

  String _currentRegion = 'world';
  String _currentLanguage = 'en';

  String get currentRegion => _currentRegion;
  String get currentLanguage => _currentLanguage;

  FeedController() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _currentRegion = prefs.getString('region') ?? 'world';
    _currentLanguage = prefs.getString('language') ?? 'en';
    
    // Initial sync and topic subscription
    _updateFcmSubscription();
    notifyListeners();
    syncFeed();
  }

  Future<void> setRegion(String region) async {
    if (_currentRegion == region) return;
    
    // Unsubscribe from old topic
    await FirebaseMessaging.instance.unsubscribeFromTopic('news_${_currentRegion}_$_currentLanguage');
    
    _currentRegion = region;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('region', region);
    
    // Subscribe to new topic
    _updateFcmSubscription();
    
    notifyListeners();
    await syncFeed();
  }

  Future<void> setLanguage(String language) async {
    if (_currentLanguage == language) return;
    
    // Unsubscribe from old topic
    await FirebaseMessaging.instance.unsubscribeFromTopic('news_${_currentRegion}_$_currentLanguage');
    
    _currentLanguage = language;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', language);
    
    // Subscribe to new topic
    _updateFcmSubscription();
    
    notifyListeners();
    await syncFeed();
  }

  Future<void> _updateFcmSubscription() async {
    final topic = 'news_${_currentRegion}_$_currentLanguage';
    debugPrint("Subscribing to topic: $topic");
    await FirebaseMessaging.instance.subscribeToTopic(topic);
  }

  Future<void> syncFeed() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final allSources = await _configService.fetchSources();
      
      // Filter sources based on current region and language
      final filteredSources = allSources.where((source) {
        final region = source['region'] ?? 'world';
        final language = source['language'] ?? 'en';
        return region == _currentRegion && language == _currentLanguage;
      }).toList();

      if (filteredSources.isEmpty) {
        articles = [];
        errorMessage = "NO SOURCES FOUND FOR THIS REGION/LANGUAGE.";
        isLoading = false;
        notifyListeners();
        return;
      }

      List<Article> allArticles = [];
      for (var source in filteredSources) {
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
