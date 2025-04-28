import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import '../providers/user_provider.dart';
import '../services/audio_service.dart';

class AudioPage extends StatefulWidget {
  const AudioPage({Key? key}) : super(key: key);
  @override
  _AudioPageState createState() => _AudioPageState();
}

class _AudioPageState extends State<AudioPage> {
  final AudioService _audioService = AudioService();
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // 검색어가 변경될 때마다 리스트 갱신
    _searchCtrl.addListener(() {
      setState(() {
        _searchQuery = _searchCtrl.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final role = context.watch<UserProvider>().role;

    return Scaffold(
      appBar: AppBar(title: const Text('음원 관리')),
      body: Column(
        children: [
          // 1) 검색창
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: '제목으로 검색',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                isDense: true,
              ),
            ),
          ),

          // 2) 음원 리스트 (스트림 + 검색 필터)
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _audioService.audioListStream(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('오류 발생: ${snap.error}'));
                }

                final allAudios = snap.data ?? [];
                final filtered = _searchQuery.isEmpty
                    ? allAudios
                    : allAudios.where((item) {
                        return (item['title'] as String)
                            .toLowerCase()
                            .contains(_searchQuery);
                      }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('검색 결과가 없습니다.'));
                }

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (ctx, i) {
                    final item = filtered[i];
                    final title = item['title'] as String;
                    final dt    = item['createdAt'] as DateTime;
                    return ListTile(
                      title: Text(title),
                      subtitle: Text(
                        '${dt.year}-${dt.month.toString().padLeft(2,'0')}-'
                        '${dt.day.toString().padLeft(2,'0')} '
                        '${dt.hour.toString().padLeft(2,'0')}:'
                        '${dt.minute.toString().padLeft(2,'0')}',
                      ),
                      onTap: () {
                        // TODO: 재생 기능 추가
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),

      // 3) admin만 보이는 추가 버튼
      floatingActionButton: role == 'admin'
          ? FloatingActionButton(
              tooltip: '음원 추가',
              child: const Icon(Icons.add),
              onPressed: _showAddAudioDialog,
            )
          : null,
    );
  }

  /// 제목과 파일 선택 후 업로드
  Future<void> _showAddAudioDialog() async {
    final titleCtrl = TextEditingController();
    PlatformFile? pickedFile;

    final shouldUpload = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('새 음원 추가'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 제목 입력
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: '제목 (필수)'),
              ),
              const SizedBox(height: 12),
              // 파일 선택
              ElevatedButton.icon(
                icon: const Icon(Icons.attach_file),
                label: Text(
                  pickedFile?.name ?? 'mp3 / mp4 파일 선택',
                  overflow: TextOverflow.ellipsis,
                ),
                onPressed: () async {
                  final res = await FilePicker.platform.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['mp3', 'mp4'],
                    withData: true,
                  );
                  if (res != null && res.files.isNotEmpty) {
                    setState(() {
                      pickedFile = res.files.first;
                    });
                  }
                },
              ),
            ],
          ),
          actions: [
            // 취소
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소'),
            ),
            // 저장
            ElevatedButton(
              onPressed: () {
                if (titleCtrl.text.trim().isEmpty || pickedFile == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('제목과 파일을 모두 선택해주세요')),
                  );
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );

    if (shouldUpload == true && pickedFile != null) {
      final title = titleCtrl.text.trim();
      try {
        await _audioService.uploadAudio(title: title, file: pickedFile!);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('음원이 추가되었습니다')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('추가 실패: $e')),
        );
      }
    }
  }
}
