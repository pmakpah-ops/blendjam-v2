import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

void main() => runApp(const BlendJamApp());
class BlendJamApp extends StatelessWidget {
  const BlendJamApp({super.key});
  @override Widget build(BuildContext c) => MaterialApp(debugShowCheckedModeBanner:false,theme:ThemeData.dark().copyWith(scaffoldBackgroundColor:const Color(0xFF121212),cardColor:const Color(0xFF1E1E1E)),home:const DJScreen());
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
  void setNm(Deck d,String? v){ if(d==Deck.a) nA=v; else nB=v; }

  @override void initState(){
    super.initState();
    sA=a.positionStream.listen((x)=>_chk(Deck.a,x));
    sB=b.positionStream.listen((x)=>_chk(Deck.b,x));
  }
  @override void dispose(){sA?.cancel();sB?.cancel();a.dispose();b.dispose();super.dispose();}

  QueuedTrack? _next(){
    if(q.isEmpty) return null;
    final t=q[qPos % q.length]; qPos=(qPos+1)%q.length; return t;
  }

  Future<void> _autoStart() async{
    if(!auto) return;
    if(nm(live)==null && q.isNotEmpty){
      final t=_next(); if(t!=null){
        // FIX 1: set name BEFORE play so it doesn't say No track
        setNm(live,t.name); setState((){});
        final pl=p(live); await pl.stop(); await pl.setFilePath(t.path);
        await pl.seek(const Duration(milliseconds:200));
        await pl.setVolume(1); xf=live==Deck.a?0:1;
        await pl.play(); setState((){});
      }
    }else if(!p(live).playing && nm(live)!=null){
      await p(live).setVolume(1); await p(live).play();
    }
    // preload free deck for auto
    final free=o(live);
    if(auto && nm(free)==null && q.isNotEmpty){
      final t=_next(); if(t!=null) await _loadOnly(free,t);
    }
  }

  Future<void> _loadOnly(Deck d,QueuedTrack t) async{
    final pl=p(d); await pl.stop(); await pl.setFilePath(t.path);
    await pl.seek(const Duration(milliseconds:200));
    setNm(d,t.name); await pl.setVolume(0);
    if(mounted) setState((){});
  }

  void _chk(Deck d,Duration pos){
    final pl=p(d), dur=pl.duration; if(dur==null || d!=live ||!pl.playing || xing) return;
    final rem=dur-pos;
    if(rem <= const Duration(seconds:15) && rem > const Duration(seconds:12) && auto){
      final free=o(live);
      if(nm(free)==null && q.isNotEmpty){ _loadOnly(free,_next()!); }
    }
    if(rem <= const Duration(seconds:10) && rem > const Duration(milliseconds:800)){
      if(auto){ _mix(); }
      else{
        if(nm(Deck.a)!=null && nm(Deck.b)!=null) _mix();
      }
    }
  }

  Future<void> _mix() async{
    if(xing) return;
    final src=live,tgt=o(src),srcP=p(src),tgtP=p(tgt);
    if(nm(tgt)==null){
      if(auto && q.isNotEmpty){
        final t=_next(); if(t!=null) await _loadOnly(tgt,t);
      }else return;
    }

    xing=true; setState((){});
    if(!tgtP.playing){ tgtP.setVolume(0); await tgtP.play(); }

    // FIX 2: simple fast fade - no blocking awaits, slider will move
    for(int i=1;i<=20;i++){
      xf = src==Deck.a? i/20 : 1 - i/20;
      srcP.setVolume(src==Deck.a? 1 - xf : xf);
      tgtP.setVolume(src==Deck.a? xf : 1 - xf);
      setState((){});
      await Future.delayed(const Duration(milliseconds:250)); // 20*250=5sec total
    }

    xf = src==Deck.a? 1 : 0;
    srcP.setVolume(0); tgtP.setVolume(1);
    await srcP.stop(); setNm(src,null);
    live=tgt; xing=false; setState((){});
  }

  Future<void> pick(bool isA) async{
    final r=await FilePicker.platform.pickFiles(type:FileType.audio); if(r?.files.single.path==null) return;
    final req=isA?Deck.a:Deck.b; final tgt=p(live).playing && req==live?o(live):req;
    final pl=p(tgt); await pl.stop(); await pl.setFilePath(r!.files.single.path!);
    await pl.seek(const Duration(milliseconds:200)); setNm(tgt,r.files.single.name); await pl.setVolume(tgt==live?1:0); setState((){});
  }

  Future<void> addQ() async{
    final r=await FilePicker.platform.pickFiles(type:FileType.audio,allowMultiple:true); if(r==null) return;
    setState(()=>q.addAll(r.files.where((f)=>f.path!=null).map((f)=>QueuedTrack(f.path!,f.name))));
  }

  Future<void> _xfAct(double v) async{
    if(xing) return;
    if(v>0.02 && nm(Deck.b)!=null &&!b.playing){b.setVolume(0);b.play();}
    if(v<0.98 && nm(Deck.a)!=null &&!a.playing){a.setVolume(0);a.play();}
    a.setVolume(1-v); b.setVolume(v);
    if(v>=0.5 && nm(Deck.b)!=null) live=Deck.b; if(v<0.5 && nm(Deck.a)!=null) live=Deck.a;
    setState(()=>xf=v);
  }

  Future<void> _toggle(Deck d) async{
    final pl=p(d); if(pl.playing){await pl.pause();return;}
    if(nm(d)==null){
      if(q.isNotEmpty){
        final idx = qPos % q.length;
        final t=q[idx]; qPos=(qPos+1)%q.length;
        setNm(d,t.name); setState((){});
        await pl.setFilePath(t.path); await pl.seek(const Duration(milliseconds:200));
        live=d; xf=d==Deck.a?0:1; await pl.setVolume(1); await pl.play(); setState((){});
      }
      return;
    }
    live=d; await pl.setVolume(1); await p(o(d)).setVolume(0); xf=d==Deck.a?0:1; await pl.play(); setState((){});
  }

  Widget deck(bool isA){
    final d=isA?Deck.a:Deck.b,pl=p(d),isLive=live==d;
    return Card(shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16)),child:Padding(padding:const EdgeInsets.all(14),child:Column(children:[
      Text('DECK ${isA?'A':'B'} ${isLive?'(LIVE)':'(NEXT)'}',style:TextStyle(fontWeight:FontWeight.bold,fontSize:12,color:isLive?const Color(0xFFCEBBFF):Colors.white70)),
      Text(nm(d)??'No track',style:const TextStyle(color:Colors.white70,fontSize:12),maxLines:1,overflow:TextOverflow.ellipsis),
      Row(mainAxisAlignment:MainAxisAlignment.center,children:[
        IconButton(icon:const Icon(Icons.folder_open),onPressed:()=>pick(isA)),
        StreamBuilder<PlayerState>(stream:pl.playerStateStream,builder:(_,s){return IconButton(iconSize:36,icon:Icon(s.data?.playing==true?Icons.pause_circle_filled:Icons.play_circle_fill,color:const Color(0xFFCEBBFF)),onPressed:()=>_toggle(d));}),
        IconButton(icon:const Icon(Icons.stop),onPressed:()async{await pl.stop();await pl.setVolume(0);setState((){});}),
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
      Padding(padding:const EdgeInsets.symmetric(vertical:8),child:Row(children:[const Text('A',style:TextStyle(fontSize:10)),Expanded(child:Slider(value:xf,min:0,max:1,onChanged:_xfAct)),const Text('B',style:TextStyle(fontSize:10))])),
      deck(false),const SizedBox(height:16),
      Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text('QUEUE (${q.length})',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:12)),IconButton(icon:const Icon(Icons.add),onPressed:addQ)]),
      if(q.isEmpty) const Padding(padding:EdgeInsets.all(16),child:Text('Tap + to add songs. In MANUAL you can tap queue to load.',style:TextStyle(color:Colors.white54,fontSize:11),textAlign:TextAlign.center))
      else...List.generate(q.length,(i)=>ListTile(dense:true,title:Text(q[i].name,style:const TextStyle(fontSize:12),maxLines:1,overflow:TextOverflow.ellipsis),trailing:IconButton(icon:const Icon(Icons.close,size:16),onPressed:()=>setState(()=>q.removeAt(i))),onTap:()async{
        final tgt=p(live).playing?o(live):(nm(live)==null?live:o(live));
        await _loadOnly(tgt,q[i]); qPos=(i+1)%q.length; setState((){});
      })),
      const SizedBox(height:80),
    ]),
  );
}
