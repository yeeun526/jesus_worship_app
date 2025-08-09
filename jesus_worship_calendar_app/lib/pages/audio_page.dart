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
  final _audioService = FirestoreService(); // FirestoreService 사용
  final _player = AudioPlayer();
  bool _isAdmin = false;
  bool _isPlaying = false;
  bool _isPaused = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  List<Audio> _audios = []; // 전체 음원 목록
  List<Audio> _filteredAudios = []; // 필터된 음원 목록
  final _searchCtrl = TextEditingController(); // 검색어를 입력받을 TextController

  @override
  void initState() {
    super.initState();
    _checkAdmin();
    _loadAudios(); // 음원 목록 로딩
    _player.positionStream.listen((position) {
      if (mounted) {
        setState(() {
          _position = position;
        });
      }
    });
    _player.durationStream.listen((duration) {
      if (mounted) {
        setState(() {
          _duration = duration ?? Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _checkAdmin() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    setState(() {
      _isAdmin = (doc.data()?['role'] as String?) == 'admin';
    });
  }

  // 음원 목록 로드
  Future<void> _loadAudios() async {
    final audios = await _audioService.fetchAllAudios();
    setState(() {
      _audios = audios;
      _filteredAudios = audios; // 전체 음원 목록을 필터링된 목록에 초기화
    });
  }

  // 검색 함수
  void _search() {
    final query = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filteredAudios = _audios
          .where((audio) => audio.title.toLowerCase().contains(query))
          .toList();
    });
  }

  // 음원 추가 함수
  Future<void> _promptUpload() async {
    final titleCtrl = TextEditingController();
    PlatformFile? pickedFile;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setState) {
          return AlertDialog(
            title: const Text('오디오 업로드'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: '제목'),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.attach_file),
                  label: const Text('파일 선택'),
                  onPressed: () async {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['mp3', 'wav', 'mp4'],
                    );
                    if (result != null && result.files.isNotEmpty) {
                      setState(() {
                        pickedFile = result.files.single;
                      });
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

    final title = titleCtrl.text.trim();
    try {
      await _audioService.addAudioFile(title: title, file: pickedFile!);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('업로드 성공')));
      _loadAudios(); // 음원 추가 후 목록 갱신
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('업로드 실패: $e')));
    }
  }

  // 음원 제어 (일시정지 / 재개)
  Future<void> _togglePlayPause() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.play();
    }
    setState(() {
      _isPlaying = !_isPlaying;
      _isPaused = !_isPlaying;
    });
  }

  // 음악 슬라이더 조정
  Future<void> _seekTo(Duration position) async {
    await _player.seek(position);
  }

  // 음원 변경 시 현재 음원을 멈추고 새로운 음원으로 설정
  Future<void> _playNewAudio(String audioUrl) async {
    await _player.stop(); // 기존 음원 멈추기
    await _player.setUrl(audioUrl); // 새로운 음원 설정
    await _player.play(); // 새 음원 재생
    setState(() {
      _isPlaying = true;
      _isPaused = false;
    });
  }

  // 음원 삭제 함수
  Future<void> _deleteAudio(String audioId) async {
    await _player.stop(); // 음원 멈추기
    try {
      await _audioService.deleteAudioFile(audioId); // 음원 삭제
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('음원 삭제 완료')));
      _loadAudios(); // 음원 삭제 후 목록 갱신
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('음원 삭제 실패: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('음원 페이지'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // 뒤로가기 버튼을 누르면 CalendarPage로 이동
            Navigator.pushNamed(context, '/calendar'); // '/calendar' 라우팅 경로로 이동
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
              onChanged: (value) => _search(), // 검색어 변경 시 실시간 검색
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
                          onPressed: () => _deleteAudio(audio.id), // 삭제 버튼
                        )
                      : null,
                  onTap: () async {
                    _playNewAudio(audio.url); // 선택된 음원 재생
                  },
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
                    value: _position.inSeconds.toDouble(),
                    min: 0,
                    max: _duration.inSeconds.toDouble(),
                    onChanged: (value) {
                      final position = Duration(seconds: value.toInt());
                      _seekTo(position);
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(
                          _isPlaying ? Icons.pause : Icons.play_arrow,
                        ),
                        onPressed: _togglePlayPause,
                      ),
                      Text(
                        '${_position.inMinutes}:${(_position.inSeconds % 60).toString().padLeft(2, '0')} / ${_duration.inMinutes}:${(_duration.inSeconds % 60).toString().padLeft(2, '0')}',
                      ),
                    ],
                  ),
                ],
              ),
            )
          : null,
    );
  }
}
