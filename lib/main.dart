import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:audiotags/audiotags.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

void main()=>runApp(const BlendJamApp());
class BlendJamApp extends StatelessWidget{
const BlendJamApp({super.key});
@override Widget build(BuildContext c)=>MaterialApp(debugShowCheckedModeBanner:false,theme:ThemeData.dark().copyWith(scaffoldBackgroundColor:const Color(0xFF121212)),home:const DJScreen());
}
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
@override void initState(){super.initState();
sA=a.positionStream.listen((pos)=>_check(Deck.a,pos));
sB=b.positionStream.listen((pos)=>_check(Deck.b,pos));}
@override void dispose(){sA?.cancel();sB?.cancel();a.dispose();b.dispose();super.dispose();}
QueuedTrack? _nextLoop(){if(q.isEmpty) return null; final t=q[qPos%q.length]; qPos=(qPos+1)%q.length; return t;}
Future<Uint8List?> _readArt(String path) async{
try{final tag=await AudioTags.read(path);
if(tag!=null&&tag.pictures.isNotEmpty){return tag.pictures.first.bytes;}}catch(_){}
return null;}
Future<void> _load(Deck d,QueuedTrack t,{bool play=false}) async{
setNm(d,t.name); setArt(d,null); if(mounted) setState((){});
final pl=p(d); await pl.stop(); await pl.setFilePath(t.path);
await pl.seek(const Duration(milliseconds:200));
_readArt(t.path).then((bytes){setArt(d,bytes); if(mounted) setState((){});});
await pl.setVolume(play?1.0:0.0); await pl.setSpeed(1.0);
if(play){live=d; xf=d==Deck.a?0:1; await pl.play();} if(mounted) setState((){});}
Future<void> _autoStart() async{
if(q.isEmpty) return;
if(nm(live)==null){await _load(live,_nextLoop()!,play:true);}
if(nm(o(live))==null&&q.isNotEmpty){await _load(o(live),_nextLoop()!);}}
void _check(Deck d,Duration pos){
if(xing||armed) return; if(d!=live) return;
final dur=p(d).duration; if(dur==null||!p(d).playing) return;
final rem=dur-pos;
if(auto&&rem.inSeconds==15){final free=o(live); if(nm(free)==null) _load(free,_nextLoop()!);}
if(rem.inSeconds<=10&&rem.inSeconds>=9){final both=nm(Deck.a)!=null&&nm(Deck.b)!=null; if(both){armed=true; _startFade();}}}
void _startFade(){
if(xing) return; final src=live; final tgt=o(src); if(nm(tgt)==null){armed=false; return;}
xing=true; final srcP=p(src); final tgtP=p(tgt);
tgtP.setVolume(0);
tgtP.setSpeed(1.0);
tgtP.play();
int tick=0;
Timer.periodic(const Duration(milliseconds:100),(timer) async{
tick++; double v=tick/50; if(v>1) v=1;
xf=src==Deck.a?v:1-v;
srcP.setVolume(1-xf); tgtP.setVolume(xf);
if(mounted) setState((){});
if(tick>=50){timer.cancel(); xf=src==Deck.a?1.0:0.0; srcP.setVolume(0); tgtP.setVolume(1);
await srcP.stop(); setNm(src,null); setArt(src,null); live=tgt; xing=false; armed=false;
if(mounted) setState((){});
if(auto&&nm(o(live))==null&&q.isNotEmpty) _load(o(live),_nextLoop()!);}});}
Future<void> pick(bool isA) async{
final r=await FilePicker.platform.pickFiles(type:FileType.audio); if(r?.files.single.path==null) return;
final tgt=p(live).playing?o(live):(isA?Deck.a:Deck.b); await _load(tgt,QueuedTrack(r!.files.single.path!,r.files.single.name));}
Future<void> addQ() async{
final r=await FilePicker.platform.pickFiles(type:FileType.audio,allowMultiple:true); if(r==null) return;
setState(()=>q.addAll(r.files.where((f)=>f.path!=null).map((f)=>QueuedTrack(f.path!,f.name))));}
Widget disc(bool isA){
final d=isA?Deck.a:Deck.b; final pl=p(d);
return _VinylDisc(deck:d,player:pl,name:nm(d)??'No track',art:art(d),isLive:live==d,isNext:o(live)==d&&nm(d)!=null,onPick:()=>pick(isA),onPlayPause:()async{
if(pl.playing){await pl.pause();}else{
if(nm(d)==null&&q.isNotEmpty){await _load(d,_nextLoop()!,play:true);}else{live=d; xf=d==Deck.a?0:1; pl.setVolume(1); await pl.setSpeed(1.0); p(o(d)).setVolume(0); await pl.play();}
}setState((){});},);}
@override Widget build(BuildContext c){
return Scaffold(
appBar:AppBar(title:const Text('BlendJam'),actions:[Row(children:[const Text('AUTO',style:TextStyle(fontSize:10,fontWeight:FontWeight.bold)),Switch(value:auto,activeColor:const Color(0xFFCEBBFF),onChanged:(v)async{setState(()=>auto=v); if(v) await _autoStart();}),const SizedBox(width:8)])]),
body:ListView(padding:const EdgeInsets.all(12),children:[
disc(true),
Padding(padding:const EdgeInsets.symmetric(horizontal:24,vertical:4),child:Row(children:[const Text('A',style:TextStyle(fontSize:10)),Expanded(child:Slider(value:xf,min:0,max:1,activeColor:const Color(0xFFCEBBFF),onChanged:(v){if(xing) return; xf=v; a.setVolume(1-v); b.setVolume(v); if(v>=0.5&&nm(Deck.b)!=null) live=Deck.b; if(v<0.5&&nm(Deck.a)!=null) live=Deck.a; setState((){});})),const Text('B',style:TextStyle(fontSize:10))])),
Center(child:Text(xing?'FADING ${xf.toStringAsFixed(2)}':'',style:const TextStyle(fontSize:9,color:Color(0xFFCEBBFF)))),
disc(false),
const SizedBox(height:12),
Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text('QUEUE (${q.length}) loops',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:12)),IconButton(icon:const Icon(Icons.add),onPressed:addQ)]),
...List.generate(q.length,(i)=>ListTile(dense:true,title:Text(q[i].name,style:const TextStyle(fontSize:12),maxLines:1,overflow:TextOverflow.ellipsis),onTap:()async{final tgt=p(live).playing?o(live):(nm(live)==null?live:o(live)); await _load(tgt,q[i]);})),
const SizedBox(height:80),]),);}}

class _VinylDisc extends StatefulWidget{
final Deck deck; final AudioPlayer player; final String name; final Uint8List? art; final bool isLive,isNext; final VoidCallback onPick,onPlayPause;
const _VinylDisc({required this.deck,required this.player,required this.name,required this.art,required this.isLive,required this.isNext,required this.onPick,required this.onPlayPause});
@override State<_VinylDisc> createState()=>_VinylDiscState();}
class _VinylDiscState extends State<_VinylDisc> with TickerProviderStateMixin{
late AnimationController _rot; late AnimationController _wave;
@override void initState(){super.initState();
_rot=AnimationController(vsync:this,duration:const Duration(seconds:3));
_wave=AnimationController(vsync:this,duration:const Duration(milliseconds:600))..repeat();
widget.player.playerStateStream.listen((s){if(s.playing) _rot.repeat(); else _rot.stop();});}
@override void dispose(){_rot.dispose(); _wave.dispose(); super.dispose();}
Future<void> _scratchStart() async=>await widget.player.setSpeed(0.0);
Future<void> _scratchUpdate(double dx) async{
double speed=dx*0.5; speed=speed.clamp(-3.0,3.0);
if(speed.abs()<0.1) speed=0;
await widget.player.setSpeed(speed.abs()<0.1?0:speed);
_rot.value=(_rot.value + dx*0.015) % 1.0;}
Future<void> _scratchEnd() async{await widget.player.setSpeed(1.0); if(widget.player.playing) _rot.repeat();}
@override Widget build(BuildContext context){
return Column(children:[
Text('DECK ${widget.deck==Deck.a?'A':'B'} ${widget.isLive?'(LIVE)':widget.isNext?'(NEXT)':''}',style:TextStyle(fontSize:11,fontWeight:FontWeight.bold,color:widget.isLive?const Color(0xFFCEBBFF):Colors.white70)),
const SizedBox(height:6),
GestureDetector(
onPanStart:(_)=>_scratchStart(),onPanUpdate:(d)=>_scratchUpdate(d.delta.dx),onPanEnd:(_)=>_scratchEnd(),
child:SizedBox(width:200,height:200,child:Stack(alignment:Alignment.center,children:[
AnimatedBuilder(animation:_wave,builder:(c,_){return CustomPaint(size:const Size(200,200),painter:_WaveRingPainter(anim:_wave.value,isLive:widget.isLive,isPlaying:widget.player.playing));}),
RotationTransition(
turns:_rot,
child:Container(width:170,height:170,decoration:BoxDecoration(shape:BoxShape.circle,border:Border.all(color:widget.isLive?const Color(0xFFCEBBFF):Colors.white24,width:2),boxShadow:[BoxShadow(color:Colors.black.withOpacity(0.6),blurRadius:10)]),
child:ClipOval(child:Stack(fit:StackFit.expand,children:[
widget.art!=null?Image.memory(widget.art!,fit:BoxFit.cover):Container(color:const Color(0xFF1A1A1A)),
Container(decoration:BoxDecoration(gradient:RadialGradient(colors:[Colors.black.withOpacity(0.2), Colors.black.withOpacity(0.7)]))),
Center(child:Container(width:58,height:58,decoration:BoxDecoration(shape:BoxShape.circle,color:const Color(0xFFCEBBFF).withOpacity(0.95),border:Border.all(color:Colors.black,width:2)),
child:IconButton(iconSize:24,icon:StreamBuilder<PlayerState>(stream:widget.player.playerStateStream,builder:(c,s)=>Icon(s.data?.playing==true?Icons.pause:Icons.play_arrow,color:Colors.black)),onPressed:widget.onPlayPause),)),]))),]))),
const SizedBox(height:4),
SizedBox(width:170,child:Text(widget.name,style:const TextStyle(fontSize:10,color:Colors.white54),maxLines:1,overflow:TextOverflow.ellipsis,textAlign:TextAlign.center)),
StreamBuilder<Duration>(stream:widget.player.positionStream,builder:(c,s){
final pos=s.data??Duration.zero; final dur=widget.player.duration??const Duration(seconds:1);
final prog=dur.inMilliseconds>0?pos.inMilliseconds/dur.inMilliseconds:0.0;
String fmt(Duration d)=>'${d.inMinutes.remainder(60).toString().padLeft(2,'0')}:${d.inSeconds.remainder(60).toString().padLeft(2,'0')}';
return Column(children:[
SizedBox(width:170,child:LinearProgressIndicator(value:prog.clamp(0.0,1.0),minHeight:3,backgroundColor:Colors.white10,valueColor:AlwaysStoppedAnimation(widget.isLive?const Color(0xFFCEBBFF):Colors.white24))),
const SizedBox(height:2),
Text('${fmt(pos)} / ${fmt(dur)}',style:const TextStyle(fontSize:8,color:Colors.white30)),]);}),
Row(mainAxisAlignment:MainAxisAlignment.center,children:[
IconButton(icon:const Icon(Icons.folder_open,size:16),onPressed:widget.onPick,visualDensity:VisualDensity.compact,padding:EdgeInsets.zero),
const Text('drag = scratch',style:TextStyle(fontSize:7,color:Colors.white24)),]),]);}}

class _WaveRingPainter extends CustomPainter{
final double anim; final bool isLive,isPlaying;
_WaveRingPainter({required this.anim,required this.isLive,required this.isPlaying});
@override void paint(Canvas canvas,Size size){
final center=Offset(size.width/2,size.height/2); final base=92.0;
final paint=Paint()..style=PaintingStyle.stroke..strokeWidth=1.5..color=isLive?const Color(0xFFCEBBFF).withOpacity(0.8):Colors.white24.withOpacity(0.25);
final path=Path();
for(int i=0;i<=100;i++){
final angle=(i/100)*2*math.pi; double amp=isPlaying?5*math.sin(i*0.6+anim*6):1.2*math.sin(i*0.3);
final r=base+amp; final x=center.dx+r*math.cos(angle); final y=center.dy+r*math.sin(angle);
if(i==0) path.moveTo(x,y); else path.lineTo(x,y);}
path.close(); canvas.drawPath(path,paint);}
@override bool shouldRepaint(covariant _WaveRingPainter old)=>old.anim!=anim;}
