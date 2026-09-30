import 'dart:async';import 'dart:math' as m;
import 'dart:typed_data';
import 'package:audiotags/audiotags.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
void main()=>runApp(const BlendJamApp());
class BlendJamApp extends StatelessWidget{
 const BlendJamApp({super.key});
 @override Widget build(c)=>MaterialApp(
  debugShowCheckedModeBanner:false,
  theme:ThemeData.dark(),home:const DJ());}
class Track{final String p,n;const Track(this.p,this.n);}
enum Deck{a,b}
class DJ extends StatefulWidget{
 const DJ({super.key});@override State<DJ> createState()=>_S();}
class _S extends State<DJ>{
 static const pu=Color(0xFFCEBBFF);
 static const fadeT=Duration(seconds:10);
 static const preT=Duration(seconds:15);
 static const trim=Duration(milliseconds:350);
 final pa=AudioPlayer(),pb=AudioPlayer();
 StreamSubscription<Duration>? sa,sb;
 StreamSubscription<PlayerState>? ca,cb;
 Timer? tk;String? na,nb;Uint8List? aa,ab;
 Deck live=Deck.a;bool auto=false,xf=false;
 double xfad=0.0;List<Track> q=[];int qi=0;
 P(Deck d)=>d==Deck.a?pa:pb;
 O(Deck d)=>d==Deck.a?Deck.b:Deck.a;
 N(Deck d)=>d==Deck.a?na:nb;
 A(Deck d)=>d==Deck.a?aa:ab;
 SN(Deck d,v){d==Deck.a?na=v:nb=v;}
 SA(Deck d,v){d==Deck.a?aa=v:ab=v;}
 @override void initState(){super.initState();
  sa=pa.positionStream.listen((p)=>_ck(Deck.a,p));
  sb=pb.positionStream.listen((p)=>_ck(Deck.b,p));
  ca=pa.playerStateStream.listen((s)=>_done(Deck.a,s));
  cb=pb.playerStateStream.listen((s)=>_done(Deck.b,s));
  tk=Timer.periodic(const Duration(milliseconds:400),(_){
   if(!mounted||xf||!auto) return;
   var pl=P(live);var du=pl.duration;if(du==null) return;
   var eff=du>trim?du-trim:du;var rem=eff-pl.position;
   if(rem<=fadeT&&N(O(live))!=null){_fade(O(live));}
   else if(rem<=preT&&N(O(live))==null){_prep();}});}
 @override void dispose(){
  tk?.cancel();sa?.cancel();sb?.cancel();
  ca?.cancel();cb?.cancel();pa.dispose();pb.dispose();
  super.dispose();}
 void _done(Deck d,PlayerState s){
  if(s.processingState==ProcessingState.completed){
   if(d==live&&N(O(d))!=null&&!xf){_fade(O(d));return;}
   if(d!=live){SN(d,null);SA(d,null);setState((){});return;}
   if(d==live&&N(O(d))==null){SN(d,null);SA(d,null);setState((){});}}}
 Track? _next(){if(q.isEmpty) return null;
  var t=q[qi%q.length];qi=(qi+1)%q.length;return t;}
 Future<Uint8List?> _art(String p) async{try{
   var t=await AudioTags.read(p);
   if(t!=null&&t.pictures.isNotEmpty) return t.pictures.first.bytes;
  }catch(_){}return null;}
 Future<bool> _load(Deck d,Track t,{bool livePlay=false}) async{
  var pl=P(d);SN(d,t.n);SA(d,null);setState((){});
  try{await pl.stop();await pl.setFilePath(t.p);
   var du=pl.duration;var st=du!=null&&du>trim?trim:Duration.zero;
   await pl.seek(st);await pl.setVolume(d==live?1.0:0.0);
   if(livePlay&&d==live) await pl.play();else await pl.pause();
  }catch(e){_msg('Load fail');return false;}
  _art(t.p).then((i){if(mounted){SA(d,i);setState((){});}});
  setState((){});return true;}
 Future _prep() async{if(q.isEmpty||xf) return;
  if(N(O(live))!=null) return;var nx=_next();if(nx==null) return;
  await _load(O(live),nx,livePlay:false);}
 Future _auto() async{if(q.isEmpty){_msg('Add music');return;}
  if(N(live)==null){var f=_next();if(f==null) return;
   await _load(live,f,livePlay:true);}else{
   var pl=P(live);if(!pl.playing) await pl.play();}
  await _prep();setState((){});}
 void _ck(Deck d,Duration p){if(!mounted||xf||!auto) return;
  if(d!=live) return;var pl=P(d);if(!pl.playing) return;
  var du=pl.duration;if(du==null) return;
  var eff=du>trim?du-trim:du;var rem=eff-p;
  if(rem<=preT&&rem>=Duration.zero&&N(O(d))==null) _prep();
  if(rem<=fadeT&&rem>=Duration.zero&&N(O(d))!=null) _fade(O(d));}
 Future _fade(Deck tar) async{if(xf||N(tar)==null) return;
  var src=live;if(src==tar) return;var sp=P(src),tp=P(tar);
  xf=true;setState((){});
  try{
   await tp.seek(trim);await tp.setVolume(0.0);await tp.pause();
   const st=100;var dl=Duration(milliseconds:fadeT.inMilliseconds~/st);
   for(int i=1;i<=st;i++){var v=i/st;
    if(i==10){try{await tp.play();}catch(_){}}
    try{var sv=m.cos(v*m.pi/2),tv=m.sin(v*m.pi/2);
     await sp.setVolume(sv);await tp.setVolume(tv);}catch(_){}
    xfad=src==Deck.a?v:1.0-v;if(mounted) setState((){});
    await Future.delayed(dl);}
  }catch(e){}finally{
   try{await sp.setVolume(0.0);await tp.setVolume(1.0);
    await sp.stop();await sp.seek(trim);await sp.pause();}catch(_){}
   SN(src,null);SA(src,null);live=tar;
   xfad=tar==Deck.a?0.0:1.0;xf=false;
   if(mounted) setState((){});if(auto) await _prep();}}
 Future _tog(Deck d) async{if(xf) return;var pl=P(d);
  try{if(pl.playing){await pl.pause();setState((){});return;}
   if(N(d)==null){if(q.isEmpty){_msg('Add file');return;}
    var t=_next();if(t==null) return;
    await _load(d,t,livePlay:true);live=d;setState((){});return;}
   if(d!=live&&N(d)!=null){await _fade(d);return;}
   live=d;xfad=d==Deck.a?0.0:1.0;
   await P(O(d)).setVolume(0.0);await P(O(d)).pause();
   await pl.setVolume(1.0);await pl.play();
   if(auto) await _prep();setState((){});
  }catch(e){_msg('Play err');}}
 Future _pick(Deck d) async{var r=await FilePicker.platform
.pickFiles(type:FileType.audio);if(r==null) return;
  var p=r.files.single.path;if(p==null) return;
  await _load(d,Track(p,r.files.single.name),livePlay:true);
  live=d;if(auto) await _prep();setState((){});}
 Future _aq() async{var r=await FilePicker.platform.pickFiles(
   type:FileType.audio,allowMultiple:true);if(r==null) return;
  var ts=r.files.where((f)=>f.path!=null)
.map((f)=>Track(f.path!,f.name)).toList();
  if(ts.isEmpty) return;setState(()=>q.addAll(ts));
  if(auto) await _auto();}
 Future _nextD(Deck d) async{if(q.isEmpty||xf) return;
  var t=_next();if(t==null) return;await _load(d,t,livePlay:d==live);}
 Future _prevD(Deck d) async{if(q.isEmpty||xf) return;
  qi=(qi-2+q.length)%q.length;var t=q[qi%q.length];
  qi=(qi+1)%q.length;await _load(d,t,livePlay:d==live);}
 Future _seek(Deck d,int s) async{var pl=P(d);
  var p=pl.position+Duration(seconds:s);
  if(p<Duration.zero) p=Duration.zero;
  var du=pl.duration;if(du!=null&&p>du) p=du;await pl.seek(p);}
 Future _setX(double v) async{if(xf) return;xfad=v;
  await pa.setVolume((1.0-v).clamp(0.0,1.0));
  await pb.setVolume(v.clamp(0.0,1.0));
  live=v>=0.5?Deck.b:Deck.a;setState((){});}
 void _msg(String t){if(!mounted) return;
  ScaffoldMessenger.of(context)..hideCurrentSnackBar()
..showSnackBar(SnackBar(content:Text(t)));}
 void _queuePop(){showModalBottomSheet(context:context,
  builder:(ctx)=>SafeArea(child:Column(children:[
   ListTile(title:Text('QUEUE ${q.length} LIVE:${N(live)??'--'}',
    style:const TextStyle(fontSize:13)),trailing:Row(
    mainAxisSize:MainAxisSize.min,children:[
    IconButton(icon:const Icon(Icons.add),onPressed:() async{
     await _aq();if(context.mounted) Navigator.pop(context);_queuePop();}),
    IconButton(icon:const Icon(Icons.close),onPressed:()=>Navigator.pop(context))])),
   const Divider(),
   Expanded(child:ListView.builder(itemCount:q.length,
    itemBuilder:(c,i){var isLive=N(live)==q[i].n;
     var isNext=N(O(live))==q[i].n;
     return ListTile(dense:true,
      leading:Text('${i+1}',style:TextStyle(color:isLive?pu:null)),
      title:Text(q[i].n,maxLines:1,overflow:TextOverflow.ellipsis,
       style:TextStyle(fontSize:13,color:isLive?pu:isNext?Colors.orange:Colors.white)),
      subtitle:isLive?const Text('▶ PLAYING ON DECK',style:TextStyle(fontSize:10,color:pu))
       :isNext?const Text('NEXT UP',style:TextStyle(fontSize:10,color:Colors.orange)):null,
      onTap:() async{Navigator.pop(c);await _load(live,q[i],livePlay:true);});}))])));}
 Widget _deck(Deck d,bool lift)=>DeckView(deck:d,player:P(d),
  name:N(d)??'No track',art:A(d),live:live==d,
  next:live!=d&&N(d)!=null,onPlay:()=>_tog(d),
  onPick:()=>_pick(d),onPrev:()=>_prevD(d),
  onNext:()=>_nextD(d),onSeek:(s)=>_seek(d,s),lift:lift);
 @override Widget build(c)=>Scaffold(
  backgroundColor:Colors.black,
  appBar:AppBar(backgroundColor:Colors.black,toolbarHeight:42,
   title:const Text('BlendJam',style:TextStyle(fontSize:19)),
   actions:[
   const Text('AUTO',style:TextStyle(fontSize:11)),
   Switch(value:auto,activeColor:pu,
    onChanged:(v) async{setState(()=>auto=v);if(v) await _auto();}),
   IconButton(icon:const Icon(Icons.queue_music,size:22),onPressed:_queuePop),
   const SizedBox(width:2)]),
  body:Column(children:[
   Expanded(child:_deck(Deck.a,false)),
   Padding(padding:const EdgeInsets.symmetric(horizontal:10),
    child:Column(children:[
     Row(children:[
      const Text('A',style:TextStyle(fontSize:12)),
      Expanded(child:Slider(value:xfad.clamp(0.0,1.0),min:0,max:1,activeColor:pu,onChanged:_setX)),
      const Text('B',style:TextStyle(fontSize:12))]),
     Text(xf?'MIXING ${(xfad*100).toInt()}% -> DECK ${live==Deck.a?'B':'A'}':'',
      style:const TextStyle(color:pu,fontSize:11)),
   ])),
   Expanded(child:Padding(padding:const EdgeInsets.only(bottom:24),
    child:_deck(Deck.b,true))),
  ]));}

class DeckView extends StatefulWidget{
 final Deck deck;final AudioPlayer player;
 final String name;final Uint8List? art;
 final bool live,next,lift;
 final VoidCallback onPlay,onPick,onPrev,onNext;
 final Future<void> Function(int) onSeek;
 const DeckView({super.key,required this.deck,
  required this.player,required this.name,
  required this.art,required this.live,
  required this.next,required this.onPlay,
  required this.onPick,required this.onPrev,
  required this.onNext,required this.onSeek,required this.lift});
 @override State<DeckView> createState()=>_DV();}
class _DV extends State<DeckView> with TickerProviderStateMixin{
 late AnimationController disc,ring;
 StreamSubscription<PlayerState>? subs;
 @override void initState(){super.initState();
  disc=AnimationController(vsync:this,duration:const Duration(seconds:3));
  ring=AnimationController(vsync:this,duration:const Duration(seconds:5));
  subs=widget.player.playerStateStream.listen((s){
   if(!mounted) return;bool has=widget.name!='No track';
   if(s.playing&&has&&widget.live){disc.repeat();ring.repeat();}
   else{disc.stop();ring.stop();}});}
 @override void didUpdateWidget(covariant DeckView old){
  super.didUpdateWidget(old);bool has=widget.name!='No track';
  if(!has||!widget.player.playing){disc.stop();ring.stop();}
  else if(widget.live){disc.repeat();ring.repeat();}}
 @override void dispose(){subs?.cancel();disc.dispose();ring.dispose();super.dispose();}
 String _fmt(Duration d)=>'${d.inMinutes.remainder(60).toString().padLeft(2,'0')}:'
  '${d.inSeconds.remainder(60).toString().padLeft(2,'0')}';
 Widget _discArt(){
  Widget img;
  if(widget.art!=null&&widget.art!.isNotEmpty){
   img=Image.memory(widget.art!,width:130,height:130,fit:BoxFit.cover,gaplessPlayback:true);}
  else{img=Image.asset('assets/images/default_cover.png',width:130,height:130,fit:BoxFit.cover);}
  return Container(width:155,height:155,decoration:BoxDecoration(
   shape:BoxShape.circle,color:Colors.black,
   border:Border.all(color:widget.live?Colors.white24:Colors.white10,width:1)),
   child:ClipOval(child:Stack(fit:StackFit.expand,children:[
    img,CustomPaint(painter:_Grooves()),
    Center(child:Container(width:60,height:60,
     decoration:const BoxDecoration(shape:BoxShape.circle,color:Color(0xFF101010)),
     child:Container(margin:const EdgeInsets.all(2),
      decoration:BoxDecoration(shape:BoxShape.circle,
       border:Border.all(color:widget.live?Color(0xFFCEBBFF):Colors.white24,width:1.2)))))])));}

 @override Widget build(c)=>Column(mainAxisAlignment:
  widget.lift?MainAxisAlignment.start:MainAxisAlignment.center,children:[
  Text('DECK ${widget.deck==Deck.a?'A':'B'} ${widget.live?'(LIVE)':widget.next?'(NEXT)':''}',
   style:TextStyle(fontSize:11,fontWeight:FontWeight.bold,
    color:widget.live?const Color(0xFFCEBBFF):Colors.white70)),
  SizedBox(width:195,height:195,child:Stack(alignment:Alignment.center,children:[
   RotationTransition(turns:ReverseTween(begin:0,end:1).animate(ring),
    child:CustomPaint(size:const Size(195,195),
     painter:_RingLight(isLive:widget.live,playing:widget.player.playing))),
   RotationTransition(turns:disc,child:_discArt()),
   StreamBuilder<bool>(stream:widget.player.playingStream,initialData:widget.player.playing,
    builder:(ctx,snap){bool pl=snap.data??false;
     return Material(color:Colors.transparent,shape:const CircleBorder(),
      child:InkWell(customBorder:const CircleBorder(),onTap:widget.onPlay,
       child:Container(width:54,height:54,alignment:Alignment.center,
        decoration:BoxDecoration(shape:BoxShape.circle,color:const Color(0xFFCEBBFF),
         boxShadow:[BoxShadow(blurRadius:10,color:const Color(0xFFCEBBFF).withOpacity(0.5))]),
        child:Icon(pl?Icons.pause:Icons.play_arrow,size:30,color:Colors.black))));}),
  ])),
  const SizedBox(height:2),
  Text(widget.name,style:const TextStyle(fontSize:11),maxLines:1,overflow:TextOverflow.ellipsis),
  StreamBuilder<Duration>(stream:widget.player.positionStream,builder:(c,s){
   var p=s.data??Duration.zero;var du=widget.player.duration;
   var show=du??const Duration(seconds:1);if(p>show) show=p+const Duration(seconds:1);
   double pr=show.inMilliseconds>0?p.inMilliseconds/show.inMilliseconds:0;pr=pr.clamp(0.0,1.0);
   return Column(children:[SizedBox(height:20,child:Slider(value:pr,min:0,max:1,
     activeColor:widget.live?const Color(0xFFCEBBFF):Colors.white38,
     onChanged:(v) async{await widget.player.seek(Duration(
      milliseconds:(v*show.inMilliseconds).round()));})),
    Text('${_fmt(p)} / ${_fmt(du??Duration.zero)}',style:const TextStyle(fontSize:10,color:Colors.white38)),
    Row(mainAxisAlignment:MainAxisAlignment.center,children:[
     IconButton(iconSize:26,icon:const Icon(Icons.skip_previous),onPressed:widget.onPrev),
     IconButton(iconSize:26,icon:const Icon(Icons.replay_10),onPressed:()=>widget.onSeek(-10)),
     IconButton(iconSize:26,icon:const Icon(Icons.folder_open),onPressed:widget.onPick),
     IconButton(iconSize:26,icon:const Icon(Icons.forward_10),onPressed:()=>widget.onSeek(10)),
     IconButton(iconSize:26,icon:const Icon(Icons.skip_next),onPressed:widget.onNext)])]);})]);}

class _RingLight extends CustomPainter{
 final bool isLive,playing;_RingLight({required this.isLive,required this.playing});
 @override void paint(Canvas cv,Size sz){
  var ct=Offset(sz.width/2,sz.height/2);var rad=sz.width/2;
  if(!isLive){cv.drawCircle(ct,rad,Paint()..style=PaintingStyle.stroke..strokeWidth=2
..color=Colors.white12);return;}
  var ringPaint=Paint()..style=PaintingStyle.stroke..strokeWidth=5
..shader=SweepGradient(colors:const[
    Color(0xFF087BFF),Color(0xFF111111),Color(0xFFFF7A00),
    Color(0xFF111111),Color(0xFF087BFF)])
.createShader(Rect.fromCircle(center:ct,radius:rad));
  cv.drawCircle(ct,rad-2,ringPaint);
  if(playing){var glow=Paint()..style=PaintingStyle.stroke..strokeWidth=12
..color=const Color(0xFFCEBBFF).withOpacity(0.22)
..maskFilter=const MaskFilter.blur(BlurStyle.normal,8);
   cv.drawCircle(ct,rad-2,glow);}}
 @override bool shouldRepaint(covariant _RingLight o)=>o.isLive!=isLive||o.playing!=playing;}
class _Grooves extends CustomPainter{
 @override void paint(Canvas cv,Size sz){
  var ct=Offset(sz.width/2,sz.height/2);var rad=sz.width/2;
  var p=Paint()..style=PaintingStyle.stroke..strokeWidth=1
..color=Colors.white.withOpacity(0.06);
  for(double r=20;r<rad-5;r+=5) cv.drawCircle(ct,r,p);}
 @override bool shouldRepaint(covariant CustomPainter old)=>false;}
class ReverseTween extends Tween<double>{
 ReverseTween({required double begin,required double end}):super(begin:begin,end:end);
 @override double lerp(double t)=>super.lerp(1.0-t);}
