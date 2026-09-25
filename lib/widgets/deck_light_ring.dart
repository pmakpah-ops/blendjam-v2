import 'package:flutter/material.dart';
class DeckLightRing extends StatefulWidget{
  final bool isLive,isPlaying;final Widget child;
  const DeckLightRing({super.key,required this.isLive,required this.isPlaying,required this.child});
  @override State<DeckLightRing> createState()=>_R();
}
class _R extends State<DeckLightRing> with SingleTickerProviderStateMixin{
  late AnimationController c;
  @override void initState(){super.initState();c=AnimationController(vsync:this,duration:Duration(milliseconds:1200))..repeat();}
  @override void dispose(){c.dispose();super.dispose();}
  @override Widget build(BuildContext context){
    return Stack(alignment:Alignment.center,children:[
      widget.child,
      if(widget.isLive&&widget.isPlaying) IgnorePointer(
        child: AnimatedBuilder(animation:c,builder:(ctx,_){
          return Container(width:220,height:220,decoration:BoxDecoration(shape:BoxShape.circle,border:Border.all(color:Color(0xFFCEBBFF).withOpacity(0.5+0.5*c.value),width:3),boxShadow:[BoxShadow(color:Color(0xFFCEBBFF).withOpacity(0.3),blurRadius:12+8*c.value,spreadRadius:2)]) );
        }),
      ),
    ]);
  }
}
