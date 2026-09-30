import 'dart:async';
import 'dart:math' as m;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
void main()=>runApp(MaterialApp(home:DJ()));
class T{String p,n;T(this.p,this.n);}
enum D{a,b}
class DJ extends StatefulWidget{
const DJ({super.key});
@override State<DJ>createState()=>S();}
class S extends State<DJ>{
final a=AudioPlayer(),b=AudioPlayer();
String?na,nb;D l=D.a;
bool au=false,xf=false;
double xv=0;List<T>q=[];int qi=0;
P(d)=>d==D.a?a:b;
O(d)=>d==D.a?D.b:D.a;
N(d)=>d==D.a?na:nb;
SN(d,v){d==D.a?na=v:nb=v;}
@override void initState(){
super.initState();
Timer.periodic(Duration(milliseconds:400),(_){
if(!mounted||xf||!au)return;
var pl=P(l);var du=pl.duration;
if(du==null)return;
var r=du-pl.position;
if(r<=Duration(seconds:10)&&N(O(l))!=null)_fd(O(l));
else if(r<=Duration(seconds:15)&&N(O(l))==null)_pr();});}
T?_nx(){
if(q.isEmpty)return null;
var t=q[qi%q.length];
qi=(qi+1)%q.length;return t;}
Future _ld(D d,T t,{bool lp=false})async{
var pl=P(d);SN(d,t.n);setState((){});
try{
await pl.stop();
await pl.setFilePath(t.p);
await pl.setVolume(d==l?1:0);
if(lp&&d==l)await pl.play();
else await pl.pause();
}catch(_){}
setState((){});}
Future _pr()async{
if(q.isEmpty||xf||N(O(l))!=null)return;
var x=_nx();if(x!=null)await _ld(O(l),x);}
Future _au()async{
if(N(l)==null){
var f=_nx();if(f!=null)await _ld(l,f,lp:true);}
await _pr();setState((){});}
Future _fd(D t)async{
if(xf||N(t)==null)return;
var s=l;var sp=P(s),tp=P(t);
xf=true;setState((){});
try{
await tp.seek(Duration.zero);
await tp.setVolume(0);
await tp.pause();
for(int i=1;i<=100;i++){
var v=i/100;
if(i==10)tp.play();
xv=s==D.a?v:1-v;
setState((){});
try{
sp.setVolume(m.cos(v*m.pi/2));
tp.setVolume(m.sin(v*m.pi/2));
}catch(_){}
await Future.delayed(Duration(milliseconds:100));
}}finally{
try{await sp.stop();await tp.setVolume(1);}catch(_){}
SN(s,null);l=t;xv=t==D.a?0:1;
xf=false;setState((){});
if(au)await _pr();}}
Future _tg(D d)async{
if(xf)return;var pl=P(d);
if(pl.playing){await pl.pause();setState((){});return;}
if(N(d)==null){
var t=_nx();if(t!=null){
await _ld(d,t,lp:true);l=d;setState((){});}return;}
if(d!=l){await _fd(d);return;}
await pl.play();setState((){});}
Future _pk(D d)async{
var r=await FilePicker.platform.pickFiles(type:FileType.audio);
if(r==null)return;var p=r.files.single.path;
if(p!=null){await _ld(d,T(p,r.files.single.name),lp:true);
l=d;setState((){});}}
Future _aq()async{
var r=await FilePicker.platform.pickFiles(
type:FileType.audio,allowMultiple:true);
if(r==null)return;
setState(()=>q.addAll(r.files.where((f)=>f.path!=null)
.map((f)=>T(f.path!,f.name))));
if(au)await _au();}
Future _sk(D d,int s)async{
await P(d).seek(P(d).position+Duration(seconds:s));}
Future _sx(double v)async{
if(xf)return;xv=v;a.setVolume(1-v);b.setVolume(v);
l=v>=0.5?D.b:D.a;setState((){});}
void _qp(){
showModalBottomSheet(context:context,builder:(c)=>
Column(children:[
ListTile(title:Text('Q ${q.length}'),trailing:Row(
mainAxisSize:MainAxisSize.min,children:[
IconButton(icon:Icon(Icons.add),onPressed:()async{
await _aq();Navigator.pop(c);_qp();}),
IconButton(icon:Icon(Icons.close),onPressed:()=>Navigator.pop(c))])),
Expanded(child:ListView.builder(itemCount:q.length,
itemBuilder:(x,i)=>ListTile(title:Text(q[i].n),
onTap:()async{Navigator.pop(x);await _ld(O(l),q[i]);})))
])));}
Widget _dk(D d){
var pl=P(d);
return Column(children:[
Text('DECK ${d==D.a?'A':'B'} ${l==d?'(LIVE)':N(d)!=null?'(NEXT)':''}'),
StreamBuilder<bool>(stream:pl.playingStream,
initialData:pl.playing,builder:(c,s)=>InkWell(
onTap:()=>_tg(d),child:Container(width:80,height:80,
margin:EdgeInsets.all(8),decoration:BoxDecoration(
shape:BoxShape.circle,color:l==d?Colors.purple:Colors.grey),
child:Icon(s.data==true?Icons.pause:Icons.play_arrow)))),
Text(N(d)??'No track',style:TextStyle(fontSize:11)),
StreamBuilder<Duration>(stream:pl.positionStream,
builder:(c,s){
var po=s.data??Duration.zero;
var du=pl.duration??Duration(seconds:1);
var pr=(po.inMilliseconds/du.inMilliseconds).clamp(0.0,1.0);
return Column(children:[
Slider(value:pr,min:0,max:1,onChanged:(v)async{
await pl.seek(Duration(milliseconds:(v*du.inMilliseconds).round()));}),
Row(mainAxisAlignment:MainAxisAlignment.center,children:[
IconButton(icon:Icon(Icons.replay_10),
onPressed:()=>_sk(d,-10)),
IconButton(icon:Icon(Icons.folder_open),
onPressed:()=>_pk(d)),
IconButton(icon:Icon(Icons.forward_10),
onPressed:()=>_sk(d,10)),
])]);})]);}
@override Widget build(BuildContext c)=>Scaffold(
appBar:AppBar(title:Text('BlendJam'),actions:[
Switch(value:au,onChanged:(v)async{
setState(()=>au=v);if(v)await _au();}),
IconButton(icon:Icon(Icons.queue_music),onPressed:_qp)]),
body:Column(children:[
Expanded(child:_dk(D.a)),
Row(children:[
Text('A'),Expanded(child:Slider(value:xv,min:0,max:1,onChanged:_sx)),
Text('B')]),
Text(xf?'MIXING ${(xv*100).toInt()}%':''),
Expanded(child:_dk(D.b))
])));}
