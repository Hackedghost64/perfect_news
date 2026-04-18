import 'views/news_feed.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';

// Defensive Programming: This must be a top-level function to run in the background.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Handling a background message: ${message.messageId}");
}

void main() async {
  // Ensure the engine is loaded before calling native code
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase using the CLI-generated options
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Set up the background listener
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Request permission for notifications (Required for iOS/Android 13+)
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(alert: true, badge: true, sound: true);

  // Subscribe this specific device to the topic the Python script broadcasts to
  await messaging.subscribeToTopic('breaking_news');

  runApp(const WireApp());
}

class WireApp extends StatelessWidget {
  const WireApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wire',
      debugShowCheckedModeBanner: false, // No garbage banners
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Colors.white,
          surface: Colors.black,
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.white, fontSize: 16),
          titleLarge: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        useMaterial3: true,
      ),
      home: const NewsFeedView(),
    );
  }
}
