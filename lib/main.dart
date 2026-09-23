import 'dart:async';
import 'dart:math' as math;
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

  QueuedTrack? _nextLoop(){if(q.isEmpty) return null; final t=q[qPos%q.length]; qPos=(qPos+1)%q.length; return t;}
  Future<void> _load(Deck d,QueuedTrack t,{bool play=false}) async{
    setNm(d,t.name); if(mounted) setState((){});
    final pl=p(d); await pl.stop(); await pl.setFilePath(t.path); await pl.seek(const Duration(milliseconds:200));
    await pl.setVolume(play?1.0:0.0); if(play){live=d; xf=d==Deck.a?0:1; await pl.play();} if(mounted) setState((){});
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
    xing=true; final srcP=p(src),tgtP=p(tgt); tgtP.setVolume(0); tgtP.play();
    int tick=0;
    Timer.periodic(const Duration(milliseconds:100), (timer) async{
      tick++; double v=tick/50; if(v>1) v=1;
      xf=src==Deck.a? v : 1-v;
      srcP.setVolume(1-xf); tgtP.setVolume(xf);
      if(mounted) setState((){});
      if(tick>=50){
        timer.cancel(); xf=src==Deck.a?1.0:0.0; srcP.setVolume(0); tgtP.setVolume(1);
        await srcP.stop(); setNm(src,null); live=tgt; xing=false; armed=false;
        if(mounted) setState((){});
        if(auto && nm(o(live))==null && q.isNotEmpty) _load(o(live),_nextLoop()!);
      }
    });
  }
  Future<void> pick(bool isA) async{
    final r=await FilePicker.platform.pickFiles(type:FileType.audio); if(r?.files.single.path==null) return;
    final tgt=p(live).playing?o(live):(isA?Deck.a:Deck.b); await _load(tgt,QueuedTrack(r!.files.single.path!,r.files.single.name));
  }
  Future<void> addQ() async{
    final r=await FilePicker.platform.pickFiles(type:FileType.audio,allowMultiple:true); if(r==null) return;
    setState(()=>q.addAll(r.files.where((f)=>f.path!=null).map((f)=>QueuedTrack(f.path!,f.name))));
  }
  Widget disc(bool isA){
    final d=isA?Deck.a:Deck.b; final pl=p(d);
    return _VinylDisc(deck:d, player:pl, name:nm(d)??'No track', isLive:live==d, isNext:o(live)==d && nm(d)!=null, onPick:()=>pick(isA),
      onPlayPause:()async{
        if(pl.playing){ await pl.pause(); }else{
          if(nm(d)==null&&q.isNotEmpty){ await _load(d,_nextLoop()!,play:true); }else{ live=d; xf=d==Deck.a?0:1; pl.setVolume(1); p(o(d)).setVolume(0); await pl.play(); }
        } setState((){});
      },
      onScratch:(delta){ final cur=pl.position; final newPos=cur + Duration(milliseconds:(delta*300).toInt()); if(newPos>Duration.zero) pl.seek(newPos); },
    );
  }
  @override Widget build(BuildContext c){
    return Scaffold(
      appBar:AppBar(title:const Text('BlendJam'),actions:[Row(children:[const Text('AUTO',style:TextStyle(fontSize:10,fontWeight:FontWeight.bold)),Switch(value:auto,activeColor:const Color(0xFFCEBBFF),onChanged:(v)async{setState(()=>auto=v); if(v) await _autoStart();}),const SizedBox(width:8)])]),
      body:ListView(padding:const EdgeInsets.all(12),children:[
        disc(true),
        Padding(padding:const EdgeInsets.symmetric(horizontal:24,vertical:4),child:Row(children:[const Text('A',style:TextStyle(fontSize:10)),Expanded(child:Slider(value:xf,min:0,max:1,activeColor:const Color(0xFFCEBBFF),onChanged:(v){ if(xing) return; xf=v; a.setVolume(1-v); b.setVolume(v); if(v>=0.5&&nm(Deck.b)!=null) live=Deck.b; if(v<0.5&&nm(Deck.a)!=null) live=Deck.a; setState((){}); })),const Text('B',style:TextStyle(fontSize:10))])),
        Center(child:Text(xing?'FADING ${xf.toStringAsFixed(2)}':'',style:const TextStyle(fontSize:9,color:Color(0xFFCEBBFF)))),
        disc(false),
        const SizedBox(height:12),
        Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text('QUEUE (${q.length}) loops',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:12)),IconButton(icon:const Icon(Icons.add),onPressed:addQ)]),
      ...List.generate(q.length,(i)=>ListTile(dense:true,title:Text(q[i].name,style:const TextStyle(fontSize:12),maxLines:1,overflow:TextOverflow.ellipsis),onTap:()async{final tgt=p(live).playing?o(live):(nm(live)==null?live:o(live)); await _load(tgt,q[i]);})),
        const SizedBox(height:80),
      ]),
    );
  }
}

class _VinylDisc extends StatefulWidget{
  final Deck deck; final AudioPlayer player; final String name; final bool isLive,isNext; final VoidCallback onPick,onPlayPause; final Function(double) onScratch;
  const _VinylDisc({required this.deck,required this.player,required this.name,required this.isLive,required this.isNext,required this.onPick,required this.onPlayPause,required this.onScratch});
  @override State<_VinylDisc> createState()=>_VinylDiscState();
}

class _VinylDiscState extends State<_VinylDisc> with TickerProviderStateMixin{
  late AnimationController _rot; late AnimationController _wave;
  @override void initState(){
    super.initState();
    _rot=AnimationController(vsync:this,duration:const Duration(seconds:3));
    _wave=AnimationController(vsync:this,duration:const Duration(milliseconds:600))..repeat();
    widget.player.playerStateStream.listen((s){ if(s.playing){ _rot.repeat(); } else { _rot.stop(); } });
  }
  @override void dispose(){_rot.dispose(); _wave.dispose(); super.dispose();}
  @override Widget build(BuildContext context){
    return Column(children:[
      Text('DECK ${widget.deck==Deck.a?'A':'B'} ${widget.isLive?'(LIVE)':widget.isNext?'(NEXT)':''}',style:TextStyle(fontSize:11,fontWeight:FontWeight.bold,color:widget.isLive?const Color(0xFFCEBBFF):Colors.white70)),
      const SizedBox(height:8),
      GestureDetector(
        onPanUpdate:(d)=>widget.onScratch(d.delta.dx),
        child: SizedBox(width:240,height:240,child:Stack(alignment:Alignment.center,children:[
          // WAVEFORM RING
          AnimatedBuilder(animation:_wave,builder:(c,_){
            return CustomPaint(size:const Size(240,240),painter:_WaveRingPainter(anim:_wave.value, isLive:widget.isLive, isPlaying:widget.player.playing));
          }),
          RotationTransition(
            turns:_rot,
            child: Container(width:200,height:200,decoration:BoxDecoration(shape:BoxShape.circle,color:const Color(0xFF1E1E1E),border:Border.all(color:widget.isLive?const Color(0xFFCEBBFF):Colors.white24,width:2),boxShadow:[BoxShadow(color:Colors.black.withOpacity(0.6),blurRadius:12)]),
              child:Stack(alignment:Alignment.center,children:[
                Container(width:180,height:180,decoration:BoxDecoration(shape:BoxShape.circle,border:Border.all(color:Colors.white10,width:0.5))),
                Container(width:140,height:140,decoration:BoxDecoration(shape:BoxShape.circle,border:Border.all(color:Colors.white10,width:0.5))),
                Container(width:70,height:70,decoration:const BoxDecoration(shape:BoxShape.circle,color:Colors.black)),
                Container(width:68,height:68,decoration:const BoxDecoration(shape:BoxShape.circle,color:Color(0xFFCEBBFF)),
                  child:IconButton(iconSize:30,icon:StreamBuilder<PlayerState>(stream:widget.player.playerStateStream,builder:(c,s)=>Icon(s.data?.playing==true?Icons.pause:Icons.play_arrow,color:Colors.black)),onPressed:widget.onPlayPause),
                ),
              ]),
            ),
          ),
        ])),
      ),
      Row(mainAxisAlignment:MainAxisAlignment.center,children:[
        IconButton(icon:const Icon(Icons.folder_open,size:18),onPressed:widget.onPick),
        SizedBox(width:150,child:Text(widget.name,style:const TextStyle(fontSize:10,color:Colors.white54),maxLines:1,overflow:TextOverflow.ellipsis,textAlign:TextAlign.center)),
      ]),
      StreamBuilder<Duration>(stream:widget.player.positionStream,builder:(c,s){
        final pos=s.data??Duration.zero; final dur=widget.player.duration??Duration.zero;
        String fmt(Duration d)=>'${d.inMinutes.remainder(60).toString().padLeft(2,'0')}:${d.inSeconds.remainder(60).toString().padLeft(2,'0')}';
        return Text('${fmt(pos)} / ${fmt(dur)} • drag disc to scratch',style:const TextStyle(fontSize:8,color:Colors.white24));
      }),
    ]);
  }
}

class _WaveRingPainter extends CustomPainter{
  final double anim; final bool isLive,isPlaying;
  _WaveRingPainter({required this.anim,required this.isLive,required this.isPlaying});
  @override void paint(Canvas canvas,Size size){
    final center=Offset(size.width/2,size.height/2);
    final base=110.0;
    final paint=Paint()..style=PaintingStyle.stroke..strokeWidth=1.8..color=isLive?const Color(0xFFCEBBFF).withOpacity(0.9):Colors.white24.withOpacity(0.3);
    final path=Path();
    for(int i=0;i<=120;i++){
      final angle=(i/120)*2*math.pi;
      double amp=0;
      if(isPlaying){ amp=6*math.sin(i*0.5 + anim*6) + 3*math.sin(i*0.2 + anim*10); }
      else{ amp=1.5*math.sin(i*0.3); }
      final r=base + amp;
      final x=center.dx + r*math.cos(angle);
      final y=center.dy + r*math.sin(angle);
      if(i==0) path.moveTo(x,y); else path.lineTo(x,y);
    }
    path.close();
    canvas.drawPath(path,paint);
    // inner glow dot when live
    if(isLive && isPlaying){
      final glow=Paint()..color=const Color(0xFFCEBBFF).withOpacity(0.15)..style=PaintingStyle.stroke..strokeWidth=8;
      canvas.drawCircle(center,base+2,glow);
    }
  }
  @override bool shouldRepaint(covariant _WaveRingPainter old)=>old.anim!=anim || old.isLive!=isLive;
}
