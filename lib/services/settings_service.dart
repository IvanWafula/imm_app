import 'dart:convert';
import 'package:http/http.dart' as http;

class SettingsService {
  static const String _baseUrl = "https://app.imradio.online/api/flutter-settings";

  static Map<String, dynamic>? _settings;

  static Future<void> loadSettings() async {
    final response = await http.get(Uri.parse(_baseUrl));

    if (response.statusCode == 200) {
      _settings = jsonDecode(response.body);
    } else {
      throw Exception('Failed to load settings');
    }
  }

  static String get apiBaseUrl => _settings?['api_base_url'] ?? '';
  static String get aboutEndpoint => "$apiBaseUrl${_settings?['about_endpoint'] ?? ''}";
  static String get contactEndpoint => "$apiBaseUrl${_settings?['contact_endpoint'] ?? ''}";
  static String get readingsEndpoint => "$apiBaseUrl${_settings?['readings_endpoint'] ?? ''}";
  static String get podcastsEndpoint => "$apiBaseUrl${_settings?['podcasts_endpoint'] ?? ''}";
  // 🧩 Add others as needed
}
