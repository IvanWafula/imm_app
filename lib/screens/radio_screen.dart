// radio_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../audio_manager.dart';

class RadioScreen extends StatefulWidget {
  const RadioScreen({super.key});

  @override
  State<RadioScreen> createState() => _RadioScreenState();
}

class _RadioScreenState extends State<RadioScreen> {
  final _player = AudioManager().player;
  bool _isPlaying = false;

  String _currentTitle = "Loading...";
  String _currentArtist = "";

  static const STREAM_URL =
      "https://a9.asurahosting.com/listen/imm_radio_broadcast/radio.mp3";
  static const NOW_PLAYING_API =
      "https://a9.asurahosting.com/api/nowplaying/imm_radio_broadcast";

  Timer? _metadataTimer;

  @override
  void initState() {
    super.initState();
    AudioManager().takeOwnership("radio");
    _initPlayer();
    _fetchMetadata();
    _metadataTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _fetchMetadata();
    });
  }

  Future<void> _initPlayer() async {
    try {
      await AudioManager().playStream(STREAM_URL, owner: "radio");

      _player.playerStateStream.listen((state) {
        if (mounted) {
          setState(() {
            _isPlaying = state.playing;
          });
        }
      });
    } catch (e) {
      debugPrint("Error loading stream: $e");
    }
  }

  Future<void> _fetchMetadata() async {
    try {
      final response = await http.get(Uri.parse(NOW_PLAYING_API));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final song = data["now_playing"]["song"];
        setState(() {
          _currentTitle = song["title"] ?? "Unknown Title";
          _currentArtist = song["artist"] ?? "";
        });
      }
    } catch (e) {
      debugPrint("Error fetching metadata: $e");
    }
  }

  @override
  void dispose() {
    _metadataTimer?.cancel();
    AudioManager().releaseOwnership("home");
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: const Text("IMM Live Radio")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset("assets/images/logo.png", height: 120),
            const SizedBox(height: 20),

            Text(
              _currentTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            if (_currentArtist.isNotEmpty)
              Text(
                _currentArtist,
                style: const TextStyle(
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                ),
              ),
            const SizedBox(height: 30),

            IconButton(
              iconSize: 100,
              icon: Icon(
                _isPlaying ? Icons.pause_circle : Icons.play_circle,
                color: color,
              ),
              onPressed: () async {
                if (_isPlaying) {
                  await _player.pause();
                } else {
                  await _player.play();
                }
              },
            ),

            const SizedBox(height: 20),
            Text(
              _isPlaying ? "Streaming IMM Radio…" : "Tap play to listen",
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
