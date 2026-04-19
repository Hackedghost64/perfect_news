import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class ConfigService {
  // Hardcoded to your raw GitHub file.
  static const String _configUrl =
      "https://raw.githubusercontent.com/Hackedghost64/perfect_news/main/sources.json";

  Future<List<Map<String, dynamic>>> fetchSources() async {
    try {
      // First try to load from local assets for faster development/offline
      try {
        final String localData = await rootBundle.loadString('assets/sources.json');
        final List<dynamic> data = json.decode(localData);
        debugPrint("Loaded sources from local assets.");
        return data.cast<Map<String, dynamic>>();
      } catch (e) {
        debugPrint("Local sources not found or failed to load: $e");
      }

      final response = await http.get(Uri.parse(_configUrl));

      // Defensive Programming: Fail-fast if the repo is unreachable
      if (response.statusCode != 200) {
        debugPrint(
          "CRITICAL: Failed to load sources. HTTP ${response.statusCode}",
        );
        return [];
      }

      final List<dynamic> data = json.decode(response.body);
      return data.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint("CRITICAL: ConfigService crash -> $e");
      return [];
    }
  }
}
