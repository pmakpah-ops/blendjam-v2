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

  List<QueuedTrack> queue = [];

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

  @override
  void dispose() {
    _positionASub?.cancel();
    _positionBSub?.cancel();

    playerA.dispose();
    playerB.dispose();

    super.dispose();
  }

  // ------------------------------------------------------------
  // AUTO MIX MONITOR
  // ------------------------------------------------------------

  void _checkAutoMix(Deck deck, Duration position) {
    if (!autoMix) return;
    if (isCrossfading) return;
    if (queue.isEmpty) return;

    // Only the currently active deck controls Auto Mix.
    if (deck != activeDeck) return;

    final player = _playerFor(deck);
    final duration = player.duration;

    if (duration == null) return;

    final remaining = duration - position;

    // Start Auto Mix during the final 10 seconds.
    if (remaining <= const Duration(seconds: 10) &&
        remaining > Duration.zero &&
        position > const Duration(seconds: 1)) {
      _triggerAutoMix();
    }
  }

  // ------------------------------------------------------------
  // PICK TRACK DIRECTLY INTO A DECK
  // ------------------------------------------------------------

  Future<void> pickTrack(bool requestedIsA) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
    );

    if (result == null || result.files.single.path == null) {
      return;
    }

    final requestedDeck = requestedIsA ? Deck.a : Deck.b;

    // Never replace a currently playing deck.
    Deck targetDeck = requestedDeck;

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

  // ------------------------------------------------------------
  // LOAD TRACK INTO DECK
  // ------------------------------------------------------------

  Future<void> _loadTrackIntoDeck(
    Deck deck,
    QueuedTrack track, {
    bool autoPlay = false,
  }) async {
    final player = _playerFor(deck);

    await player.stop();

    await player.setFilePath(track.path);

    // Skip a small amount of leading silence.
    await player.seek(
      const Duration(milliseconds: 350),
    );

    await player.setVolume(
      deck == activeDeck ? 1.0 : 0.0,
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
  // ADD SONGS TO QUEUE
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

    if (mounted) {
      setState(() {
        queue.addAll(tracks);
      });
    }
  }

  // ------------------------------------------------------------
  // MANUAL QUEUE SELECTION
  // ------------------------------------------------------------

  Future<void> playFromQueue(int index) async {
    if (index < 0 || index >= queue.length) return;

    final track = queue.removeAt(index);

    Deck targetDeck;

    // If something is playing, always use the other deck.
    if (_isPlaying(activeDeck)) {
      targetDeck = _otherDeck(activeDeck);
    } else {
      final activeName = _nameFor(activeDeck);

      if (activeName == null) {
        targetDeck = activeDeck;
      } else {
        targetDeck = _otherDeck(activeDeck);
      }
    }

    // Load it into the free deck.
    // It does NOT replace or interrupt the currently playing deck.
    await _loadTrackIntoDeck(
      targetDeck,
      track,
      autoPlay: false,
    );

    if (mounted) {
      setState(() {});
    }
  }

  // ------------------------------------------------------------
  // AUTO MIX
  // ------------------------------------------------------------

  Future<void> _triggerAutoMix() async {
    if (queue.isEmpty || isCrossfading) return;

    final sourceDeck = activeDeck;
    final targetDeck = _otherDeck(sourceDeck);

    final sourcePlayer = _playerFor(sourceDeck);
    final targetPlayer = _playerFor(targetDeck);

    final next = queue.removeAt(0);

    if (mounted) {
      setState(() {
        isCrossfading = true;
      });
    }

    // Prepare
