import 'views/news_feed.dart';
import 'views/reader_view.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'services/notification_filter.dart';

// Global navigator key to handle navigation without context
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Defensive Programming: This must be a top-level function to run in the background.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  if (await NotificationFilter.shouldHandleMessage(message)) {
    debugPrint("Handling a background message: ${message.messageId}");
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Set up foreground listener (optional: you might want to show a toast or nothing)
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    if (await NotificationFilter.shouldHandleMessage(message)) {
      debugPrint("Received a foreground message: ${message.messageId}");
    }
  });

  // Handle clicking the notification while the app is in the background
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    _handleNotificationClick(message);
  });

  FirebaseMessaging messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(alert: true, badge: true, sound: true);
  await messaging.subscribeToTopic('breaking_news');

  // Check if the app was opened via a notification from a terminated state
  RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  
  runApp(WireApp(initialMessage: initialMessage));
}

void _handleNotificationClick(RemoteMessage message) {
  final url = message.data['url'];
  final source = message.data['source'] ?? "Unknown Source";
  
  if (url != null && url.isNotEmpty) {
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => ReaderView(url: url, sourceName: source),
      ),
    );
  }
}

class WireApp extends StatelessWidget {
  final RemoteMessage? initialMessage;
  const WireApp({super.key, this.initialMessage});

  @override
  Widget build(BuildContext context) {
    // If we have an initial message, handle it after the first frame
    if (initialMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleNotificationClick(initialMessage!);
      });
    }

    return MaterialApp(
      title: 'Wire',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
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
