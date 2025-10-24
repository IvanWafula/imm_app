import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../config.dart';
import '../audio_manager.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

class HomeScreen extends StatefulWidget {
  final ValueChanged<bool>? onFullscreenChanged;
  const HomeScreen({super.key, this.onFullscreenChanged});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, RouteAware {
  Map<String, dynamic>? liveStream;
  YoutubePlayerController? _ytController;
  bool _loading = false; // used for full-page loading and short connect spinner
  bool _loadingPage = true;
  bool _loadingButton = false; // radio button loading
  bool _isPlaying = false; // "home" radio is actively playing
  bool _isFullscreen = false;
  double _volume = 1.0;
  bool _hasStarted = false;

  /// If user explicitly closed the live player, we hide the full player but
  /// show a compact "Live available — Tap to open" bar so they can re-open it
  bool _showLivePlayer = true;

  String? _currentLiveVideoId;
  String _currentOwner = "";

  List<dynamic> readings = [];
  List<dynamic> podcasts = [];
  List<dynamic> events = [];

  final AudioManager _audioManager = AudioManager();
  late final dynamic _player; // keep dynamic typing to match your AudioManager.player

  Timer? _refreshTimer;
  Timer? _timeoutTimer;
  String? errorMessage;

  StreamSubscription? _playerStateSub;

  _HomeScreenState() {
    _player = _audioManager.player; // initialize here so it's available in ctor
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Set initial volume
    try {
      _player.setVolume(_volume);
    } catch (_) {}

    // Listen to underlying audio player's state stream.
    // We only mark _isPlaying = true when the current owner is "home".
    _playerStateSub = _player.playerStateStream?.listen((state) {
    final owner = _audioManager.currentOwner ?? "";
    if (!mounted) return;
    setState(() {
      _currentOwner = owner;
      _isPlaying = (owner == "home") && (state.playing == true);

      // ✅ Automatically hide the loading spinner once playback starts
      if (_isPlaying) {
        _loadingButton = false;
      }
    });
  });


    // Slight delay to allow UI to settle then load content
    Future.delayed(const Duration(milliseconds: 300), _fullLoad);
    _startAutoRefresh();

    // If loading takes too long - stop the big spinner but keep UI responsive
    _timeoutTimer = Timer(const Duration(seconds: 6), () {
      if (mounted && _loading) setState(() => _loading = false);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) routeObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ytController?.removeListener(_ytListener);
    _ytController?.dispose();
    _refreshTimer?.cancel();
    _timeoutTimer?.cancel();
    _playerStateSub?.cancel();
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPushNext() => _pauseAndReset();
  @override
  void didPopNext() => _pauseAndReset();

  Future<void> _pauseAndReset() async {
    try {
      if (_player.playing == true) await _player.pause();
      _ytController?.pause();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _isPlaying = false;
        _hasStarted = false;
      });
    }
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      _loadLive();
      _loadExtras();
    });
  }

  Future<void> _ensureHomeOwnership() async {
    try {
      await _audioManager.takeOwnership("home");
    } catch (e) {
      debugPrint("Error ensuring home ownership: $e");
    }
  }

  Future<void> _fullLoad() async {
  if (!mounted) return;
  setState(() {
    _loadingPage = true; // ✅ correct variable name
    errorMessage = null;
  });

  await Future.wait([_loadLive(), _loadExtras()]);

  if (mounted) setState(() => _loadingPage = false);
}


  Future<void> _loadLive() async {
    try {
      final response = await http.get(Uri.parse(Config.liveStreamEndpoint));
      if (response.statusCode != 200) throw Exception("Failed to fetch live stream");

      final data = jsonDecode(response.body);
      if (data['is_live'] != true || data['stream'] == null) throw Exception("No live stream");

      final stream = data['stream'];
      final rawUrl = stream['url'] ?? '';
      String? videoId = YoutubePlayer.convertUrlToId(rawUrl);

      if (videoId == null && rawUrl.contains("youtube.com/live/")) {
        final parts = rawUrl.split("live/");
        if (parts.length > 1) videoId = parts[1].split("?").first;
      }

      if (videoId != null && videoId.isNotEmpty) {
        final changed = _currentLiveVideoId != null && _currentLiveVideoId != videoId;
        _currentLiveVideoId = videoId;

        // create or update controller
        if (_ytController == null || _ytController!.initialVideoId != videoId) {
          _ytController?.removeListener(_ytListener);
          _ytController?.dispose();
          _ytController = YoutubePlayerController(
            initialVideoId: videoId,
            flags: const YoutubePlayerFlags(autoPlay: true, mute: false),
          );
          _ytController!.addListener(_ytListener);
        }

        if (mounted) {
          setState(() {
            liveStream = stream;
            _loading = false;
            errorMessage = null;
            if (changed) {
              // keep user preference but show compact banner when live changes
              _showLivePlayer = false;
            }
          });
        }
        return;
      }
    } catch (e) {
      debugPrint("Error fetching live stream: $e");
    }

    // no valid live found - clean up
    _ytController?.removeListener(_ytListener);
    _ytController?.dispose();
    _ytController = null;
    if (mounted) {
      setState(() {
      liveStream = null;
      _currentLiveVideoId = null;
      _showLivePlayer = true;
    });
    }
  }

  void _ytListener() async {
    if (!mounted || _ytController == null) return;
    try {
      final value = _ytController!.value;
      // If youtube starts playing, make sure radio player is paused
      if (value.isPlaying == true && _player.playing == true) {
        await _player.pause();
      }
      final isFullScreen = value.isFullScreen == true;
      if (mounted && _isFullscreen != isFullScreen) {
        setState(() => _isFullscreen = isFullScreen);
        widget.onFullscreenChanged?.call(isFullScreen);
      }
    } catch (_) {}
  }

  Future<void> _loadExtras() async {
    try {
      final r = await http.get(Uri.parse(Config.readingsEndpoint));
      if (r.statusCode == 200) readings = jsonDecode(r.body);
    } catch (_) {}

    try {
      final p = await http.get(Uri.parse(Config.podcastsEndpoint));
      if (p.statusCode == 200) podcasts = jsonDecode(p.body);
    } catch (_) {}

    try {
      final eRes = await http.get(Uri.parse(Config.eventsEndpoint));
      if (eRes.statusCode == 200) events = jsonDecode(eRes.body);
    } catch (_) {}

    if (mounted) setState(() {});
  }

  /// Toggle radio play/pause. Shows a short spinner while connecting so UI doesn't freeze.
  Future<void> _togglePlayPause() async {
    try {
      // If already playing, just pause
      if (_isPlaying) {
        await _player.pause();
        return;
      }

      // Pause YouTube if active
      _ytController?.pause();

      // Show spinner while connecting
      if (mounted) setState(() => _loadingButton = true);

      await _ensureHomeOwnership();

      // Start the radio stream
      await _audioManager.playStream(
        Config.streamUrl,
        title: "IMM Live Radio",
        owner: "home",
      );

      _hasStarted = true;
    } catch (e) {
      debugPrint("Error toggling play/pause: $e");
      if (mounted) {
        setState(() {
          _loadingButton = false;
          errorMessage = "No Internet: Unable to connect to radio stream.";
        });
      }
    }
  }




  void _setVolume(double value) {
    setState(() => _volume = value);
    try {
      _player.setVolume(_volume);
    } catch (_) {}
  }

  Future<void> _onRefresh() async => await _fullLoad();

  Widget _header(String text) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(text,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
      );

  @override
  Widget build(BuildContext context) {
    // If youtube fullscreen activated we show it full
    if (_isFullscreen && _ytController != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          top: false,
          bottom: false,
          child: YoutubePlayerBuilder(
            player: YoutubePlayer(
              controller: _ytController!,
              showVideoProgressIndicator: true,
              progressColors: ProgressBarColors(
                playedColor: Theme.of(context).colorScheme.secondary,
                handleColor: Theme.of(context).colorScheme.secondary,
              ),
            ),
            builder: (context, player) => SizedBox.expand(child: player),
          ),
        ),
      );
    }

    final cs = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text("IMM Connect", style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
          foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
          elevation: 0,
          actions: [
            IconButton(onPressed: _onRefresh, icon: const Icon(Icons.refresh))
          ],
          bottom: TabBar(
            labelColor: cs.onPrimary,
            unselectedLabelColor: cs.onPrimary.withOpacity(0.7),
            indicatorColor: cs.secondary,
            tabs: const [
              Tab(icon: Text("📖", style: TextStyle(fontSize: 18)), text: "Readings"),
              Tab(icon: Text("🎧", style: TextStyle(fontSize: 18)), text: "Podcasts"),
              Tab(icon: Text("📅", style: TextStyle(fontSize: 18)), text: "Events"),
            ],
          ),
        ),
        body: RefreshIndicator(
          onRefresh: _onRefresh,
          color: cs.secondary,
          child: _loadingPage
                ? Center(child: CircularProgressIndicator(color: cs.secondary))
                : TabBarView(
                  children: [
                    _buildTab(readings, "Today's Wisdom for Your Marriage"),
                    _buildTab(podcasts, "Recent Podcasts"),
                    _buildTab(events, "Upcoming Events"),
                  ],
                ),
        ),
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  Widget _buildTab(List<dynamic> list, String title) => ListView(children: [
        _buildTopCard(),
        const SizedBox(height: 12),
        _listPreview(title, list),
        const SizedBox(height: 90),
      ]);

  Widget _buildBottomBar() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildMiniPlayer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  onPressed: _togglePlayPause,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isPlaying ? Theme.of(context).colorScheme.secondary : Theme.of(context).colorScheme.primary,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                 child: _loadingButton
                    ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onPrimary))
                    : Text(
                        _isPlaying ? "Now Listening to IMM" : "Tap to Listen",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    IconButton(
                        icon: Icon(_volume == 0 ? Icons.volume_off : Icons.volume_down, color: Theme.of(context).colorScheme.secondary),
                        onPressed: () => _setVolume(0)),
                    Expanded(
                      child: Slider(
                        value: _volume,
                        onChanged: _setVolume,
                        min: 0,
                        max: 1,
                        divisions: 10,
                        activeColor: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                    IconButton(
                        icon: Icon(Icons.volume_up, color: Theme.of(context).colorScheme.secondary),
                        onPressed: () => _setVolume(1)),
                  ],
                ),
              ],
            ),
          ),
        ],
      );

  Widget _buildTopCard() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: liveStream != null && _ytController != null
            ? _buildLiveCard(cs)
            : _buildRadioCard(cs),
      ),
    );
  }

  Widget _buildLiveCard(ColorScheme cs) {
    return Card(
      key: const ValueKey('live_card'),
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.hardEdge,
      color: cs.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
            ),
            child: Row(
              children: [
                Icon(Icons.live_tv, color: cs.onPrimaryContainer),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(liveStream!['title'] ?? 'Live Now',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: cs.onPrimaryContainer)),
                ),
                IconButton(
                  onPressed: () {
                    setState(() => _showLivePlayer = false);
                  },
                  icon: Icon(Icons.close, color: cs.onPrimaryContainer),
                  tooltip: 'Close live player',
                ),
              ],
            ),
          ),
          if (_showLivePlayer)
            SizedBox(
              height: 220,
              child: YoutubePlayerBuilder(
                player: YoutubePlayer(
                  controller: _ytController!,
                  showVideoProgressIndicator: true,
                  progressColors: ProgressBarColors(
                    playedColor: cs.secondary,
                    handleColor: cs.secondary,
                  ),
                ),
                builder: (context, player) {
                  return player;
                },
              ),
            )
          else
            InkWell(
              onTap: () {
                setState(() => _showLivePlayer = true);
              },
              child: Container(
                height: 56,
                color: cs.surface,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: cs.secondary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('LIVE', style: TextStyle(color: cs.onSecondary, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text('Live stream available — tap to open', style: TextStyle(color: cs.onSurface))),
                    Icon(Icons.open_in_new, color: cs.onSurface),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRadioCard(ColorScheme cs) {
    return Container(
      key: const ValueKey('radio_card'),
      height: 160,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [cs.primaryContainer, cs.primary], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: cs.shadow.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Icon(Icons.headset, size: 64, color: cs.onPrimary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("IMM Live Radio",
                      style: TextStyle(color: cs.onPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text("Encouraging families daily with truth and love",
                      style: TextStyle(color: cs.onPrimary.withOpacity(0.9), fontSize: 13)),
                ]),
          ),
          ElevatedButton(
            onPressed: _togglePlayPause,
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.surface,
              foregroundColor: cs.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _loadingButton
                ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary))
                : Text(_isPlaying ? "Listening" : "Play"),

          ),
        ],
      ),
    );
  }

  Widget _buildMiniPlayer() {
    final title = _isPlaying ? "IMM Live Radio" : (_hasStarted ? "Paused" : "IMM Radio");
    final cs = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [BoxShadow(color: cs.shadow.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, -1))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.radio, color: cs.primary, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: cs.onSurface, fontSize: 15)),
                if (errorMessage != null)
                  Text(errorMessage!, style: TextStyle(fontSize: 12, color: cs.error)),
              ],
            ),
          ),
          IconButton(
            icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill, color: cs.primary, size: 36),
            onPressed: _togglePlayPause,
          ),
        ],
      ),
    );
  }

  Widget _listPreview(String title, List<dynamic> items) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(title),
        SizedBox(
          height: 140, // smaller cards as requested
          child: items.isEmpty
              ? Center(child: Text("No $title available yet", style: TextStyle(color: cs.onSurface.withOpacity(0.6), fontSize: 13)))
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: items.length > 6 ? 6 : items.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemBuilder: (context, i) {
                    final it = items[i];
                    final titleText = it['title'] ?? "Untitled";
                    String subtitle = '';
                  if (it.containsKey('location') && it['location'] != null && it['location'].toString().isNotEmpty) {
                    subtitle = '${it['location']}';
                  } else if (it.containsKey('date') && it['date'] != null) {
                    subtitle = it['date'];
                  } else if (it.containsKey('description') && it['description'] != null) {
                    subtitle = it['description'];
                  } else if (it.containsKey('body') && it['body'] != null) {
                    subtitle = it['body'];
                  } else {
                    subtitle = '';
                  }


                    return GestureDetector(
                      onTap: () => Navigator.push(
                          context, MaterialPageRoute(builder: (_) => DetailsScreen(item: it))),
                      child: Container(
                        width: 170,
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(color: cs.shadow.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 4))],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                titleText,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: cs.onSurface),
                              ),
                              if (subtitle.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    subtitle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: cs.onSurface.withOpacity(0.7), fontSize: 12),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
        ),
      ],
    );
  }
}

class DetailsScreen extends StatefulWidget {
  final dynamic item;
  const DetailsScreen({super.key, required this.item});

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  final AudioManager _audioManager = AudioManager();
  bool _isPlaying = false;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _sub = _audioManager.player.playerStateStream.listen((state) {
      if (mounted) setState(() => _isPlaying = state.playing == true);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _togglePlayPause() async {
    final audioUrl = widget.item['audio_url'];
    if (audioUrl == null || (audioUrl as String).isEmpty) return;

    if (_isPlaying) {
      await _audioManager.player.pause();
    } else {
      await _audioManager.takeOwnership("podcast");
      await _audioManager.playStream(audioUrl, title: widget.item['title'] ?? "Podcast", owner: "podcast");
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.item['title'] ?? 'Detail';
    final description = widget.item['description'] ?? widget.item['body'] ?? 'No description available';
    final thumbnail = widget.item['thumbnail'] ?? widget.item['cover_image'];
    final date = widget.item['date'] ?? '';
    final location = widget.item['location'];
    final audioUrl = widget.item['audio_url'];

    return Scaffold(
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (thumbnail != null && thumbnail.toString().isNotEmpty)
              Image.network(thumbnail)
            else
              Container(
                height: 180,
                color: Colors.grey[200],
                alignment: Alignment.center,
                child: const Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
              ),

           const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),

            if (date.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      date,
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),
            Text(
              description,
              textAlign: TextAlign.start,
              style: TextStyle(
                fontSize: 16,
                height: 1.6,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black, // ✅ clear readable black text
              ),
            ),
            const SizedBox(height: 40),


            if (location != null && location.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 12),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(location, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    ),
                  ],
                ),
              ),


            if (audioUrl != null && (audioUrl as String).isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).shadowColor.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.replay_10),
                      iconSize: 36,
                      color: Theme.of(context).colorScheme.primary,
                      onPressed: () async {
                        final position = _audioManager.player.position;
                        await _audioManager.player.seek(position - const Duration(seconds: 10));
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                      ),
                      iconSize: 48,
                      color: Theme.of(context).colorScheme.primary,
                      onPressed: _togglePlayPause,
                    ),
                    IconButton(
                      icon: const Icon(Icons.forward_10),
                      iconSize: 36,
                      color: Theme.of(context).colorScheme.primary,
                      onPressed: () async {
                        final position = _audioManager.player.position;
                        final duration = _audioManager.player.duration;
                        if (duration != null) {
                          final newPos = position + const Duration(seconds: 10);
                          await _audioManager.player.seek(newPos < duration ? newPos : duration);
                        }
                      },
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
