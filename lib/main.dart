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
        colorScheme: const ColorScheme.dark(primary: Color(0xFFCEBBFF)),
      ),
      home: const DJScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
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
  double crossfade = 0.5;
  bool autoMix = false;

  Future<void> pickTrack(bool isA) async {
    final r = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (r == null) return;
    final path = r.files.single.path!;
    final name = r.files.single.name;
    final p = isA ? playerA : playerB;
    await p.setFilePath(path);
    setState(() { isA ? nameA = name : nameB = name; });
  }

  Widget deck(bool isA) {
    final player = isA ? playerA : playerB;
    final name = isA ? nameA : nameB;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('DECK ${isA ? 'A' : 'B'}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(name ?? 'No track', style: const TextStyle(color: Colors.white70), overflow: TextOverflow.ellipsis),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(icon: const Icon(Icons.folder_outlined), onPressed: () => pickTrack(isA)),
              StreamBuilder<PlayerState>(
                stream: player.playerStateStream,
                builder: (c, snap) {
                  final playing = snap.data?.playing ?? false;
                  return IconButton(
                    iconSize: 32,
                    icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                    onPressed: () { playing ? player.pause() : player.play(); },
                  );
                },
              ),
            ]),
            StreamBuilder<Duration>(
              stream: player.positionStream,
              builder: (c, snap) {
                final pos = snap.data ?? Duration.zero;
                final dur = player.duration ?? Duration.zero;
                final max = dur.inMilliseconds > 0 ? dur.inMilliseconds.toDouble() : 1.0;
                return Column(children: [
                  Slider(value: pos.inMilliseconds.clamp(0, max.toInt()).toDouble(), min: 0, max: max, onChanged: (v) => player.seek(Duration(milliseconds: v.toInt()))),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(_fmt(pos), style: const TextStyle(fontSize: 11)),
                    Text(_fmt(dur), style: const TextStyle(fontSize: 11)),
                  ]),
                ]);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(Duration d) => "${d.inMinutes.remainder(60).toString().padLeft(2,'0')}:${(d.inSeconds.remainder(60)).toString().padLeft(2,'0')}";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BlendJam'), actions: [
        const Icon(Icons.queue_music), const SizedBox(width:4),
        const Text('Auto'), Switch(value: autoMix, onChanged: (v) => setState(()=>autoMix=v)), const SizedBox(width:12),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        deck(true),
        Row(children: [const Text('A'), Expanded(child: Slider(value: crossfade, onChanged: (v){setState(()=>crossfade=v); playerA.setVolume(1-v); playerB.setVolume(v);})), const Text('B')]),
        deck(false),
        const SizedBox(height:20),
        OutlinedButton.icon(onPressed: ()=>pickTrack(false), icon: const Icon(Icons.add), label: const Text('Add songs to queue')),
      ]),
    );
  }
}
