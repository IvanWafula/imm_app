import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'theme_provider.dart';
import 'screens/home_screen.dart';
import 'screens/document_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/splash_screen.dart';
import 'dart:convert';
import 'screens/books_screen.dart';


/// 🔑 Global navigator key (used to open pages from notification tap)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// 📱 Local notifications plugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// 🔔 Background notification handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await showNotification(message);
}

/// 🔔 Display notification
Future<void> showNotification(RemoteMessage message) async {
  final notification = message.notification;
  final data = message.data;

  const androidDetails = AndroidNotificationDetails(
    'default_channel',
    'Default',
    importance: Importance.max,
    priority: Priority.high,
  );

  const details = NotificationDetails(android: androidDetails);

  await flutterLocalNotificationsPlugin.show(
    notification.hashCode,
    notification?.title ?? data['reading_title'] ?? 'Daily Reading',
    notification?.body ?? data['reading_body'] ?? 'Tap to read',
    details,
    payload: jsonEncode(data), // ✅ Encoded as JSON (safe to keep)
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // 🔔 Setup local notifications
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidInit);
  await flutterLocalNotificationsPlugin.initialize(
    initSettings,
    // 🔕 Removed navigation to deleted MessageDetailScreen
    onDidReceiveNotificationResponse: (NotificationResponse response) async {
      // Handle tap if needed (optional: show a snackbar or do nothing)
    },
  );

  final messaging = FirebaseMessaging.instance;
  await messaging.requestPermission();
  await messaging.subscribeToTopic('daily_readings');

  // 🔑 Print FCM token
  final token = await messaging.getToken();
  debugPrint('🔥 FCM Token: $token');

  // 🔔 Handle foreground notifications
  FirebaseMessaging.onMessage.listen(showNotification);

  // 🔔 Handle background messages
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const ImmApp(),
    ),
  );

  // 🚀 Removed logic for MessageDetailScreen navigation on terminated state
}

class ImmApp extends StatelessWidget {
  const ImmApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'IMM Connect',
      debugShowCheckedModeBanner: false,
      theme: themeProvider.lightTheme,
      darkTheme: themeProvider.darkTheme,
      themeMode: themeProvider.themeMode,
      routes: {
        '/': (context) => const SplashScreen(),
        '/home': (context) => const MainNavigation(),
      },
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  bool _isFullscreen = false;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(
        onFullscreenChanged: (isFullscreen) {
          setState(() => _isFullscreen = isFullscreen);
        },
      ),
      const DocumentsScreen(),
      const BooksScreen(),
      const SettingsScreen(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: _isFullscreen
          ? null
          : BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              selectedItemColor: Colors.deepPurple,
              unselectedItemColor: Colors.grey,
              items: [
                
                BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
                BottomNavigationBarItem(icon: Icon(Icons.library_books), label: 'Reading Material'),
                BottomNavigationBarItem(icon: Icon(Icons.book), label: 'Books'),
                BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
              ],
            ),
    );
  }
}
