import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../audio_manager.dart';

class EventPlayerScreen extends StatefulWidget {
  final Map<String, dynamic> event;

  const EventPlayerScreen({super.key, required this.event});

  @override
  State<EventPlayerScreen> createState() => _EventPlayerScreenState();
}

class _EventPlayerScreenState extends State<EventPlayerScreen> {
  final _player = AudioManager().player;
  YoutubePlayerController? _youtubeController;
  bool _loading = true;
  bool _isPlaying = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final url = widget.event['url'] ?? '';

    if (url.isEmpty) {
      setState(() {
        _errorMessage = "No URL provided.";
        _loading = false;
      });
      return;
    }

    if (url.contains('youtube.com') || url.contains('youtu.be')) {
      AudioManager().takeOwnership("event");
      final videoId = YoutubePlayer.convertUrlToId(url);
      _youtubeController = YoutubePlayerController(
        initialVideoId: videoId ?? '',
        flags: const YoutubePlayerFlags(autoPlay: false, mute: false),
      );
      setState(() => _loading = false);
    } else {
      _initAudio(url);
    }
  }

  Future<void> _initAudio(String url) async {
    try {
      await AudioManager().takeOwnership("event");
      await _player.setUrl(url);
    } catch (e) {
      setState(() => _errorMessage = "Failed to load audio.");
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _youtubeController?.dispose();
    AudioManager().releaseOwnership("event");
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: Center(child: Text(_errorMessage!)),
      );
    }

    if (_youtubeController != null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.event['title'] ?? "Event")),
        body: YoutubePlayer(
          controller: _youtubeController!,
          showVideoProgressIndicator: true,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.event['title'] ?? "Event")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(widget.event['title'] ?? "Event"),
            IconButton(
              icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
              onPressed: () async {
                if (_player.playing) {
                  await _player.pause();
                } else {
                  await _player.play();
                }
                setState(() => _isPlaying = _player.playing);
              },
            ),
          ],
        ),
      ),
    );
  }
}
