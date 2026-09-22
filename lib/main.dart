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
  List<QueuedTrack> q=[]; int qPos=0; bool hasPreloaded=false;
  StreamSubscription<Duration>? sA,sB; StreamSubscription<PlayerState>? stA,stB;

  AudioPlayer p(Deck d)=>d==Deck.a?a:b;
  Deck o(Deck d)=>d==Deck.a?Deck.b:Deck.a;
  String? nm(Deck d)=>d==Deck.a?nA:nB;
  void setNm(Deck d,String? v)=>d==Deck.a?nA=v:nB=v;

  @override void initState(){
    super.initState();
    sA=a.positionStream.listen((x)=>_chk(Deck.a,x));
    sB=b.positionStream.listen((x)=>_chk(Deck.b,x));
    stA=a.playerStateStream.listen((s){ if(s.processingState==ProcessingState.completed) _onEnd(Deck.a); });
    stB=b.playerStateStream.listen((s){ if(s.processingState==ProcessingState.completed) _onEnd(Deck.b); });
  }
  @override void dispose(){sA?.cancel();sB?.cancel();stA?.cancel();stB?.cancel();a.dispose();b.dispose();super.dispose();}

  QueuedTrack? _nextFromQueue(){
    if(q.isEmpty) return null;
    final t=q[qPos % q.length]; qPos=(qPos+1)%q.length; return t;
  }

  Future<void> _autoStartIfNeeded() async{
    if(!auto || p(live).playing) return;
    if(nm(live)==null && q.isNotEmpty){
      final t=_nextFromQueue(); if(t!=null) await _load(live,t,play:true);
    }
    hasPreloaded=false; await _preloadFree();
  }

  Future<void> _preloadFree() async{
    if(!auto) return;
    if(hasPreloaded) return;
    final free=o(live); if(nm(free)!=null) return;
    final t=_nextFromQueue(); if(t==null) return;
    await _load(free,t,play:false); hasPreloaded=true;
  }

  void _chk(Deck d,Duration pos){
    final pl=p(d), dur=pl.duration; if(dur==null || d!=live ||!pl.playing || xing) return;
    final rem=dur-pos;

    if(auto){
      if(!hasPreloaded && rem <= const Duration(seconds:15) && rem > const Duration(seconds:10)){
        _preloadFree();
      }
      if(rem <= const Duration(seconds:10) && rem > const Duration(milliseconds:500)){
        _mix();
      }
    }else{
      final both = nm(Deck.a)!=null && nm(Deck.b)!=null;
      if(both && rem <= const Duration(seconds:10) && rem > const Duration(milliseconds:500)){
        _mix();
      }
    }
  }

  Future<void> _onEnd(Deck d) async{
    if(d!=live) return;
    hasPreloaded=false;
    if(nm(o(d))!=null){ await _mix(force:true); return; }
    if(auto && q.isNotEmpty){
      final t=_nextFromQueue(); if(t!=null){ await _load(o(d),t,play:false); await _mix(force:true); }
    }
  }

  Future<void> _mix({bool force=false}) async{
    if(xing) return;
    final src=live,tgt=o(src),srcP=p(src),tgtP=p(tgt);

    if(nm(tgt)==null){
      if(auto){
        final t=_nextFromQueue(); if(t==null) return; await _load(tgt,t,play:false);
      }else{ return; }
    }

    setState(()=>xing=true);
    await tgtP.setVolume(0);
    if(!tgtP.playing){ await tgtP.play(); }

    // FIX: 5 sec fade, not 10 sec - so old song doesn't end mid-fade
    for(var i=1;i<=60;i++){
      final v=i/60; xf=src==Deck.a?v:1-v;
      await srcP.setVolume(src==Deck.a?1-v:v);
      await tgtP.setVolume(src==Deck.a?v:1-v);
      if(mounted) setState((){});
      await Future.delayed(const Duration(milliseconds:80));
    }

    xf=src==Deck.a?1:0; await srcP.setVolume(0); await tgtP.setVolume(1);
    await srcP.stop(); setNm(src,null); live=tgt; hasPreloaded=false;
    setState(()=>xing=false);
    if(auto) await _preloadFree();
  }

  Future<void> _load(Deck d,QueuedTrack t,{bool play=false}) async{
    final pl=p(d); await pl.stop(); await pl.setFilePath(t.path);
    await pl.seek(const Duration(milliseconds:250));
    setNm(d,t.name); await pl.setVolume(d==live?1:0);
    if(play){ live=d; xf=d==Deck.a?0:1; await pl.setVolume(1); await pl.play(); }
    if(mounted) setState((){});
  }

  Future<void> pick(bool isA) async{
    final r=await FilePicker.platform.pickFiles(type:FileType.audio); if(r?.files.single.path==null) return;
    final req=isA?Deck.a:Deck.b, tgt=p(live).playing && req==live?o(live):req;
    await _load(tgt,QueuedTrack(r!.files.single.path!,r.files.single.name),play:false);
  }

  Future<void> addQ() async{
    final r=await FilePicker.platform.pickFiles(type:FileType.audio,allowMultiple:true); if(r==null) return;
    setState(()=>q.addAll(r.files.where((f)=>f.path!=null).map((f)=>QueuedTrack(f.path!,f.name))));
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
    if(nm(d)==null){
      if(auto && q.isNotEmpty){ final t=_nextFromQueue(); if(t!=null) await _load(d,t,play:true); }
      return;
    }
    final op=p(o(d));
    if(op.playing){await pl.setVolume(0);await pl.play();setState((){});return;}
    live=d; await pl.setVolume(1); await op.setVolume(0); xf=d==Deck.a?0:1; await pl.play(); setState((){});
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
    appBar:AppBar(title:const Text('BlendJam'),actions:[Row(children:[const Text('AUTO MIX',style:TextStyle(fontSize:10,fontWeight:FontWeight.bold)),Switch(value:auto,activeColor:const Color(0xFFCEBBFF),onChanged:(v)async{setState(()=>auto=v); hasPreloaded=false; if(v) await _autoStartIfNeeded();}),const SizedBox(width:8)])]),
    body:ListView(padding:const EdgeInsets.all(12),children:[
      deck(true),
      Column(children:[Row(children:[const Text('A',style:TextStyle(fontSize:10)),Expanded(child:Slider(value:xf,min:0,max:1,onChanged:_xfAct)),const Text('B',style:TextStyle(fontSize:10))]),if(auto) const Text('AUTO: 15s preload | 10s->5s fade | loops',textAlign:TextAlign.center,style:TextStyle(fontSize:9,color:Colors.white54)) else const Text('MANUAL: tap queue to load free deck, 10s xfade',textAlign:TextAlign.center,style:TextStyle(fontSize:9,color:Colors.white54)),if(xing) const LinearProgressIndicator(color:Color(0xFFCEBBFF))]),
      deck(false),const SizedBox(height:16),
      Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text('QUEUE (${q.length}) ${auto?'loops':'(tap to load in MANUAL too)'}',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:12)),IconButton(icon:const Icon(Icons.add),onPressed:addQ)]),
      if(q.isEmpty) const Padding(padding:EdgeInsets.all(16),child:Text('Queue empty. Tap +',style:TextStyle(color:Colors.white54,fontSize:11),textAlign:TextAlign.center))
      else...List.generate(q.length,(i)=>ListTile(dense:true,title:Text(q[i].name,style:const TextStyle(fontSize:12),maxLines:1,overflow:TextOverflow.ellipsis),subtitle: i==qPos%q.length && auto?const Text('next',style:TextStyle(fontSize:8,color:Color(0xFFCEBBFF))):null, trailing:IconButton(icon:const Icon(Icons.close,size:16),onPressed:()=>setState(()=>q.removeAt(i))),onTap:()async{
        // FIX: allowed in BOTH auto and manual - just loads free deck, does NOT auto-start queue
        final tgt=p(live).playing?o(live):(nm(live)==null?live:o(live));
        if(q[i].path.isNotEmpty){ await _load(tgt,q[i],play:false); qPos=(i+1)%q.length; setState((){}); }
      })),
      const SizedBox(height:80),
    ]),
  );
}
