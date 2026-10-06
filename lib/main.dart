import 'dart:async';import 'dart:math' as m;import 'dart:typed_data';import 'package:audiotags/audiotags.dart';
import 'package:file_picker/file_picker.dart';import 'package:flutter/material.dart';import 'package:just_audio/just_audio.dart';
void main()=>runApp(MaterialApp(theme:ThemeData.dark(),home:DJ()));class T{String p,n;T(this.p,this.n);}enum D{a,b}
class DJ extends StatefulWidget{const DJ({super.key});@override State<DJ>createState()=>S();}
class S extends State<DJ>{static const C=Color(0xFFCEBBFF);final a=AudioPlayer(),b=AudioPlayer();
String?na,nb;Uint8List?aa,ab;D l=D.a;bool au=false,xf=false;double xv=0;List<T>q=[];int qi=0;Timer?tk;
P(d)=>d==D.a?a:b;O(d)=>d==D.a?D.b:D.a;N(d)=>d==D.a?na:nb;A(d)=>d==D.a?aa:ab;SN(d,v){d==D.a?na=v:nb=v;}SA(d,v){d==D.a?aa=v:ab=v;}
@override void initState(){super.initState();a.positionStream.listen((p)=>_ck(D.a,p));b.positionStream.listen((p)=>_ck(D.b,p));
tk=Timer.periodic(Duration(milliseconds:400),(_){if(!mounted||xf||!au)return;var pl=P(l);var du=pl.duration;if(du==null)return;
var r=du-pl.position;if(r<=Duration(seconds:10)&&N(O(l))!=null)_fd(O(l));else if(r<=Duration(seconds:15)&&N(O(l))==null)_pr();});}
@override void dispose(){tk?.cancel();a.dispose();b.dispose();super.dispose();}
void _ck(D d,Duration p){if(!mounted||xf||!au||d!=l)return;var pl=P(d);if(!pl.playing)return;var du=pl.duration;if(du==null)return;
var rem=du-Duration(milliseconds:350)-p;if(rem<=Duration(seconds:15)&&rem>=Duration.zero&&N(O(d))==null)_pr();
if(rem<=Duration(seconds:10)&&rem>=Duration.zero&&N(O(d))!=null)_fd(O(d));}
T?_nx(){if(q.isEmpty)return null;var t=q[qi%q.length];qi=(qi+1)%q.length;return t;}
Future<Uint8List?>_ar(String p)async{try{var t=await AudioTags.read(p);if(t!=null&&t.pictures.isNotEmpty)return t.pictures.first.bytes;}catch(_){}return null;}
Future _ld(D d,T t,{bool lp=false})async{var pl=P(d);SN(d,t.n);SA(d,null);setState((){});try{await pl.stop();await pl.setFilePath(t.p);
await pl.seek(Duration(milliseconds:350));await pl.setVolume(d==l?1:0);if(lp&&d==l)await pl.play();else await pl.pause();}catch(_){}
_ar(t.p).then((i){if(mounted){SA(d,i);setState((){});}});setState((){});}
Future _pr()async{if(q.isEmpty||xf||N(O(l))!=null)return;var x=_nx();if(x!=null)await _ld(O(l),x);}
Future _au()async{if(N(l)==null){var f=_nx();if(f!=null)await _ld(l,f,lp:true);}await _pr();setState((){});}
Future _fd(D t)async{if(xf||N(t)==null)return;var s=l,sp=P(s),tp=P(t);xf=true;setState((){});try{
await tp.seek(Duration(milliseconds:350));await tp.setVolume(0);await tp.pause();for(int i=1;i<=100;i++){var v=i/100;if(i==10)tp.play();
xv=s==D.a?v:1-v;setState((){});try{sp.setVolume(m.cos(v*m.pi/2));tp.setVolume(m.sin(v*m.pi/2));}catch(_){}
await Future.delayed(Duration(milliseconds:100));}}finally{try{await sp.stop();await tp.setVolume(1);}catch(_){}
SN(s,null);SA(s,null);l=t;xv=t==D.a?0:1;xf=false;setState((){});if(au)await _pr();}}
Future _tg(D d)async{if(xf)return;var pl=P(d);if(pl.playing){await pl.pause();setState((){});return;}
if(N(d)==null){var t=_nx();if(t!=null){await _ld(d,t,lp:true);l=d;setState((){});}return;}if(d!=l){await _fd(d);return;}await pl.play();setState((){});}
Future _pk(D d)async{var r=await FilePicker.platform.pickFiles(type:FileType.audio);if(r==null)return;var p=r.files.single.path;
if(p!=null){await _ld(d,T(p,r.files.single.name),lp:true);l=d;setState((){});}}
Future _aq()async{var r=await FilePicker.platform.pickFiles(type:FileType.audio,allowMultiple:true);if(r==null)return;
setState(()=>q.addAll(r.files.where((f)=>f.path!=null).map((f)=>T(f.path!,f.name))));if(au)await _au();}
Future _sx(double v)async{if(xf)return;xv=v;a.setVolume(1-v);b.setVolume(v);l=v>=0.5?D.b:D.a;setState((){});}
void _qp(){showModalBottomSheet(context:context,builder:(c)=>SafeArea(child:Column(children:[ListTile(title:Text('QUEUE ${q.length}'),
trailing:Row(mainAxisSize:MainAxisSize.min,children:[IconButton(icon:Icon(Icons.add),onPressed:()async{await _aq();Navigator.pop(c);_qp();}),
IconButton(icon:Icon(Icons.close),onPressed:()=>Navigator.pop(c))])),Expanded(child:ListView.builder(itemCount:q.length,itemBuilder:(x,i){
var live=N(l)==q[i].n;return ListTile(dense
