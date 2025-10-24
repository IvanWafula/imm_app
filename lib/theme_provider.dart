import 'package:flutter/material.dart';

class ThemeProvider with ChangeNotifier {
  bool _isDark = false; // <-- set default to dark

  bool get isDark => _isDark;

  ThemeMode get themeMode => _isDark ? ThemeMode.dark : ThemeMode.light;

  void toggleTheme() {
    _isDark = !_isDark;
    notifyListeners();
  }

  void setLightMode() {
    _isDark = false;
    notifyListeners();
  }

  void setDarkMode() {
    _isDark = true;
    notifyListeners();
  }

  /// Light theme
  ThemeData get lightTheme => ThemeData(
        brightness: Brightness.light,
        primaryColor: Colors.redAccent,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.redAccent,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        scaffoldBackgroundColor: Colors.grey.shade50,
        cardColor: Colors.white,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.redAccent),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: Colors.redAccent,
          unselectedItemColor: Colors.grey,
        ),
      );

  /// Dark theme
  ThemeData get darkTheme => ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.redAccent,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.redAccent,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        scaffoldBackgroundColor: Colors.grey.shade900,
        cardColor: Colors.grey.shade800,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.redAccent),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Colors.grey.shade900,
          selectedItemColor: Colors.redAccent,
          unselectedItemColor: Colors.grey.shade400,
        ),
      );

  /// Theme-aware gradient for cards, etc.
  LinearGradient get cardGradient => LinearGradient(
        colors: [
          _isDark
              ? Colors.redAccent.withOpacity(0.5)
              : Colors.redAccent.withOpacity(0.7),
          Colors.redAccent,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
}
