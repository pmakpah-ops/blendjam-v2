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
    if (deck != activeDeck) return;

    final player = _playerFor(deck);
    final duration = player.duration;

    if (duration == null) return;

    final remaining = duration - position;

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

    // Do not replace the currently playing deck.
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
  // LOAD TRACK
  // ============================================================

  Future<void> _loadTrackIntoDeck(
    Deck deck,
    QueuedTrack track, {
    required bool autoPlay,
  }) async {
    final player = _playerFor(deck);

    await player.stop();

    await player.setFilePath(track.path);

    await player.seek(
      const Duration(milliseconds: 350),
    );

    _setName(deck, track.name);

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
  // QUEUE
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
    } else if (_nameFor(activeDeck) == null) {
      targetDeck = activeDeck;
    } else {
      targetDeck = _otherDeck(activeDeck);
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

    // ----------------------------------------------------------
    // GET NEXT TRACK
    // ----------------------------------------------------------
    //
    // First use a song already loaded in the free deck.
    // Otherwise take the first song from the queue.
    //

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

    // ----------------------------------------------------------
    // START NEXT DECK SILENTLY
    // ----------------------------------------------------------

    await targetPlayer.setVolume(0.0);

    if (!targetPlayer.playing) {
      await targetPlayer.play();
    }

    // ----------------------------------------------------------
    // 10 SECOND CROSSFADE
    // ----------------------------------------------------------

    const int steps = 100;

    for (int i = 0; i <= steps; i++) {
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

    // ----------------------------------------------------------
    // FINISH TRANSITION
    // ----------------------------------------------------------

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
  // MANUAL CROSSFADER
  // ============================================================

  Future<void> _handleCrossfade(double value) async {
    if (isCrossfading) {
      return;
    }

    // Moving toward B starts B.
    if (value > 0.01 &&
        _nameFor(Deck.b) != null &&
        !playerB.playing) {
      await playerB.setVolume(0.0);
      await playerB.play();
    }

    // Moving toward A starts A.
    if (value < 0.99 &&
        _nameFor(Deck.a) != null &&
        !playerA.playing) {
      await playerA.setVolume(0.0);
      await playerA.play();
    }

    // Apply fader volumes.
    await playerA.setVolume(1.0 - value);
    await playerB.setVolume(value);

    // Determine which
