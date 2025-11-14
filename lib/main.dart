import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'theme_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/document_screen.dart';
import 'screens/books_screen.dart';
import 'screens/settings_screen.dart';
import 'firebase_options.dart';

// 🌐 Global navigation key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// 🔔 Local notifications plugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// =======================================
//  🔕 Background message handler (iOS-safe)
// =======================================
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _showNotification(message);
}

// =======================================
//  🔔 Show notification (iOS + Android)
// =======================================
Future<void> _showNotification(RemoteMessage message) async {
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
    notification?.title ?? data['title'] ?? 'IMM Connect',
    notification?.body ?? data['body'] ?? 'Tap to open',
    details,
    payload: jsonEncode(data),
  );
}

// =======================================
//          🔥 MAIN (IOS-STABLE)
// =======================================
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // -----------------------------
  // 1️⃣ Firebase Initialization
  // -----------------------------
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("🔥 Firebase initialized successfully");
  } catch (e, s) {
    print("❌ Firebase init FAILED: $e");
    print(s);
  }

  // -----------------------------
  // 2️⃣ Register background handler
  // -----------------------------
  FirebaseMessaging.onBackgroundMessage(
    _firebaseMessagingBackgroundHandler,
  );

  // -----------------------------
  // 3️⃣ Request notification permissions (iOS REQUIRED)
  // -----------------------------
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
    announcement: true,
    criticalAlert: true,
    provisional: false,
  );

  await messaging.subscribeToTopic('daily_readings');

  // -----------------------------
  // 4️⃣ SAFE Notification Initialization (AFTER runApp)
  // -----------------------------
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const ImmApp(),
    ),
  );

  // Post-frame init (fixes iOS crash during init)
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    const initSettings = InitializationSettings(
      android: androidInit,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null) {
          final data = jsonDecode(payload);
          navigatorKey.currentState?.pushNamed('/home', arguments: data);
        }
      },
    );

    print("🔔 Local notifications initialized safely");
  });

  // -----------------------------
  // 5️⃣ Foreground message listener
  // -----------------------------
  FirebaseMessaging.onMessage.listen(_showNotification);
}

// =======================================
//          APP ROOT WIDGET
// =======================================
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
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/home': (context) => const MainNavigation(),
      },
    );
  }
}

// =======================================
//        NAVIGATION + BOTTOM BAR
// =======================================
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

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

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
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.library_books), label: 'Reading Material'),
                BottomNavigationBarItem(icon: Icon(Icons.book), label: 'Books'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.settings), label: 'Settings'),
              ],
            ),
    );
  }
}
