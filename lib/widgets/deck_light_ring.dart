import 'package:flutter/material.dart';
import 'dart:math';

class DeckLightRing extends StatefulWidget {
  final bool isPlaying;
  final bool isLive;
  final double audioLevel;
  final Widget child;
  final double size;
  const DeckLightRing({super.key, required this.isPlaying, required this.isLive, this.audioLevel = 0, required this.child, this.size = 210});
  @override
  State<DeckLightRing> createState() => _DeckLightRingState();
}

class _DeckLightRingState extends State<DeckLightRing> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(); }
  @override
  void dispose(){ _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    if (!widget.isPlaying) {
      return Container(width: widget.size, height: widget.size, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade900, width: 6)), child: Center(child: widget.child));
    }
    return AnimatedBuilder(animation: _ctrl, builder: (_, __) {
      double t = _ctrl.value; double level = widget.audioLevel.clamp(0,1);
      Color c1 = Color.lerp(Colors.redAccent, Colors.greenAccent, (sin(t*2*pi)+1)/2)!;
      Color c2 = Color.lerp(Colors.greenAccent, Colors.cyanAccent, (cos(t*2*pi)+1)/2)!;
      Color c3 = Color.lerp(Colors.blueAccent, Colors.redAccent, (sin(t*pi)+1)/2)!;
      return Container(width: widget.size, height: widget.size, decoration: BoxDecoration(shape: BoxShape.circle, gradient: SweepGradient(colors: [c1,c2,c3,c1])), child: Padding(padding: EdgeInsets.all(5 + level*3), child: Container(decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black, boxShadow: widget.isLive ? [BoxShadow(color: c2.withOpacity(0.5 + level*0.5), blurRadius: 12 + level*18)] : []), child: Center(child: widget.child))));
    });
  }
}
