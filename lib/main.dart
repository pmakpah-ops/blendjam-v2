import 'dart:async';import 'dart:math' as m;import 'dart:typed_data';import 'package:audiotags/audiotags.dart';
import 'package:file_picker/file_picker.dart';import 'package:flutter/material.dart';import 'package:just_audio/just_audio.dart';
void main()=>runApp(MaterialApp(theme:ThemeData.dark(),home:DJ()));class T{String p,n;T(this.p,this.n);}enum D{a,b}
class DJ extends StatefulWidget{const DJ({super.key});@override State<DJ>createState()=>S();}
class S extends State<DJ>{static const C=Color(0xFFCEBBFF);final a=AudioPlayer(),b=AudioPlayer();
String?na,nb;Uint8List?aa,ab;D l=D.a;bool au=false,xf=false,ld=false;double xv=0;List<T>q=[];int qi=0;Timer?tk;
P(d)=>d==D.a?a:b;O(d)=>d==D.a?D.b:D.a;N(d)=>d==D.a?na:nb;A(d)=>d==D.a?aa:ab;SN(d,v){d==D.a?na=v:nb=v;}SA(d,v){d==D.a?aa=v:ab=v;}
@override void initState(){super.initState();
a.playerStateStream.listen((s){if(s.processingState==ProcessingState.completed){if(xf&&N(O(l))!=null)_force(O(l));else _hn(l);}});
b.playerStateStream.listen((s){if(s.processingState==ProcessingState.completed){if(xf&&N(O(l))!=null)_force(O(l));else _hn(l);}});
tk=Timer.periodic(Duration(milliseconds:200),(_){_tick();});}
void _tick()async{if(!mounted||xf||ld)return;bool both=N(D.a)!=null&&N(D.b)!=null;if(!au&&!both)return;
var pl=P(l);var du=pl.duration;if(du==null)return;var pos=pl.position.inMilliseconds;var rem=du.inMilliseconds-pos;if(rem<0)rem=0;
var nd=O(l);if(N(nd)==null&&rem<=15000)await _pr();if(N(nd)!=null&&rem<=10000&&rem>=0)await _fd(nd);}
@override void dispose(){tk?.cancel();a.dispose();b.dispose();super.dispose();}
void _force(D t){if(t==l||N(t)==null)return;xf=false;ld=false;l=t;xv=t==D.a?0:1;try{P(t).setVolume(1);P(O(t)).setVolume(0);}catch(_){}
SN(O(t),null);SA(O(t),null);if(mounted)setState((){});}
void _hn(D d)async{if(xf||ld)return;var nd=O(d);if(N(nd)==null&&au){var n=_nx();if(n!=null)await _ld(nd,n);}if(N(O(l))!=null&&!xf)await _fd(O(l));}
T?_nx(){if(q.isEmpty)return null;var t=q[qi%q.length];qi=(qi+1)%q.length;return t;}
Future<Uint8List?>_ar(String p)async{try{var x=await AudioTags.read(p);if(x!=null&&x.pictures.isNotEmpty)return x.pictures.first.bytes;}catch(_){}return null;}
Future _ld(D d,T t,{bool lp=false})async{ld=true;var pl=P(d);try{await pl.stop();await pl.setFilePath(t.p);await pl.setVolume(d==l?1:0);
SN(d,t.n);SA(d,null);}catch(_){}finally{ld=false;}if(lp){try{await pl.play();}catch(_){}}_ar(t.p).then((i){if(mounted){SA(d,i);setState((){});}});if(mounted)setState((){});}
Future _pr()async{if(q.isEmpty||ld||xf||N(O(l))!=null)return;ld=true;var nd=O(l);var x=_nx();if(x==null){ld=false;return;}
try{var pl=P(nd);await pl.stop();await pl.setFilePath(x.p);await pl.seek(Duration.zero);await pl.setVolume(0);
SN(nd,x.n);SA(nd,null);_ar(x.p).then((i){if(mounted){SA(nd,i);setState((){});}});if(mounted)setState((){});}catch(_){qi=(qi-1+q.length)%q.length;SN(nd,null);}
finally{ld=false;}}
Future _au()async{if(q.isEmpty)return;if(N(l)==null){var f=_nx();if(f!=null){await _ld(l,f,lp:true);xv=l==D.a?0:1;}}else{try{await P(l).play();}catch(_){}}if(mounted)setState((){});}
Future _fd(D t)async{if(N(t)==null||xf||ld)return;var s=l,sp=P(s),tp=P(t);xf=true;if(mounted)setState((){});
try{await tp.setVolume(0);try{await tp.seek(Duration.zero);}catch(_){} // slider starts moving at 10s, B starts at 9s
for(int i=0;i<=100;i++){var v=i/100.0;var av=m.cos(v*m.pi/2);var bv=m.sin(v*m.pi/2);xv=s==D.a?v:1-v;
try{await sp.setVolume(av);}catch(_){}try{await tp.setVolume(i<10?0:bv);}catch(_){} // mute first 10 steps = 1s delay
if(i==10){try{await tp.play();}catch(_){try{await tp.setFilePath(q.firstWhere((e)=>e.n==N(t)).p);await tp.seek(Duration.zero);await tp.setVolume(0);await tp.play();}catch(_){}}}
if(mounted)setState((){});if(i<100)await Future.delayed(Duration(milliseconds:100));}
try{await sp.pause();}catch(_){}try{await sp.seek(Duration.zero);}catch(_){}try{await sp.setVolume(0);}catch(_){}try{await tp.setVolume(1);}catch(_){}
SN(s,null);SA(s,null);l=t;xv=t==D.a?0:1;}catch(_){try{await tp.setVolume(1);}catch(_){}}finally{xf=false;if(mounted)setState((){});}}
Future _tg(D d)async{if(xf||ld)return;var pl=P(d);if(pl.playing){await pl.pause();if(mounted)setState((){});return;}
if(N(d)==null){var x=_nx();if(x!=null){await _ld(d,x,lp:true);l=d;xv=d==D.a?0:1;}}else if(d!=l){await _fd(d);}else{try{await pl.play();}catch(_){}}if(mounted)setState((){});}
Future _pk(D d)async{var r=await FilePicker.platform.pickFiles(type:FileType.audio);if(r==null)return;var p=r.files.single.path;
if(p!=null){await _ld(d,T(p,r.files.single.name),lp: P(l).playing?d==l:true);if(P(l).playing&&d!=l)await P(d).setVolume(0);else{l=d;xv=d==D.a?0:1;}if(mounted)setState((){});}}
Future _aq()async{var r=await FilePicker.platform.pickFiles(type:FileType.audio,allowMultiple:true);if(r==null)return;
setState(()=>q.addAll(r.files.where((f)=>f.path!=null).map((f)=>T(f.path!,f.name))));if(au)await _au();}
Future _sx(double v)async{xv=v;if(v<0.35)l=D.a;else if(v>0.65)l=D.b;if(!xf){try{await a.setVolume(s==D.a?1-v:v);}catch(_){}try{await b.setVolume(s==D.a?v:1-v);}catch(_){} // keep s for manual
}var s=l;if(mounted)setState((){});} // manual still works, auto tick will take over if both loaded
void _qp(){showModalBottomSheet(context:context,builder:(c){return SafeArea(child:Column(children:[ListTile(title:Text('QUEUE ${q.length}'),
trailing:Row(mainAxisSize:MainAxisSize.min,children:[IconButton(icon:Icon(Icons.add),onPressed:()async{await _aq();Navigator.pop(c);_qp();}),
IconButton(icon:Icon(Icons.close),onPressed:()=>Navigator.pop(c))])),Expanded(child:ListView.builder(itemCount:q.length,itemBuilder:(x,i){
var live=N(l)==q[i].n;return ListTile(dense:true,title:Text(q[i].n,overflow:TextOverflow.ellipsis,style:TextStyle(color:live?C:Colors.white)),
onTap:()async{Navigator.pop(c);var d=O(l);if(P(l).playing){await _ld(d,q[i],lp:false);await P(d).setVolume(0);}else{await _ld(d,q[i],lp:true);l=d;xv=d==D.a?0:1;}});}))]));});}
Widget _dk(D d,bool up)=>Deck(deck:d,pl:P(d),name:N(d)??'No track',art:A(d),live:l==d,next:N(d)!=null&&l!=d,onPlay:()=>_tg(d),onPick:()=>_pk(d),onSeek:(s)async=>await P(d).seek(P(d).position+Duration(seconds:s)),lift:up);
@override Widget build(BuildContext c)=>Scaffold(backgroundColor:Colors.black,appBar:AppBar(backgroundColor:Colors.black,title:Text('BlendJam'),
actions:[Text('AUTO'),Switch(value:au,activeColor:C,onChanged:(v)async{setState(()=>au=v);if(v)await _au();}),IconButton(icon:Icon(Icons.queue_music),onPressed:_qp)]),
body:SafeArea(child:Column(children:[Flexible(child:_dk(D.a,false)),Padding(padding:EdgeInsets.symmetric(horizontal:12,vertical:2),child:Column(children:[
Row(children:[Text('A'),Expanded(child:Slider(value:xv,min:0,max:1,activeColor:C,onChanged:_sx)),Text('B')]),
Text(xf?'MIXING ${(xv*100).toInt()}% -> ${l==D.a?'B':'A'}':'',style:TextStyle(color:C,fontSize:11))])),Flexible(child:_dk(D.b,true))]))) ;}
class Deck extends StatefulWidget{final D deck;final AudioPlayer pl;final String name;final Uint8List?art;final bool live,next,lift;
final VoidCallback onPlay,onPick;final Future<void> Function(int)onSeek;const Deck({super.key,required this.deck,required this.pl,required this.name,required this.art,required this.live,required this.next,required this.onPlay,required this.onPick,required this.onSeek,required this.lift});@override State<Deck>createState()=>DD();}
class DD extends State<Deck> with TickerProviderStateMixin{late AnimationController an,rg;StreamSubscription<bool>?ps;
@override void initState(){super.initState();an=AnimationController(vsync:this,duration:Duration(seconds:3));rg=AnimationController(vsync:this,duration:Duration(seconds:5));
ps=widget.pl.playingStream.listen((p){if(!mounted)return;if(p){an.repeat();rg.repeat();}else{an.stop();rg.stop();}});} @override void dispose(){ps?.cancel();an.dispose();rg.dispose();super.dispose();}
String _f(Duration d)=>'${d.inMinutes.remainder(60).toString().padLeft(2,'0')}:${(d.inSeconds%60).toString().padLeft(2,'0')}';
Widget _da(){Widget im;if(widget.art!=null&&widget.art!.isNotEmpty)im=Image.memory(widget.art!,width:130,height:130,fit:BoxFit.cover);
else im=Image.asset('assets/images/default_cover.png',width:130,height:130,fit:BoxFit.cover,errorBuilder:(c,e,s)=>Icon(Icons.music_note,size:60));
return Container(width:135,height:135,decoration:BoxDecoration(shape:BoxShape.circle,color:Colors.black,border:Border.all(color:widget.live?Colors.white24:Colors.white10)),
child:ClipOval(child:Stack(fit:StackFit.expand,children:[im,CustomPaint(painter:Gr()),Center(child:Container(width:50,height:50,decoration:BoxDecoration(shape:BoxShape.circle,color:Color(0xFF101010)),child:Container(margin:EdgeInsets.all(2),decoration:BoxDecoration(shape:BoxShape.circle,border:Border.all(color:widget.live?Color(0xFFCEBBFF):Colors.white24)))))]))); }
@override Widget build(BuildContext c)=>Column(mainAxisAlignment:widget.lift?MainAxisAlignment.start:MainAxisAlignment.center,children:[
Text('DECK ${widget.deck==D.a?'A':'B'} ${widget.live?'(LIVE)':widget.next?'(NEXT)':''}',style:TextStyle(fontSize:11,color:widget.live?Color(0xFFCEBBFF):Colors.white70)),
SizedBox(width:165,height:165,child:Stack(alignment:Alignment.center,children:[RotationTransition(turns:rg,child:CustomPaint(size:Size(165,165),painter:RL(live:widget.live,has:widget.name!='No track',play:widget.pl.playing))),RotationTransition(turns:an,child:_da()),
StreamBuilder<bool>(stream:widget.pl.playingStream,initialData:widget.pl.playing,builder:(x,s){bool pl=s.data??false;return InkWell(customBorder:CircleBorder(),onTap:widget.onPlay,child:Container(width:48,height:48,decoration:BoxDecoration(shape:BoxShape.circle,color:Color(0xFFCEBBFF)),child:Icon(pl?Icons.pause:Icons.play_arrow,color:Colors.black)));})])),
Text(widget.name,style:TextStyle(fontSize:11),overflow:TextOverflow.ellipsis),StreamBuilder<Duration>(stream:widget.pl.positionStream,builder:(x,s){
var po=s.data??Duration.zero;var du=widget.pl.duration??Duration(seconds:1);var pr=(po.inMilliseconds/du.inMilliseconds).clamp(0.0,1.0);
return Column(children:[SizedBox(height:18,child:Slider(value:pr,min:0,max:1,activeColor:widget.live?Color(0xFFCEBBFF):Colors.white38,onChanged:(v)async=>await widget.pl.seek(Duration(milliseconds:(v*du.inMilliseconds).round())))),
Text('${_f(po)} / ${_f(du)}',style:TextStyle(fontSize:10,color:Colors.white38)),Row(mainAxisAlignment:MainAxisAlignment.center,children:[
IconButton(icon:Icon(Icons.replay_10),visualDensity:VisualDensity.compact,onPressed:()=>widget.onSeek(-10)),IconButton(icon:Icon(Icons.folder_open),visualDensity:VisualDensity.compact,onPressed:widget.onPick),IconButton(icon:Icon(Icons.forward_10),visualDensity:VisualDensity.compact,onPressed:()=>widget.onSeek(10))])]);})]);}
class RL extends CustomPainter{final bool live,has,play;RL({required this.live,required this.has,required this.play});@override void paint(Canvas cv,Size sz){var ct=Offset(sz.width/2,sz.height/2);var rad=sz.width/2;if(!has){cv.drawCircle(ct,rad,Paint()..style=PaintingStyle.stroke..strokeWidth=2..color=Colors.white12);return;}
var p=Paint()..style=PaintingStyle.stroke..strokeWidth=5..shader=SweepGradient(colors:[Color(0xFF087BFF),Color(0xFF111111),Color(0xFFFF7A00),Color(0xFF111111),Color(0xFF087BFF)]).createShader(Rect.fromCircle(center:ct,radius:rad));cv.drawCircle(ct,rad-2,p);
if(play){var g=Paint()..style=PaintingStyle.stroke..strokeWidth=12..color=(live?Color(0xFFCEBBFF):Colors.orange).withOpacity(0.25)..maskFilter=MaskFilter.blur(BlurStyle.normal,8);cv.drawCircle(ct,rad-2,g);}}@override bool shouldRepaint(covariant RL o)=>o.live!=live||o.has!=has||o.play!=play;}
class Gr extends CustomPainter{@override void paint(Canvas cv,Size sz){var ct=Offset(sz.width/2,sz.height/2);var r=sz.width/2;var p=Paint()..style=PaintingStyle.stroke..strokeWidth=1..color=Colors.white.withOpacity(0.06);for(double i=20;i<r-5;i+=5)cv.drawCircle(ct,i,p);}@override bool shouldRepaint(covariant CustomPainter o)=>false;}
