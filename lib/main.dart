import 'dart:developer' as console;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:push_notification/firebase_options.dart';

import 'app/services/notification_service.dart';


@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('Background message: ${message.messageId}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Register the background handler before runApp, and only once.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await NotificationService.instance.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Push Notification',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _token = 'Fetching token...';
  String _lastMessage = 'No message yet';

  @override
  void initState() {
    super.initState();
    _loadToken();
    NotificationService.instance.onMessage = (message) {
      setState(() {
        _lastMessage = '${message.notification?.title ?? '(no title)'}\n'
            '${message.notification?.body ?? message.data.toString()}';
      });
    };
  }

  Future<void> _loadToken() async {
    final token = await NotificationService.instance.getToken();
    if (!mounted) return;
    setState(() => _token = token ?? 'Token is null. Check Google Play services.');
    console.log(_token);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Push notification')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('FCM token', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SelectableText(_token),
            const SizedBox(height: 24),
            const Text('Last message', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_lastMessage),
          ],
        ),
      ),
    );
  }
}