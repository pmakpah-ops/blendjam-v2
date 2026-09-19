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
    final r = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (r == null) return;
    final p = isA ? playerA : playerB;
    await p.setFilePath(r.files.single.path!);
    setState(() { isA ? nameA = r.files.single.name : nameB = r.files.single.name; });
  }

  Future<void> addToQueue() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.audio, allowMultiple: true);
    if (r == null) return;
    setState(() => queue.addAll(r.files));
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
                final max = dur.inMilliseconds.toDouble() > 0 ? dur.inMilliseconds.toDouble() : 1.0;
                return Column(children: [
                  Slider(value: pos.inMilliseconds.toDouble().clamp(0.0, max), min: 0.0, max: max, onChanged: (v) => player.seek(Duration(milliseconds: v.toInt()))),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(_fmt(pos), style: const TextStyle(fontSize: 11)),
                    Text(_fmt(dur), style: const TextStyle(fontSize: 11)),
                  ]),
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
        const Text('Auto'), Switch(value: autoMix, onChanged: (v)=>setState(()=>autoMix=v)), const SizedBox(width:12),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        deck(true),
        Row(children: [const Text('A'), Expanded(child: Slider(value: crossfade, min: 0.0, max: 1.0, onChanged: (v){setState(()=>crossfade=v); playerA.setVolume(1-v); playerB.setVolume(v);})), const Text('B')]),
        deck(false),
        const SizedBox(height:12),
        if(queue.isNotEmpty) Text('Queue (${queue.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
        ...queue.map((f) => ListTile(dense:true, title: Text(f.name, style: const TextStyle(fontSize:12), overflow: TextOverflow.ellipsis), trailing: IconButton(icon: const Icon(Icons.close, size:16), onPressed: ()=>setState(()=>queue.remove(f))))),
        const SizedBox(height:8),
        OutlinedButton.icon(onPressed: addToQueue, icon: const Icon(Icons.add), label: Text('Add songs to queue (${queue.length})')),
      ]),
    );
  }
}
