import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../config.dart';

/// Singleton service managing radio playback with ownership control
/// and auto-reconnect for the live stream.
class AudioManager {
  AudioManager._internal() {
    // 🔁 Auto-reconnect and stability checks
    player.playerStateStream.listen((state) async {
      print("[AudioManager] ▶️ State: ${state.processingState}, Playing: ${state.playing}");

      // If the stream unexpectedly completes (e.g., live stream disconnects)
      if (state.processingState == ProcessingState.completed) {
        print("[AudioManager] Stream ended — trying to reconnect...");
        await _safeReconnect();
      }

      // If the player becomes idle (no active source)
      if (state.processingState == ProcessingState.idle && _currentOwner == "home") {
        print("[AudioManager] Player idle — restarting live stream...");
        await _safeReconnect();
      }
    });

    // Detect playback errors
    player.playbackEventStream.listen((event) {
      if (event.processingState == ProcessingState.idle && event.duration == null) {
        print("[AudioManager] ⚠️ Stream dropped, waiting for reconnect...");
      }
    }, onError: (Object e, StackTrace stackTrace) {
      print('[AudioManager] ❌ Playback error: $e');
    });
  }

  static final AudioManager _instance = AudioManager._internal();
  factory AudioManager() => _instance;

  final AudioPlayer player = AudioPlayer();
  String? _currentOwner;
  bool _wasPlayingBeforePause = false;

  String? get currentOwner => _currentOwner;

  // 🔁 Helper: reconnect live stream safely
  Future<void> _safeReconnect() async {
    try {
      await Future.delayed(const Duration(seconds: 2));
      if (_currentOwner == "home" && !player.playing) {
        await playStream(
          Config.streamUrl,
          title: "IMM Live Radio",
          owner: "home",
        );
      }
    } catch (e) {
      print("[AudioManager] Reconnect failed: $e");
    }
  }

  /// Play or restart the live stream and claim ownership.
  Future<void> playStream(
    String streamUrl, {
    String title = "IMM Radio",
    String artist = "IMM Ministries",
    String album = "Internet Radio",
    String artUrl = "https://yourdomain.com/logo.png",
    String owner = "home",
  }) async {
    _currentOwner = owner;

    // Prevent unnecessary reload if already playing same stream
    final currentUri = (player.audioSource is ProgressiveAudioSource)
        ? (player.audioSource as ProgressiveAudioSource).uri.toString()
        : null;

    if (currentUri != streamUrl) {
      try {
        await player.setAudioSource(
          AudioSource.uri(
            Uri.parse(streamUrl),
            tag: MediaItem(
              id: streamUrl,
              album: album,
              title: title,
              artist: artist,
              artUri: Uri.tryParse(artUrl),
            ),
          ),
        );
        await player.setLoopMode(LoopMode.one); // Keeps connection alive
      } catch (e) {
        print("[AudioManager] ❌ Failed to load stream: $e");
        rethrow;
      }
    }

    // Start playback
    try {
      await player.play();
      print("[AudioManager] ✅ Playing: $title");
    } catch (e) {
      print("[AudioManager] ❌ Play failed: $e");
    }
  }

  /// Claim ownership for a given screen.
  Future<void> takeOwnership(String owner) async {
    if (_currentOwner == owner) {
      _currentOwner = owner;
      return;
    }

    // Pause previous owner if needed
    _wasPlayingBeforePause = player.playing;
    if (_wasPlayingBeforePause) {
      await player.pause();
    }

    _currentOwner = owner;
  }

  /// Release ownership back to home screen.
  Future<void> releaseOwnership(String owner) async {
    if (_currentOwner == owner) {
      _currentOwner = null;

      // When a screen releases control, restore home radio automatically
      if (owner != "home") {
        await takeOwnership("home");
        await playStream(
          Config.streamUrl,
          title: "IMM Live Radio",
          owner: "home",
        );
      }
    }
  }

  /// Safely pause current playback
  Future<void> pause() async {
    try {
      await player.pause();
    } catch (e) {
      print("[AudioManager] Pause failed: $e");
    }
  }

  /// Fully stop playback
  Future<void> stop() async {
    try {
      await player.stop();
    } catch (e) {
      print("[AudioManager] Stop failed: $e");
    }
  }

  /// Adjust volume level
  Future<void> setVolume(double v) async {
    try {
      await player.setVolume(v);
    } catch (e) {
      print("[AudioManager] Volume set failed: $e");
    }
  }

  /// Dispose player (only call when app closes)
  Future<void> dispose() async {
    await player.dispose();
  }
}
