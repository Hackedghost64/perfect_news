import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class NotificationFilter {
  static const String _lastProcessedKey = 'last_processed_message_id';
  static const String _processedIdsKey = 'processed_message_ids';
  static const int _maxStoredIds = 50;

  /// Checks if a message should be shown to the user.
  /// Returns true if the message is fresh and hasn't been processed before.
  static Future<bool> shouldHandleMessage(RemoteMessage message) async {
    if (message.messageId == null) return true;

    final prefs = await SharedPreferences.getInstance();
    
    // 1. Deduplication by ID
    final processedIds = prefs.getStringList(_processedIdsKey) ?? [];
    if (processedIds.contains(message.messageId)) {
      debugPrint("NotificationFilter: Dropping duplicate message ${message.messageId}");
      return false;
    }

    // 2. Freshness Check (Ignore if older than 10 minutes)
    // This helps when coming back online after a long time.
    if (message.sentTime != null) {
      final age = DateTime.now().difference(message.sentTime!);
      if (age.inMinutes > 10) {
        debugPrint("NotificationFilter: Dropping stale message ${message.messageId} (Age: ${age.inMinutes} mins)");
        return false;
      }
    }

    // Mark as processed
    processedIds.add(message.messageId!);
    // Keep list size manageable
    if (processedIds.length > _maxStoredIds) {
      processedIds.removeAt(0);
    }
    await prefs.setStringList(_processedIdsKey, processedIds);
    
    return true;
  }
}
