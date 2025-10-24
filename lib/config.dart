
class Config {
  /// 🌍 Your live production domain
  static const String _liveDomain = 'app.imradio.online';

  /// ✅ Base Laravel API URL
  static String get apiBaseUrl => 'https://$_liveDomain';

  /// ✅ Icecast/Liquidsoap stream
  static String get streamUrl => 'https://$_liveDomain/stream';

  /// 📡 API Endpoints
  static String get programsEndpoint => '$apiBaseUrl/api/programs';
  static String get eventsEndpoint => '$apiBaseUrl/api/events';
  static String get liveStreamEndpoint => '$apiBaseUrl/api/live/current';
  static String get scheduleEndpoint => '$apiBaseUrl/api/schedule';

  /// 📚 Additional Content
  static String get readingsEndpoint => '$apiBaseUrl/api/readings';
  static String get podcastsEndpoint => '$apiBaseUrl/api/podcasts';

  /// 📘 Books
  static String get booksEndpoint => '$apiBaseUrl/api/books'; // ✅ NEW
  static String get documentEndpoint => '$apiBaseUrl/api/documents';
  static String get settingsEndpoint => '$apiBaseUrl/api/settings';
}

