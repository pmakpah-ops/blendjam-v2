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
  List<QueuedTrack> q=[]; StreamSubscription<Duration>? sA,sB; StreamSubscription<PlayerState>? stA,stB;

  AudioPlayer p(Deck d)=>d==Deck.a?a:b;
  Deck o(Deck d)=>d==Deck.a?Deck.b:Deck.a;
  String? nm(Deck d)=>d==Deck.a?nA:nB;
  void setNm(Deck d,String? v)=>d==Deck.a?nA=v:nB=v;

  @override void initState(){
    super.initState();
    sA=a.positionStream.listen((x)=>_chk(Deck.a,x));
    sB=b.positionStream.listen((x)=>_chk(Deck.b,x));
    stA=a.playerStateStream.listen((s){ if(s.processingState==ProcessingState.completed) _onComplete(Deck.a); });
    stB=b.playerStateStream.listen((s){ if(s.processingState==ProcessingState.completed) _onComplete(Deck.b); });
  }
  @override void dispose(){sA?.cancel();sB?.cancel();stA?.cancel();stB?.cancel();a.dispose();b.dispose();super.dispose();}

  Future<void> _maybePreload() async{
    if(!auto || q.isEmpty) return;
    final free=o(live);
    if(nm(free)!=null) return;
    final t=q.removeAt(0);
    await _load(free,t);
  }

  void _chk(Deck d,Duration pos){
    if(!auto || xing || d!=live) return;
    final pl=p(d), dur=pl.duration; if(dur==null ||!pl.playing) return;
    final rem=dur-pos;
    if(rem <= const Duration(seconds:10) && rem > const Duration(seconds:-1)){ _mix(); }
  }

  Future<void> _onComplete(Deck d) async{
    if(d!=live) return;
    if(q.isEmpty && nm(o(d))==null) return;
    await _mix(force:true);
  }

  Future<void> _mix({bool force=false}) async{
    if(xing) return;
    if(q.isNotEmpty && nm(o(live))==null){
      final t=q.removeAt(0); await _load(o(live),t);
    }
    final src=live,tgt=o(src),srcP=p(src),tgtP=p(tgt);
    if(nm(tgt)==null){
      if(q.isNotEmpty){
        final t=q.removeAt(0); await _load(tgt,t);
      }else return;
    }
    setState(()=>xing=true);
    await tgtP.setVolume(0); if(!tgtP.playing) await tgtP.play();
    for(var i=1;i<=100;i++){
      final v=i/100; xf=src==Deck.a?v:1-v;
      await srcP.setVolume(src==Deck.a?1-v:v);
      await tgtP.setVolume(src==Deck.a?v:1-v);
      if(mounted) setState((){});
      await Future.delayed(const Duration(milliseconds:100));
    }
    xf=src==Deck.a?1:0; await srcP.setVolume(0); await tgtP.setVolume(1); await srcP.stop(); setNm(src,null);
    live=tgt; setState(()=>xing=false);
    if(q.isNotEmpty){ await _load(o(live),q.removeAt(0)); }
  }

  Future<void> _load(Deck d,QueuedTrack t) async{
    final pl=p(d); await pl.stop(); await pl.setFilePath(t.path); await pl.seek(Duration.zero);
    setNm(d,t.name); await pl.setVolume(d==live?1:0); if(mounted) setState((){});
  }

  Future<void> pick(bool isA) async{
    final r=await FilePicker.platform.pickFiles(type:FileType.audio); if(r?.files.single.path==null) return;
    final req=isA?Deck.a:Deck.b, tgt=p(live).playing && req==live?o(live):req;
    await _load(tgt,QueuedTrack(r!.files.single.path!,r.files.single.name));
    if(auto) await _maybePreload();
  }

  Future<void> addQ() async{
    final r=await FilePicker.platform.pickFiles(type:FileType.audio,allowMultiple:true); if(r==null) return;
    setState(()=>q.addAll(r.files.where((f)=>f.path!=null).map((f)=>QueuedTrack(f.path!,f.name))));
    if(auto) await _maybePreload();
  }

  Future<void> _xfAct(double v) async{
    if(xing) return;
    if(v>0.01 && nm(Deck.b)!=null &&!b.playing){await b.setVolume(0);await b.play();}
    if(v<0.99 && nm(Deck.a)!=null &&!a.playing){await a.setVolume(0);await a.play();}
    await a.setVolume(1-v); await b.setVolume(v);
    if(v>=0.5 && nm(Deck.b)!=null) live=Deck.b; if(v<0.5 && nm(Deck.a)!=null) live=Deck.a;
    setState(()=>xf=v);
  }

  Future<void> _toggle(Deck d) async{
    final pl=p(d); if(pl.playing){await pl.pause();return;}
    if(nm(d)==null) return; final op=p(o(d));
    if(op.playing){await pl.setVolume(0);await pl.play();setState((){});return;}
    live=d; await pl.setVolume(1); await op.setVolume(0); xf=d==Deck.a?0:1; await pl.play(); setState((){});
    if(auto) await _maybePreload();
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
    appBar:AppBar(title:const Text('BlendJam'),actions:[Row(children:[const Text('AUTO MIX',style:TextStyle(fontSize:10,fontWeight:FontWeight.bold)),Switch(value:auto,activeColor:const Color(0xFFCEBBFF),onChanged:(v)async{setState(()=>auto=v); if(v) await _maybePreload();}),const SizedBox(width:8)])]),
    body:ListView(padding:const EdgeInsets.all(12),children:[
      deck(true),
      Column(children:[Row(children:[const Text('A',style:TextStyle(fontSize:10)),Expanded(child:Slider(value:xf,min:0,max:1,onChanged:_xfAct)),const Text('B',style:TextStyle(fontSize:10))]),if(auto) const Text('Auto Mix: last 10 seconds',textAlign:TextAlign.center,style:TextStyle(fontSize:9,color:Colors.white54)),if(xing) const LinearProgressIndicator(color:Color(0xFFCEBBFF))]),
      deck(false),const SizedBox(height:16),
      Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text('QUEUE (${q.length})',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:12)),IconButton(icon:const Icon(Icons.add),onPressed:addQ)]),
      if(q.isEmpty) const Padding(padding:EdgeInsets.all(16),child:Text('Queue empty. Tap +',style:TextStyle(color:Colors.white54,fontSize:11),textAlign:TextAlign.center))
      else...List.generate(q.length,(i)=>ListTile(dense:true,title:Text(q[i].name,style:const TextStyle(fontSize:12),maxLines:1,overflow:TextOverflow.ellipsis),trailing:IconButton(icon:const Icon(Icons.close,size:16),onPressed:()=>setState(()=>q.removeAt(i))),onTap:()async{final t=q.removeAt(i);final tgt=p(live).playing?o(live):(nm(live)==null?live:o(live));await _load(tgt,t);setState((){});})),
      const SizedBox(height:80),
    ]),
  );
}
