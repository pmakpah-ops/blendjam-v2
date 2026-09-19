import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:file_picker/file_picker.dart';

void main() => runApp(const BlendJamApp());

class BlendJamApp extends StatelessWidget {
  const BlendJamApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BlendJam',
      theme: ThemeData.dark(useMaterial3: true),
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
  double crossfade = 0.5;
  String? trackA, trackB;

  Future<void> pickTrack(bool isA) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result != null) {
      final path = result.files.single.path!;
      if (isA) {
        trackA = path;
        await playerA.setFilePath(path);
        await playerA.setLoopMode(LoopMode.all);
        await playerA.play();
      } else {
        trackB = path;
        await playerB.setFilePath(path);
        await playerB.setLoopMode(LoopMode.all);
        await playerB.play();
      }
      setState(() {});
      playerA.setVolume(1.0 - crossfade);
      playerB.setVolume(crossfade);
    }
  }

  @override
  void dispose() {
    playerA.dispose();
    playerB.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BlendJam V2')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: ElevatedButton(onPressed: () => pickTrack(true), child: Text(trackA == null ? 'Load A' : 'A OK'))),
                const SizedBox(width: 10),
                Expanded(child: ElevatedButton(onPressed: () => pickTrack(false), child: Text(trackB == null ? 'Load B' : 'B OK'))),
              ],
            ),
            const SizedBox(height: 30),
            Slider(value: crossfade, onChanged: (v) { setState(() => crossfade = v); playerA.setVolume(1.0 - v); playerB.setVolume(v); }),
            Text('Mix: ${(crossfade*100).toInt()}% B'),
          ],
        ),
      ),
    );
  }
}
