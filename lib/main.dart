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

    // If the next deck is empty, load the next song from queue.
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
    }

    if (mounted) {
      setState(() {
        isCrossfading = true;
      });
    }

    // Target starts completely silent.
    await targetPlayer.setVolume(0.0);

    // Start target deck.
    if (!targetPlayer.playing) {
      await targetPlayer.play();
    }

    // 10-second crossfade.
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

    // Source is now finished.
    await sourcePlayer.stop();

    await sourcePlayer.setVolume(0.0);

    await targetPlayer.setVolume(1.0);

    // Target becomes the live deck.
    activeDeck = targetDeck;

    crossfade =
        activeDeck == Deck.a ? 0.0 : 1.0;

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

    if (_isPlaying
