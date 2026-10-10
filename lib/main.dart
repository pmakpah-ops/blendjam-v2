import 'dart:async';import 'dart:math' as m;import 'dart:typed_data';import 'package:audiotags/audiotags.dart';import 'package:file_picker/file_picker.dart';import 'package:flutter/material.dart';import 'package:just_audio/just_audio.dart';
void main()=>runApp(MaterialApp(theme:ThemeData.dark(),home:DJ()));class T{String p,n;T(this.p,this.n);}enum D{a,b}
class DJ extends StatefulWidget {
  const DJ({super.key});
  @override State<DJ> createState()=>S();
}
class S extends State<DJ> {
  static const C=Color(0xFFCEBBFF);
  static const _fadeLength=Duration(seconds:10);
  final a=AudioPlayer(), b=AudioPlayer();
  String? na,nb; Uint8List? aa,ab;
  D l=D.a; bool au=false,xf=false,ar=false;
  double xv=0; List<T> q=[]; int qi=0;
  StreamSubscription<Duration>? _posA,_posB;
  Timer? _fadeTimer;
  bool _disposed=false,_transitioning=false;
  int _generationA=0,_generationB=0;
  final Set<String> _preparedFor= <String>{};

  AudioPlayer P(D d)=>d==D.a?a:b;
  D O(D d)=>d==D.a?D.b:D.a;
  String? N(D d)=>d==D.a?na:nb;
  Uint8List? A(D d)=>d==D.a?aa:ab;
  void SN(D d,String? v){if(d==D.a)na=v;else nb=v;}
  void SA(D d,Uint8List? v){if(d==D.a)aa=v;else ab=v;}
  int _gen(D d)=>d==D.a?_generationA:_generationB;
  void _bump(D d){if(d==D.a)_generationA++;else _generationB++;}
  @override void initState(){
    super.initState();
    _posA=a.positionStream.listen((p)=>_ck(D.a,p));
    _posB=b.positionStream.listen((p)=>_ck(D.b,p));
  }
  @override void dispose(){
    _disposed=true;_fadeTimer?.cancel();
    _posA?.cancel();_posB?.cancel();
    a.dispose();b.dispose();super.dispose();
  }
  T? _nx(){
    if(q.isEmpty)return null;
    final t=q[qi%q.length];qi=(qi+1)%q.length;return t;
  }
  Future<Uint8List?> _rt(String p)async{
    try{final t=await AudioTags.read(p);if(t!=null&&t.pictures.isNotEmpty)return t.pictures.first.bytes;}catch(_){}
    return null;
  }
  Future<bool> _ld(D d,T t,{bool pl=false})async{
    _bump(d);final token=_gen(d);final ap=P(d);
    try{
      await ap.stop();
      await ap.setVolume(0);
      await ap.setFilePath(t.p);
      if(token!=_gen(d)||_disposed)return false;
      await ap.seek(const Duration(milliseconds:200));
      await ap.setSpeed(1);
      SN(d,t.n);SA(d,null);
      if(pl){l=d;xv=d==D.a?0:1;await ap.setVolume(1);await ap.play();}
      if(mounted)setState((){});
      _rt(t.p).then((bytes){if(!_disposed&&token==_gen(d)){SA(d,bytes);if(mounted)setState((){});}});
      return true;
    }catch(_){
      if(token==_gen(d)){SN(d,null);SA(d,null);try{await ap.stop();}catch(_){}}
      if(mounted)setState((){});
      return false;
    }
  }
  Future<void> _as()async{
    if(q.isEmpty||_disposed)return;
    if(N(l)==null){
      final f=_nx();if(f!=null){final ok=await _ld(l,f,pl:true);if(!ok)return;}
    }
    if(N(O(l))==null){
      final f=_nx();if(f!=null)await _ld(O(l),f);
    }
  }
  void _ck(D d,Duration p){
    if(_disposed||!au||xf||_transitioning||d!=l)return;
    final ap=P(d),du=ap.duration;
    if(du==null||!ap.playing)return;
    final remaining=du-p;
    final incoming=O(d);
    if(remaining<=Duration(seconds:15)&&N(incoming)==null){
      final key=N(d);
      if(key!=null&&_preparedFor.add(key)){
        final next=_nx();
        if(next!=null){_ld(incoming,next).then((ok){if(!ok)_preparedFor.remove(key);});}
      }
    }
    if(remaining<=_fadeLength&&N(incoming)!=null&&P(incoming).duration!=null){
      _beginFade(d,automatic:true);
    }else if(remaining<=Duration.zero&&N(incoming)==null){
      // No next track: leave the player stopped at its natural end.
      _preparedFor.remove(N(d)??'');
    }
  }
  Future<void> _beginFade(D outgoing,{bool automatic=false})async{
    if(_disposed||xf||_transitioning||(automatic&&!au))return;
    final incoming=O(outgoing),sp=P(outgoing),tp=P(incoming);
    final outgoingName=N(outgoing);
    if(N(incoming)==null||tp.duration==null)return;
    _transitioning=true;xf=true;_fadeTimer?.cancel();
    try{
      await tp.setVolume(0);
      await tp.seek(const Duration(milliseconds:200));
      await tp.play();
    }catch(_){
      _transitioning=false;xf=false;
      try{await tp.stop();}catch(_){}
      if(mounted)setState((){});
      return;
    }
    final start=DateTime.now();
    _fadeTimer=Timer.periodic(const Duration(milliseconds:50),(timer)async{
      if(_disposed){timer.cancel();return;}
      final elapsed=DateTime.now().difference(start);
      final t=(elapsed.inMilliseconds/_fadeLength.inMilliseconds).clamp(0.0,1.0);
      final out=m.cos(t*m.pi/2),inc=m.sin(t*m.pi/2);
      xv=outgoing==D.a?t:1-t;
      try{await sp.setVolume(out);await tp.setVolume(inc);}catch(_){timer.cancel();_transitioning=false;xf=false;return;}
      if(mounted)setState((){});
      if(t>=1){
        timer.cancel();
        try{await tp.setVolume(1);await sp.setVolume(0);await sp.stop();}catch(_){}
        SN(outgoing,null);SA(outgoing,null);l=incoming;
        _preparedFor.remove(outgoingName??'');
        _transitioning=false;xf=false;ar=false;
        if(mounted)setState((){});
        if(au&&N(O(l))==null){
          final f=_nx();if(f!=null)await _ld(O(l),f);
        }
      }
    });
  }
  Future<void> _tg(D d)async{
    if(_disposed||_transitioning)return;
    final pl=P(d);
    if(pl.playing){await pl.pause();}
    else if(N(d)==null){
      final f=_nx();if(f!=null)await _ld(d,f,pl:true);
    }else if(d!=l){
      // A loaded inactive deck is an explicit manual transition.
      await _beginFade(l);
    }else{
      try{await pl.play();l=d;xv=d==D.a?0:1;}catch(_){}
    }
    if(mounted)setState((){});
  }
  Future<void> _pk(D d)async{
    final r=await FilePicker.platform.pickFiles(type:FileType.audio);
    if(r==null||_disposed)return;
    final p=r.files.single.path;if(p==null)return;
    final target=P(l).playing?O(l):d;
    await _ld(target,T(p,r.files.single.name),pl:!P(l).playing&&target==l);
    if(P(l).playing){try{await P(target).setVolume(0);}catch(_){}}
  }
  Future<void> _aq()async{
    final r=await FilePicker.platform.pickFiles(type:FileType.audio,allowMultiple:true);
    if(r==null||_disposed)return;
    final tracks=r.files.where((f)=>f.path!=null).map((f)=>T(f.path!,f.name)).toList();
    if(!mounted)return;setState(()=>q.addAll(tracks));
    if(au)await _as();
  }
  void _qp(){
    showModalBottomSheet(context:context,builder:(c)=>SafeArea(child:Column(children:[
      ListTile(title:Text('QUEUE ${q.length} (loops)'),trailing:Row(mainAxisSize:MainAxisSize.min,children:[
        IconButton(icon:Icon(Icons.add),onPressed:()async{await _aq();if(c.mounted)Navigator.pop(c);if(mounted)_qp();}),
        IconButton(icon:Icon(Icons.close),onPressed:()=>Navigator.pop(c))])),
      Expanded(child:ListView.builder(itemCount:q.length,itemBuilder:(x,i)=>ListTile(dense:true,title:Text(q[i].n,overflow:TextOverflow.ellipsis,style:TextStyle(color:N(l)==q[i].n?C:Colors.white)),onTap:()async{
        Navigator.pop(c);final d=P(l).playing?O(l):l;await _ld(d,q[i],pl:!P(l).playing);
      })))
    ])));
  }
Widget _dk(D d,bool up)=>Deck(deck:d,pl:P(d),name:N(d)??'No track',art:A(d),live:l==d,next:N(d)!=null&&l!=d,onPlay:()=>_tg(d),onPick:()=>_pk(d),onSeek:(s)async=>await P(d).seek(P(d).position+Duration(seconds:s)),lift:up);
@override Widget build(BuildContext c)=>Scaffold(backgroundColor:Colors.black,appBar:AppBar(backgroundColor:Colors.black,title:Text('BlendJam'),
actions:[Text('AUTO',style:TextStyle(fontSize:11)),Switch(value:au,activeColor:C,onChanged:(v)async{setState(()=>au=v);if(v)await _as();}),PopupMenuButton(icon:Icon(Icons.upload_file),itemBuilder:(_)=>[PopupMenuItem(child:Text('Load A'),onTap:()=>_pk(D.a)),PopupMenuItem(child:Text('Load B'),onTap:()=>_pk(D.b)),PopupMenuItem(child:Text('Add Queue'),onTap:()=>_aq())]),IconButton(icon:Icon(Icons.queue_music),onPressed:_qp)]),
body:SafeArea(child:Column(children:[Flexible(child:_dk(D.a,false)),Padding(padding:EdgeInsets.symmetric(horizontal:12,vertical:2),child:Column(children:[Row(children:[Text('A',style:TextStyle(fontSize:12)),Expanded(child:Slider(value:xv,min:0,max:1,activeColor:C,onChanged:(v){if(xf)return;xv=v;try{a.setVolume(1-v);}catch(_){}try{b.setVolume(v);}catch(_){}if(v>=0.5&&N(D.b)!=null)l=D.b;if(v<0.5&&N(D.a)!=null)l=D.a;setState((){});})),Text('B',style:TextStyle(fontSize:12))]),Text(xf?'MIXING ${(xv*100).toInt()}%':'',style:TextStyle(color:C,fontSize:11))])),Flexible(child:_dk(D.b,true))])));}
class Deck extends StatefulWidget{final D deck;final AudioPlayer pl;final String name;final Uint8List?art;final bool live,next,lift;final VoidCallback onPlay,onPick;final Future<void> Function(int)onSeek;const Deck({super.key,required this.deck,required this.pl,required this.name,required this.art,required this.live,required this.next,required this.onPlay,required this.onPick,required this.onSeek,required this.lift});@override State<Deck>createState()=>DD();}
class DD extends State<Deck> with TickerProviderStateMixin{late AnimationController an,rg;StreamSubscription<bool>?ps;@override void initState(){super.initState();an=AnimationController(vsync:this,duration:Duration(seconds:3));rg=AnimationController(vsync:this,duration:Duration(seconds:5));ps=widget.pl.playingStream.listen((p){if(!mounted)return;if(p){an.repeat();rg.repeat();}else{an.stop();rg.stop();}});} @override void dispose(){ps?.cancel();an.dispose();rg.dispose();super.dispose();}
String _f(Duration d)=>'${d.inMinutes.remainder(60).toString().padLeft(2,'0')}:${(d.inSeconds%60).toString().padLeft(2,'0')}';
Widget _da(){Widget im;if(widget.art!=null&&widget.art!.isNotEmpty)im=Image.memory(widget.art!,width:130,height:130,fit:BoxFit.cover);else im=Image.asset('assets/images/default_cover.png',width:130,height:130,fit:BoxFit.cover,errorBuilder:(c,e,s)=>Icon(Icons.music_note,size:60));
return Container(width:135,height:135,decoration:BoxDecoration(shape:BoxShape.circle,color:Colors.black,border:Border.all(color:widget.live?Colors.white24:Colors.white10)),child:ClipOval(child:Stack(fit:StackFit.expand,children:[im,CustomPaint(painter:Gr()),Center(child:Container(width:50,height:50,decoration:BoxDecoration(shape:BoxShape.circle,color:Color(0xFF101010)),child:Container(margin:EdgeInsets.all(2),decoration:BoxDecoration(shape:BoxShape.circle,border:Border.all(color:widget.live?Color(0xFFCEBBFF):Colors.white24)))))]))); }
@override Widget build(BuildContext c)=>Column(mainAxisAlignment:widget.lift?MainAxisAlignment.start:MainAxisAlignment.center,children:[Text('DECK ${widget.deck==D.a?'A':'B'} ${widget.live?'(LIVE)':widget.next?'(NEXT)':''}',style:TextStyle(fontSize:11,color:widget.live?Color(0xFFCEBBFF):Colors.white70)),SizedBox(width:165,height:165,child:Stack(alignment:Alignment.center,children:[RotationTransition(turns:rg,child:CustomPaint(size:Size(165,165),painter:RL(live:widget.live,has:widget.name!='No track',play:widget.pl.playing))),RotationTransition(turns:an,child:_da()),StreamBuilder<bool>(stream:widget.pl.playingStream,initialData:widget.pl.playing,builder:(x,s){bool pl=s.data??false;return InkWell(customBorder:CircleBorder(),onTap:widget.onPlay,child:Container(width:48,height:48,decoration:BoxDecoration(shape:BoxShape.circle,color:Color(0xFFCEBBFF)),child:Icon(pl?Icons.pause:Icons.play_arrow,color:Colors.black)));})])),Text(widget.name,style:TextStyle(fontSize:11),overflow:TextOverflow.ellipsis),StreamBuilder<Duration>(stream:widget.pl.positionStream,builder:(x,s){var po=s.data??Duration.zero;var du=widget.pl.duration??Duration(seconds:1);var pr=(po.inMilliseconds/du.inMilliseconds).clamp(0.0,1.0);return Column(children:[SizedBox(height:18,child:Slider(value:pr,min:0,max:1,activeColor:widget.live?Color(0xFFCEBBFF):Colors.white38,onChanged:(v)async=>await widget.pl.seek(Duration(milliseconds:(v*du.inMilliseconds).round())))),Text('${_f(po)} / ${_f(du)}',style:TextStyle(fontSize:10,color:Colors.white38)),Row(mainAxisAlignment:MainAxisAlignment.center,children:[IconButton(icon:Icon(Icons.replay_10),visualDensity:VisualDensity.compact,onPressed:()=>widget.onSeek(-10)),IconButton(icon:Icon(Icons.folder_open),visualDensity:VisualDensity.compact,onPressed:widget.onPick),IconButton(icon:Icon(Icons.forward_10),visualDensity:VisualDensity.compact,onPressed:()=>widget.onSeek(10))])]);})]);}
class RL extends CustomPainter{final bool live,has,play;RL({required this.live,required this.has,required this.play});@override void paint(Canvas cv,Size sz){var ct=Offset(sz.width/2,sz.height/2);var rad=sz.width/2;if(!has){cv.drawCircle(ct,rad,Paint()..style=PaintingStyle.stroke..strokeWidth=2..color=Colors.white12);return;}var p=Paint()..style=PaintingStyle.stroke..strokeWidth=5..shader=SweepGradient(colors:[Color(0xFF087BFF),Color(0xFF111111),Color(0xFFFF7A00),Color(0xFF111111),Color(0xFF087BFF)]).createShader(Rect.fromCircle(center:ct,radius:rad));cv.drawCircle(ct,rad-2,p);if(play){var g=Paint()..style=PaintingStyle.stroke..strokeWidth=12..color=(live?Color(0xFFCEBBFF):Colors.orange).withOpacity(0.25)..maskFilter=MaskFilter.blur(BlurStyle.normal,8);cv.drawCircle(ct,rad-2,g);}}@override bool shouldRepaint(covariant RL o)=>o.live!=live||o.has!=has||o.play!=play;}
class Gr extends CustomPainter{@override void paint(Canvas cv,Size sz){var ct=Offset(sz.width/2,sz.height/2);var r=sz.width/2;var p=Paint()..style=PaintingStyle.stroke..strokeWidth=1..color=Colors.white.withOpacity(0.06);for(double i=20;i<r-5;i+=5)cv.drawCircle(ct,i,p);}@override bool shouldRepaint(covariant CustomPainter o)=>false;}
