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
      (position) {
        _checkAutoMix(Deck.a, position);
      },
    );

    positionBSub = playerB.positionStream.listen(
      (position) {
        _checkAutoMix(Deck.b, position);
      },
    );
  }

  AudioPlayer _playerFor(Deck deck) {
    if (deck == Deck.a) {
      return playerA;
    }

    return playerB;
  }

  Deck _otherDeck(Deck deck) {
    if (deck == Deck.a) {
      return Deck.b;
    }

    return Deck.a;
  }

  String? _nameFor(Deck deck) {
    if (deck == Deck.a) {
      return nameA;
    }

    return nameB;
  }

  void _setName(
    Deck deck,
    String? name,
  ) {
    if (deck == Deck.a) {
      nameA = name;
    } else {
      nameB = name;
    }
  }

  bool _isPlaying(Deck deck) {
    return _playerFor(deck).playing;
  }

  @override
  void dispose() {
    positionASub?.cancel();
    positionBSub?.cancel();

    playerA.dispose();
    playerB.dispose();

    super.dispose();
  }

  // ============================================================
  // AUTO MIX
  // ============================================================

  void _checkAutoMix(
    Deck deck,
    Duration position,
  ) {
    if (!autoMix) {
      return;
    }

    if (isCrossfading) {
      return;
    }

    if (deck != activeDeck) {
      return;
    }

    final player = _playerFor(deck);
    final duration = player.duration;

    if (duration == null) {
      return;
    }

    final remaining = duration - position;

    if (remaining <= const Duration(seconds: 10) &&
        remaining > Duration.zero &&
        position > const Duration(seconds: 1)) {
      _triggerAutoMix();
    }
  }

  Future<void> _triggerAutoMix() async {
    if (isCrossfading) {
      return;
    }

    final sourceDeck = activeDeck;
    final targetDeck = _otherDeck(sourceDeck);

    final sourcePlayer = _playerFor(sourceDeck);
    final targetPlayer = _playerFor(targetDeck);

    // Load the next queued song if the target deck is empty.
    if (_nameFor(targetDeck) == null) {
      if (queue.isEmpty) {
        return;
      }

      final nextTrack = queue.removeAt(0);

      await targetPlayer.stop();

      await targetPlayer.setFilePath(
        nextTrack.path,
      );

      await targetPlayer.seek(
        const Duration(milliseconds: 350),
      );

      _setName(
        targetDeck,
        nextTrack.name,
      );

      if (mounted) {
        setState(() {});
      }
    }

    if (mounted) {
      setState(() {
        isCrossfading = true;
      });
    }

    // Target deck starts completely silent.
    await targetPlayer.setVolume(0.0);

    // Start target deck.
    if (!targetPlayer.playing) {
      await targetPlayer.play();
    }

    // Exactly 10 seconds.
    const int steps = 100;

    for (int i = 0; i <= steps; i++) {
      final value = i / steps;

      if (sourceDeck == Deck.a) {
        crossfade = value;

        await sourcePlayer.setVolume(
          1.0 - value,
        );

        await targetPlayer.setVolume(
          value,
        );
      } else {
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

    // Stop the old deck.
    await sourcePlayer.stop();

    await sourcePlayer.setVolume(0.0);

    await targetPlayer.setVolume(1.0);

    // Target becomes the active deck.
    activeDeck = targetDeck;

    crossfade = activeDeck == Deck.a ? 0.0 : 1.0;

    if (mounted) {
      setState(() {
        isCrossfading = false;
      });
    }
  }

  // ============================================================
  // LOAD TRACK
  // ============================================================

  Future<void> pickTrack(
    bool requestedIsA,
  ) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
    );

    if (result == null) {
      return;
    }

    if (result.files.single.path == null) {
      return;
    }

    final requestedDeck =
        requestedIsA ? Deck.a : Deck.b;

    Deck targetDeck = requestedDeck;

    // Do not replace the currently playing deck.
    if (_isPlaying(activeDeck) &&
        requestedDeck == activeDeck) {
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

  Future<void> _loadTrackIntoDeck(
    Deck deck,
    QueuedTrack track, {
    required bool autoPlay,
  }) async {
    final player = _playerFor(deck);

    await player.stop();

    await player.setFilePath(
      track.path,
    );

    await player.seek(
      const Duration(milliseconds: 350),
    );

    _setName(
      deck,
      track.name,
    );

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
        queue.addAll(tracks);
      });
    }
  }

  Future<void> playFromQueue(
    int index,
  ) async {
    if (index < 0 ||
        index >= queue.length) {
      return;
    }

    final track = queue.removeAt(index);

    Deck targetDeck;

    // If the active deck is playing,
    // load the queued song into the other deck.
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
  // MANUAL CROSSFADER
  // ============================================================

  Future<void> _handleCrossfade(
    double value,
  ) async {
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

    // Set A volume.
    await playerA.setVolume(
      1.0 - value,
    );

    // Set B volume.
    await playerB.setVolume(
      value,
    );

    // Determine active deck.
    if (value >= 0.5 &&
        _nameFor(Deck.b) != null) {
      activeDeck = Deck.b;
    } else if (value < 0.5 &&
        _nameFor(Deck.a) != null) {
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

  Future<void> togglePlay(
    Deck deck,
  ) async {
    final player = _playerFor(deck);

    if (player.playing) {
      await player.pause();
      return;
    }

    if (_nameFor(deck) == null) {
      return;
    }

    final otherDeck = _otherDeck(deck);
    final otherPlayer = _playerFor(otherDeck);

    // If the other deck is playing,
    // start this deck silently.
    if (otherPlayer.playing) {
      await player.setVolume(0.0);
      await player.play();

      if (mounted) {
        setState(() {});
      }

      return;
    }

    activeDeck = deck;

    await player.setVolume(1.0);

    await otherPlayer.setVolume(0.0);

    crossfade = deck == Deck.a ? 0.0 : 1.0;

    await player.play();

    if (mounted) {
      setState(() {});
    }
  }

  // ============================================================
  // STOP
  // ============================================================

  Future<void> stopDeck(
    Deck deck,
  ) async {
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

  Widget deckWidget(
    bool isA,
  ) {
    final deck = isA ? Deck.a : Deck.b;

    final player = _playerFor(deck);

    final name = _nameFor(deck);

    final isActive = activeDeck
