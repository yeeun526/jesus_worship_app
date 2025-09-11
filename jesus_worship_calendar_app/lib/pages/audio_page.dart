// lib/pages/audio_page.dart

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';

import '../models/audio.dart';
import '../services/firestore_service.dart'; // FirestoreService 임포트
import '../widgets/permission_widget.dart'; // 권한 확인 위젯

class AudioPage extends StatefulWidget {
  const AudioPage({Key? key}) : super(key: key);

  @override
  _AudioPageState createState() => _AudioPageState();
}

class _AudioPageState extends State<AudioPage> {
  final _audioService = FirestoreService();
  final _player = AudioPlayer();

  bool _isAdmin = false;
  bool _isPlaying = false;
  bool _isPaused = false;

  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  List<Audio> _audios = []; // 전체 음원 목록
  List<Audio> _filteredAudios = []; // 필터된 음원 목록
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkAdmin();
    _loadAudios();

    _player.positionStream.listen((position) {
      if (!mounted) return;
      setState(() => _position = position);
    });
    _player.durationStream.listen((duration) {
      if (!mounted) return;
      setState(() => _duration = duration ?? Duration.zero);
    });
    _player.playerStateStream.listen((state) {
      if (!mounted) return;
      final playing = state.playing;
      setState(() {
        _isPlaying = playing;
        _isPaused =
            !playing && _position > Duration.zero && _position < _duration;
      });
    });
  }

  @override
  void dispose() {
    _player.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkAdmin() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (!mounted) return;
    setState(() {
      _isAdmin = (doc.data()?['role'] as String?) == 'admin';
    });
  }

  Future<void> _loadAudios() async {
    final audios = await _audioService.fetchAllAudios();
    if (!mounted) return;
    setState(() {
      _audios = audios;
      _filteredAudios = audios;
    });
  }

  void _search() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filteredAudios =
          _audios.where((a) => a.title.toLowerCase().contains(q)).toList();
    });
  }

  Future<void> _promptUpload() async {
    final titleCtrl = TextEditingController();
    PlatformFile? pickedFile;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setLocal) {
          return AlertDialog(
            title: const Text('오디오 업로드'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: '제목'),
                  onChanged: (_) => setLocal(() {}),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.attach_file),
                  label: const Text('파일 선택'),
                  onPressed: () async {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['mp3', 'wav', 'mp4'],
                      withData: true,
                    );
                    if (result != null && result.files.isNotEmpty) {
                      setLocal(() => pickedFile = result.files.single);
                    }
                  },
                ),
                if (pickedFile != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      pickedFile!.name,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed:
                    (titleCtrl.text.trim().isNotEmpty && pickedFile != null)
                        ? () => Navigator.pop(ctx, true)
                        : null,
                child: const Text('확인'),
              ),
            ],
          );
        });
      },
    );
    if (ok != true) return;

    try {
      await _audioService.addAudioFile(
          title: titleCtrl.text.trim(), file: pickedFile!);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('업로드 성공')));
      _loadAudios();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('업로드 실패: $e')));
    }
  }

  Future<void> _togglePlayPause() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.play();
    }
    // playerStateStream에서 상태 업데이트됨
  }

  Future<void> _seekTo(Duration position) async {
    await _player.seek(position);
  }

  Future<void> _playNewAudio(String url) async {
    await _player.stop();
    await _player.setUrl(url);
    await _player.play();
    // 상태는 스트림으로 반영
  }

  Future<void> _deleteAudio(String audioId) async {
    // 재생 중이면 정지
    await _player.stop();
    try {
      await _audioService.deleteAudioFile(audioId);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('음원 삭제 완료')));
      _loadAudios();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('음원 삭제 실패: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // 시스템 뒤로가기/스와이프로 나가기 직전에 재생 중지
      onWillPop: () async {
        await _player.stop();
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('음원 페이지'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              await _player.stop(); // 먼저 멈추기
              if (!mounted) return;
              Navigator.pushReplacementNamed(context, '/calendar'); // 교체 이동
            },
          ),
        ),
        floatingActionButton: _isAdmin
            ? FloatingActionButton(
                onPressed: _promptUpload,
                child: const Icon(Icons.upload_file),
              )
            : null,
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: TextField(
                controller: _searchCtrl,
                decoration: const InputDecoration(labelText: '검색'),
                onChanged: (_) => _search(),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _filteredAudios.length,
                itemBuilder: (ctx, idx) {
                  final audio = _filteredAudios[idx];
                  return ListTile(
                    title: Text(audio.title),
                    trailing: _isAdmin
                        ? IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _deleteAudio(audio.id),
                          )
                        : null,
                    onTap: () => _playNewAudio(audio.url),
                  );
                },
              ),
            ),
          ],
        ),
        bottomNavigationBar: (_isPlaying || _isPaused)
            ? Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Slider(
                      value: _position.inSeconds
                          .clamp(0, _duration.inSeconds)
                          .toDouble(),
                      min: 0,
                      max: (_duration.inSeconds == 0 ? 1 : _duration.inSeconds)
                          .toDouble(),
                      onChanged: (v) => _seekTo(Duration(seconds: v.toInt())),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon:
                              Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                          onPressed: _togglePlayPause,
                        ),
                        Text(
                          '${_mmss(_position)} / ${_mmss(_duration)}',
                        ),
                      ],
                    ),
                  ],
                ),
              )
            : null,
      ),
    );
  }

  String _mmss(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
