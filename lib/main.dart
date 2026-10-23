import 'dart:async';import 'dart:convert';import 'dart:io';import 'dart:math' as m;import 'dart:typed_data';import 'package:audiotags/audiotags.dart';import 'package:file_picker/file_picker.dart';import 'package:flutter/material.dart';import 'package:just_audio/just_audio.dart';import 'package:shared_preferences/shared_preferences.dart';import 'package:just_waveform/just_waveform.dart';
void main()=>runApp(MaterialApp(theme:ThemeData.dark(),home:DJ()));class T{String p,n;T(this.p,this.n);}enum D{a,b}
class DJ extends StatefulWidget {
  const DJ({super.key});
  @override State<DJ> createState()=>S();
}
class S extends State<DJ> {
  static const C=Color(0xFFCEBBFF);
  static const _fadeLength=Duration(seconds:10);
  final a=AudioPlayer(), b=AudioPlayer();
  String? na,nb,pathA,pathB; Uint8List? aa,ab; double? bpmA,bpmB; bool bpmBusyA=false,bpmBusyB=false; final Map<String,double> _bpmCache={};
  D l=D.a; bool au=false,xf=false,ar=false;
  double xv=0; List<T> q=[]; int qi=0; List<Map<String,dynamic>> crates=[]; List<T> recent=[]; String? lastFolder;
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
  String? PathOf(D d)=>d==D.a?pathA:pathB;
  void SPath(D d,String? v){if(d==D.a)pathA=v;else pathB=v;}
  double? BPM(D d)=>d==D.a?bpmA:bpmB;
  bool BPMBusy(D d)=>d==D.a?bpmBusyA:bpmBusyB;
  void SBPM(D d,double? v){if(d==D.a)bpmA=v;else bpmB=v;}
  void SBBusy(D d,bool v){if(d==D.a)bpmBusyA=v;else bpmBusyB=v;}
  int _gen(D d)=>d==D.a?_generationA:_generationB;
  void _bump(D d){if(d==D.a)_generationA++;else _generationB++;}
  @override void initState(){
    super.initState();
    _posA=a.positionStream.listen((p)=>_ck(D.a,p));
    _posB=b.positionStream.listen((p)=>_ck(D.b,p));
    unawaited(_loadCrates());
    unawaited(_loadRecent());
  }
  @override void dispose(){
    _disposed=true;_fadeTimer?.cancel();
    _posA?.cancel();_posB?.cancel();
    a.dispose();b.dispose();super.dispose();
  }
  Future<void> _loadCrates()async{try{final prefs=await SharedPreferences.getInstance();final raw=prefs.getString('blendjam_crates_v1');if(raw==null)return;final decoded=jsonDecode(raw);if(decoded is List){crates=decoded.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).where((e)=>e['name'] is String&&e['tracks'] is List).take(5).toList();if(mounted)setState((){});}}catch(e){debugPrint('BlendJam crates load error: $e');}}
  Future<void> _loadRecent()async{try{final prefs=await SharedPreferences.getInstance();lastFolder=prefs.getString('blendjam_last_folder_v1');final raw=prefs.getString('blendjam_recent_v1');if(raw!=null){final decoded=jsonDecode(raw);if(decoded is List){recent=decoded.whereType<Map>().map((e)=>T(e['p'] as String,e['n'] as String)).take(20).toList();}}if(mounted)setState((){});}catch(e){debugPrint('BlendJam recent load error: $e');}}
  Future<void> _rememberTracks(List<T> tracks)async{try{for(final t in tracks){recent.removeWhere((x)=>x.p==t.p);recent.insert(0,t);}if(recent.length>20)recent=recent.take(20).toList();if(tracks.isNotEmpty){lastFolder=File(tracks.first.p).parent.path;}final prefs=await SharedPreferences.getInstance();await prefs.setString('blendjam_recent_v1',jsonEncode(recent.map((t)=>{'p':t.p,'n':t.n}).toList()));if(lastFolder!=null)await prefs.setString('blendjam_last_folder_v1',lastFolder!);}catch(e){debugPrint('BlendJam recent save error: $e');}}
  Future<void> _loadRecentQueue({bool shuffle=false})async{final tracks=<T>[];for(final t in recent){try{if(await File(t.p).exists())tracks.add(t);}catch(_){}}if(shuffle&&!au){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Shuffle is available only when Auto Mix is ON.')));return;}if(shuffle)tracks.shuffle();if(tracks.isEmpty){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('No recent songs are currently available.')));return;}setState((){q=tracks;qi=0;});if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('${tracks.length}/${recent.length} recent songs available')));if(!au){await _showRecentSongs();return;}final playing=P(l).playing;if(playing){await _ld(O(l),tracks.first);}else{await _ld(l,tracks.first,pl:true);if(tracks.length>1)await _ld(O(l),tracks[1]);if(mounted)setState(()=>qi=tracks.length>1?1:0);}}
  Future<void> _saveCrates()async{try{final prefs=await SharedPreferences.getInstance();await prefs.setString('blendjam_crates_v1',jsonEncode(crates));}catch(e){debugPrint('BlendJam crates save error: $e');}}
  Future<void> _saveQueueAsCrate()async{
    if(q.isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Add songs to the queue first.')));return;}
    if(crates.length>=5){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('You can save up to 5 crates. Delete a crate to make room.')));return;}
    final nameCtrl=TextEditingController();
    final name=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Save Mix as Crate'),content:TextField(controller:nameCtrl,autofocus:true,maxLength:30,decoration:const InputDecoration(hintText:'Enter crate name')),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('CANCEL')),TextButton(onPressed:()=>Navigator.pop(ctx,nameCtrl.text.trim()),child:const Text('SAVE'))]));
    final chosen=nameCtrl.text.trim();nameCtrl.dispose();if(name==null||chosen.isEmpty||!mounted)return;
    final tracks=q.take(20).map((t)=>{'p':t.p,'n':t.n}).toList();
    if(q.length>20)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Only the first 20 queued songs were saved.')));
    setState(()=>crates.add({'name':chosen,'tracks':tracks}));await _saveCrates();
  }
  Future<void> _createCrateWithTrack(T track)async{
    if(!mounted)return;
    if(crates.length>=5){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('You can save up to 5 crates. Delete a crate to make room.')));return;}
    final nameCtrl=TextEditingController();
    final name=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('Create New Crate'),
      content:TextField(controller:nameCtrl,autofocus:true,maxLength:30,decoration:const InputDecoration(hintText:'Enter crate name')),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('CANCEL')),TextButton(onPressed:()=>Navigator.pop(ctx,nameCtrl.text.trim()),child:const Text('CREATE'))],
    ));
    final chosen=nameCtrl.text.trim();nameCtrl.dispose();
    if(name==null||chosen.isEmpty||!mounted)return;
    setState(()=>crates.add({'name':chosen,'tracks':[{'p':track.p,'n':track.n}]}));
    await _saveCrates();
    if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Created "${chosen}" with ${track.n}.')));
  }
  Future<void> _addTrackToCrate(int index,T track)async{
    if(index<0||index>=crates.length||!mounted)return;
    final list=(crates[index]['tracks'] as List?)??<dynamic>[];
    if(list.any((item)=>item is Map&&item['p']==track.p)){
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('That song is already in this crate.')));return;
    }
    if(list.length>=20){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('This crate is full (20 songs).')));return;}
    setState(()=>list.add({'p':track.p,'n':track.n}));
    await _saveCrates();
    if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Added ${track.n} to "${crates[index]['name']}".')));
  }
  Future<void> _addSongsToCrate(int index,StateSetter setDialog)async{
    if(index<0||index>=crates.length||!mounted)return;
    final current=(crates[index]['tracks'] as List?)??<dynamic>[];
    if(current.length>=20){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('This crate is full (20 songs).')));return;}
    final picked=await FilePicker.platform.pickFiles(type:FileType.audio,allowMultiple:true);
    if(picked==null||_disposed||!mounted||index>=crates.length)return;
    final list=(crates[index]['tracks'] as List?)??<dynamic>[];
    final paths=<String>{for(final item in list) if(item is Map&&item['p'] is String) item['p'] as String};
    var duplicates=0,added=0;
    for(final file in picked.files){
      final path=file.path;if(path==null)continue;
      if(paths.contains(path)){duplicates++;continue;}
      if(list.length>=20)break;
      paths.add(path);list.add({'p':path,'n':file.name});added++;
    }
    setState((){});setDialog((){});await _saveCrates();
    if(!mounted)return;
    final message=added==0
      ?(duplicates>0?'All selected songs are already in this crate.':'No songs were added.')
      :'Added $added song${added==1?'':'s'} to "${crates[index]['name']}"${duplicates>0?' ($duplicates duplicates skipped)':''}.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(message)));
  }
  Future<void> _showQueueTrackActions(T track)async{
    if(!mounted)return;
    final action=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('Add to Crate'),content:Text(track.n,maxLines:2,overflow:TextOverflow.ellipsis),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,'cancel'),child:const Text('CANCEL')),TextButton(onPressed:()=>Navigator.pop(ctx,'add'),child:const Text('ADD TO CRATE'))],
    ));
    if(action!='add'||!mounted)return;
    final choice=await showDialog<int>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('Choose a crate'),
      content:SizedBox(width:double.maxFinite,child:Column(mainAxisSize:MainAxisSize.min,children:[
        if(crates.isEmpty)const Padding(padding:EdgeInsets.all(12),child:Text('No crates yet. Create one for this song.')),
        ...List.generate(crates.length,(i){
          final count=((crates[i]['tracks'] as List?)??[]).length;
          return ListTile(dense:true,leading:const Icon(Icons.library_music),title:Text('${crates[i]['name']}',maxLines:1,overflow:TextOverflow.ellipsis),subtitle:Text('$count/20 songs'),onTap:()=>Navigator.pop(ctx,i));
        }),
        ListTile(dense:true,leading:const Icon(Icons.create_new_folder),title:const Text('Create New Crate'),enabled:crates.length<5,onTap:()=>Navigator.pop(ctx,-1)),
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,-2),child:const Text('CANCEL'))],
    ));
    if(choice==null||choice==-2||!mounted)return;
    if(choice==-1){await _createCrateWithTrack(track);}
    else if(choice>=0&&choice<crates.length){await _addTrackToCrate(choice,track);}
  }
  Future<void> _loadCrate(int index,{bool shuffle=false})async{
    if(index<0||index>=crates.length)return;
    if(shuffle&&!au){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Shuffle is available only when Auto Mix is ON.')));return;}
    if(!au){await _showCrateSongs(index);return;}
    final raw=(crates[index]['tracks'] as List?)??[];
    final tracks=<T>[];
    for(final item in raw){if(item is Map&&item['p'] is String&&item['n'] is String){final t=T(item['p'] as String,item['n'] as String);try{if(await File(t.p).exists())tracks.add(t);}catch(_){}}}
    if(tracks.isEmpty){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('No saved songs are currently available in this crate.')));return;}
    if(shuffle)tracks.shuffle();
    if(!mounted)return;
    setState((){q=tracks;qi=tracks.length>1?1:0;});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('${tracks.length}/${raw.length} songs available')));
    final playing=P(l).playing;
    if(playing){await _ld(O(l),tracks.first);if(au){} }
    else{await _ld(l,tracks.first,pl:true);if(tracks.length>1)await _ld(O(l),tracks[1]);}
    if(mounted)setState((){});
  }
  Future<void> _loadPickedTrack(T t)async{
    if(au){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Select a crate to load its automatic mix.')));return;}
    final target=P(l).playing?O(l):(na==null?D.a:nb==null?D.b:O(l));
    await _ld(target,t);
    if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Loaded ${t.n} into Deck ${target==D.a?'A':'B'}; press Play when ready.')));
  }
  Future<void> _showRecentSongs()async{
    if(!mounted)return;
    await showDialog<void>(
      context:context,
      builder:(ctx)=>AlertDialog(
        title:const Text('Recent Played — select a deck'),
        content:SizedBox(width:double.maxFinite,height:320,child:ListView.builder(
          itemCount:recent.length,
          itemBuilder:(ctx,i){final t=recent[i];return ListTile(
            dense:true,title:Text(t.n,maxLines:1,overflow:TextOverflow.ellipsis),
            subtitle:Text(t.p,maxLines:1,overflow:TextOverflow.ellipsis),
            onTap:(){Navigator.pop(ctx);_loadPickedTrack(t);},
          );},
        )),
        actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('CLOSE'))],
      ),
    );
  }
  Future<void> _showCrateSongs(int index)async{
    if(index<0||index>=crates.length||!mounted)return;
    await showDialog<void>(
      context:context,
      builder:(ctx)=>StatefulBuilder(builder:(ctx,setDialog){
        final tracks=(crates[index]['tracks'] as List?)??[];
        return AlertDialog(
          title:Text('${crates[index]['name']} — ${tracks.length}/20 songs'),
          content:SizedBox(width:double.maxFinite,height:340,child:tracks.isEmpty
            ?const Center(child:Text('This crate has no songs.'))
            :ListView.builder(itemCount:tracks.length,itemBuilder:(ctx,i){
              final item=tracks[i];
              if(item is! Map||item['p'] is! String||item['n'] is! String)return const SizedBox.shrink();
              final t=T(item['p'] as String,item['n'] as String);
              return ListTile(
                dense:true,title:Text(t.n,maxLines:1,overflow:TextOverflow.ellipsis),
                subtitle:const Text('Tap to load into a deck'),
                onTap:(){Navigator.pop(ctx);_loadPickedTrack(t);},
                trailing:IconButton(
                  tooltip:'Remove song from crate',icon:const Icon(Icons.remove_circle_outline),
                  onPressed:(){setDialog((){(crates[index]['tracks'] as List).removeAt(i);});setState((){});unawaited(_saveCrates());},
                ),
              );
            }),
          ),
          actions:[TextButton(onPressed:()=>_addSongsToCrate(index,setDialog),child:const Text('ADD SONGS')),TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('DONE'))],
        );
      }),
    );
  }
  Future<void> _deleteCrate(int index)async{if(index<0||index>=crates.length)return;final name=crates[index]['name'];final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Delete crate?'),content:Text('Delete "$name"? The original music files will not be deleted.'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('CANCEL')),TextButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('DELETE'))]));if(ok==true&&mounted){setState(()=>crates.removeAt(index));await _saveCrates();}}
  T? _nx(){
    if(q.isEmpty)return null;
    final t=q[qi%q.length];qi=(qi+1)%q.length;return t;
  }
  Future<Uint8List?> _rt(String p)async{
    try{final t=await AudioTags.read(p);if(t!=null&&t.pictures.isNotEmpty)return t.pictures.first.bytes;}catch(_){}
    return null;
  }
  Future<void> _analyseBpm(D d) async {
    final path=PathOf(d);
    if(path==null||N(d)==null||_disposed)return;
    final cached=_bpmCache[path];
    if(cached!=null){if(mounted)setState(()=>SBPM(d,cached));return;}
    final token=_gen(d);
    if(mounted)setState(()=>SBBusy(d,true));
    File? waveFile;
    try{
      final output=File('${Directory.systemTemp.path}/blendjam_bpm_${DateTime.now().microsecondsSinceEpoch}.wave');
      waveFile=output;
      final progress=await JustWaveform.extract(
        audioInFile:File(path),
        waveOutFile:output,
        zoom:const WaveformZoom.pixelsPerSecond(20),
      ).where((p)=>p.waveform!=null||p.progress>=1.0).first.timeout(const Duration(minutes:3));
      if(_disposed||token!=_gen(d))return;
      final w=progress.waveform;
      if(w==null||w.length<200)throw StateError('Audio is too short to analyse.');
      const rate=20.0;
      final count=w.length;
      final window=(rate*40).round().clamp(200,count).toInt();
      final start=((count-window)~/2).clamp(0,count-window).toInt();
      final energy=List<double>.generate(window,(i){
        final index=start+i;
        final lo=w.getPixelMin(index).abs().toDouble();
        final hi=w.getPixelMax(index).abs().toDouble();
        return m.max(lo,hi);
      });
      final onset=List<double>.filled(window,0);
      for(var i=1;i<window;i++){onset[i]=m.max(0,energy[i]-energy[i-1]);}
      final mean=onset.reduce((a,b)=>a+b)/onset.length;
      for(var i=0;i<onset.length;i++){onset[i]-=mean;}
      var bestScore=-1.0,bestLag=0;
      final minLag=(rate*60/200).round(),maxLag=(rate*60/55).round();
      for(var lag=minLag;lag<=maxLag&&lag<onset.length~/2;lag++){
        var dot=0.0,aa=0.0,bb=0.0;
        for(var i=lag;i<onset.length;i++){
          final x=onset[i],y=onset[i-lag];
          dot+=x*y;aa+=x*x;bb+=y*y;
        }
        final score=dot/(m.sqrt(aa*bb)+1e-9);
        if(score>bestScore){bestScore=score;bestLag=lag;}
      }
      if(bestLag==0||bestScore<0.04)throw StateError('No reliable beat pattern found.');
      var value=rate*60/bestLag;
      if(value<70)value*=2;
      if(value>180)value/=2;
      if(value<40||value>240||!value.isFinite)throw StateError('Could not estimate a reliable BPM.');
      _bpmCache[path]=value;
      if(!_disposed&&token==_gen(d)&&mounted)setState(()=>SBPM(d,value));
    }catch(e){
      debugPrint('BlendJam BPM analysis error: $e');
      if(!_disposed&&token==_gen(d)&&mounted){
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Could not detect a reliable BPM for this track.')));
      }
    }finally{
      try{if(waveFile!=null&&await waveFile.exists())await waveFile.delete();}catch(_){}
      if(!_disposed&&token==_gen(d)&&mounted)setState(()=>SBBusy(d,false));
    }
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
      SN(d,t.n);SA(d,null);SPath(d,t.p);SBPM(d,_bpmCache[t.p]);SBBusy(d,false);
      if(pl){l=d;xv=d==D.a?0:1;await ap.setVolume(1);unawaited(ap.play().catchError((Object e){debugPrint('BlendJam deck playback error: $e');}));}
      if(mounted)setState((){});
      _rt(t.p).then((bytes){if(!_disposed&&token==_gen(d)){SA(d,bytes);if(mounted)setState((){});}});
      return true;
    }catch(_){
      if(token==_gen(d)){SN(d,null);SA(d,null);SPath(d,null);SBPM(d,null);SBBusy(d,false);try{await ap.stop();}catch(_){}}
      if(mounted)setState((){});
      return false;
    }
  }
  Future<void> _as()async{
    if(q.isEmpty||_disposed)return;
    if(N(l)==null){
      final f=_nx();if(f!=null){final ok=await _ld(l,f,pl:true);if(!ok)return;}
    }
    if(au&&N(O(l))==null){
      final f=_nx();if(f!=null)await _ld(O(l),f);
    }
  }
  void _ck(D d,Duration p){
    if(_disposed||xf||_transitioning||d!=l)return;
    final ap=P(d),du=ap.duration;
    if(du==null||!ap.playing)return;
    final remaining=du-p;
    final incoming=O(d);
    if(au&&remaining<=Duration(seconds:15)&&N(incoming)==null){
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
    if(_disposed||xf||_transitioning)return;
    final incoming=O(outgoing),sp=P(outgoing),tp=P(incoming);
    final outgoingName=N(outgoing);
    if(N(incoming)==null||tp.duration==null)return;

    // Lock before the first await so position events cannot start a second fade.
    _transitioning=true;
    xf=true;
    _fadeTimer?.cancel();
    try{
      await tp.setVolume(0);
      await tp.seek(const Duration(milliseconds:200));
      // just_audio's play() future can remain pending until playback stops or
      // completes. Do not await it here: the fade loop must run concurrently.
      unawaited(tp.play().catchError((Object e){debugPrint('BlendJam incoming deck playback error: $e');}));
      final started=DateTime.now();

      // Use one sequential loop instead of an async Timer.periodic callback.
      // Timer.periodic can overlap volume writes when platform calls take longer
      // than the tick interval, causing the mix to stall or jump.
      while(!_disposed){
        final elapsed=DateTime.now().difference(started);
        final t=(elapsed.inMilliseconds/_fadeLength.inMilliseconds).clamp(0.0,1.0).toDouble();
        final out=m.cos(t*m.pi/2),inc=m.sin(t*m.pi/2);
        xv=outgoing==D.a?t:1-t;

        await sp.setVolume(out);
        await tp.setVolume(inc);
        if(mounted)setState((){});
        if(t>=1)break;
        await Future.delayed(const Duration(milliseconds:50));
      }

      if(_disposed)return;
      await tp.setVolume(1);
      await sp.setVolume(0);
      await sp.stop();
      SN(outgoing,null);
      SA(outgoing,null);SPath(outgoing,null);SBPM(outgoing,null);SBBusy(outgoing,false);
      l=incoming;
      xv=incoming==D.a?0:1;
      _preparedFor.remove(outgoingName??'');
      _transitioning=false;
      xf=false;
      ar=false;
      if(mounted)setState((){});

      // Keep the next deck prepared for uninterrupted alternating playback.
      if(au&&N(O(l))==null){
        final f=_nx();
        if(f!=null)await _ld(O(l),f);
      }
    }catch(_){
      _transitioning=false;
      xf=false;
      try{await tp.setVolume(1);}catch(_){}
      if(mounted)setState((){});
    }
  }
  Future<void> _tg(D d)async{
    if(_disposed||_transitioning)return;
    final pl=P(d);
    if(pl.playing){
      await pl.pause();
    }else if(N(d)==null){if(!au)return;
      final f=_nx();if(f!=null)await _ld(d,f,pl:true);
    }else if(d!=l){
      final active=P(l);
      if(active.playing){
        // If the other deck is already playing, transition to the loaded deck.
        await _beginFade(l);
      }else{
        // With Auto Mix off, a loaded deck must still start audibly on demand.
        try{await active.setVolume(0);}catch(_){}
        l=d;xv=d==D.a?0:1;
        try{await pl.setVolume(1);unawaited(pl.play().catchError((Object e){debugPrint('BlendJam manual deck playback error: $e');}));}catch(_){}
      }
    }else{
      try{
        l=d;xv=d==D.a?0:1;
        await pl.setVolume(1);
        unawaited(pl.play().catchError((Object e){debugPrint('BlendJam manual deck playback error: $e');}));
      }catch(_){}
    }
    if(mounted)setState((){});
  }
  bool _manualStartingA=false,_manualStartingB=false;
  Future<void> _manualCrossfade(double v)async{
    if(xf||_disposed)return;
    final value=v.clamp(0.0,1.0).toDouble();
    xv=value;
    // Any movement toward a loaded deck starts that deck, not only movement
    // past the midpoint. This makes the fader itself the manual start control.
    final startA=value<1.0&&na!=null&&!a.playing;
    final startB=value>0.0&&nb!=null&&!b.playing;
    try{await a.setVolume(1-value);}catch(_){}
    try{await b.setVolume(value);}catch(_){}
    if(startA&&!_manualStartingA){
      _manualStartingA=true;
      unawaited(a.play().catchError((Object e){debugPrint('BlendJam manual deck A playback error: $e');}).whenComplete(()=>_manualStartingA=false));
    }
    if(startB&&!_manualStartingB){
      _manualStartingB=true;
      unawaited(b.play().catchError((Object e){debugPrint('BlendJam manual deck B playback error: $e');}).whenComplete(()=>_manualStartingB=false));
    }
    // Keep the logical active deck aligned with the louder side of the mix.
    final target=value>=0.5?D.b:D.a;
    if(N(target)!=null)l=target;
    if(mounted)setState((){});
  }
  Future<void> _pk(D d)async{
    final r=await FilePicker.platform.pickFiles(type:FileType.audio);
    if(r==null||_disposed)return;
    final p=r.files.single.path;if(p==null)return;
    final target=P(l).playing?O(l):d;
    // If neither deck is playing, a file picked for either deck should start audibly.
    final picked=T(p,r.files.single.name);await _rememberTracks([picked]);await _ld(target,picked,pl:!P(l).playing);
    if(P(l).playing){try{await P(target).setVolume(0);}catch(_){}}
  }
  Future<void> _aq()async{
    final r=await FilePicker.platform.pickFiles(type:FileType.audio,allowMultiple:true);
    if(r==null||_disposed)return;
    final tracks=r.files.where((f)=>f.path!=null).map((f)=>T(f.path!,f.name)).toList();
    if(!mounted)return;await _rememberTracks(tracks);setState(()=>q.addAll(tracks));
    if(au)await _as();
  }
  void _qp(){
    showModalBottomSheet(context:context,builder:(c)=>SafeArea(child:Column(children:[
      Padding(padding:const EdgeInsets.fromLTRB(16,12,8,4),child:Row(children:[Expanded(child:Text('MY CRATES ${crates.length}/5',style:const TextStyle(fontWeight:FontWeight.bold))),IconButton(tooltip:'Save current queue as crate',icon:const Icon(Icons.bookmark_add),onPressed:()=>_saveQueueAsCrate()),IconButton(tooltip:'Close',icon:const Icon(Icons.close),onPressed:()=>Navigator.pop(c))])),
      if(recent.isNotEmpty) ListTile(dense:true,leading:const Icon(Icons.history),title:const Text('Recent 20 Songs'),subtitle:Text(lastFolder==null?'Saved locally':'Last folder: $lastFolder',maxLines:1,overflow:TextOverflow.ellipsis),onTap:(){Navigator.pop(c);_loadRecentQueue();},trailing:au?IconButton(tooltip:'Shuffle recent songs',icon:const Icon(Icons.shuffle),onPressed:(){Navigator.pop(c);_loadRecentQueue(shuffle:true);}):null),
      if (crates.isNotEmpty)
        SizedBox(
          height: crates.length > 2 ? 150 : null,
          child: ListView(
            shrinkWrap: crates.length <= 2,
            children: List.generate(crates.length, (i) {
              final cr = crates[i];
              final count = ((cr['tracks'] as List?) ?? []).length;
              return ListTile(
                dense: true,
                leading: const Icon(Icons.library_music),
                title: Text('${cr['name']}', overflow: TextOverflow.ellipsis),
                subtitle: Text('$count/20 saved songs'),
                onTap: () async {
                  Navigator.pop(c);
                  await _loadCrate(i);
                },
                trailing: PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'shuffle') {
                      Navigator.pop(c);
                      _loadCrate(i, shuffle: true);
                    } else if (v == 'delete') {
                      _deleteCrate(i);
                    }
                  },
                  itemBuilder: (_) => [
                    if (au) const PopupMenuItem(value: 'shuffle', child: Text('Load shuffled')),
                    PopupMenuItem(value: 'delete', child: Text('Delete crate')),
                  ],
                ),
              );
            }),
          ),
        ),
      ListTile(title:Text('QUEUE ${q.length} (loops)'),trailing:Row(mainAxisSize:MainAxisSize.min,children:[
        IconButton(icon:Icon(Icons.add),onPressed:()async{await _aq();if(c.mounted)Navigator.pop(c);if(mounted)_qp();}),
        IconButton(icon:Icon(Icons.close),onPressed:()=>Navigator.pop(c))])),
      Expanded(child:ListView.builder(itemCount:q.length,itemBuilder:(x,i)=>ListTile(dense:true,title:Text(q[i].n,overflow:TextOverflow.ellipsis,style:TextStyle(color:N(l)==q[i].n?C:Colors.white)),onTap:()async{
        Navigator.pop(c);final d=P(l).playing?O(l):l;await _ld(d,q[i],pl:!P(l).playing);
      },onLongPress:()=>_showQueueTrackActions(q[i]))))
    ])));
  }
Widget _dk(D d,bool up)=>Deck(deck:d,pl:P(d),name:N(d)??'No track',art:A(d),live:l==d,next:N(d)!=null&&l!=d,bpm:BPM(d),bpmLoading:BPMBusy(d),onBpm:()=>_analyseBpm(d),onPlay:()=>_tg(d),onPick:()=>_pk(d),onSeek:(s)async=>await P(d).seek(P(d).position+Duration(seconds:s)),lift:up);
@override Widget build(BuildContext c)=>Scaffold(backgroundColor:Colors.black,appBar:AppBar(backgroundColor:Colors.black,title:Text('BlendJam'),
actions:[Text('AUTO',style:TextStyle(fontSize:11)),Switch(value:au,activeColor:C,onChanged:(v)async{setState(()=>au=v);if(v)await _as();}),PopupMenuButton(icon:Icon(Icons.upload_file),itemBuilder:(_)=>[PopupMenuItem(child:Text('Load A'),onTap:()=>_pk(D.a)),PopupMenuItem(child:Text('Load B'),onTap:()=>_pk(D.b)),PopupMenuItem(child:Text('Add Queue'),onTap:()=>_aq())]),IconButton(icon:Icon(Icons.queue_music),onPressed:_qp)]),
body:SafeArea(child:Column(children:[Flexible(child:_dk(D.a,false)),Padding(padding:EdgeInsets.symmetric(horizontal:12,vertical:2),child:Column(children:[Row(children:[Text('A',style:TextStyle(fontSize:12)),Expanded(child:Slider(value:xv,min:0,max:1,activeColor:C,onChanged:(v)=>unawaited(_manualCrossfade(v)))),Text('B',style:TextStyle(fontSize:12))]),Text(xf?'MIXING ${(xv*100).toInt()}%':'',style:TextStyle(color:C,fontSize:11))])),Flexible(child:_dk(D.b,true))])));}
class Deck extends StatefulWidget{final D deck;final AudioPlayer pl;final String name;final Uint8List?art;final bool live,next,lift,bpmLoading;final double? bpm;final VoidCallback onPlay,onPick,onBpm;final Future<void> Function(int)onSeek;const Deck({super.key,required this.deck,required this.pl,required this.name,required this.art,required this.live,required this.next,required this.lift,required this.bpm,required this.bpmLoading,required this.onBpm,required this.onPlay,required this.onPick,required this.onSeek});@override State<Deck>createState()=>DD();}
class DD extends State<Deck> with TickerProviderStateMixin{late AnimationController an,rg,titleScroll;StreamSubscription<bool>?ps;@override void initState(){super.initState();an=AnimationController(vsync:this,duration:Duration(seconds:3));rg=AnimationController(vsync:this,duration:Duration(seconds:5));titleScroll=AnimationController(vsync:this,duration:Duration(seconds:10));ps=widget.pl.playingStream.listen((p){if(!mounted)return;if(p){an.repeat();rg.repeat();titleScroll.repeat();}else{an.stop();rg.stop();titleScroll.stop();}});if(widget.pl.playing){an.repeat();rg.repeat();titleScroll.repeat();}}@override void didUpdateWidget(covariant Deck oldWidget){super.didUpdateWidget(oldWidget);if(oldWidget.name!=widget.name){titleScroll.value=0;if(widget.pl.playing)titleScroll.repeat();else titleScroll.stop();}} @override void dispose(){ps?.cancel();an.dispose();rg.dispose();titleScroll.dispose();super.dispose();}
String _f(Duration d)=>'${d.inMinutes.remainder(60).toString().padLeft(2,'0')}:${(d.inSeconds%60).toString().padLeft(2,'0')}';
Widget _da(){Widget im;if(widget.art!=null&&widget.art!.isNotEmpty)im=Image.memory(widget.art!,width:130,height:130,fit:BoxFit.cover);else im=Image.asset('assets/images/default_cover.png',width:130,height:130,fit:BoxFit.cover,errorBuilder:(c,e,s)=>Icon(Icons.music_note,size:60));
return Container(width:135,height:135,decoration:BoxDecoration(shape:BoxShape.circle,color:Colors.black,border:Border.all(color:widget.live?Colors.white24:Colors.white10)),child:ClipOval(child:Stack(fit:StackFit.expand,children:[im,CustomPaint(painter:Gr()),Center(child:Container(width:50,height:50,decoration:BoxDecoration(shape:BoxShape.circle,color:Color(0xFF101010)),child:Container(margin:EdgeInsets.all(2),decoration:BoxDecoration(shape:BoxShape.circle,border:Border.all(color:widget.live?Color(0xFFCEBBFF):Colors.white24)))))]))); }
@override Widget build(BuildContext c)=>Column(mainAxisAlignment:widget.lift?MainAxisAlignment.start:MainAxisAlignment.center,children:[Text('DECK ${widget.deck==D.a?'A':'B'} ${widget.live?'(LIVE)':widget.next?'(NEXT)':''}',style:TextStyle(fontSize:11,color:widget.live?Color(0xFFCEBBFF):Colors.white70)),SizedBox(width:165,height:165,child:Stack(alignment:Alignment.center,children:[RotationTransition(turns:rg,child:CustomPaint(size:Size(165,165),painter:RL(live:widget.live,has:widget.name!='No track',play:widget.pl.playing))),RotationTransition(turns:an,child:_da()),StreamBuilder<bool>(stream:widget.pl.playingStream,initialData:widget.pl.playing,builder:(x,s){bool pl=s.data??false;return InkWell(customBorder:CircleBorder(),onTap:widget.onPlay,child:Container(width:48,height:48,decoration:BoxDecoration(shape:BoxShape.circle,color:Color(0xFFCEBBFF)),child:Icon(pl?Icons.pause:Icons.play_arrow,color:Colors.black)));})])),LayoutBuilder(builder:(ctx,limits){final barWidth=limits.maxWidth*0.5;final style=TextStyle(fontSize:11,color:Colors.white);final painter=TextPainter(text:TextSpan(text:widget.name,style:style),textDirection:TextDirection.ltr,maxLines:1)..layout();final textWidth=painter.width;return Container(width:barWidth,height:20,alignment:Alignment.center,clipBehavior:Clip.hardEdge,decoration:BoxDecoration(color:Color(0xFF171717),borderRadius:BorderRadius.circular(4)),child:textWidth<=barWidth?Center(child:Text(widget.name,style:style,maxLines:1,softWrap:false)):AnimatedBuilder(animation:titleScroll,builder:(ctx,child)=>Transform.translate(offset:Offset((-textWidth+(barWidth+textWidth)*titleScroll.value).toDouble(),0),child:child),child:SizedBox(width:textWidth,child:Text(widget.name,style:style,maxLines:1,softWrap:false))));}),Padding(padding:EdgeInsets.only(top:1),child:Text(widget.bpm!=null?'BPM ${widget.bpm!.round()}':widget.bpmLoading?'ANALYSING BPM…':'BPM —',style:TextStyle(fontSize:10,color:widget.bpm!=null?Color(0xFFCEBBFF):Colors.white38))),StreamBuilder<Duration>(stream:widget.pl.positionStream,builder:(x,s){var po=s.data??Duration.zero;var du=widget.pl.duration??Duration(seconds:1);var pr=(po.inMilliseconds/du.inMilliseconds).clamp(0.0,1.0);return Column(children:[SizedBox(height:18,child:Slider(value:pr,min:0,max:1,activeColor:widget.live?Color(0xFFCEBBFF):Colors.white38,onChanged:(v)async=>await widget.pl.seek(Duration(milliseconds:(v*du.inMilliseconds).round())))),Text('${_f(po)} / ${_f(du)}',style:TextStyle(fontSize:10,color:Colors.white38)),Row(mainAxisAlignment:MainAxisAlignment.center,children:[IconButton(icon:Icon(Icons.replay_10),visualDensity:VisualDensity.compact,onPressed:()=>widget.onSeek(-10)),IconButton(icon:Icon(Icons.folder_open),visualDensity:VisualDensity.compact,onPressed:widget.onPick),IconButton(icon:Icon(Icons.speed),tooltip:'Analyse BPM',visualDensity:VisualDensity.compact,onPressed:widget.bpmLoading?null:widget.onBpm),IconButton(icon:Icon(Icons.forward_10),visualDensity:VisualDensity.compact,onPressed:()=>widget.onSeek(10))])]);})]);}
class RL extends CustomPainter{final bool live,has,play;RL({required this.live,required this.has,required this.play});@override void paint(Canvas cv,Size sz){var ct=Offset(sz.width/2,sz.height/2);var rad=sz.width/2;if(!has){cv.drawCircle(ct,rad,Paint()..style=PaintingStyle.stroke..strokeWidth=2..color=Colors.white12);return;}var p=Paint()..style=PaintingStyle.stroke..strokeWidth=5..shader=SweepGradient(colors:[Color(0xFF087BFF),Color(0xFF111111),Color(0xFFFF7A00),Color(0xFF111111),Color(0xFF087BFF)]).createShader(Rect.fromCircle(center:ct,radius:rad));cv.drawCircle(ct,rad-2,p);if(play){var g=Paint()..style=PaintingStyle.stroke..strokeWidth=12..color=(live?Color(0xFFCEBBFF):Colors.orange).withOpacity(0.25)..maskFilter=MaskFilter.blur(BlurStyle.normal,8);cv.drawCircle(ct,rad-2,g);}}@override bool shouldRepaint(covariant RL o)=>o.live!=live||o.has!=has||o.play!=play;}
class Gr extends CustomPainter{@override void paint(Canvas cv,Size sz){var ct=Offset(sz.width/2,sz.height/2);var r=sz.width/2;var p=Paint()..style=PaintingStyle.stroke..strokeWidth=1..color=Colors.white.withOpacity(0.06);for(double i=20;i<r-5;i+=5)cv.drawCircle(ct,i,p);}@override bool shouldRepaint(covariant CustomPainter o)=>false;}
