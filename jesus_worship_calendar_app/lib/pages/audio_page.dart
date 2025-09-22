// lib/pages/audio_page.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';

import '../models/audio.dart';
import '../services/firestore_service.dart';
import '../widgets/permission_widget.dart';

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
  bool _isUploading = false;

  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  // 배속 관련
  final List<double> _rates = const [0.5, 0.6, 0.7, 0.8, 0.9, 1.0];
  double _currentRate = 1.0;

  List<Audio> _audios = [];
  List<Audio> _filteredAudios = [];
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
                      withData: kIsWeb ? true : false, // 웹은 bytes 필수
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
      setState(() => _isUploading = true);
      await _audioService.addAudioFile(
        title: titleCtrl.text.trim(),
        file: pickedFile!,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('업로드 성공')));
      _loadAudios();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('업로드 실패: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _togglePlayPause() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> _seekTo(Duration position) async {
    await _player.seek(position);
  }

  Future<void> _playNewAudio(String url) async {
    await _player.stop();
    await _player.setUrl(url);
    // 현재 선택된 배속 유지
    await _player.setSpeed(_currentRate);
    await _player.play();
  }

  Future<void> _deleteAudio(String audioId) async {
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

  Future<void> _applySpeed(double rate) async {
    setState(() => _currentRate = rate);
    try {
      await _player.setSpeed(rate);
    } catch (_) {
      // just_audio가 아직 준비 전이면 무시
    }
  }

  String _rateLabel(double r) {
    // 1.0 → 1x, 0.5 → 0.5x
    final s = r.toStringAsFixed(r == 1.0 ? 0 : 1);
    return '${s}x';
    // 필요하면 0.6~0.9도 소수 한 자리로 고정됨
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _player.stop();
        return true;
      },
      child: Stack(
        children: [
          Scaffold(
            appBar: AppBar(
              title: const Text('음원 페이지'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () async {
                  await _player.stop();
                  if (!mounted) return;
                  Navigator.pushReplacementNamed(context, '/calendar');
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
                    padding: const EdgeInsets.only(bottom: 120),
                    itemCount: _filteredAudios.length,
                    itemBuilder: (ctx, idx) {
                      final audio = _filteredAudios[idx];
                      return ListTile(
                        title: Text(audio.title),
                        trailing: audio.url.isEmpty
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : _isAdmin
                                ? IconButton(
                                    icon: const Icon(Icons.delete),
                                    onPressed: () => _deleteAudio(audio.id),
                                  )
                                : null,
                        onTap: audio.url.isNotEmpty
                            ? () => _playNewAudio(audio.url)
                            : null,
                      );
                    },
                  ),
                ),
              ],
            ),
            bottomNavigationBar: (_isPlaying || _isPaused)
                ? SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Material(
                        elevation: 6,
                        borderRadius: BorderRadius.circular(16),
                        clipBehavior: Clip.antiAlias,
                        color: Theme.of(context).colorScheme.surface,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // ─── 배속 선택 버튼들 ───
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: _rates.map((r) {
                                    final selected = (r == _currentRate);
                                    return ChoiceChip(
                                      label: Text(
                                        _rateLabel(r),
                                        style: TextStyle(
                                          fontWeight:
                                              selected ? FontWeight.w700 : null,
                                        ),
                                      ),
                                      selected: selected,
                                      onSelected: (_) => _applySpeed(r),
                                    );
                                  }).toList(),
                                ),
                              ),
                              const SizedBox(height: 8),

                              // ─── 시크/타임라인 ───
                              Slider(
                                value: _position.inSeconds
                                    .clamp(0, _duration.inSeconds)
                                    .toDouble(),
                                min: 0,
                                max: (_duration.inSeconds == 0
                                        ? 1
                                        : _duration.inSeconds)
                                    .toDouble(),
                                onChanged: (v) =>
                                    _seekTo(Duration(seconds: v.toInt())),
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  IconButton(
                                    icon: Icon(_isPlaying
                                        ? Icons.pause
                                        : Icons.play_arrow),
                                    onPressed: _togglePlayPause,
                                  ),
                                  Text(
                                      '${_mmss(_position)} / ${_mmss(_duration)}'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                : null,
          ),

          // 업로드 중 중앙 로딩 오버레이
          if (_isUploading)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  String _mmss(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
