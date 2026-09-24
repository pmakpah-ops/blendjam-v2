import 'dart:async';import 'dart:math' as m;import 'dart:typed_data';import 'package:audiotags/audiotags.dart';import 'package:file_picker/file_picker.dart';import 'package:flutter/material.dart';import 'package:just_audio/just_audio.dart';import 'widgets/deck_light_ring.dart';
void main()=>runApp(MaterialApp(debugShowCheckedModeBanner:false,theme:ThemeData.dark(),home:DJ()));
class Q{String p,n;Q(this.p,this.n);}enum D{a,b}
class DJ extends StatefulWidget{const DJ({super.key});@override State<DJ> createState()=>_S();}
class _S extends State<DJ>{final a=AudioPlayer(),b=AudioPlayer();String? na,nb;Uint8List? aa,ab;double x=0;bool au=false,xg=false;D lv=D.a;List<Q> q=[];int qp=0;bool ar=false;
AudioPlayer P(D d)=>d==D.a?a:b;D O(D d)=>d==D.a?D.b:D.a;String? N(D d)=>d==D.a?na:nb;Uint8List? A(D d)=>d==D.a?aa:ab;
void SN(D d,String? v){d==D.a?na=v:nb=v;}void SA(D d,Uint8List? v){d==D.a?aa=v:ab=v;}
@override void initState(){super.initState();a.positionStream.listen((p)=>_ck(D.a,p));b.positionStream.listen((p)=>_ck(D.b,p));}
@override void dispose(){a.dispose();b.dispose();super.dispose();}
Q? _nl(){if(q.isEmpty) return null;var t=q[qp%q.length];qp=(qp+1)%q.length;return t;}
Future<Uint8List?> _art(String p) async{try{var t=await AudioTags.read(p);if(t!=null&&t.pictures.isNotEmpty) return t.pictures.first.bytes;}catch(_){}return null;}
Future<void> _ld(D d,Q t,{bool play=false}) async{SN(d,t.n);SA(d,null);setState((){});var pl=P(d);await pl.stop();await pl.setFilePath(t.p);await pl.seek(const Duration(milliseconds:200));_art(t.p).then((b){SA(d,b);if(mounted) setState((){});});await pl.setVolume(play?1:0);await pl.setSpeed(1);if(play){lv=d;x=d==D.a?0:1;await pl.play();}setState((){});}
Future<void> _as() async{if(q.isEmpty) return;if(N(lv)==null) await _ld(lv,_nl()!,play:true);if(N(O(lv))==null) await _ld(O(lv),_nl()!);}
void _ck(D d,Duration p){if(xg||ar) return;if(d!=lv) return;var du=P(d).duration;if(du==null||!P(d).playing) return;var r=du-p;if(au&&r.inSeconds==15){var f=O(lv);if(N(f)==null) _ld(f,_nl()!);}if(r.inSeconds<=10&&r.inSeconds>=9){if(N(D.a)!=null&&N(D.b)!=null){ar=true;_fade();}}}
void _fade(){if(xg) return;var s=lv,t=O(s);if(N(t)==null){ar=false;return;}xg=true;var sp=P(s),tp=P(t);tp.setVolume(0);tp.setSpeed(1);tp.play();int k=0;const tot=100;Timer.periodic(const Duration(milliseconds:60),(tm) async{k++;double lin=k/tot;if(lin>1) lin=1;double srcV=m.cos(lin*m.pi/2);double tgtV=m.sin(lin*m.pi/2);x=s==D.a?lin:1-lin;await sp.setVolume(srcV);await tp.setVolume(tgtV);if(mounted) setState((){});if(k>=tot){tm.cancel();x=s==D.a?1:0;await sp.setVolume(0);await tp.setVolume(1);await sp.stop();SN(s,null);SA(s,null);lv=t;xg=false;ar=false;if(mounted) setState((){});if(au&&N(O(lv))==null&&q.isNotEmpty) _ld(O(lv),_nl()!);}});}
Future<void> _pk(bool isA) async{var r=await FilePicker.platform.pickFiles(type:FileType.audio);if(r==null) return;var tg=P(lv).playing?O(lv):(isA?D.a:D.b);await _ld(tg,Q(r.files.single.path!,r.files.single.name));}
Future<void> _aq() async{var r=await FilePicker.platform.pickFiles(type:FileType.audio,allowMultiple:true);if(r==null) return;setState(()=>q.addAll(r.files.where((f)=>f.path!=null).map((f)=>Q(f.path!,f.name))));}
Future<void> _nx(D d) async{if(q.isEmpty) return;await _ld(d,_nl()!);}
Future<void> _pv(D d) async{if(q.isEmpty) return;qp=(qp-2+q.length)%q.length;var t=q[qp%q.length];qp=(qp+1)%q.length;await _ld(d,t);}
Widget _disc(bool isA){var d=isA?D.a:D.b;var pl=P(d);return _V(d:d,pl:pl,na:N(d)??'No track selected',ar:A(d),live:lv==d,nxt:O(lv)==d&&N(d)!=null,onPk:()=>_pk(isA),onPP:()async{if(pl.playing){await pl.pause();}else{if(N(d)==null&&q.isNotEmpty){await _ld(d,_nl()!,play:true);}else{lv=d;x=d==D.a?0:1;pl.setVolume(1);await pl.setSpeed(1);P(O(d)).setVolume(0);await pl.play();}setState((){});}},onNext:()=>_nx(d),onPrev:()=>_pv(d),onF:(int s) async{var p=pl.position+Duration(seconds:s);if(p<Duration.zero) p=Duration.zero;await pl.seek(p);});}
@override Widget build(BuildContext c){return Scaffold(appBar:AppBar(title:const
