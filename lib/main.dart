import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart'; // <- FIXED: removed _new

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
  List<String> queuePaths = []; List<String> queueNames = [];
  bool autoMix = false; int autoMixIndex = -1;
  bool isBlending = false; Timer? blendTimer;
  Map<String, double> silenceMap = {};

  @override
  void initState() {
    super.initState();
    playerA = AudioPlayer(); playerB = AudioPlayer();
    updateVol();
    blendTimer = Timer.periodic(const Duration(milliseconds: 500), (_) => checkBlend());
  }

  @override void dispose() { blendTimer?.cancel(); playerA.dispose(); playerB.dispose(); super.dispose(); }

  void updateVol() {
    double a = (1 - cross).clamp(0.0, 1.0);
    double b = cross.clamp(0.0, 1.0);
    playerA.setVolume(a); playerB.setVolume(b);
  }

  Future<double> detectTrailingSilence(String path) async {
    try {
      final session = await FFmpegKit.execute(
        '-i "$path" -af silencedetect=noise=-60dB:d=1 -f null -'
      );
      final logs = await session.getAllLogsAsString(); // <- This still works in v6.0.3
      if (logs ==
