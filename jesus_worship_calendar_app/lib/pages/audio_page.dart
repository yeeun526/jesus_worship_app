import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';

import '../providers/user_provider.dart';
import '../services/audio_service.dart';

class AudioPage extends StatefulWidget {
  const AudioPage({Key? key}) : super(key: key);
  @override
  _AudioPageState createState() => _AudioPageState();
}

class _AudioPageState extends State<AudioPage> {
  final AudioService _audioService = AudioService();

  Future<void> _showAddAudioDialog() async {
    print('[AudioPage] ▶ _showAddAudioDialog() 시작');
    final messenger = ScaffoldMessenger.of(context);

    final titleCtrl = TextEditingController();
    PlatformFile? pickedFile;

    // 1) 다이얼로그 호출 전
    print('[AudioPage] 1) showDialog() 전');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('새 음원 추가'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: '제목')),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.attach_file),
                label: Text(pickedFile?.name ?? '파일 선택'),
                onPressed: () async {
                  print('[AudioPage] 2) 파일 선택 버튼 눌림');
                  final res = await FilePicker.platform.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['mp3', 'mp4'],
                    withData: true,
                  );
                  if (res != null && res.files.isNotEmpty) {
                    print('[AudioPage] 3) 파일 선택 완료: ${res.files.first.name}');
                    setState(() => pickedFile = res.files.first);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () {
                  print('[AudioPage] 4) 취소 버튼 눌림');
                  Navigator.pop(ctx, false);
                },
                child: const Text('취소')),
            ElevatedButton(
              onPressed: () {
                print(
                    '[AudioPage] 5) 저장 버튼 눌림 (title="${titleCtrl.text}", file=$pickedFile)');
                // 제목·파일 검증
                if (titleCtrl.text.trim().isEmpty || pickedFile == null) {
                  print('[AudioPage] 6) 저장 불가: 제목/파일이 없음');
                  messenger.showSnackBar(
                    const SnackBar(content: Text('제목과 파일을 모두 선택해주세요')),
                  );
                  return;
                }
                print('[AudioPage] 7) Navigator.pop true');
                Navigator.pop(ctx, true);
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );

    // 8) 다이얼로그 종료 후 반환값
    print('[AudioPage] 8) showDialog 반환: $result, pickedFile=$pickedFile');

    if (result == true && pickedFile != null) {
      final title = titleCtrl.text.trim();
      print(
          '[AudioPage] ▶ 확인 눌림, uploadAudio() 호출 직전 title="$title" file="${pickedFile!.name}"');
      try {
        await _audioService.uploadAudio(title: title, file: pickedFile!);
        print('[AudioPage] ✔ uploadAudio() 성공 리턴');
        messenger.showSnackBar(const SnackBar(content: Text('음원이 추가되었습니다')));
      } catch (e) {
        print('[AudioPage] uploadAudio() 에러: $e');
        messenger.showSnackBar(SnackBar(content: Text('업로드 실패: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = context.watch<UserProvider>().role;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pushReplacementNamed(context, '/calendar'),
        ),
        title: const Text('음원 검색'),
      ),
      // ... body + FAB ...
      floatingActionButton: role == 'admin'
          ? FloatingActionButton(
              onPressed: _showAddAudioDialog, child: const Icon(Icons.add))
          : null,
    );
  }
}
