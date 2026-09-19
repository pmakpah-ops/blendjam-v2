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
        sliderTheme: const SliderThemeData(
          activeTrackColor: Color(0xFFCEBBFF),
          inactiveTrackColor: Color(0x33FFFFFF),
          thumbColor: Color(0xFFCEBBFF),
          trackHeight: 4,
          overlayShape: RoundSliderOverlayShape(overlayRadius: 18),
        ),
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
  List<PlatformFile> queue = [];
  RangeValues trimA = const RangeValues(0, 1);
  RangeValues trimB = const RangeValues(0, 1);

  Future<void> pickTrack(bool isA) async {
    final r = await FilePicker.platform.pickFiles(type: FileType.audio, allowMultiple: false);
    if (r == null) return;
    final path = r.files.single.path!;
    final name = r.files.single.name;
    final p = isA ? playerA : playerB;
    await p.setFilePath(path);
    setState(() { isA ? nameA = name : nameB = name; });
  }

  Future<void> addToQueue() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.audio, allowMultiple: true);
    if (r == null) return;
    setState(() => queue.addAll(r.files));
    if (autoMix && nameA == null && queue.isNotEmpty) {
      final f = queue.removeAt(0);
      await playerA.setFilePath(f.path!);
      setState(() => nameA = f.name);
      playerA.play();
    }
  }

  void playNextAuto() {
    if (!autoMix || queue.isEmpty) return;
    // Simple auto-mix: when A finishes, play next on B and crossfade
    playerA.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed) {
        final next = queue.removeAt(0);
        playerB.setFilePath(next.path!).then((_) {
          setState(() { nameB = next.name; crossfade = 1.0; });
          playerB.setVolume(1); playerA.setVolume(0);
          playerB.play();
        });
      }
    });
  }

  Widget deck(bool isA) {
    final player = isA ? playerA : playerB;
    final name = isA ? nameA : nameB;
    final trim = isA ? trimA : trimB;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('DECK ${isA ? 'A' : 'B'}', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(name ?? 'No track', style: const TextStyle(color: Colors.white70, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(icon: const Icon(Icons.folder_outlined), onPressed: () => pickTrack(isA)),
              StreamBuilder<PlayerState>(
                stream: player.playerStateStream,
                builder: (c, snap) {
                  final playing = snap.data?.playing ?? false;
                  return IconButton(iconSize: 34, icon: Icon(playing ? Icons.pause : Icons.play_arrow), onPressed: () => playing ? player.pause() : player.play());
                },
              ),
            ]),
            StreamBuilder<Duration>(
              stream: player.positionStream,
              builder: (c, snap) {
                final pos = snap.data ?? Duration.zero;
                final dur = player.duration ?? Duration.zero;
                final max = dur.inMilliseconds.toDouble() > 0 ? dur.inMilliseconds.toDouble() : 1;
                return Column(children: [
                  Slider(value: pos.inMilliseconds.clamp(0, max.toInt()).toDouble(), min: 0, max: max, onChanged: (v) => player.seek(Duration(milliseconds: v.toInt()))),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(_fmt(pos), style: const TextStyle(fontSize: 11)),
                    Text(_fmt(dur), style: const TextStyle(fontSize: 11)),
                  ]),
                  const SizedBox(height: 6),
                  Row(children: [
                    const Text('Trim', style: TextStyle(fontSize: 10)),
                    Expanded(child: RangeSlider(values: trim, min: 0, max: 1, onChanged: (v) => setState(() => isA ? trimA = v : trimB = v))),
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
        const Text('Auto'), Switch(value: autoMix, onChanged: (v){setState(()=>autoMix=v); if(v) playNextAuto();}), const SizedBox(width:12),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        deck(true),
        Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [const Text('A'), Expanded(child: Slider(value: crossfade, onChanged: (v){setState(()=>crossfade=v); playerA.setVolume(1-v); playerB.setVolume(v);})), const Text('B')])),
        deck(false),
        const SizedBox(height: 12),
        if (queue.isNotEmpty) ...[
          Text('Queue (${queue.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
          ...queue.map((f) => ListTile(dense: true, title: Text(f.name, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis), trailing: IconButton(icon: const Icon(Icons.close, size: 16), onPressed: ()=>setState(()=>queue.remove(f))))),
          const SizedBox(height: 8),
        ],
        OutlinedButton.icon(onPressed: addToQueue, icon: const Icon(Icons.add), label: Text('Add songs to queue (${queue.length})')),
      ]),
    );
  }
}
