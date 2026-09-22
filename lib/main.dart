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
  bool autoTriggered=false;

  AudioPlayer p(Deck d)=>d==Deck.a?a:b;
  Deck o(Deck d)=>d==Deck.a?Deck.b:Deck.a;
  String? nm(Deck d)=>d==Deck.a?nA:nB;
  void setNm(Deck d,String? v){if(d==Deck.a)nA=v;else nB=v;}

  @override void initState(){
    super.initState();
    sA=a.positionStream.listen((pos)=>_checkAutoMix(Deck.a,pos));
    sB=b.positionStream.listen((pos)=>_checkAutoMix(Deck.b,pos));
  }
  @override void dispose(){sA?.cancel();sB?.cancel();a.dispose();b.dispose();super.dispose();}

  void _checkAutoMix(Deck deck,Duration position){
    if(!auto || xing || autoTriggered) return;
    if(deck!=live) return;
    final player=p(deck); final duration=player.duration;
    if(duration==null ||!player.playing) return;
    final remaining=duration-position;
    if(remaining <= const Duration(seconds:15) && remaining > const Duration(seconds:10)){
      _preloadNext();
    }
    if(remaining <= const Duration(seconds:10) && remaining > Duration.zero){
      autoTriggered=true; _mix();
    }
  }

  Future<void> _preloadNext() async{
    final free=o(live); if(nm(free)!=null || q.isEmpty) return;
    final track=q.removeAt(0); await _load(free,track,play:false);
  }

  Future<void> _autoStart() async{
    if(q.isEmpty) return;
    if(nm(live)==null){
      final t=q.removeAt(0); await _load(live,t,play:true);
    }
    if(nm(o(live))==null && q.isNotEmpty){
      final t=q.removeAt(0); await _load(o(live),t,play:false);
    }
  }

  Future<void> _mix() async{
    if(xing) return;
    final source=live,target=o(source);
    if(nm(target)==null){
      if(!auto || q.isEmpty){autoTriggered=false; return;}
      final track=q.removeAt(0); await _load(target,track,play:false);
    }
    if(nm(target)==null){autoTriggered=false; return;}
    final sourcePlayer=p(source),targetPlayer=p(target);
    xing=true; if(mounted) setState((){});
    await targetPlayer.setVolume(0.0);
    if(!targetPlayer.playing) await targetPlayer.play();

    // 100 steps = 10 sec, slider FORCED to move
    for(int step=1; step<=100; step++){
      final value=step/100.0;
      if(source==Deck.a){
        xf=value;
        sourcePlayer.setVolume(1.0-value);
        targetPlayer.setVolume(value);
      }else{
        xf=1.0-value;
        sourcePlayer.setVolume(value);
        targetPlayer.setVolume(1.0-value);
      }
      if(mounted) setState((){});
      if(step<100) await Future.delayed(const Duration(milliseconds:100));
    }
    await sourcePlayer.setVolume(0.0); await targetPlayer.setVolume(1.0);
    await sourcePlayer.stop(); setNm(source,null);
    live=target; xf=live==Deck.a?0.0:1.0; xing=false; autoTriggered=false;
    if(mounted) setState((){});
    if(auto && q.isNotEmpty) await _preloadNext();
  }

  Future<void> _load(Deck deck,QueuedTrack track,{bool play=false}) async{
    final player=p(deck); await player.stop(); await player.setFilePath(track.path);
    await player.seek(const Duration(milliseconds:150));
    setNm(deck,track.name); await player.setVolume(deck==live?1.0:0.0);
    if(play){
      live=deck; xf=deck==Deck.a?0.0:1.0; autoTriggered=false;
      await player.setVolume(1.0); await player.play();
    }
    if(mounted) setState((){});
  }

  Future<void> pick(bool isA) async{
    final result=await FilePicker.platform.pickFiles(type:FileType.audio);
    if(result==null || result.files.single.path==null) return;
    final requested=isA?Deck.a:Deck.b;
    final target=p(live).playing && requested==live?o(live):requested;
    await _load(target,QueuedTrack(result.files.single.path!,result.files.single.name));
  }

  Future<void> addQ() async{
    final result=await FilePicker.platform.pickFiles(type:FileType.audio,allowMultiple:true);
    if(result==null) return;
    final tracks=result.files.where((f)=>f.path!=null).map((f)=>QueuedTrack(f.path!,f.name)).toList();
    if(mounted) setState(()=>q.addAll(tracks));
  }

  Future<void> loadFromQueue(int index) async{
    if(index<0||index>=q.length) return;
    final track=q.removeAt(index);
    final target=p(live).playing?o(live): nm(live)==null?live:o(live);
    await _load(target,track);
  }

  Widget deck(bool isA){
    final deck=isA?Deck.a:Deck.b; final player=p(deck); final isLive=live==deck;
    return Card(shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16)),child:Padding(padding:const EdgeInsets.all(14),child:Column(children:[
      Text('DECK ${isA?'A':'B'} ${isLive?'(LIVE)':'(NEXT)'}${xing&&isLive?' MIXING':''}',style:TextStyle(fontWeight:FontWeight.bold,fontSize:12,color:isLive?const Color(0xFFCEBBFF):Colors.white70)),
      const SizedBox(height:4),
      Text(nm(deck)??'No track',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Colors.white70,fontSize:12)),
      Row(mainAxisAlignment:MainAxisAlignment.center,children:[
        IconButton(icon:const Icon(Icons.folder_open),onPressed:()=>pick(isA)),
        StreamBuilder<PlayerState>(stream:player.playerStateStream,builder:(c,s){
          final playing=s.data?.playing??false;
          return IconButton(iconSize:36,icon:Icon(playing?Icons.pause_circle_filled:Icons.play_circle_fill,color:const Color(0xFFCEBBFF)),onPressed:()async{
            if(player.playing){await player.pause();return;}
            if(nm(deck)==null){
              if(q.isEmpty) return; final track=q.removeAt(0); await _load(deck,track,play:true);
            }else{
              live=deck; xf=deck==Deck.a?0.0:1.0; autoTriggered=false;
              await player.setVolume(1.0); await p(o(deck)).setVolume(0.0); await player.play();
            }
            if(mounted) setState((){});
          });
        }),
        IconButton(icon:const Icon(Icons.stop),onPressed:()async{await player.stop();await player.setVolume(0.0);if(mounted)setState((){});}),
      ]),
      StreamBuilder<Duration>(stream:player.positionStream,builder:(c,s){
        final pos=s.data??Duration.zero; final dur=player.duration??Duration.zero;
        final max=dur.inMilliseconds>0?dur.inMilliseconds.toDouble():1.0;
        final value=pos.inMilliseconds.toDouble().clamp(0.0,max);
        String fmt(Duration d)=>'${d.inMinutes.remainder(60).toString().padLeft(2,'0')}:${d.inSeconds.remainder(60).toString().padLeft(2,'0')}';
        return Column(children:[Slider(value:value,min:0,max:max,activeColor:const Color(0xFFCEBBFF),onChanged:(v)=>player.seek(Duration(milliseconds:v.toInt()))),Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text(fmt(pos),style:const TextStyle(fontSize:10)),Text(fmt(dur),style:const TextStyle(fontSize:10))])]);
      }),
    ])));
  }

  @override Widget build(BuildContext context){
    return Scaffold(
      appBar:AppBar(title:const Text('BlendJam'),actions:[Row(children:[const Text('AUTO MIX',style:TextStyle(fontSize:10,fontWeight:FontWeight.bold)),Switch(value:auto,activeColor:const Color(0xFFCEBBFF),onChanged:(value)async{setState(()=>auto=value); if(value) await _autoStart();}),const SizedBox(width:8)])]),
      body:ListView(padding:const EdgeInsets.all(12),children:[
        deck(true),
        Padding(padding:const EdgeInsets.all(8),child:Column(children:[
          Row(children:[
            const Text('A',style:TextStyle(fontSize:10)),
            Expanded(child:Slider(value:xf,min:0,max:1,activeColor:const Color(0xFFCEBBFF),
              // FIX: never null, so slider can animate during auto mix
              onChanged:(value)async{
                if(xing) return; // block manual drag during auto mix, but still allow animation
                xf=value; await a.setVolume(1-value); await b.setVolume(value);
                if(value>=0.5 && nm(Deck.b)!=null) live=Deck.b;
                if(value<0.5 && nm(Deck.a)!=null) live=Deck.a;
                setState((){});
              },
            )),
            const Text('B',style:TextStyle(fontSize:10)),
          ]),
          Text(xing?'CROSSFADING ${live==Deck.a?'A → B':'B → A'} — ${xf.toStringAsFixed(2)}':'Crossfader at ${xf.toStringAsFixed(2)}',style:const TextStyle(fontSize:9,color:Colors.white54)),
          if(xing) const LinearProgressIndicator(color:Color(0xFFCEBBFF)),
        ])),
        deck(false),
        const SizedBox(height:16),
        Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text('QUEUE (${q.length})',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:12)),IconButton(icon:const Icon(Icons.add),onPressed:addQ)]),
        if(q.isEmpty) const Padding(padding:EdgeInsets.all(16),child:Text('Tap + to add songs',style:TextStyle(color:Colors.white54,fontSize:11),textAlign:TextAlign.center))
        else...List.generate(q.length,(i)=>ListTile(dense:true,title:Text(q[i].name,style:const TextStyle(fontSize:12),maxLines:1,overflow:TextOverflow.ellipsis),trailing:IconButton(icon:const Icon(Icons.close,size:16),onPressed:()=>setState(()=>q.removeAt(i))),onTap:()=>loadFromQueue(i))),
        const SizedBox(height:80),
      ]),
    );
  }
}
