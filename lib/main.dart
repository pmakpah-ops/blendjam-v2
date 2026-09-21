import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

void main() => runApp(const BlendJamApp());

class BlendJamApp extends StatelessWidget {
  const BlendJamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardColor: const Color(0xFF1E1E1E),
      ),
      home: const DJScreen(),
      debugShowCheckedModeBanner: false,
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

class _DJScreenState extends State<DJScreen> {
  final playerA = AudioPlayer();
  final playerB = AudioPlayer();

  String? nameA;
  String? nameB;

  List<QueuedTrack> queue = [];

  // The deck currently carrying the main/active song.
  Deck activeDeck = Deck.a;

  double crossfade = 0.0;

  bool autoMix = false;
  bool isCrossfading = false;

  StreamSubscription<Duration>? _positionASub;
  StreamSubscription<Duration>? _positionBSub;

  @override
  void initState() {
    super.initState();

    _positionASub = playerA.positionStream.listen(
      (position) => _checkAutoMix(Deck.a, position),
    );

    _positionBSub = playerB.positionStream.listen(
      (position) => _checkAutoMix(Deck.b, position),
    );
  }

  // ------------------------------------------------------------
  // DECK HELPERS
  // ------------------------------------------------------------

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

  // ------------------------------------------------------------
  // AUTO MIX MONITOR
  // ------------------------------------------------------------

  void _checkAutoMix(Deck deck, Duration position) {
    if (!autoMix) return;
    if (isCrossfading) return;
    if (queue.isEmpty) return;

    // Only the active deck controls the automatic transition.
    if (deck != activeDeck) return;

    final player = _playerFor(deck);
    final duration = player.duration;

    if (duration == null) return;

    final remaining = duration - position;

    // Do not require the position to be exactly 10 seconds.
    // Trigger when the song enters the final 10 seconds.
    if (remaining <= const Duration(seconds: 10) &&
        remaining > Duration.zero &&
        position > const Duration(seconds: 1)) {
      _triggerAutoMix();
    }
  }

  Future<void> _triggerAutoMix() async {
    if (queue.isEmpty || isCrossfading) return;

    final sourceDeck = activeDeck;
    final targetDeck = _otherDeck(sourceDeck);

    final sourcePlayer = _playerFor(sourceDeck);
    final targetPlayer = _playerFor(targetDeck);

    final next = queue.removeAt(0);

    setState(() {
      isCrossfading = true;
    });

    // Make sure the free deck is really free.
    await targetPlayer.stop();

    // Load next song into the OTHER deck.
    await targetPlayer.setFilePath(next.path);

    // AUTO-TRIM: skip 350ms of leading silence.
    await targetPlayer.seek(
      const Duration(milliseconds: 350),
    );

    _setName(targetDeck, next.name);

    // Start the next song quietly.
    await targetPlayer.setVolume(0.0);
    await targetPlayer.play();

    if (sourceDeck == Deck.a) {
      crossfade = 0.0;
    } else {
      crossfade = 1.0;
    }

    if (mounted) {
      setState(() {});
    }

    // 10-second crossfade.
    const steps = 100;

    for (int i = 0; i <= steps; i++) {
      if (!mounted) break;

      final value = i / steps;

      if (sourceDeck == Deck.a) {
        // A -> B
        crossfade = value;
        await sourcePlayer.setVolume(1.0 - value);
        await targetPlayer.setVolume(value);
      } else {
        // B -> A
        crossfade = 1.0 - value;
        await sourcePlayer.setVolume(value);
        await targetPlayer.setVolume(1.0 - value);
      }

      setState(() {});

      await Future.delayed(
        const Duration(milliseconds: 100),
      );
    }

    // Stop the old deck.
    await sourcePlayer.stop();
    await sourcePlayer.setVolume(0.0);

    // The target deck is now the active deck.
    activeDeck = targetDeck;

    if (activeDeck == Deck.a) {
      crossfade = 0.0;
    } else {
      crossfade = 1.0;
    }

    if (mounted) {
      setState(() {
        isCrossfading = false;
      });
    }
  }

  // ------------------------------------------------------------
  // MANUAL FILE PICKING
  // ------------------------------------------------------------

  Future<void> pickTrack(bool requestedDeckIsA) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
    );

    if (result == null || result.files.single.path == null) return;

    final selected = QueuedTrack(
      result.files.single.path!,
      result.files.single.name,
    );

    final requestedDeck =
        requestedDeckIsA ? Deck.a : Deck.b;

    /*
     * If the requested deck is currently the active playing deck,
     * protect it and load the song into the free deck instead.
     */
    Deck targetDeck = requestedDeck;

    if (_isPlaying(activeDeck) &&
        requestedDeck == activeDeck) {
      targetDeck = _otherDeck(activeDeck);
    }

    await _loadTrackIntoDeck(
      targetDeck,
      selected,
      autoPlay: false,
    );
  }

  Future<void> _loadTrackIntoDeck(
    Deck deck,
    QueuedTrack track, {
    required bool autoPlay,
  }) async {
    final player = _playerFor(deck);

    // Never replace a playing track without first stopping that deck.
    await player.stop();

    await player.setFilePath(track.path);

    // AUTO-TRIM: skip 350ms leading silence.
    await player.seek(
      const Duration(milliseconds: 350),
    );

    await player.setVolume(
      deck == Deck.a
          ? (activeDeck == Deck.a ? 1.0 : 0.0)
          : (activeDeck == Deck.b ? 1.0 : 0.0),
    );

    _setName(deck, track.name);

    if (autoPlay) {
      await player.play();
    }

    if (mounted) {
      setState(() {});
    }
  }

  // ------------------------------------------------------------
  // QUEUE
  // ------------------------------------------------------------

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

    setState(() {
      queue.addAll(tracks);
    });
  }

  Future<void> playFromQueue(int index) async {
    if (index < 0 || index >= queue.length) return;

    final track = queue.removeAt(index);

    /*
     * If a deck is currently playing, ALWAYS use the other deck.
     * This prevents the current song from being replaced.
     */
    Deck targetDeck;

    if (_isPlaying(activeDeck)) {
      targetDeck = _otherDeck(activeDeck);
    } else {
      /*
       * Nothing is playing.
       * Prefer the active deck if it is empty.
       */
      final activeName = _nameFor(activeDeck);

      if (activeName == null) {
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
  }

  // ------------------------------------------------------------
  // PLAY / PAUSE
  // ------------------------------------------------------------

  Future<void> togglePlay(Deck deck) async {
    final player = _playerFor(deck);

    if (player.playing) {
      await player.pause();
      return;
    }

    await player.play();

    // If nothing else is playing, make this deck active.
    final otherDeck = _otherDeck(deck);

    if (!_isPlaying(otherDeck)) {
      activeDeck = deck;

      if (deck == Deck.a) {
        crossfade = 0.0;
        await playerA.setVolume(1.0);
        await playerB.setVolume(0.0);
      } else {
        crossfade = 1.0;
        await playerA.setVolume(0.0);
        await playerB.setVolume(1.0);
      }

      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> stopDeck(Deck deck) async {
    final player = _playerFor(deck);

    await player.stop();
    await player.setVolume(0.0);

    if (deck == activeDeck) {
      final other = _otherDeck(deck);

      if (_isPlaying(other)) {
        activeDeck = other;
        crossfade = other == Deck.a ? 0.0 : 1.0;
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  // ------------------------------------------------------------
  // DECK UI
  // ------------------------------------------------------------

  Widget deckWidget(bool isA) {
    final deck = isA ? Deck.a : Deck.b;
    final player = _playerFor(deck);
    final name = _nameFor(deck);
    final isLive = deck == activeDeck;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Text(
              'DECK ${isA ? 'A' : 'B'} ${isLive ? '(LIVE)' : '(NEXT)'}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: isLive
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
                          _fmt(position),
                          style:
                              const TextStyle(fontSize: 10),
                        ),
                        Text(
                          _fmt(duration),
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

  String _fmt(Duration duration) {
    return '${duration.inMinutes.remainder(60).toString().padLeft(2, '0')}:${duration.inSeconds.remainder(60).toString().padLeft(2, '0')}';
  }

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------

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
                        onChanged: (value) {
                          setState(() {
                            crossfade = value;
                          });

                          playerA.setVolume(1 - value);
                          playerB.setVolume(value);
                        },
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
                    'Auto Mix: next track loads into the free deck during the final 10 seconds.',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.white54,
                    ),
                    textAlign: TextAlign.center,
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
                'QUEUE (${queue.length})',
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
                (entry) => Card(
                  color: const Color(0xFF252525),
                  child: ListTile(
                    dense: true,
                    title: Text(
                      entry.value.name,
                      style:
                          const TextStyle(fontSize: 12),
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                    ),
                    leading: Text(
                      '${entry.key + 1}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white54,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.close,
                        size: 16,
                      ),
                      onPressed: () {
                        setState(() {
                          queue.removeAt(entry.key);
                        });
                      },
                    ),
                    onTap: () =>
                        playFromQueue(entry.key),
                  ),
                ),
              ),

          const SizedBox(height: 8),

          FilledButton.icon(
            onPressed: addToQueue,
            icon: const Icon(Icons.add),
            label: Text(
              'Add songs (${queue.length})',
            ),
            style: FilledButton.styleFrom(
              backgroundColor:
                  const Color(0xFFCEBBFF),
              foregroundColor: Colors.black,
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _positionASub?.cancel();
    _positionBSub?.cancel();

    playerA.dispose();
    playerB.dispose();

    super.dispose();
  }
}
