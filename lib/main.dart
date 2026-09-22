import 'dart:async';
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
  String? nA,nB; double xf=0; bool auto=false,xing=false; Deck live=Deck.a;
  List<QueuedTrack> q=[]; int qPos=0; bool armed=false;
  StreamSubscription<Duration>? sA,sB;

  AudioPlayer p(Deck d)=>d==Deck.a?a:b;
  Deck o(Deck d)=>d==Deck.a?Deck.b:Deck.a;
  String? nm(Deck d)=>d==Deck.a?nA:nB;
  void setNm(Deck d,String? v){if(d==Deck.a)nA=v;else nB=v;}

  @override void initState(){super.initState(); sA=a.positionStream.listen((pos)=>_check(Deck.a,pos)); sB=b.positionStream.listen((pos)=>_check(Deck.b,pos));}
  @override void dispose(){sA?.cancel();sB?.cancel();a.dispose();b.dispose();super.dispose();}

  QueuedTrack? _nextLoop(){
    if(q.isEmpty) return null;
    final t=q[qPos % q.length]; qPos=(qPos+1)%q.length; return t;
  }

  Future<void> _load(Deck d,QueuedTrack t,{bool play=false}) async{
    setNm(d,t.name); if(mounted) setState((){});
    final pl=p(d); await pl.stop(); await pl.setFilePath(t.path);
    await pl.seek(const Duration(milliseconds:200));
    await pl.setVolume(play?1.0:0.0);
    if(play){live=d; xf=d==Deck.a?0:1; await pl.play();}
    if(mounted) setState((){});
  }

  Future<void> _autoStart() async{
    if(q.isEmpty) return;
    if(nm(live)==null){ await _load(live,_nextLoop()!,play:true); }
    if(nm(o(live))==null){ await _load(o(live),_nextLoop()!); }
  }

  void _check(Deck d,Duration pos){
    if(!auto || xing || armed) return;
    if(d!=live) return;
    final dur=p(d).duration; if(dur==null) return;
    if(!p(d).playing) return;
    final rem=dur-pos;
    if(rem.inSeconds==15){ final free=o(live); if(nm(free)==null) _load(free,_nextLoop()!); }
    if(rem.inSeconds<=10 && rem.inSeconds>=9){
      armed=true; _startFade();
    }
  }

  void _startFade(){
    if(xing) return;
    final src=live,tgt=o(src);
    if(nm(tgt)==null){ armed=false; return; }
    xing=true;
    final srcP=p(src),tgtP=p(tgt);
    tgtP.setVolume(0); tgtP.play();

    int tick=0;
    Timer.periodic(const Duration(milliseconds:100), (timer) async{
      tick++;
      double v=tick/50; // 5 seconds fade
      if(v>1) v=1;
      // FORCE SLIDER TO MOVE FIRST
      if(src==Deck.a){ xf=v; } else { xf=1-v; }
      // volume follows slider, no await
      srcP.setVolume(1-xf); tgtP.setVolume(xf);
      if(mounted) setState((){});
      if(tick>=50){
        timer.cancel();
        xf=src==Deck.a?1.0:0.0;
        srcP.setVolume(0); tgtP.setVolume(1);
        await srcP.stop(); setNm(src,null);
        live=tgt; xing=false; armed=false;
        if(mounted) setState((){});
        if(auto && nm(o(live))==null && q.isNotEmpty){ _load(o(live),_nextLoop()!); }
      }
    });
  }

  Future<void> pick(bool isA) async{
    final r=await FilePicker.platform.pickFiles(type:FileType.audio); if(r?.files.single.path==null) return;
    final tgt=p(live).playing?o(live):(isA?Deck.a:Deck.b);
    await _load(tgt,QueuedTrack(r!.files.single.path!,r.files.single.name));
  }
  Future<void> addQ() async{
    final r=await FilePicker.platform.pickFiles(type:FileType.audio,allowMultiple:true); if(r==null) return;
    setState(()=>q.addAll(r.files.where((f)=>f.path!=null).map((f)=>QueuedTrack(f.path!,f.name))));
  }

  Widget deck(bool isA){
    final d=isA?Deck.a:Deck.b; final pl=p(d); final isLive=live==d;
    return Card(shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16)),child:Padding(padding:const EdgeInsets.all(14),child:Column(children:[
      Text('DECK ${isA?'A':'B'} ${isLive?'(LIVE)':'(NEXT)'}',style:TextStyle(fontWeight:FontWeight.bold,fontSize:12,color:isLive?const Color(0xFFCEBBFF):Colors.white70)),
      Text(nm(d)??'No track',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Colors.white70,fontSize:12)),
      Row(mainAxisAlignment:MainAxisAlignment.center,children:[
        IconButton(icon:const Icon(Icons.folder_open),onPressed:()=>pick(isA)),
        StreamBuilder<PlayerState>(stream:pl.playerStateStream,builder:(c,s)=>IconButton(iconSize:36,icon:Icon(s.data?.playing==true?Icons.pause_circle_filled:Icons.play_circle_fill,color:const Color(0xFFCEBBFF)),onPressed:()async{if(pl.playing){await pl.pause();}else{if(nm(d)==null&&q.isNotEmpty){await _load(d,_nextLoop()!,play:true);}else{live=d; xf=d==Deck.a?0:1; pl.setVolume(1); p(o(d)).setVolume(0); await pl.play();} setState((){});}})),
        IconButton(icon:const Icon(Icons.stop),onPressed:()async{await pl.stop(); pl.setVolume(0); setState((){});}),
      ]),
      StreamBuilder<Duration>(stream:pl.positionStream,builder:(c,s){
        final pos=s.data??Duration.zero; final dur=pl.duration??Duration.zero; final max=dur.inMilliseconds>0?dur.inMilliseconds.toDouble():1.0; final cur=pos.inMilliseconds.toDouble().clamp(0.0,max);
        String fmt(Duration d)=>'${d.inMinutes.remainder(60).toString().padLeft(2,'0')}:${d.inSeconds.remainder(60).toString().padLeft(2,'0')}';
        return Column(children:[Slider(value:cur,min:0,max:max,activeColor:const Color(0xFFCEBBFF),onChanged:(v)=>pl.seek(Duration(milliseconds:v.toInt()))),Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text(fmt(pos),style:const TextStyle(fontSize:10)),Text(fmt(dur),style:const TextStyle(fontSize:10))])]);
      }),
    ])));
  }

  @override Widget build(BuildContext context){
    return Scaffold(
      appBar:AppBar(title:const Text('BlendJam'),actions:[Row(children:[const Text('AUTO MIX',style:TextStyle(fontSize:10,fontWeight:FontWeight.bold)),Switch(value:auto,activeColor:const Color(0xFFCEBBFF),onChanged:(v)async{setState(()=>auto=v); if(v) await _autoStart();}),const SizedBox(width:8)])]),
      body:ListView(padding:const EdgeInsets.all(12),children:[
        deck(true),
        Padding(padding:const EdgeInsets.all(8),child:Column(children:[
          Row(children:[const Text('A',style:TextStyle(fontSize:10)),Expanded(child:Slider(value:xf,min:0,max:1,activeColor:const Color(0xFFCEBBFF),onChanged:(v){ if(xing) return; xf=v; a.setVolume(1-v); b.setVolume(v); if(v>=0.5&&nm(Deck.b)!=null) live=Deck.b; if(v<0.5&&nm(Deck.a)!=null) live=Deck.a; setState((){}); })),const Text('B',style:TextStyle(fontSize:10))]),
          Text(xing?'FADING ${xf.toStringAsFixed(2)}':'xf $xf',style:const TextStyle(fontSize:10,color:Colors.white54)),
        ])),
        deck(false),
        const SizedBox(height:12),
        Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text('QUEUE (${q.length}) loops',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:12)),IconButton(icon:const Icon(Icons.add),onPressed:addQ)]),
       ...List.generate(q.length,(i)=>ListTile(dense:true,title:Text(q[i].name,style:const TextStyle(fontSize:12),maxLines:1,overflow:TextOverflow.ellipsis),onTap:()async{final tgt=p(live).playing?o(live):(nm(live)==null?live:o(live)); await _load(tgt,q[i]);})),
        const SizedBox(height:80),
      ]),
    );
  }
}
