import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';

void main() => runApp(const BlendJamApp());

class BlendJamApp extends StatelessWidget {
  const BlendJamApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'BlendJam', debugShowCheckedModeBanner: false, theme: ThemeData.dark(), home: const DJPage());
  }
}

class DJPage extends StatefulWidget {
  const DJPage({super.key});
  @override State<DJPage> createState() => DJState();
}

class MiniBars extends StatefulWidget {
  final AudioPlayer player;
  const MiniBars({super.key, required this.player});
  @override State<MiniBars> createState() => _MiniBarsState();
}

class _MiniBarsState extends State<MiniBars> {
  late Timer t;
  final Random rnd = Random();
  List<double> heights = List.filled(24, 4.0);
  @override
  void initState() {
    super.initState();
    t = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (!mounted) return;
      if (!widget.player.playing) return;
      setState(() {
        for (int i=0;i<heights.length;i++) {
          heights[i] = 4 + rnd.nextDouble() * 28;
        }
      });
    });
  }
  @override void dispose(){ t.cancel(); super.dispose(); }
  @override Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: heights.map((h) => Container(
          width: 4, height: h,
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          decoration: BoxDecoration(color: Colors.purpleAccent, borderRadius: BorderRadius.circular(2)),
        )).toList(),
      ),
    );
  }
}

class DJState extends State<DJPage> {
  late AudioPlayer playerA; late AudioPlayer playerB;
  String? nameA; String? nameB;
  double cross = 0.0;
  bool isBlending = false;

  @override
  void initState() {
    super.initState();
    playerA = AudioPlayer(); playerB = AudioPlayer();
    updateVol();
  }
  @override void dispose() { playerA.dispose(); playerB.dispose(); super.dispose(); }

  void updateVol() {
    playerA.setVolume((1 - cross).clamp(0.0, 1.0));
    playerB.setVolume(cross.clamp(0.0, 1.0));
  }

  Future<void> pickFile(bool isA) async {
    var result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result == null) return;
    String path = result.files.single.path!;
    String name = result.files.single.name;
    if (isA) {
      await playerA.setFilePath(path);
      setState(() => nameA = name);
    } else {
      await playerB.setFilePath(path);
      setState(() => nameB = name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BlendJam DJ Mixer')),
      body: Column(
        children: [
          Expanded(child: Row(children: [
            Expanded(child: Column(children: [
              Text(nameA?? 'Deck A'), MiniBars(player: playerA),
              ElevatedButton(onPressed: () => pickFile(true), child: const Text('Load A')),
              ElevatedButton(onPressed: () => playerA.play(), child: const Text('Play A')),
            ])),
            Expanded(child: Column(children: [
              Text(nameB?? 'Deck B'), MiniBars(player: playerB),
              ElevatedButton(onPressed: () => pickFile(false), child: const Text('Load B')),
              ElevatedButton(onPressed: () => playerB.play(), child: const Text('Play B')),
            ])),
          ])),
          Slider(value: cross, onChanged: (v){ setState(()=> cross=v); updateVol(); }),
          const Padding(padding: EdgeInsets.all(8), child: Text('Crossfader')),
        ],
      ),
    );
  }
}
