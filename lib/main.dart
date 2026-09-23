import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:audiotags/audiotags.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

void main() => runApp(const BlendJamApp());
class BlendJamApp extends StatelessWidget{const BlendJamApp({super.key});@override Widget build(BuildContext c)=>MaterialApp(debugShowCheckedModeBanner:false,theme:ThemeData.dark().copyWith(scaffoldBackgroundColor:const Color(0xFF121212),cardColor:const Color(0xFF1E1E1E)),home:const DJScreen());}
class QueuedTrack{final String path,name;QueuedTrack(this.path,this.name);}
enum Deck{a,b}

class DJScreen extends StatefulWidget{const DJScreen({super.key});@override State<DJScreen> createState()=>_DJScreenState();}

class _DJScreenState extends State<DJScreen>{
  final a=AudioPlayer(),b=AudioPlayer();
  String? nA,nB; Uint8List? artA,artB;
  double xf=0; bool auto=false,xing=false; Deck live=Deck.a;
  List<QueuedTrack> q=[]; int qPos=0; bool armed=false;
  StreamSubscription<Duration>? sA,sB;

  AudioPlayer p(Deck d)=>d==Deck.a?a:b;
  Deck o(Deck d)=>d==Deck.a?Deck.b:Deck.a;
  String? nm(Deck d)=>d==Deck.a?nA:nB;
  Uint8List? art(Deck d)=>d==Deck.a?artA:artB;
  void setNm(Deck d,String? v){if(d==Deck.a)nA=v;else nB=v;}
  void setArt(Deck d,Uint8List? v){if(d==Deck.a)artA=v;else artB=v;}

  @override void initState(){super.initState(); sA=a.positionStream.listen((pos)=>_check(Deck.a,pos)); sB=b.positionStream.listen((pos)=>_check(Deck.b,pos));}
  @override void dispose(){sA?.cancel();sB?.cancel();a.dispose();b.dispose();super.dispose();}

  QueuedTrack? _nextLoop(){if(q.isEmpty) return null; final t=q[qPos%q.length]; qPos=(qPos+1)%q.length; return t;}

  Future<Uint8List?> _readArt(String path) async{
    try{
      final tag=await AudioTags.read(path);
      if(tag!=null && tag.pictures.isNotEmpty){
        return tag.pictures.first.bytes; // FIXED: was imageData
      }
    }catch(_){}
    return null;
  }

  Future<void> _load(Deck d,QueuedTrack t,{bool play=false}) async{
    setNm(d,t.name); setArt(d,null); if(mounted) setState((){});
    final pl=p(d); await pl.stop(); await pl.setFilePath(t.path); await pl.seek(const Duration(milliseconds:200));
    _readArt(t.path).then((bytes){ setArt(d,bytes); if(mounted) setState((){}); });
    await pl.setVolume(play?1.0:0.0); await pl.setSpeed(1.0);
    if(play){live=d; xf=d==Deck.a?0:1; await pl.play();} if(mounted) setState((){});
  }

  Future<void> _autoStart() async{
    if(q.isEmpty) return;
    if(nm(live)==null){ await _load(live,_nextLoop()!,play:true); }
    if(nm(o(live))==null && q.isNotEmpty){ await _load(o(live),_nextLoop()!); }
  }
  void _check(Deck d,Duration pos){
    if(xing || armed) return; if(d!=live) return;
    final dur=p(d).duration; if(dur==null ||!p(d).playing) return;
    final rem=dur-pos;
    if(auto && rem.inSeconds==15){ final free=o(live); if(nm(free)==null) _load(free,_nextLoop()!); }
    if(rem.inSeconds<=10 && rem.inSeconds>=9){ final both=nm(Deck.a)!=null && nm(Deck.b)!=null; if(both){ armed=true; _startFade(); } }
  }
  void _startFade(){
    if(xing) return; final src=live,tgt=o(src); if(nm(tgt)==null){ armed=false; return; }
    xing=true; final srcP=p(src),tgtP=p(tgt); tgtP.setVolume(0); tgtP.setSpeed(1.0
