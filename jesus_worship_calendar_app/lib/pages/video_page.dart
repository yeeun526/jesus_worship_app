// lib/pages/video_page.dart

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/firestore_service.dart';
import '../widgets/permission_widget.dart';
import 'video_player_page.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:ui';

class VideoPage extends StatefulWidget {
  const VideoPage({Key? key}) : super(key: key);

  @override
  _VideoPageState createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage> {
  final _searchCtrl = TextEditingController();
  final _service = FirestoreService();

  List<Map<String, dynamic>> _videos = [];
  List<Map<String, dynamic>> _filteredVideos = [];

  // 업로드 상태
  bool _uploading = false;
  double _uploadProgress = 0.0; // 0.0 ~ 1.0

  @override
  void initState() {
    super.initState();
    _fetchVideos();
  }

  Future<void> _fetchVideos() async {
    final res = await _service.fetchVideos();
    if (!mounted) return;
    setState(() {
      _videos = res;
      _filteredVideos = res;
    });
  }

  void _search() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filteredVideos = _videos
          .where(
            (v) => (v['title'] as String?)?.toLowerCase().contains(q) ?? false,
          )
          .toList();
    });
  }

  void _add() => _showUploadDialog();

  /// 제목 + 파일선택 다이얼로그 → 업로드(진행률 표시)
  Future<void> _showUploadDialog() async {
    final titleCtrl = TextEditingController();
    PlatformFile? pickedFile;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setLocal) {
          final canSubmit =
              titleCtrl.text.trim().isNotEmpty && pickedFile != null;
          return AlertDialog(
            title: const Text('영상 업로드'),
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
                      allowedExtensions: ['mp4', 'mov', 'avi'],
                      withData: kIsWeb ? true : false, // ✅ 메모리 적재 금지, 경로만
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
                onPressed: canSubmit ? () => Navigator.pop(ctx, true) : null,
                child: const Text('확인'),
              ),
            ],
          );
        });
      },
    );

    if (ok != true || pickedFile == null) return;

    // ✅ 업로드 시작: 진행률 오버레이
    setState(() {
      _uploading = true;
      _uploadProgress = 0.0;
    });

    try {
      await _service.addVideo(
        data: {'title': titleCtrl.text.trim()},
        file: pickedFile!,
        onProgress: (p) {
          if (!mounted) return;
          setState(() => _uploadProgress = p);
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('업로드 성공')));
      await _fetchVideos();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('업로드 실패: $e')));
    } finally {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _uploadProgress = 0.0;
      });
    }
  }

  Future<void> _deleteVideo(String id, String url) async {
    setState(() {
      _uploading = true; // 같은 오버레이 재사용
      _uploadProgress = 0.0;
    });
    try {
      await _service.deleteVideo(id, url);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('영상 삭제 완료')));
      await _fetchVideos();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('영상 삭제 실패: $e')));
    } finally {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _uploadProgress = 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext ctx) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('동영상 목록'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pushNamed(context, '/calendar'),
            ),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(labelText: '제목 검색'),
                  onChanged: (_) => _search(),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _filteredVideos.length,
                  itemBuilder: (ctx, i) {
                    final v = _filteredVideos[i];
                    return ListTile(
                      title: Text(v['title'] ?? '제목 없음'),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                VideoPlayerPage(videoUrl: v['url'] ?? ''),
                          ),
                        );
                      },
                      trailing: PermissionWidget(
                        requiredRole: 'admin',
                        child: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () =>
                              _deleteVideo(v['id'] ?? '', v['url'] ?? ''),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          floatingActionButton: PermissionWidget(
            requiredRole: 'admin',
            child: FloatingActionButton(
              onPressed: _add,
              child: const Icon(Icons.add),
            ),
          ),
        ),

        // ✅ 업로드/삭제 중 오버레이 + 진행률
        if (_uploading)
          Positioned.fill(
            child: Stack(
              children: [
                // 배경 블러 + 반투명 딤
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                  child: Container(color: Colors.black45),
                ),

                // 가운데 카드
                Center(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: _uploadProgress.clamp(0, 1)),
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    builder: (context, value, _) {
                      final percent =
                          (value * 100).clamp(0, 100).toStringAsFixed(0);

                      return Material(
                        color: Colors.transparent,
                        child: Container(
                          width: 180,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 18),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surface
                                .withOpacity(0.98),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.25),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 72,
                                height: 72,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    CircularProgressIndicator(
                                      value: value > 0
                                          ? value
                                          : null, // 0일 때는 indeterminate
                                      strokeWidth: 6,
                                    ),
                                    // 숫자만 표시 (밑줄 없음)
                                    Text(
                                      '$percent%',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        decoration:
                                            TextDecoration.none, // 🔒 밑줄 방지
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              // 필요하면 얇은 진행 바도 추가 가능
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  minHeight: 6,
                                  value: value > 0 ? value : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
