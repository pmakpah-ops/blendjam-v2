import 'dart:async';
import 'dart:math' as m;
import 'dart:typed_data';
import 'package:audiotags/audiotags.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
void main()=>runApp(const BlendJamApp());
class BlendJamApp extends StatelessWidget{
 const BlendJamApp({super.key});
 @override Widget build(BuildContext c){
  return MaterialApp(
   debugShowCheckedModeBanner:false,
   theme:ThemeData.dark(),home:const DJ());}}
class Track{final String p,n;const Track(this.p,this.n);}
enum Deck{a,b}
class DJ extends StatefulWidget{
 const DJ({super.key});@override State<DJ> createState()=>_S();}
class _S extends State<DJ>{
 static const pu=Color(0xFFCEBBFF);
 static const fadeT=Duration(seconds:10);
 static const preT=Duration(seconds:15);
 static const trim=Duration(milliseconds:350);
 final pa=AudioPlayer();final pb=AudioPlayer();
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
 @override void initState(){
  super.initState();
  sa=pa.positionStream.listen((p)=>_ck(Deck.a,p));
  sb=pb.positionStream.listen((p)=>_ck(Deck.b,p));
  ca=pa.playerStateStream.listen((s)=>_done(Deck.a,s));
  cb=pb.playerStateStream.listen((s)=>_done(Deck.b,s));
  tk=Timer.periodic(const Duration(milliseconds:400),(_){
   if(!mounted||xf||!auto) return;
   var pl=P(live);var du=pl.duration;if(du==null) return;
   var eff=du>trim?du-trim:du;var rem=eff-pl.position;
   if(rem<=fadeT&&N(O(live))!=null)_fade(O(live));
   else if(rem<=preT&&N(O(live))==null)_prep();});}
 @override void dispose(){
  tk?.cancel();sa?.cancel();sb?.cancel();
  ca?.cancel();cb?.cancel();pa.dispose();pb.dispose();
  super.dispose();}
 void _done(Deck d,PlayerState s){
  if(s.processingState==ProcessingState.completed){
   if(d==live&&N(O(d))!=null&&!xf){_fade(O(d));return;}
   if(d!=live){SN(d,null);SA(d,null);setState((){});return;}
   if(d==live&&N(O(d))==null){SN(d,null);SA(d,null);setState((){});}}}
 Track? _next(){
  if(q.isEmpty) return null;
  var t=q[qi%q.length];qi=(qi+1)%q.length;return t;}
 Future<Uint8List?> _art(String p) async{try{
  var t=await AudioTags.read(p);
  if(t!=null&&t.pictures.isNotEmpty)return t.pictures.first.bytes;
 }catch(_){}return null;}
 Future<bool> _load(Deck d,Track t,{bool livePlay=false}) async{
  var pl=P(d);SN(d,t.n);SA(d,null);setState((){});
  try{
   await pl.stop();await pl.setFilePath(t.p);
   var du=pl.duration;
   var st=du!=null&&du>trim?trim:Duration.zero;
   await pl.seek(st);await pl.setVolume(d==live?1.0:0.0);
   if(livePlay&&d==live)await pl.play();else await pl.pause();
  }catch(e){_msg('Load fail');return false;}
  _art(t.p).then((i){if(mounted){SA(d,i);setState((){});}});
  setState((){});return true;}
 Future _prep() async{
  if(q.isEmpty||xf)return;if(N(O(live))!=null)return;
  var nx=_next();if(nx==null)return;
  await _load(O(live),nx,livePlay:false);}
 Future _auto() async{
  if(q.isEmpty){_msg('Add music');return;}
  if(N(live)==null){
   var f=_next();if(f==null)return;
   await _load(live,f,livePlay:true);
  }else{var pl=P(live);if(!pl.playing)await pl.play();}
  await _prep();setState((){});}
 void _ck(Deck d,Duration p){
  if(!mounted||xf||!auto)return;if(d!=live)return;
  var pl=P(d);if(!pl.playing)return;
  var du=pl.duration;if(du==null)return;
  var eff=du>trim?du-trim:du;var rem=eff-p;
  if(rem<=preT&&rem>=Duration.zero&&N(O(d))==null)_prep();
  if(rem<=fadeT&&rem>=Duration.zero&&N(O(d))!=null)_fade(O(d));}
 Future _fade(Deck tar) async{
  if(xf||N(tar)==null)return;var src=live;if(src==tar)return;
  var sp=P(src),tp=P(tar);xf=true;setState((){});
  try{
   await tp.seek(trim);await tp.setVolume(0.0);await tp.pause();
   const st=100;
   var dl=Duration(milliseconds:fadeT.inMilliseconds~/st);
   for(int i=1;i<=st;i++){
    var v=i/st;if(i==10){tp.play();}
    xfad=src==Deck.a?v:1.0-v;if(mounted)setState((){});
    try{var sv=m.cos(v*m.pi/2);var tv=m.sin(v*m.pi/2);
     sp.setVolume(sv);tp.setVolume(tv);}catch(_){}
    await Future.delayed(dl);}
  }catch(e){}finally{
   try{await sp.stop();await sp.seek(trim);
    await sp.setVolume(0.0);await tp.setVolume(1.0);}catch(_){}
   SN(src,null);SA(src,null);live=tar;
   xfad=tar==Deck.a?0.0:1.0;xf=false;
   if(mounted)setState((){});if(auto)await _prep();}}
 Future _tog(Deck d) async{
  if(xf)return;var pl=P(d);
  try{
   if(pl.playing){await pl.pause();setState((){});return;}
   if(N(d)==null){
    if(q.isEmpty){_msg('Add file');return;}
    var t=_next();if(t==null)return;
    await _load(d,t,livePlay:true);live=d;setState((){});return;}
   if(d!=live&&N(d)!=null){await _fade(d);return;}
   live=d;xfad=d==Deck.a?0.0:1.0;
   await P(O(d)).setVolume(0.0);await P(O(d)).pause();
   await pl.setVolume(1.0);await pl.play();
   if(auto)await _prep();setState((){});
  }catch(e){_msg('Play err');}}
 Future _pick(Deck d) async{
  var r=await FilePicker.platform.pickFiles(type:FileType.audio);
  if(r==null)return;var p=r.files.single.path;if(p==null)return;
  await _load(d,Track(p,r.files.single.name),livePlay:true);
  live=d;if(auto)await _prep();setState((){});}
 Future _aq() async{
  var r=await FilePicker.platform.pickFiles(
   type:FileType.audio,allowMultiple:true);
  if(r==null)return;
  var ts=r.files.where((f)=>f.path!=null)
   .map((f)=>Track(f.path!,f.name)).toList();
  if(ts.isEmpty)return;setState(()=>q.addAll(ts));if(auto)await _auto();}
 Future _nextD(Deck d) async{
  if(q.isEmpty||xf)return;var t=_next();if(t==null)return;
  await _load(d,t,livePlay:d==live);}
 Future _prevD(Deck d) async{
  if(q.isEmpty||xf)return;
  qi=(qi-2+q.length)%q.length;var t=q[qi%q.length];
  qi=(qi+1)%q.length;await _load(d,t,livePlay:d==live);}
 Future _seek(Deck d,int s) async
