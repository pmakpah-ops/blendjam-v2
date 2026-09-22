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

enum Deck { a, b }

class DJScreen extends StatefulWidget {
  const DJScreen({super.key});

  @override
  State<DJScreen> createState() => _DJScreenState();
}

class _DJScreenState extends State<DJScreen> {
  final AudioPlayer a = AudioPlayer();
  final AudioPlayer b = AudioPlayer();

  String? nA;
  String? nB;

  double xf = 0.0;

  bool auto = false;
  bool xing = false;

  Deck live = Deck.a;

  final List<QueuedTrack> q = [];

  StreamSubscription<Duration>? sA;
  StreamSubscription<Duration>? sB;

  // Prevents the same song from starting Auto Mix more than once.
  bool autoTriggered = false;

  AudioPlayer p(Deck d) => d == Deck.a ? a : b;

  Deck o(Deck d) => d == Deck.a ? Deck.b : Deck.a;

  String? nm(Deck d) => d == Deck.a ? nA : nB;

  void setNm(Deck d, String? value) {
    if (d == Deck.a) {
      nA = value;
    } else {
      nB = value;
    }
  }

  @override
  void initState() {
    super.initState();

    sA = a.positionStream.listen(
      (position) => _checkAutoMix(Deck.a, position),
    );

    sB = b.positionStream.listen(
      (position) => _checkAutoMix(Deck.b, position),
    );
  }

  @override
  void dispose() {
    sA?.cancel();
    sB?.cancel();
    a.dispose();
    b.dispose();
    super.dispose();
  }

  // ============================================================
  // AUTO MIX CHECK
  // ============================================================

  void _checkAutoMix(
    Deck deck,
    Duration position,
  ) {
    if (!auto || xing || autoTriggered) {
      return;
    }

    if (deck != live) {
      return;
    }

    final player = p(deck);
    final duration = player.duration;

    if (duration == null || !player.playing) {
      return;
    }

    final remaining = duration - position;

    // Preload the next song when 15 seconds remain.
    if (remaining <= const Duration(seconds: 15) &&
        remaining > const Duration(seconds: 10)) {
      _preloadNext();
    }

    // IMPORTANT:
    // Do NOT use rem.inSeconds == 10.
    //
    // The position stream can jump from 10.2 seconds
    // directly to 9.8 seconds.
    //
    // <= 10 seconds guarantees the transition starts.
    if (remaining <= const Duration(seconds: 10) &&
        remaining > Duration.zero) {
      autoTriggered = true;
      _mix();
    }
  }

  // ============================================================
  // PRELOAD NEXT SONG
  // ============================================================

  Future<void> _preloadNext() async {
    final free = o(live);

    // Do not replace a song already loaded into the free deck.
    if (nm(free) != null || q.isEmpty) {
      return;
    }

    final track = q.removeAt(0);

    await _load(
      free,
      track,
      play: false,
    );
  }

  // ============================================================
  // AUTO MIX
  // ============================================================

  Future<void> _mix() async {
    if (xing) {
      return;
    }

    final source = live;
    final target = o(source);

    // If target deck is empty, get the next queued song.
    if (nm(target) == null) {
      if (!auto || q.isEmpty) {
        autoTriggered = false;
        return;
      }

      final track = q.removeAt(0);

      await _load(
        target,
        track,
        play: false,
      );
    }

    if (nm(target) == null) {
      autoTriggered = false;
      return;
    }

    final sourcePlayer = p(source);
    final targetPlayer = p(target);

    xing = true;

    if (mounted) {
      setState(() {});
    }

    // Target begins completely silent.
    await targetPlayer.setVolume(0.0);

    // Start target song.
    if (!targetPlayer.playing) {
      await targetPlayer.play();
    }

    // ==========================================================
    // EXACT 10-SECOND CROSSFADER MOVEMENT
    // ==========================================================
    //
    // 100 steps x 100ms = 10 seconds.
    //
    for (int step = 1; step <= 100; step++) {
      final value = step / 100.0;

      if (source == Deck.a) {
        xf = value;

        await sourcePlayer.setVolume(
          1.0 - value,
        );

        await targetPlayer.setVolume(
          value,
        );
      } else {
        xf = 1.0 - value;

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

      if (step < 100) {
        await Future.delayed(
          const Duration(milliseconds: 100),
        );
      }
    }

    // Make the final volumes exact.
    await sourcePlayer.setVolume(0.0);
    await targetPlayer.setVolume(1.0);

    // Stop the old song.
    await sourcePlayer.stop();

    // Remove old song from its deck.
    setNm(source, null);

    // Target becomes the live deck.
    live = target;

    // Set the slider to the correct final position.
    xf = live == Deck.a ? 0.0 : 1.0;

    xing = false;

    // New song can now trigger the next Auto Mix.
    autoTriggered = false;

    if (mounted) {
      setState(() {});
    }

    // Prepare another song for the next transition.
    if (auto && q.isNotEmpty) {
      await _preloadNext();
    }
  }

  // ============================================================
  // LOAD TRACK
  // ============================================================

  Future<void> _load(
    Deck deck,
    QueuedTrack track, {
    bool play = false,
  }) async {
    final player = p(deck);

    await player.stop();

    await player.setFilePath(
      track.path,
    );

    await player.seek(
      const Duration(milliseconds: 150),
    );

    setNm(
      deck,
      track.name,
    );

    await player.setVolume(
      deck == live ? 1.0 : 0.0,
    );

    if (play) {
      live = deck;
      xf = deck == Deck.a ? 0.0 : 1.0;
      autoTriggered = false;

      await player.setVolume(1.0);
      await player.play();
    }

    if (mounted) {
      setState(() {});
    }
  }

  // ============================================================
  // PICK SONG
  // ============================================================

  Future<void> pick(
    bool isA,
  ) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
    );

    if (result == null ||
        result.files.single.path == null) {
      return;
    }

    final requested =
        isA ? Deck.a : Deck.b;

    final target =
        p(live).playing && requested == live
            ? o(live)
            : requested;

    await _load(
      target,
      QueuedTrack(
        result.files.single.path!,
        result.files.single.name,
      ),
    );
  }

  // ============================================================
  // QUEUE
  // ============================================================

  Future<void> addQ() async {
    final result =
        await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
    );

    if (result == null) {
      return;
    }

    final tracks = result.files
        .where(
          (file) => file.path != null,
        )
        .map(
          (file) => QueuedTrack(
            file.path!,
            file.name,
          ),
        )
        .toList();

    if (mounted) {
      setState(() {
        q.addAll(tracks);
      });
    }
  }

  Future<void> loadFromQueue(
    int index,
  ) async {
    if (index < 0 || index >= q.length) {
      return;
    }

    final track = q.removeAt(index);

    final target = p(live).playing
        ? o(live)
        : nm(live) == null
            ? live
            : o(live);

    await _load(
      target,
      track,
    );
  }

  // ============================================================
  // DECK UI
  // ============================================================

  Widget deck(
    bool isA,
  ) {
    final deck =
        isA ? Deck.a : Deck.b;

    final player = p(deck);
    final isLive = live == deck;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(16),
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(14),
        child: Column(
          children: [
            Text(
              'DECK ${isA ? 'A' : 'B'} '
              '${isLive ? '(LIVE)' : '(NEXT)'}'
              '${xing && isLive ? ' MIXING' : ''}',
              style: TextStyle(
                fontWeight:
                    FontWeight.bold,
                fontSize: 12,
                color: isLive
                    ? const Color(
                        0xFFCEBBFF,
                      )
                    : Colors.white70,
              ),
            ),

            const SizedBox(height: 4),

            Text(
              nm(deck) ?? 'No track',
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),

            Row(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.folder_open,
                  ),
                  onPressed: () {
                    pick(isA);
                  },
                ),

                StreamBuilder<PlayerState>(
                  stream:
                      player.playerStateStream,
                  builder:
                      (context, snapshot) {
                    final playing =
                        snapshot.data?.playing ??
                            false;

                    return IconButton(
                      iconSize: 36,
                      icon: Icon(
                        playing
                            ? Icons
                                .pause_circle_filled
                            : Icons
                                .play_circle_fill,
                        color:
                            const Color(
                          0xFFCEBBFF,
                        ),
                      ),
                      onPressed: () async {
                        if (player.playing) {
                          await player.pause();
                          return;
                        }

                        if (nm(deck) == null) {
                          if (q.isEmpty) {
                            return;
                          }

                          final track =
                              q.removeAt(0);

                          await _load(
                            deck,
                            track,
                            play: true,
                          );
                        } else {
                          live = deck;
                          xf = deck ==
                                  Deck.a
                              ? 0.0
                              : 1.0;

                          autoTriggered =
                              false;

                          await player
                              .setVolume(
                            1.0,
                          );

                          await p(
                            o(deck),
                          ).setVolume(0.0);

                          await player.play();
                        }

                        if (mounted) {
                          setState(() {});
                        }
                      },
                    );
                  },
                ),

                IconButton(
                  icon: const Icon(
                    Icons.stop,
                  ),
                  onPressed: () async {
                    await player.stop();
                    await player.setVolume(0.0);

                    if (mounted) {
                      setState(() {});
                    }
                  },
                ),
              ],
            ),

            StreamBuilder<Duration>(
              stream:
                  player.positionStream,
              builder:
                  (context, snapshot) {
                final position =
                    snapshot.data ??
                        Duration.zero;

                final duration =
                    player.duration ??
                        Duration.zero;

                final max =
                    duration.inMilliseconds >
                            0
                        ? duration
                            .inMilliseconds
                            .toDouble()
                        : 1.0;

                final value = position
                    .inMilliseconds
                    .toDouble()
                    .clamp(
                      0.0,
                      max,
                    );

                String format(
                  Duration d,
                ) {
                  final m = d.inMinutes
                      .remainder(60)
                      .toString()
                      .padLeft(2, '0');

                  final s = d.inSeconds
                      .remainder(60)
                      .toString()
                      .padLeft(2, '0');

                  return '$m:$s';
                }

                return Column(
                  children: [
                    Slider(
                      value: value,
                      min: 0,
                      max: max,
                      activeColor:
                          const Color(
                        0xFFCEBBFF,
                      ),
                      onChanged: (v) {
                        player.seek(
                          Duration(
                            milliseconds:
                                v.toInt(),
                          ),
                        );
                      },
                    ),

                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment
                              .spaceBetween,
                      children: [
                        Text(
                          format(position),
                          style:
                              const TextStyle(
                            fontSize: 10,
                          ),
                        ),
                        Text(
                          format(duration),
                          style:
                              const TextStyle(
                            fontSize: 10,
                          ),
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
  // MAIN UI
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('BlendJam'),
        actions: [
          Row(
            children: [
              const Text(
                'AUTO MIX',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              Switch(
                value: auto,
                activeColor:
                    const Color(
                  0xFFCEBBFF,
                ),
                onChanged:
                    (value) async {
                  setState(
                    () => auto = value,
                  );

                  if (value) {
                    await _autoStart();
                  }
                },
              ),

              const SizedBox(
                width: 8,
              ),
            ],
          ),
        ],
      ),

      body: ListView(
        padding:
            const EdgeInsets.all(12),
        children: [
          deck(true),

          Padding(
            padding:
                const EdgeInsets.all(8),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text(
                      'A',
                      style: TextStyle(
                        fontSize: 10,
                      ),
                    ),

                    Expanded(
                      child: Slider(
                        value: xf,
                        min: 0,
                        max: 1,
                        activeColor:
                            const Color(
                          0xFFCEBBFF,
                        ),
                        onChanged:
                            xing
                                ? null
                                : (value) async {
                                    xf =
                                        value;

                                    await a
                                        .setVolume(
                                      1 - value,
                                    );

                                    await b
                                        .setVolume(
                                      value,
                                    );

                                    if (value >=
                                            0.5 &&
                                        nm(Deck.b) !=
                                            null) {
                                      live =
                                          Deck.b;
                                    }

                                    if (value <
                                            0.5 &&
                                        nm(Deck.a) !=
                                            null) {
                                      live =
                                          Deck.a;
                                    }

                                    setState(
                                      () {},
                                    );
                                  },
                      ),
                    ),

                    const Text(
                      'B',
                      style: TextStyle(
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),

                Text(
                  xing
                      ? 'CROSSFADING '
                        '${live == Deck.a ? 'A → B' : 'B → A'}'
                        ' — ${xf.toStringAsFixed(2)}'
                      : 'Crossfader at '
                        '${xf.toStringAsFixed(2)}',
                  style:
                      const TextStyle(
                    fontSize: 9,
                    color:
                        Colors.white54,
                  ),
                ),

                if (xing)
                  const LinearProgressIndicator(
                    color:
                        Color(0xFFCEBBFF),
                  ),
              ],
            ),
          ),

          deck(false),

          const SizedBox(
            height:
