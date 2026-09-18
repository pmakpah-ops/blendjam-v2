import 'dart:async';import 'dart:math';import 'package:flutter/material.dart';import 'package:just_audio/just_audio.dart';import 'package:file_picker/file_picker.dart';import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
void main()=>runApp(const BlendJamApp());
class BlendJamApp extends StatelessWidget{const BlendJamApp({super.key});@override Widget build(BuildContext c){return MaterialApp(title:'BlendJam',debugShowCheckedModeBanner:false,theme:ThemeData.dark(),home:const DJPage());}}
class DJPage extends StatefulWidget{const DJPage({super.key});@override State<DJPage> createState()=>DJState();}
class DJState extends State<DJPage>{
 late AudioPlayer a,b; String? nA,nB; double cross=0; Map<String,double> sm={};
 @override void initState(){super.initState();a=AudioPlayer();b=AudioPlayer();a.setVolume(1);b.setVolume(0);}
 @override void dispose(){a.dispose();b.dispose();super.dispose();}
 Future<double> detectSilence(String p) async{try{final s=await FFmpegKit.execute('-i "$p" -af silencedetect=noise=-60dB:d=0.5 -f null -');final l=await s.getAllLogsAsString();if(l==null)return 0;double last=0;for(var m in RegExp(r'silence_end: (\d+\.?\d*)').allMatches(l)){last=double.tryParse(m.group(1)!)??0;}return last;}catch(_){return 0;}}
 void upd(double v){setState(()=>cross=v);a.setVolume((1-v).clamp(0.0,1.0));b.setVolume(v.clamp(0.0,1.0));}
 Future<void> pick(bool isA) async{var r=await FilePicker.platform.pickFiles(type:FileType.audio);if(r==null)return;String path=r.files.single.path!;String name=r.files.single.name;double si=await detectSilence(path);sm[path]=si;if(isA){await a.setFilePath(path);setState(()=>nA='$name s:$si');}else{await b.setFilePath(path);setState(()=>nB='$name s:$si');}}
 @override Widget build(BuildContext c){return Scaffold(appBar:AppBar(title:const Text('BlendJam v2')),body:Column(children:[Expanded(child:Row(children:[Expanded(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Text(nA??'Deck A'),ElevatedButton(onPressed:()=>pick(true),child:const Text('Load A')),ElevatedButton(onPressed:()=>a.play(),child:const Text('Play A'))])),Expanded(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Text(nB??'Deck B'),ElevatedButton(onPressed:()=>pick(false),child:const Text('Load B')),ElevatedButton(onPressed:()=>b.play(),child:const Text('Play B'))]))])),Slider(value:cross,onChanged:upd),const Text('Crossfader')])) ;}}
