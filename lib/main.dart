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

  AudioPlayer _playerFor(Deck deck) {
    return deck == Deck.a ? playerA : playerB;
  }

 
