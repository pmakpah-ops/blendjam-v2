import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

void main() => runApp(const BlendJamApp());

class BlendJamApp extends StatelessWidget {
  const BlendJamApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF121212),
          cardColor: const Color(0xFF1E1E1E),
        ),
        home: const DJScreen(),
      );
}

class QueuedTrack {
  final String path, name;
  QueuedTrack(this.path, this.name);
}

enum Deck { a, b }

class DJScreen extends StatefulWidget {
  const DJScreen({super.key});

  @override
  State<DJScreen> createState() => _DJScreenState();
}

class _DJScreenState extends State<DJScreen> {
  final playerA = AudioPlayer();
  final playerB = AudioPlayer();
  final queue = <QueuedTrack>[];

  String? nameA, nameB;
  double crossfade = 0;
  bool autoMix = false, isCrossfading = false;
  Deck activeDeck = Deck.a;

  StreamSubscription<Duration>? subA, subB;

  @override
  void initState() {
    super.initState();
    subA = playerA.positionStream.listen((p) => _checkAutoMix(Deck.a, p));
    subB = playerB.positionStream.listen((p) => _checkAutoMix(Deck.b, p));
  }

  AudioPlayer player(Deck d) => d == Deck.a ? playerA : playerB;

  Deck other(Deck d) => d == Deck.a ? Deck.b : Deck.a;

  String? name(Deck d) => d == Deck.a ? nameA : nameB;

  void setName(Deck d, String? n) {
    if (d == Deck.a) {
      nameA = n;
    } else {
      nameB = n;
    }
  }

  bool playing(Deck d) => player(d).playing;

  @override
  void dispose() {
    subA?.cancel();
    subB?.cancel();
    playerA.dispose();
    playerB.dispose();
    super.dispose();
  }

  // ==================== AUTO MIX ====================

  void _checkAutoMix(Deck deck, Duration position) {
    if (!autoMix || isCrossfading || deck != activeDeck) return;

    final p = player(deck);
    final duration = p.duration;

    if (duration == null || !p.playing) return;

    final remaining = duration - position;

    if (remaining <= const Duration(seconds: 10) &&
        remaining > Duration.zero &&
        position > const Duration(seconds: 2)) {
      _triggerAutoMix();
    }
  }

  Future<void> _triggerAutoMix() async {
    if (isCrossfading) return;

    final source = activeDeck;
    final target = other(source);
    final sourcePlayer = player(source);
    final targetPlayer = player(target);

    // Use the next queued song for the transition.
    if (queue.isNotEmpty) {
      final track = queue.removeAt(0);

      await targetPlayer.stop();
      await targetPlayer.setFilePath(track.path);
      await targetPlayer.seek(Duration.zero);

      setName(target, track.name);

      if (mounted) setState(() {});
    }

    if (name(target) == null) return;

    if (mounted) setState(() => isCrossfading = true);

    await targetPlayer.setVolume(0);
    if (!targetPlayer.playing) await targetPlayer.play();

    // 100 x 100ms = 10 seconds.
    for (int step = 1; step <= 100; step++) {
      final value = step / 100;

      if (source == Deck.a) {
        crossfade = value;
        await sourcePlayer.setVolume(1 - value);
        await targetPlayer.setVolume(value);
      } else {
        crossfade = 1 - value;
        await sourcePlayer.setVolume(value);
        await targetPlayer.setVolume(1 - value);
      }

      if (mounted) setState(() {});

      if (step < 100) {
        await Future.delayed(
          const Duration(milliseconds: 100),
        );
      }
    }

    await sourcePlayer.setVolume(0);
    await targetPlayer.setVolume(1);
    await sourcePlayer.stop();

    setName(source, null);
    activeDeck = target;

    crossfade = target == Deck.a ? 0 : 1;

    if (mounted) {
      setState(() => isCrossfading = false);
    }

    // Pre-load another queued song into the free deck.
    if (queue.isNotEmpty) {
      final next = queue.removeAt(0);
      await _load(target == Deck.a ? Deck.b : Deck.a, next);
    }
  }

  // ==================== TRACK LOADING ====================

  Future<void> pickTrack(bool isA) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
    );

    if (result == null || result.files.single.path == null) return;

    final requested = isA ? Deck.a : Deck.b;
    final target = playing(activeDeck) && requested == activeDeck
        ? other(activeDeck)
        : requested;

    await _load(
      target,
      QueuedTrack(
        result.files.single.path!,
        result.files.single.name,
      ),
    );
  }

  Future<void> _load(
    Deck deck,
    QueuedTrack track, {
    bool autoPlay = false,
  }) async {
    final p = player(deck);

    await p.stop();
    await p.setFilePath(track.path);
    await p.seek(Duration.zero);

    setName(deck, track.name);
    await p.setVolume(deck == activeDeck ? 1 : 0);

    if (autoPlay) await p.play();

    if (mounted) setState(() {});
  }

  // ==================== QUEUE ====================

  Future<void> addToQueue() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
    );

    if (result == null) return;

    final tracks = result.files
        .where((f) => f.path != null)
        .map((f) => QueuedTrack(f.path!, f.name));

    if (mounted) {
      setState(() => queue.addAll(tracks));
    }
  }

  Future<void> playFromQueue(int index) async {
    if (index < 0 || index >= queue.length) return;

    final track = queue.removeAt(index);

    final target = playing(activeDeck)
        ? other(activeDeck)
        : name(activeDeck) == null
            ? activeDeck
            : other(activeDeck);

    await _load(target, track);

    if (mounted) setState(() {});
  }

  // ==================== CROSSFADER ====================

  Future<void> _handleCrossfade(double value) async {
    if (isCrossfading) return;

    if (value > .01 &&
        name(Deck.b) != null &&
        !playerB.playing) {
      await playerB.setVolume(0);
      await playerB.play();
    }

    if (value < .99 &&
        name(Deck.a) != null &&
        !playerA.playing) {
      await playerA.setVolume(0);
      await playerA.play();
    }

    await playerA.setVolume(1 - value);
    await playerB.setVolume(value);

    if (value >= .5 && name(Deck.b) != null) {
      activeDeck = Deck.b;
    } else if (value < .5 && name(Deck.a) != null) {
      activeDeck = Deck.a;
    }

    if (mounted) {
      setState(() => crossfade = value);
    }
  }

  // ==================== PLAY / PAUSE ====================

  Future<void> togglePlay(Deck deck) async {
    final p = player(deck);

    if (p.playing) {
      await p.pause();
      return;
    }

    if (name(deck) == null) return;

    final otherPlayer = player(other(deck));

    if (otherPlayer.playing) {
      await p.setVolume(0);
      await p.play();

      if (mounted) setState(() {});
      return;
    }

    activeDeck = deck;

    await p.setVolume(1);
    await otherPlayer.setVolume(0);

    crossfade = deck == Deck.a ? 0 : 1;

    await p.play();

    if (mounted) setState(() {});
  }

  Future<void> stopDeck(Deck deck) async {
    final p = player(deck);

    await p.stop();
    await p.setVolume(0);

    if (mounted) setState(() {});
  }

  // ==================== DECK UI ====================

  Widget deckWidget(bool isA) {
    final deck = isA ? Deck.a : Deck.b;
    final p = player(deck);
    final trackName = name(deck);
    final active = activeDeck == deck;

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
              '${active ? '(LIVE)' : '(NEXT)'}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: active
                    ? const Color(0xFFCEBBFF)
                    : Colors.white70,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              trackName ?? 'No track',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.folder_open),
                  onPressed: () => pickTrack(isA),
                ),
                StreamBuilder<PlayerState>(
                  stream: p.playerStateStream,
                  builder: (context, snapshot) {
                    final isPlaying =
                        snapshot.data?.playing ?? false;

                    return IconButton(
                      iconSize: 36,
                      icon: Icon(
                        isPlaying
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
              stream: p.positionStream,
              builder: (context, snapshot) {
                final position =
                    snapshot.data ?? Duration.zero;
                final duration =
                    p.duration ?? Duration.zero;

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
                      min: 0,
                      max: max,
                      activeColor:
                          const Color(0xFFCEBBFF),
