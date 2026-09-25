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
 String? na,nb;Uint8List? aa,ab;
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
  sb=pb.positionStream.listen((p)=>_ck(Deck.b,p));}
 @override void dispose(){
  sa?.cancel();sb?.cancel();pa.dispose();pb.dispose();
  super.dispose();}
 Track? _next(){if(q.isEmpty) return null;
  var t=q[qi%q.length];qi=(qi+1)%q.length;return t;}
 Future<Uint8List?> _art(String p) async{try{
   var t=await AudioTags.read(p);
   if(t!=null&&t.pictures.isNotEmpty)
    return t.pictures.first.bytes;
  }catch(_){}return null;}
 Future<bool> _load(Deck d,Track t,{bool play=false}) async{
  var pl=P(d);SN(d,t.n);SA(d,null);setState((){});
  try{await pl.stop();await pl.setFilePath(t.p);
   var du=pl.duration;
   if(du!=null&&du>trim) await pl.seek(trim);
   else await pl.seek(Duration.zero);
   await pl.pause();
  }catch(e){_msg('Load fail');return false;}
  _art(t.p).then((i){if(!mounted) return;
   SA(d,i);setState((){});});
  await pl.setVolume(play?1.0:0.0);
  if(play) await _live(d,play:true);
  setState((){});return true;}
 Future _live(Deck d,{bool play=false}) async{
  live=d;xfad=d==Deck.a?0.0:1.0;
  await P(O(d)).setVolume(0.0);
  await P(d).setVolume(1.0);
  if(play) await P(d).play();setState((){});}
 Future _prep() async{if(q.isEmpty||xf) return;
  var nd=O(live);if(N(nd)!=null) return;
  var nx=_next();if(nx==null) return;
  await _load(nd,nx,play:false);}
 Future _auto() async{if(q.isEmpty){
   _msg('Add music first');return;}
  if(N(live)==null){var f=_next();
   if(f==null) return;await _load(live,f,play:true);}
  else{var pl=P(live);if(!pl.playing) await pl.play();}
  await _prep();setState((){});}
 // FIX: preload 15s, fade 10s, works even when auto OFF if NEXT loaded
 void _ck(Deck d,Duration p){if(!mounted||xf) return;
  if(d!=live) return;var pl=P(d);if(!pl.playing) return;
  var du=pl.duration;if(du==null) return;
  var rem=du-p;
  if(rem<=preT&&N(O(d))==null&&auto&&q.isNotEmpty){
   unawaited(_prep());}
  if(rem<=fadeT&&N(O(d))!=null){
   unawaited(_fade(O(d)));}}
 Future _fade(Deck tar) async{if(xf) return;
  if(N(tar)==null) return;var src=live;
  if(src==tar) return;var sp=P(src),tp=P(tar);
  xf=true;try{
   await tp.seek(trim);await tp.setVolume(0.0);
   await tp.play();
   const st=100;
   var dl=Duration(milliseconds:fadeT.inMilliseconds~/st);
   for(int i=1;i<=st;i++){var v=i/st;
    var sv=m.cos(v*m.pi/2),tv=m.sin(v*m.pi/2);
    await sp.setVolume(sv.toDouble());
    await tp.setVolume(tv.toDouble());
    xfad=src==Deck.a?v:1.0-v;
    if(mounted) setState((){});
    await Future.delayed(dl);}
   await sp.setVolume(0.0);await tp.setVolume(1.0);
   await sp.stop();await sp.seek(trim);await sp.pause();
   SN(src,null);SA(src,null);live=tar;
  }catch(e){_msg('Crossfade failed: $e');}
  finally{xf=false;setState((){});if(auto) await _prep();}}
 Future _tog(Deck d) async{if(xf) return;var pl=P(d);
  try{if(pl.playing){await pl.pause();setState((){});return;}
   if(N(d)==null){if(q.isEmpty){_msg('Add file');return;}
    var t=_next();if(t==null) return;
    await _load(d,t,play:d==live);if(d==live) await _prep();
    return;}
   if(d!=live&&N(live)!=null){await _fade(d);return;}
   live=d;xfad=d==Deck.a?0.0:1.0;
   await P(O(d)).setVolume(0.0);
   await pl.setVolume(1.0);await pl.play();
   if(auto) await _prep();setState((){});
  }catch(e){_msg('Play err');}}
 Future _pick(Deck d) async{var r=await FilePicker.platform
   .pickFiles(type:FileType.audio);if(r==null) return;
  var p=r.files.single.path;if(p==null) return;
  var t=Track(p,r.files.single.name);
  await _load(d,t,play:true);live=d;
  if(auto) await _prep();setState((){});}
 Future _aq() async{var r=await FilePicker.platform.pickFiles(
   type:FileType.audio,allowMultiple:true);if(r==null) return;
  var ts=r.files.where((f)=>f.path!=null)
   .map((f)=>Track(f.path!,f.name)).toList();
  if(ts.isEmpty) return;setState(()=>q.addAll(ts));
  if(auto) await _auto();}
 Future _nextD(Deck d) async{if(q.isEmpty||xf) return;
  var t=_next();if(t==null) return;
  await _load(d,t,play:d==live);}
 Future _prevD(Deck d) async{if(q.isEmpty||xf) return;
  qi=(qi-2+q.length)%q.length;var t=q[qi%q.length];
  qi=(qi+1)%q.length;await _load(d,t,play:d==live);}
 Future _seek(Deck d,int s) async{var pl=P(d);
  var p=pl.position+Duration(seconds:s);
  if(p<Duration.zero) p=Duration.zero;
  var du=pl.duration;if(du!=null&&p>du) p=du;
  await pl.seek(p);}
 Future _setX(double v) async{if(xf) return;xfad=v;
  await pa.setVolume((1.0-v).clamp(0.0,1.0));
  await pb.setVolume(v.clamp(0.0,1.0));
  live=v>=0.5?Deck.b:Deck.a;setState((){});}
 void _msg(String t){if(!mounted) return;
  ScaffoldMessenger.of(context)..hideCurrentSnackBar()
   ..showSnackBar(SnackBar(content:Text(t)));}
 Widget _deck(Deck d)=>DeckView(deck:d,player:P(d),
  name:N(d)??'No track',art:A(d),live:live==d,
  next:live!=d&&N(d)!=null,onPlay:()=>_tog(d),
  onPick:()=>_pick(d),onPrev:()=>_prevD(d),
  onNext:()=>_nextD(d),onSeek:(s)=>_seek(d,s));
 @override Widget build(c)=>Scaffold(
  appBar:AppBar(title:const Text('BlendJam',
   style:TextStyle(fontSize:26)),actions:[
   const Text('AUTO'),Switch(value:auto,activeColor:pu,
    onChanged:(v) async{setState(()=>auto=v);
     if(v) await _auto();}),
   const SizedBox(width:8)]),
  body:ListView(padding:const EdgeInsets.all(14),children:[
   _deck(Deck.a),const SizedBox(height:4),
   Row(children:[const Text('A'),Expanded(child:Slider(
     value:xfad.clamp(0.0,1.0),min:0,max:1,
     activeColor:pu,onChanged:_setX)),const Text('B')]),
   Center(child:Text(xf?'MIXING ${(xfad*100).toInt()}%':'',
    style:const TextStyle(color:pu))),
   const SizedBox(height:8),_deck(Deck.b),
   const SizedBox(height:12),
   Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
    Text('QUEUE ${q.length}'),IconButton(
     icon:const Icon(Icons.add_circle),onPressed:_aq)]),
   ...q.asMap().entries.map((e)=>ListTile(dense:true,
    leading:Text('${e.key+1}'),title:Text(e.value.n,
     maxLines:1,overflow:TextOverflow.ellipsis,
     style:const TextStyle(fontSize:13)))) ]));}

class DeckView extends StatefulWidget{
 final Deck deck;final AudioPlayer player;
 final String name;final Uint8List? art;
 final bool live,next;
 final VoidCallback onPlay,onPick,onPrev,onNext;
 final Future<void> Function(int) onSeek;
 const DeckView({super.key,required this.deck,
  required this.player,required this.name,
  required this.art,required this.live,
  required this.next,required this.onPlay,
  required this.onPick,required this.onPrev,
  required this.onNext,required this.onSeek});
 @override State<DeckView> createState()=>_DV();}
class _DV extends State<DeckView>
 with SingleTickerProviderStateMixin{
 late AnimationController rot;
 StreamSubscription<PlayerState>? subs;
 @override void initState(){super.initState();
  rot=AnimationController(vsync:this,
   duration:const Duration(seconds:3));
  subs=widget.player.playerStateStream.listen((s){
   if(!mounted) return;if(s.playing) rot.repeat();
   else rot.stop();});}
 @override void dispose(){subs?.cancel();rot.dispose();super.dispose();}
 String _fmt(Duration d)=>'${d.inMinutes.remainder(60).toString().padLeft(2,'0')}:'
  '${d.inSeconds.remainder(60).toString().padLeft(2,'0')}';
 // FIX ART + RING ALLOWANCE: art 160, ring 220, hollow 74
 Widget _discArt(){
  Widget base;
  if(widget.art!=null&&widget.art!.isNotEmpty){
   base=ClipOval(child:Image.memory(
    widget.art!,width:160,height:160,
    fit:BoxFit.cover,gaplessPlayback:true));}
  else{
   base=ClipOval(child:Image.asset(
    'assets/images/default_cover.png',
    width:160,height:160,fit:BoxFit.cover));}
  return Container(width:190,height:190,
   decoration:BoxDecoration(shape:BoxShape.circle,
    color:Colors.black,
    border:Border.all(color:widget.live?const Color(0xFFCEBBFF):Colors.white24,width:2)),
   child:Stack(alignment:Alignment.center,children:[
    base,
    // inner hollow so ring not covered by art
    Container(width:74,height:74,decoration:const BoxDecoration(
     shape:BoxShape.circle,color:Color(0xFF101010))),
   ]));}
 @override Widget build(c)=>Column(children:[
  Text('DECK ${widget.deck==Deck.a?'A':'B'} '
   '${widget.live?'(LIVE)':widget.next?'(NEXT)':''}',
   style:TextStyle(fontWeight:FontWeight.bold,
    color:widget.live?const Color(0xFFCEBBFF):Colors.white70)),
  const SizedBox(height:8),
  SizedBox(width:220,height:220,
   child:Stack(alignment:Alignment.center,children:[
    // RING LIGHT OUTER - 220 allowance so art does not conceal
    Container(width:220,height:220,decoration:BoxDecoration(
     shape:BoxShape.circle,
     border:Border.all(color:widget.live?const Color(0xFFCEBBFF):Colors.transparent,width:3),
     boxShadow:widget.live?[BoxShadow(blurRadius:18,
      color:const Color(0xFFCEBBFF).withOpacity(0.6))]:null)),
    RotationTransition(turns:rot,child:_discArt()),
    StreamBuilder<bool>(stream:widget.player.playingStream,
     initialData:widget.player.playing,
     builder:(ctx,snap){bool pl=snap.data??false;
      return Material(color:Colors.transparent,shape:const CircleBorder(),
       child:InkWell(customBorder:const CircleBorder(),
        onTap:widget.onPlay,child:Container(width:68,height:68,
         alignment:Alignment.center,decoration:BoxDecoration(
          shape:BoxShape.circle,color:const Color(0xFFCEBBFF),
          boxShadow:[BoxShadow(blurRadius:10,spreadRadius:1,
           color:const Color(0xFFCEBBFF).withOpacity(0.45))]),
         child:Icon(pl?Icons.pause:Icons.play_arrow,
          size:38,color:Colors.black))));}),
  ])),
  const SizedBox(height:8),
  Text(widget.name,style:const TextStyle(fontSize:13),
   maxLines:1,overflow:TextOverflow.ellipsis),
  StreamBuilder<Duration>(stream:widget.player.positionStream,
   builder:(c,s){var p=s.data??Duration.zero;
    var du=widget.player.duration??const Duration(seconds:1);
    double pr=du.inMilliseconds>0?p.inMilliseconds/du.inMilliseconds:0;
    pr=pr.clamp(0.0,1.0);
    return Column(children:[Slider(value:pr,min:0,max:1,
      activeColor:widget.live?const Color(0xFFCEBBFF):Colors.white54,
      onChanged:(v) async{await widget.player.seek(Duration(
       milliseconds:(v*du.inMilliseconds).round()));}),
     Text('${_fmt(p)} / ${_fmt(du)}',style:const TextStyle(
      fontSize:11,color:Colors.white38)),
     Row(mainAxisAlignment:MainAxisAlignment.center,children:[
      IconButton(icon:const Icon(Icons.skip_previous),onPressed:widget.onPrev),
      IconButton(icon:const Icon(Icons.replay_10),onPressed:()=>widget.onSeek(-10)),
      IconButton(icon:const Icon(Icons.folder_open),onPressed:widget.onPick),
      IconButton(icon:const Icon(Icons.forward_10),onPressed:()=>widget.onSeek(10)),
      IconButton(icon:const Icon(Icons.skip_next),onPressed:widget.onNext)])]);})]);}
