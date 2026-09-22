import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

void main() => runApp(const BlendJamApp());
class BlendJamApp extends StatelessWidget{
  const BlendJamApp({super.key});
  @override Widget build(BuildContext c)=>MaterialApp(debugShowCheckedModeBanner:false,theme:ThemeData.dark().copyWith(scaffoldBackgroundColor:const Color(0xFF121212),cardColor:const Color(0xFF1E1E1E)),home:const DJScreen());
}
class QueuedTrack{final String path,name;QueuedTrack(this.path,this.name);}
enum Deck{a,b}

class DJScreen extends StatefulWidget{const DJScreen({super.key});@override State<DJScreen> createState()=>_DJScreenState();}

class _DJScreenState extends State<DJScreen>{
  final a=AudioPlayer(),b=AudioPlayer();
  String? nA,nB; double xf=0; bool auto=false,xing=false; Deck live=Deck.a;
  List<QueuedTrack> q=[]; int qPos=0;
  StreamSubscription<Duration>? sA,sB;

  AudioPlayer p(Deck d)=>d==Deck.a?a:b;
  Deck o(Deck d)=>d==Deck.a?Deck.b:Deck.a;
  String? nm(Deck d)=>d==Deck.a?nA:nB;
  void setNm(Deck d,String? v){if(d==Deck.a)nA=v;else nB=v;}

  @override void initState(){super.initState(); sA=a.positionStream.listen((x)=>_chk(Deck.a,x)); sB=b.positionStream.listen((x)=>_chk(Deck.b,x));}
  @override void dispose(){sA?.cancel();sB?.cancel();a.dispose();b.dispose();super.dispose();}

  QueuedTrack? _next(){if(q.isEmpty)return null; final t=q[qPos%q.length]; qPos=(qPos+1)%q.length; return t;}

  Future<void> _loadNameFirst(Deck d,QueuedTrack t,{bool play=false}) async{
    setNm(d,t.name); if(mounted) setState((){});
    final pl=p(d); await pl.stop(); await pl.setFilePath(t.path);
    await pl.seek(const Duration(milliseconds:150));
    await pl.setVolume(d==live?1:0);
    if(play){live=d; xf=d==Deck.a?0:1; await pl.setVolume(1); await pl.play();}
    if(mounted) setState((){});
  }

  Future<void> _autoStart() async{
    if(!auto) return;
    if(nm(live)==null && q.isNotEmpty){ await _loadNameFirst(live,_next()!,play:true); }
    final free=o(live); if(nm(free)==null && q.isNotEmpty){ await _loadNameFirst(free,_next()!); }
  }

  void _chk(Deck d,Duration pos){
    if(d!=live || xing) return;
    final dur=p(d).duration; if(dur==null) return;
    final rem=dur-pos;
    if(!p(d).playing) return;

    // 15s preload in AUTO only
    if(auto && rem.inSeconds==15){
      final free=o(live); if(nm(free)==null && q.isNotEmpty) _loadNameFirst(free,_next()!);
    }
    // 10s -> FORCE CROSSFADER TO MOVE
    if(rem.inSeconds==10){
      final both=nm(Deck.a)!=null && nm(Deck.b)!=null;
      if(both) _mix();
    }
  }

  Future<void> _mix() async{
    if(xing) return;
    if(nm(o(live))==null){ if(auto && q.isNotEmpty) await _loadNameFirst(o(live),_next()!); else return; }

    final src=live,tgt=o(live),srcP=p(src),tgtP=p(tgt);
    xing=true; setState((){});

    // ensure next deck is playing at 0 volume
    tgtP.setVolume(0); if(!tgtP.playing) await tgtP.play();

    // THIS IS THE COMMAND THAT MOVES THE SLIDER
    if(src==Deck.a){
      for(double v=0; v<=1.0; v+=0.05){
        xf=v;
        srcP.setVolume(1-v); tgtP.setVolume(v);
        setState((){});
        await Future.delayed(const Duration(milliseconds:250)); // 5 sec fade
      }
      xf=1.0;
    }else{
      for(double v=1.0; v>=0; v-=0.05){
        xf=v;
        srcP.setVolume(1-v); tgtP.setVolume(v);
        setState((){});
        await Future.delayed(const Duration(milliseconds:250));
      }
      xf=0.0;
    }

    await srcP.stop(); setNm(src,null); live=tgt; xing=false; setState((){});
    if(auto && q.isNotEmpty && nm(o(live))==null){ await _loadNameFirst(o(live),_next()!); }
  }

  Future<void> pick(bool isA) async{
    final r=await FilePicker.platform.pickFiles(type:FileType.audio); if(r?.files.single.path==null) return;
    final tgt= p(live).playing? o(live) : (isA?Deck.a:Deck.b);
    await _loadNameFirst(tgt,QueuedTrack(r!.files.single.path!,r.files.single.name));
  }

  Future<void> addQ() async{
    final r=await FilePicker.platform.pickFiles(type:FileType.audio,allowMultiple:true); if(r==null) return;
    setState(()=>q.addAll(r.files.where((f)=>f.path!=null).map((f)=>QueuedTrack(f.path!,f.name))));
  }

  Widget deck(bool isA){
    final d=isA?Deck.a:Deck.b,pl=p(d),isLive=live==d;
    return Card(shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16)),child:Padding(padding:const EdgeInsets.all(14),child:Column(children:[
      Text('DECK ${isA?'A':'B'} ${isLive?'(LIVE)':'(NEXT)'} ${xing&&isLive?' MIXING':''}',style:TextStyle(fontWeight:FontWeight.bold,fontSize:12,color:isLive?const Color(0xFFCEBBFF):Colors.white70)),
      Text(nm(d)??'No track',style:const TextStyle(color:Colors.white70,fontSize:12),maxLines:1,overflow:TextOverflow.ellipsis),
      Row(mainAxisAlignment:MainAxisAlignment.center,children:[
        IconButton(icon:const Icon(Icons.folder_open),onPressed:()=>pick(isA)),
        StreamBuilder<PlayerState>(stream:pl.playerStateStream,builder:(_,s){return IconButton(iconSize:36,icon:Icon(s.data?.playing==true?Icons.pause_circle_filled:Icons.play_circle_fill,color:const Color(0xFFCEBBFF)),onPressed:()async{if(pl.playing){await pl.pause();}else{if(nm(d)==null&&q.isNotEmpty){await _loadNameFirst(d,q[qPos%q.length],play:true); qPos++;}else{live=d; xf=d==Deck.a?0:1; pl.setVolume(1); p(o(d)).setVolume(0); await pl.play();} setState((){});}});}),
        IconButton(icon:const Icon(Icons.stop),onPressed:()async{await pl.stop(); pl.setVolume(0); setState((){});}),
      ]),
      StreamBuilder<Duration>(stream:pl.positionStream,builder:(_,s){
        final pos=s.data??Duration.zero,dur=pl.duration??Duration.zero,max=dur.inMilliseconds>0?dur.inMilliseconds.toDouble():1.0,cur=pos.inMilliseconds.toDouble().clamp(0.0,max);
        String fmt(Duration d)=>'${d.inMinutes.remainder(60).toString().padLeft(2,'0')}:${d.inSeconds.remainder(60).toString().padLeft(2,'0')}';
        return Column(children:[Slider(value:cur,min:0,max:max,activeColor:const Color(0xFFCEBBFF),onChanged:(v)=>pl.seek(Duration(milliseconds:v.toInt()))),Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text(fmt(pos),style:const TextStyle(fontSize:10)),Text(fmt(dur),style:const TextStyle(fontSize:10))])]);
      }),
    ])));
  }

  @override Widget build(BuildContext c)=>Scaffold(
    appBar:AppBar(title:const Text('BlendJam'),actions:[Row(children:[const Text('AUTO MIX',style:TextStyle(fontSize:10,fontWeight:FontWeight.bold)),Switch(value:auto,activeColor:const Color(0xFFCEBBFF),onChanged:(v)async{setState(()=>auto=v); if(v) await _autoStart();}),const SizedBox(width:8)])]),
    body:ListView(padding:const EdgeInsets.all(12),children:[
      deck(true),
      Padding(padding:const EdgeInsets.all(8),child:Column(children:[
        Row(children:[const Text('A',style:TextStyle(fontSize:10)),Expanded(child:Slider(value:xf,min:0,max:1,activeColor:const Color(0xFFCEBBFF),onChanged:(v){xf=v; a.setVolume(1-v); b.setVolume(v); if(v>=0.5&&nm(Deck.b)!=null)live=Deck.b; if(v<0.5&&nm(Deck.a)!=null)live=Deck.a; setState((){});})),const Text('B',style:TextStyle(fontSize:10))]),
        Text(xing? 'CROSSFADING ${live==Deck.a?'A->B':'B->A'} - ${xf.toStringAsFixed(2)}' : 'Crossfader at ${xf.toStringAsFixed(2)}',style:const TextStyle(fontSize:9,color:Colors.white54)),
      ])),
      deck(false),
      Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text('QUEUE (${q.length})',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:12)),IconButton(icon:const Icon(Icons.add),onPressed:addQ)]),
     ...List.generate(q.length,(i)=>ListTile(dense:true,title:Text(q[i].name,style:const TextStyle(fontSize:12),maxLines:1,overflow:TextOverflow.ellipsis),onTap:()async{final tgt=p(live).playing?o(live):(nm(live)==null?live:o(live)); await _loadNameFirst(tgt,q[i]); qPos=(i+1)%q.length;})),
      const SizedBox(height:80),
    ]),
  );
}
