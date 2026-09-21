import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

void main() {
  runApp(const BlendJamApp());
}

class BlendJamApp extends StatelessWidget {
  const BlendJamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardColor: const Color(0xFF1E1E1E),
      ),
      home: const DJScreen(),
    );
  }
}

class QueuedTrack {
  final String path;
  final String name;

  QueuedTrack(this.path, this.name);
}

enum Deck {
  a,
  b,
}

class DJScreen extends StatefulWidget {
  const DJScreen({super.key});

  @override
  State<DJScreen> createState() => _DJScreenState();
}

class _DJScreenState extends State<DJScreen> {
  final AudioPlayer playerA = AudioPlayer();
  final AudioPlayer playerB = AudioPlayer();

  String? nameA;
  String? nameB;

  double crossfade = 0.0;

  bool autoMix = false;
  bool isCrossfading = false;

  Deck activeDeck = Deck.a;

  final List<QueuedTrack> queue = [];

  StreamSubscription<Duration>? positionASub;
  StreamSubscription<Duration>? positionBSub;

  @override
  void initState() {
    super.initState();

    positionASub = playerA.positionStream.listen(
      (position) => _checkAutoMix(Deck.a, position),
    );

    positionBSub = playerB.positionStream.listen(
      (position) => _checkAutoMix(Deck.b, position),
    );
  }

  // ============================================================
  // DECK HELPERS
  // ============================================================

  AudioPlayer _playerFor(Deck deck) {
    return deck == Deck.a ? playerA : playerB;
  }

  Deck _otherDeck(Deck deck) {
    return deck == Deck.a ? Deck.b : Deck.a;
  }

  String? _nameFor(Deck deck) {
    return deck == Deck.a ? nameA : nameB;
  }

  void _setName(Deck deck, String? name) {
    if (deck == Deck.a) {
      nameA = name;
    } else {
      nameB = name;
    }
  }

  bool _isPlaying(Deck deck) {
    return _playerFor(deck).playing;
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    positionASub?.cancel();
    positionBSub?.cancel();

    playerA.dispose();
    playerB.dispose();

    super.dispose();
  }

  // ============================================================
  // AUTO MIX MONITOR
  // ============================================================

  void _checkAutoMix(Deck deck, Duration position) {
    if (!autoMix) return;

    if (isCrossfading) return;

    // Only the LIVE deck controls Auto Mix.
    if (deck != activeDeck) return;

    final player = _playerFor(deck);
    final duration = player.duration;

    if (duration == null) return;

    final remaining = duration - position;

    // Start the transition during the final 10 seconds.
    if (remaining <= const Duration(seconds: 10) &&
        remaining > Duration.zero &&
        position > const Duration(seconds: 1)) {
      _triggerAutoMix();
    }
  }

  // ============================================================
  // PICK TRACK
  // ============================================================

  Future<void> pickTrack(bool requestedIsA) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
    );

    if (result == null || result.files.single.path == null) {
      return;
    }

    final requestedDeck = requestedIsA ? Deck.a : Deck.b;

    Deck targetDeck = requestedDeck;

    // Never replace the currently playing deck.
    if (_isPlaying(activeDeck) && requestedDeck == activeDeck) {
      targetDeck = _otherDeck(activeDeck);
    }

    final track = QueuedTrack(
      result.files.single.path!,
      result.files.single.name,
    );

    await _loadTrackIntoDeck(
      targetDeck,
      track,
      autoPlay: false,
    );
  }

  // ============================================================
  // LOAD TRACK INTO DECK
  // ============================================================

  Future<void> _loadTrackIntoDeck(
    Deck deck,
    QueuedTrack track, {
    required bool autoPlay,
  }) async {
    final player = _playerFor(deck);

    await player.stop();

    await player.setFilePath(track.path);

    // Small leading silence trim.
    await player.seek(
      const Duration(milliseconds: 350),
    );

    _setName(deck, track.name);

    // LIVE deck gets full volume.
    // NEXT deck starts silent.
    if (deck == activeDeck) {
      await player.setVolume(1.0);
    } else {
      await player.setVolume(0.0);
    }

    if (autoPlay) {
      await player.play();
    }

    if (mounted) {
      setState(() {});
    }
  }

  // ============================================================
  // ADD SONGS TO QUEUE
  // ============================================================

  Future<void> addToQueue() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
    );

    if (result == null) return;

    final tracks = result.files
        .where((file) => file.path != null)
        .map(
          (file) => QueuedTrack(
            file.path!,
            file.name,
          ),
        )
        .toList();

    if (mounted) {
      setState(() {
        queue.addAll(tracks);
      });
    }
  }

  // ============================================================
  // MANUAL QUEUE SELECTION
  // ============================================================

  Future<void> playFromQueue(int index) async {
    if (index < 0 || index >= queue.length) {
      return;
    }

    final track = queue.removeAt(index);

    Deck targetDeck;

    if (_isPlaying(activeDeck)) {
      targetDeck = _otherDeck(activeDeck);
    } else {
      if (_nameFor(activeDeck) == null) {
        targetDeck = activeDeck;
      } else {
        targetDeck = _otherDeck(activeDeck);
      }
    }

    await _loadTrackIntoDeck(
      targetDeck,
      track,
      autoPlay: false,
    );

    if (mounted) {
      setState(() {});
    }
  }

  // ============================================================
  // AUTO MIX
  // ============================================================

  Future<void> _triggerAutoMix() async {
    if (isCrossfading) return;

    final sourceDeck = activeDeck;
    final targetDeck = _otherDeck(sourceDeck);

    final sourcePlayer = _playerFor(sourceDeck);
    final targetPlayer = _playerFor(targetDeck);

    /*
     * IMPORTANT:
     *
     * First use a song that is already loaded in the free deck.
     *
     * If the free deck is empty, take the next song from the queue.
     */
    if (_nameFor(targetDeck) == null) {
      if (queue.isEmpty) {
        return;
      }

      final next = queue.removeAt(0);

      await targetPlayer.stop();

      await targetPlayer.setFilePath(next.path);

      await targetPlayer.seek(
        const Duration(milliseconds: 350),
      );

      _setName(targetDeck, next.name);
    }

    if (mounted) {
      setState(() {
        isCrossfading = true;
      });
    }

    // ------------------------------------------------------------
    // START NEXT DECK SILENTLY
    // ------------------------------------------------------------

    await targetPlayer.setVolume(0.0);

    if (!targetPlayer.playing) {
      await targetPlayer.play();
    }

    // ------------------------------------------------------------
    // 10 SECOND CROSSFADE
    // ------------------------------------------------------------

    const int steps = 100;

    for (int i = 0; i <= steps; i++) {
      if (!isCrossfading) {
        break;
      }

      final value = i / steps;

      if (sourceDeck == Deck.a) {
        // A -> B
        crossfade = value;

        await sourcePlayer.setVolume(
          1.0 - value,
        );

        await targetPlayer.setVolume(
          value,
        );
      } else {
        // B -> A
        crossfade = 1.0 - value;

        await sourcePlayer.setVolume(
          value,
        );

        await targetPlayer.setVolume(
          1.0 - value,
        );
      }

      if (mounted) {
        setState(() {});
      }

      await Future.delayed(
        const Duration(milliseconds: 100),
      );
    }

    // ------------------------------------------------------------
    // FINISH TRANSITION
    // ------------------------------------------------------------

    await sourcePlayer.stop();
    await sourcePlayer.setVolume(0.0);

    await targetPlayer.setVolume(1.0);

    activeDeck = targetDeck;

    crossfade = activeDeck == Deck.a ? 0.0 : 1.0;

    if (mounted) {
      setState(() {
        isCrossfading = false;
      });
    }
  }

  // ============================================================
  // MANUAL CROSSFADE
  // ============================================================

  Future<void> _handleCrossfade(double value) async {
    if (isCrossfading) {
      return;
    }

    // ------------------------------------------------------------
    // A -> B
    // ------------------------------------------------------------

    if (value > 0.01 &&
        _nameFor(Deck.b) != null &&
        !playerB.playing) {
      await playerB.setVolume(0.0);
      await playerB.play();
    }

    // ------------------------------------------------------------
    // B -> A
    // ------------------------------------------------------------

    if (value < 0.99 &&
        _nameFor(Deck.a) != null &&
        !playerA.playing) {
      await playerA.setVolume(0.0);
      await playerA.play();
    }

    // ------------------------------------------------------------
    // APPLY VOLUME
    // ------------------------------------------------------------

    await playerA.setVolume(1.0 - value);
    await playerB.setVolume(value);

    // ------------------------------------------------------------
    // DETERMINE LIVE DECK
    // ------------------------------------------------------------

    if (value >= 0.5 && _nameFor(Deck.b) != null) {
      activeDeck = Deck.b;
    } else if (value < 0.5 && _nameFor(Deck.a) != null) {
      activeDeck = Deck.a;
    }

    if (mounted) {
      setState(() {
        crossfade = value;
      });
    }
  }

  // ============================================================
  // PLAY / PAUSE
  // ============================================================

  Future<void> togglePlay(Deck deck) async {
    final player = _playerFor(deck);

    // Pause if already playing.
    if (player.playing) {
      await player.pause();
      return;
    }

    // Nothing loaded.
    if (_nameFor(deck) == null) {
      return;
    }

    // If another deck is playing, prepare this deck as the
    // NEXT deck. The crossfader can then bring it in.
    final otherDeck = _otherDeck(deck);
    final otherPlayer = _playerFor(otherDeck);

    if (otherPlayer.playing && otherDeck != deck) {
      activeDeck = otherDeck;

      await player.setVolume(0.0);

      await player.play();

      if (mounted) {
        setState(() {});
      }

      return;
    }

    // No other deck is playing.
    activeDeck = deck;

    await player.setVolume(1.0);

    await _playerFor(_otherDeck(deck)).setVolume(0.0);

    crossfade = deck == Deck.a ? 0.0 : 1.0;

    await player.play();

    if (mounted) {
      setState(() {});
    }
  }

  // ============================================================
  // STOP DECK
  // ============================================================

  Future<void> stopDeck(Deck deck) async {
    final player = _playerFor(deck);

    await player.stop();
    await player.setVolume(0.0);

    if (mounted) {
      setState(() {});
    }
  }

  // ============================================================
  // DECK UI
  // ============================================================

  Widget deckWidget(bool isA) {
    final deck = isA ? Deck.a : Deck.b;
    final player = _playerFor(deck);
    final name = _nameFor(deck);
    final isActive = activeDeck == deck;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Text(
              'DECK ${isA ? 'A' : 'B'} '
              '${isActive ? '(LIVE)' : '(NEXT)'}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: isActive
                    ? const Color(0xFFCEBBFF)
                    : Colors.white70,
              ),
            ),

            const SizedBox(height: 4),

            Text(
              name ?? 'No track',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.folder_open),
                  onPressed: () => pickTrack(isA),
                ),

                StreamBuilder<PlayerState>(
                  stream: player.playerStateStream,
                  builder: (context, snapshot) {
                    final playing =
                        snapshot.data?.playing ?? false;

                    return IconButton(
                      iconSize: 36,
                      icon: Icon(
                        playing
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_fill,
                        color: const Color(0xFFCEBBFF),
                      ),
                      onPressed: () => togglePlay(deck),
                    );
                  },
                ),

                IconButton(
                  icon: const Icon(Icons.stop),
                  onPressed: () => stopDeck(deck),
                ),
              ],
            ),

            StreamBuilder<Duration>(
              stream: player.positionStream,
              builder: (context, snapshot) {
                final position =
                    snapshot.data ?? Duration.zero;

                final duration =
                    player.duration ?? Duration.zero;

                final max = duration.inMilliseconds > 0
                    ? duration.inMilliseconds.toDouble()
                    : 1.0;

                final value = position.inMilliseconds
                    .toDouble()
                    .clamp(0.0, max);

                return Column(
                  children: [
                    Slider(
                      value: value,
                      min: 0.0,
                      max: max,
                      activeColor:
                          const Color(0xFFCEBBFF),
                      onChanged: (value) {
                        player.seek(
                          Duration(
                            milliseconds: value.toInt(),
                          ),
                        );
                      },
                    ),

                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(position),
                          style:
                              const TextStyle(fontSize: 10),
                        ),
                        Text(
                          _formatDuration(duration),
                          style:
                              const TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TIME FORMAT
  // ============================================================

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0');

    final seconds = duration.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');

    return '$minutes:$seconds';
  }

  // ============================================================
  // MAIN SCREEN
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BlendJam'),
        actions: [
          Row(
            children: [
              const Text(
                'AUTO MIX',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),

              Switch(
                value: autoMix,
                activeColor: const Color(0xFFCEBBFF),
                onChanged: (value) {
                  setState(() {
                    autoMix = value;
                  });
                },
              ),

              const SizedBox(width: 8),
            ],
          ),
        ],
      ),

      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          deckWidget(true),

          Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text(
                      'A',
                      style: TextStyle(fontSize: 10),
                    ),

                    Expanded(
                      child: Slider(
                        value: crossfade,
                        min: 0.0,
                        max: 1.0,
                        onChanged: _handleCrossfade,
                      ),
                    ),

                    const Text(
                      'B',
                      style: TextStyle(fontSize: 10),
                    ),
                  ],
                ),

                if (autoMix)
                  const Text(
                    'Auto Mix: transition starts during the final 10 seconds.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.white54,
                    ),
                  ),

                if (isCrossfading)
                  const LinearProgressIndicator(
                    color: Color(0xFFCEBBFF),
                  ),
              ],
            ),
          ),

          deckWidget(false),

          const SizedBox(height: 16),

          Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'QUEUE (${queue.length}) - Tap to load',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),

              IconButton(
                icon: const Icon(Icons.clear_all),
                onPressed: () {
                  setState(() {
                    queue.clear();
                  });
                },
              ),
            ],
          ),

          ...queue.asMap().entries.map(
            (entry) {
              final index = entry.key;
              final track = entry.value;

              return Card(
                color: const Color(0xFF252525),
                child: ListTile(
                  dense: true,

                  title: Text(
                    track.name,
                    style:
                        const TextStyle(fontSize: 12),
              
