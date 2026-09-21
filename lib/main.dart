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

enum Deck { a, b }

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
    positionASub = playerA.positionStream.listen((p) => _checkAutoMix(Deck.a, p));
    positionBSub = playerB.positionStream.listen((p) => _checkAutoMix(Deck.b, p));
  }

  AudioPlayer _playerFor(Deck d) => d == Deck.a ? playerA : playerB;
  Deck _otherDeck(Deck d) => d == Deck.a ? Deck.b : Deck.a;
  String? _nameFor(Deck d) => d == Deck.a ? nameA : nameB;
  void _setName(Deck d, String? n) { if (d == Deck.a) nameA = n; else nameB = n; }
  bool _isPlaying(Deck d) => _playerFor(d).playing;

  @override
  void dispose() {
    positionASub?.cancel();
    positionBSub?.cancel();
    playerA.dispose();
    playerB.dispose();
    super.dispose();
  }

  // === FIXED AUTO MIX ===
  void _checkAutoMix(Deck deck, Duration position) {
    if (!autoMix || isCrossfading || deck != activeDeck) return;
    final player = _playerFor(deck);
    final duration = player.duration;
    if (duration == null || !player.playing) return;
    final remaining = duration - position;
    if (remaining <= const Duration(seconds: 10) && remaining > Duration.zero && position > const Duration(seconds: 2)) {
      _triggerAutoMix();
    }
  }

  Future<void> _triggerAutoMix() async {
    if (isCrossfading) return;
    final sourceDeck = activeDeck;
    final targetDeck = _otherDeck(sourceDeck);
    final sourcePlayer = _playerFor(sourceDeck);
    final targetPlayer = _playerFor(targetDeck);

    // Always use QUEUE first if available
    if (queue.isNotEmpty) {
      final nextTrack = queue.removeAt(0);
      await targetPlayer.stop();
      await targetPlayer.setFilePath(nextTrack.path);
      await targetPlayer.seek(Duration.zero);
      _setName(targetDeck, nextTrack.name);
      if (mounted) setState(() {});
    }

    if (_nameFor(targetDeck) == null)
