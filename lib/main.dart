import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audiotags/audiotags.dart';
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
      theme: ThemeData.dark(),
      home: const DJ(),
    );
  }
}

class Track {
  final String path;
  final String name;

  const Track(this.path, this.name);
}

enum Deck { a, b }

class DJ extends StatefulWidget {
  const DJ({super.key});

  @override
  State<DJ> createState() => _DJState();
}

class _DJState extends State<DJ> {
  static const purple = Color(0xFFCEBBFF);

  static const fadeTime = Duration(seconds: 10);
  static const preloadTime = Duration(seconds: 15);
  static const trim = Duration(milliseconds: 350);

  final AudioPlayer playerA = AudioPlayer();
  final AudioPlayer playerB = AudioPlayer();

  StreamSubscription<Duration>? positionA;
  StreamSubscription<Duration>? positionB;

  String? nameA;
  String? nameB;

  Uint8List? artA;
  Uint8List? artB;

  Deck liveDeck = Deck.a;

  bool autoMix = true;
  bool crossfading = false;

  double crossfader = 0;

  final List<Track> queue = [];
  int queueIndex = 0;

  bool nextLoaded = false;

  AudioPlayer _player(Deck d) {
    return d == Deck.a ? playerA : playerB;
  }

  Deck _other(Deck d) {
    return d == Deck.a ? Deck.b : Deck.a;
  }

  String? _name(Deck d) {
    return d == Deck.a ? nameA : nameB;
  }

  Uint8List? _art(Deck d) {
    return d == Deck.a ? artA : artB;
  }

  void _setName(Deck d, String? value) {
    if (d == Deck.a) {
      nameA = value;
    } else {
      nameB = value;
    }
  }

  void _setArt(Deck d, Uint8List? value) {
    if (d == Deck.a) {
      artA = value;
    } else {
      artB = value;
    }
  }

  @override
  void initState() {
    super.initState();

    positionA = playerA.positionStream.listen(
      (p) => _checkTransition(Deck.a, p),
    );

    positionB = playerB.positionStream.listen(
      (p) => _checkTransition(Deck.b, p),
    );
  }

  @override
  void dispose() {
    positionA?.cancel();
    positionB?.cancel();

    playerA.dispose();
    playerB.dispose();

    super.dispose();
  }

  // ============================================================
  // QUEUE
  // ============================================================

  Track? _nextTrack() {
    if (queue.isEmpty) {
      return null;
    }

    final track = queue[queueIndex % queue.length];

    queueIndex++;

    if (queueIndex >= queue.length) {
      queueIndex = 0;
    }

    return track;
  }

  // ============================================================
  // ARTWORK
  // ============================================================

  Future<Uint8List?> _getArtwork(String path) async {
    try {
      final tags = await AudioTags.read(path);

      if (tags != null && tags.pictures.isNotEmpty) {
        return tags.pictures.first.bytes;
      }
    } catch (_) {}

    return null;
  }

  // ============================================================
  // LOAD DECK
  // ============================================================

  Future<bool> _load(
    Deck deck,
    Track track, {
    bool play = false,
  }) async {
    final pl = _player(deck);

    _setName(deck, track.name);
    _setArt(deck, null);

    if (mounted) {
      setState(() {});
    }

    try {
      await pl.stop();

      await pl.setFilePath(track.path);

      final duration = pl.duration;

      if (duration != null && duration > trim) {
        await pl.seek(trim);
      } else {
        await pl.seek(Duration.zero);
      }
    } catch (e) {
      _message(
        'Could not load ${track.name}',
      );
      return false;
    }

    unawaited(
      _getArtwork(track.path).then((image) {
        if (!mounted) return;

        _setArt(deck, image);

        setState(() {});
      }),
    );

    await pl.setVolume(
      play ? 1.0 : 0.0,
    );

    if (play) {
      await _makeLive(
        deck,
        play: true,
      );
    }

    if (mounted) {
      setState(() {});
    }

    return true;
  }

  // ============================================================
  // MAKE LIVE
  // ============================================================

  Future<void> _makeLive(
    Deck deck, {
    bool play = false,
  }) async {
    final active = _player(deck);
    final inactive = _player(_other(deck));

    liveDeck = deck;

    nextLoaded = false;

    crossfader = deck == Deck.a ? 0 : 1;

    await inactive.setVolume(0);

    await active.setVolume(1);

    if (play) {
      await active.play();
    }

    if (mounted) {
      setState(() {});
    }
  }

  // ============================================================
  // PREPARE NEXT
  // ============================================================

  Future<void> _prepareNext() async {
    if (queue.isEmpty || crossfading) {
      return;
    }

    final nextDeck = _other(liveDeck);

    if (_name(nextDeck) != null) {
      return;
    }

    final next = _nextTrack();

    if (next == null) {
      return;
    }

    await _load(
      nextDeck,
      next,
      play: false,
    );
  }

  // ============================================================
  // AUTO START
  // ============================================================

  Future<void> _startAuto() async {
    if (queue.isEmpty) {
      _message('Add music to the queue first.');
      return;
    }

    if (_name(liveDeck) == null) {
      final first = _nextTrack();

      if (first == null) {
        return;
      }

      final ok = await _load(
        liveDeck,
        first,
        play: true,
      );

      if (!ok) return;
    } else {
      final pl = _player(liveDeck);

      if (!pl.playing) {
        await pl.play();
      }
    }

    await _prepareNext();

    if (mounted) {
      setState(() {});
    }
  }

  // ============================================================
  // TRANSITION CHECK
  // ============================================================

  void _checkTransition(
    Deck deck,
    Duration position,
  ) {
    if (!mounted) return;

    if (crossfading) return;

    if (deck != liveDeck) return;

    final pl = _player(deck);

    if (!pl.playing) return;

    final duration = pl.duration;

    if (duration == null) return;

    final remaining = duration - position;

    // Load next song before the transition.
    if (remaining <= preloadTime &&
        _name(_other(deck)) == null &&
        !nextLoaded &&
        queue.isNotEmpty) {
      nextLoaded = true;

      unawaited(
        _prepareNext(),
      );
    }

    // Start transition.
    //
    // Do NOT use == 10 seconds.
    if (remaining <= fadeTime) {
      final target = _other(deck);

      if (_name(target) != null) {
        unawaited(
          _crossfade(target),
        );
      }
    }
  }

  // ============================================================
  // CROSSFADE
  // ============================================================

  Future<void> _crossfade(Deck target) async {
    if (crossfading) return;

    if (_name(target) == null) return;

    final source = liveDeck;

    if (source == target) return;

    final sourcePlayer = _player(source);
    final targetPlayer = _player(target);

    crossfading = true;

    try {
      await targetPlayer.setVolume(0);

      if (!targetPlayer.playing) {
        await targetPlayer.play();
      }

      const steps = 100;

      final delay = Duration(
        milliseconds:
            fadeTime.inMilliseconds ~/ steps,
      );

      for (int i = 1; i <= steps; i++) {
        final value = i / steps;

        final sourceVolume =
            math.cos(
              value * math.pi / 2,
            );

        final targetVolume =
            math.sin(
              value * math.pi / 2,
            );

        await sourcePlayer.setVolume(
          sourceVolume,
        );

        await targetPlayer.setVolume(
          targetVolume,
        );

        crossfader =
            source == Deck.a
                ? value
                : 1 - value;

        if (mounted) {
          setState(() {});
        }

        await Future<void>.delayed(
          delay,
        );
      }

      await sourcePlayer.setVolume(0);

      await targetPlayer.setVolume(1);

      await sourcePlayer.stop();

      _setName(source, null);
      _setArt(source, null);

      liveDeck = target;

      nextLoaded = false;

      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      _message('Crossfade failed.');
    }

    crossfading = false;

    if (mounted) {
      setState(() {});
    }

    if (autoMix) {
      await _prepareNext();
    }
  }

  // ============================================================
  // PLAY / PAUSE
  // ============================================================

  Future<void> _togglePlay(Deck deck) async {
    if (crossfading) return;

    final pl = _player(deck);

    try {
      // --------------------------------------------------------
      // PAUSE
      // --------------------------------------------------------

      if (pl.playing) {
        await pl.pause();

        if (mounted) {
          setState(() {});
        }

        return;
      }

      // --------------------------------------------------------
      // NO TRACK
      // --------------------------------------------------------

      if (_name(deck) == null) {
        if (queue.isEmpty) {
          _message(
            'Add an audio file first.',
          );
          return;
        }

        final track = _nextTrack();

        if (track == null) {
          return;
        }

        final ok = await _load(
          deck,
          track,
        );

        if (!ok) return;
      }

      // --------------------------------------------------------
      // OTHER DECK
      // --------------------------------------------------------

      if (deck != liveDeck &&
          _name(liveDeck) != null) {
        await _crossfade(deck);
        return;
      }

      // --------------------------------------------------------
      // PLAY
      // --------------------------------------------------------

      liveDeck = deck;

      crossfader =
          deck == Deck.a ? 0 : 1;

      await _player(
        _other(deck),
      ).setVolume(0);

      await pl.setVolume(1);

      await pl.play();

      if (autoMix) {
        await _prepareNext();
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      _message(
        'Playback error.',
      );
    }
  }

  // ============================================================
  // PICK FILE
  // ============================================================

  Future<void> _pick(
    Deck deck,
  ) async {
    final result =
        await FilePicker.platform.pickFiles(
      type: FileType.audio,
    );

    if (result == null) return;

    final path =
        result.files.single.path;

    if (path == null) return;

    final track = Track(
      path,
      result.files.single.name,
    );

    final ok = await _load(
      deck,
      track,
      play: true,
    );

    if (!ok) return;

    liveDeck = deck;

    if (autoMix) {
      await _prepareNext();
    }

    if (mounted) {
      setState(() {});
    }
  }

  // ============================================================
  // ADD QUEUE
  // ============================================================

  Future<void> _addQueue() async {
    final result =
        await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
    );

    if (result == null) return;

    final tracks = result.files
        .where(
          (f) => f.path != null,
        )
        .map(
          (f) => Track(
            f.path!,
            f.name,
          ),
        )
        .toList();

    if (tracks.isEmpty) return;

    setState(() {
      queue.addAll(tracks);
    });

    if (autoMix) {
      await _startAuto();
    }
  }

  // ============================================================
  // NEXT
  // ============================================================

  Future<void> _next(
    Deck deck,
  ) async {
    if (queue.isEmpty) return;

    if (crossfading) return;

    final track = _nextTrack();

    if (track == null) return;

    final ok = await _load(
      deck,
      track,
      play: deck == liveDeck,
    );

    if (!ok) return;

    if (deck == liveDeck &&
        autoMix) {
      await _prepareNext();
    }
  }

  // ============================================================
  // PREVIOUS
  // ============================================================

  Future<void> _previous(
    Deck deck,
  ) async {
    if (queue.isEmpty) return;

    if (crossfading) return;

    queueIndex -= 2;

    while (queueIndex < 0) {
      queueIndex += queue.length;
    }

    final track = _nextTrack();

    if (track == null) return;

    final ok = await _load(
      deck,
      track,
      play: deck == liveDeck,
    );

    if (!ok) return;

    if (deck == liveDeck &&
        autoMix) {
      await _prepareNext();
    }
  }

  // ============================================================
  // SEEK
  // ============================================================

  Future<void> _seek(
    Deck deck,
    int seconds,
  ) async {
    final pl = _player(deck);

    var position =
        pl.position +
        Duration(seconds: seconds);

    if (position < Duration.zero) {
      position = Duration.zero;
    }

    final duration = pl.duration;

    if (duration != null &&
        position > duration) {
      position = duration;
    }

    await pl.seek(position);
  }

  // ============================================================
  // CROSSFADER
  // ============================================================

  Future<void> _setCrossfader(
    double value,
  ) async {
    if (crossfading) return;

    crossfader = value;

    await playerA.setVolume(
      1 - value,
    );

    await playerB.setVolume(
      value,
    );

    if (value >= 0.5) {
      liveDeck = Deck.b;
    } else {
      liveDeck = Deck.a;
    }

    final target =
        value >= 0.5
            ? Deck.b
            : Deck.a;

    if (_name(target) != null &&
        !_player(target).playing) {
      await _player(target).play();
    }

    if (mounted) {
      setState(() {});
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _message(
    String text,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
        ),
      );
  }

  // ============================================================
  // DECK
  // ============================================================

  Widget _deck(
    Deck deck,
  ) {
    return DeckView(
      deck: deck,
      player: _player(deck),
      trackName:
          _name(deck) ?? 'No track',
      artwork: _art(deck),
      live: liveDeck == deck,
      next:
          liveDeck != deck &&
          _name(deck) != null,
      onPlay:
          () => _togglePlay(deck),
      onPick:
          () => _pick(deck),
      onPrevious:
          () => _previous(deck),
      onNext:
          () => _next(deck),
      onSeek:
          (seconds) =>
              _seek(deck, seconds),
    );
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'BlendJam',
          style: TextStyle(
            fontSize: 26,
          ),
        ),
        actions: [
          const Text('AUTO'),

          Switch(
            value: autoMix,
            activeColor: purple,
            onChanged: (value) async {
              setState(() {
                autoMix = value;
              });

              if (value) {
                await _startAuto();
              }
            },
          ),

          const SizedBox(width: 8),
        ],
      ),

      body: ListView(
        padding:
            const EdgeInsets.all(14),
        children: [
          _deck(Deck.a),

          const SizedBox(height: 4),

          Row(
            children: [
              const Text('A'),

              Expanded(
                child: Slider(
                  value: crossfader
                      .clamp(0.0, 1.0),
                  min: 0,
                  max: 1,
                  activeColor: purple,
                  onChanged:
                      _setCrossfader,
                ),
              ),

              const Text('B'),
            ],
          ),

          Center(
            child: Text(
              crossfading
                  ? 'MIXING '
                    '${(crossfader * 100).toInt()}%'
                  : '',
              style:
                  const TextStyle(
                color: purple,
              ),
            ),
          ),

          const SizedBox(height: 8),

          _deck(Deck.b),

          const SizedBox(height: 12),

          Row(
            mainAxisAlignment:
                MainAxisAlignment
                    .spaceBetween,
            children: [
              Text(
                'QUEUE ${queue.length}',
              ),

              IconButton(
                icon: const Icon(
                  Icons.add_circle,
                ),
                onPressed:
                    _addQueue,
              ),
            ],
          ),

          ...queue.asMap().entries.map(
            (entry) {
              return ListTile(
                dense: true,

                leading: Text(
                  '${entry.key + 1}',
                ),

                title: Text(
                  entry.value.name,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    fontSize: 13,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ==================================================================
// DECK VIEW
// ==================================================================

class DeckView extends StatefulWidget {
  final Deck deck;
  final AudioPlayer player;

  final String trackName;
  final Uint8List? artwork;

  final bool live;
  final bool next;

  final VoidCallback onPlay;
  final VoidCallback onPick;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  final Future<void> Function(
    int seconds,
  ) onSeek;

  const DeckView({
    super.key,
    required this.deck,
    required this.player,
    required this.trackName,
    required this.artwork,
    required this.live,
    required this.next,
    required this.onPlay,
    required this.onPick,
    required this.onPrevious,
    required this.onNext,
    required this.onSeek,
  });

  @override
  State<DeckView> createState() =>
      _DeckViewState();
}

class _DeckViewState
    extends State<DeckView>
    with SingleTickerProviderStateMixin {
  late AnimationController rotation;

  StreamSubscription<PlayerState>?
      stateSubscription;

  @override
  void initState() {
    super.initState();

    rotation =
        AnimationController(
      vsync: this,
      duration:
          const Duration(seconds: 3),
    );

    stateSubscription =
        widget.player.playerStateStream
            .listen(
      (state) {
        if (!mou
