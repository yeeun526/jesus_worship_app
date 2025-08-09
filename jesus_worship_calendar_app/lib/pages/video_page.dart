// lib/pages/video_page.dart

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/firestore_service.dart';
import '../widgets/permission_widget.dart';
import 'video_player_page.dart';

class VideoPage extends StatefulWidget {
  const VideoPage({Key? key}) : super(key: key);

  @override
  _VideoPageState createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _videos = [];
  List<Map<String, dynamic>> _filteredVideos = [];

  @override
  void initState() {
    super.initState();
    _fetchVideos();
  }

  void _fetchVideos() async {
    final res = await FirestoreService().fetchVideos();
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
          .where((v) =>
              (v['title'] as String?)?.toLowerCase().contains(q) ?? false)
          .toList();
    });
  }

  // 추가 버튼: 업로드 다이얼로그 띄우기
  void _add() => _showUploadDialog();

  // 업로드 다이얼로그 (제목 + 파일 선택)
  Future<void> _showUploadDialog() async {
    final titleCtrl = TextEditingController();
    PlatformFile? pickedFile;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
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
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.attach_file),
                    label: const Text('파일 선택'),
                    onPressed: () async {
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['mp4', 'mov', 'avi'],
                      );
                      if (result != null && result.files.isNotEmpty) {
                        setState(() => pickedFile = result.files.single);
                      }
                    },
                  ),
                  if (pickedFile != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        pickedFile!.name,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54),
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
          },
        );
      },
    );

    if (ok != true) return;

    // ✅ 업로드 시작: 로딩 다이얼로그 표시
    _showLoading();

    try {
      await FirestoreService().addVideo(
        {'title': titleCtrl.text.trim()},
        pickedFile!, // 선택된 파일
      );

      // 로딩 닫기
      _hideLoading();

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('업로드 성공')));

      _fetchVideos();
    } catch (e) {
      // 로딩 닫기
      _hideLoading();

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('업로드 실패: $e')));
    }
  }

  // ✅ 모달 로딩 다이얼로그
  void _showLoading() {
    showDialog<void>(
      context: context,
      barrierDismissible: false, // 업로드 중 닫히지 않도록
      builder: (_) => WillPopScope(
        onWillPop: () async => false, // 뒤로가기도 막기
        child: const Dialog(
          insetPadding: EdgeInsets.symmetric(horizontal: 120, vertical: 24),
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('업로드 중...'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _hideLoading() {
    if (Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  Future<void> _deleteVideo(String id, String url) async {
    try {
      _showLoading();
      await FirestoreService().deleteVideo(id, url);
      _hideLoading();

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('영상 삭제 완료')));
      _fetchVideos();
    } catch (e) {
      _hideLoading();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('영상 삭제 실패: $e')));
    }
  }

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
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
    );
  }
}
