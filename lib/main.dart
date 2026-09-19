import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:file_picker/file_picker.dart';

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

class DJScreen extends StatefulWidget {
  const DJScreen({super.key});
  @override
  State<DJScreen> createState() => _DJScreenState();
}

class _DJScreenState extends State<DJScreen> {
  final playerA = AudioPlayer();
  final playerB = AudioPlayer();
  String? nameA, nameB;
  double crossfade = 0.0; // 0 = A full, 1 = B full
  bool autoMix = false;
  List<QueuedTrack> queue = [];
  Timer? autoTimer;
  bool isCrossfading = false;

  @override
  void initState() {
    super.initState();
    // Monitor player A for auto-mix trigger
    playerA.positionStream.listen((pos) {
      if (!autoMix || isCrossfading || queue.isEmpty) return;
      final dur = playerA.duration;
      if (dur == null) return;
      final remaining = dur - pos;
      if (remaining.inSeconds == 10) {
        _triggerAutoMix();
      }
    });
  }

  Future<void> pickTrack(bool isA) async {
    final r = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (r == null) return;
    final p = isA? playerA : playerB;
    await p.setFilePath(r.files.single.path!);
    // AUTO-TRIM: skip 0.35s leading silence
    await p.seek(const Duration(milliseconds: 350));
    setState(() => isA? nameA = r.files.single.name : nameB = r.files.single.name);
  }

  Future<void> addToQueue() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.audio, allowMultiple: true);
    if (r == null) return;
    setState(() => queue.addAll(r.files.map((f) => QueuedTrack(f.path!, f.name))));
  }

  // NEW: Tap queue to play
  Future<void> playFromQueue(int index) async {
    final track = queue[index];
    // Choose idle deck
    final isAPlaying = playerA.playing;
    final isBPlaying = playerB.playing;
    bool useA =!isAPlaying; // if A not playing, use A, else use B

    if (isAPlaying && isBPlaying) {
      // Both playing, replace the quieter one
      useA = crossfade < 0.5? false : true;
    }

    final p = useA? playerA : playerB;
    await p.setFilePath(track.path);
    await p.seek(const Duration(milliseconds: 350)); // auto-trim silence
    await p.play();
    setState(() {
      if (useA) nameA = track.name; else nameB = track.name;
      crossfade = useA? 0.0 : 1.0;
      playerA.setVolume(useA? 1.0 : 0.0);
      playerB.setVolume(useA? 0.0 : 1.0);
    });
  }

  Future<void> _triggerAutoMix() async {
    if (queue.isEmpty) return;
    setState(() => isCrossfading = true);
    final next = queue.removeAt(0);

    // Load next to Deck B
    await playerB.setFilePath(next.path);
    await playerB.seek(const Duration(milliseconds: 350)); // trim silent start
    await playerB.play();
    setState(() => nameB = next.name);

    // 10-second auto crossfade
    for (int i = 0; i <= 100; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      final v = i / 100;
      setState(() => crossfade = v);
      playerA.setVolume(1 - v);
      playerB.setVolume(v);
    }

    // Swap decks: B becomes new A
    final tempPlayer = playerA;
    // Actually just reset A and keep B playing as A
    await playerA.stop();
    // Move B's data to A visually
    setState(() {
      nameA = nameB;
      nameB = null;
      isCrossfading = false;
      crossfade = 0.0;
    });
    // Swap players logic: we keep playing on B but show as A
    // Simpler: keep B as active
    playerA.setVolume(1.0);
    playerB.setVolume(1.0);
  }

  Widget deck(bool isA) {
    final player = isA? playerA : playerB;
    final name = isA? nameA : nameB;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Text('DECK ${isA? 'A' : 'B'} ${isA? (crossfade < 0.5? '(LIVE)' : '') : (crossfade >= 0.5? '(LIVE)' : '')}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            Text(name?? 'No track', style: const TextStyle(color: Colors.white70, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(icon: const Icon(Icons.folder_open), onPressed: () => pickTrack(isA)),
              StreamBuilder<PlayerState>(
                stream: player.playerStateStream,
                builder: (c, snap) {
                  final playing = snap.data?.playing?? false;
                  return IconButton(iconSize: 36, icon: Icon(playing? Icons.pause_circle_filled : Icons.play_circle_fill, color: const Color(0xFFCEBBFF)), onPressed: () => playing? player.pause() : player.play());
                },
              ),
              IconButton(icon: const Icon(Icons.stop), onPressed: () => player.stop()),
            ]),
            StreamBuilder<Duration>(
              stream: player.positionStream,
              builder: (c, snap) {
                final pos = snap.data?? Duration.zero;
                final dur = player.duration?? Duration.zero;
                final max = dur.inMilliseconds.toDouble() > 0? dur.inMilliseconds.toDouble() : 1.0;
                return Column(children: [
                  Slider(value: pos.inMilliseconds.toDouble().clamp(0.0, max), min: 0.0, max: max, activeColor: const Color(0xFFCEBBFF), onChanged: (v) => player.seek(Duration(milliseconds: v.toInt()))),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(_fmt(pos), style: const TextStyle(fontSize: 10)),
                    Text(_fmt(dur), style: const TextStyle(fontSize: 10)),
                  ]),
                ]);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(Duration d) => "${d.inMinutes.remainder(60).toString().padLeft(2,'0')}:${d.inSeconds.remainder(60).toString().padLeft(2,'0')}";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BlendJam'),
        actions: [
          Row(children: [
            const Text('AUTO 10s TRIM', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            Switch(value: autoMix, activeColor: const Color(0xFFCEBBFF), onChanged: (v) => setState(() => autoMix = v)),
            const SizedBox(width: 8),
          ])
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        deck(true),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(children: [
            Row(children: [const Text('A', style: TextStyle(fontSize: 10)), Expanded(child: Slider(value: crossfade, min: 0.0, max: 1.0, onChanged: (v) { setState(() => crossfade = v); playerA.setVolume(1 - v); playerB.setVolume(v); })), const Text('B', style: TextStyle(fontSize: 10))]),
            if (autoMix) const Text('Auto: next track starts 10s before end, silence trimmed', style: TextStyle(fontSize: 9, color: Colors.white54)),
            if (isCrossfading) const LinearProgressIndicator(color: Color(0xFFCEBBFF)),
          ]),
        ),
        deck(false),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('QUEUE (${queue.length}) - Tap to play', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          IconButton(icon: const Icon(Icons.clear_all), onPressed: () => setState(() => queue.clear())),
        ]),
       ...queue.asMap().entries.map((e) => Card(
              color: const Color(0xFF252525),
              child: ListTile(
                dense: true,
                title: Text(e.value.name, style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                leading: Text('${e.key + 1}', style: const TextStyle(fontSize: 10, color: Colors.white54)),
                trailing: IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () => setState(() => queue.removeAt(e.key))),
                onTap: () => playFromQueue(e.key),
              ),
            )),
        const SizedBox(height: 8),
        FilledButton.icon(onPressed: addToQueue, icon: const Icon(Icons.add), label: Text('Add songs (${queue.length})'), style: FilledButton.styleFrom(backgroundColor: const Color(0xFFCEBBFF), foregroundColor: Colors.black)),
        const SizedBox(height: 20),
      ]),
    );
  }
}
