import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';

class AudioService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<void> uploadAudio({
    required String title,
    required PlatformFile file,
  }) async {
    // 1) 업로드 경로
    final path = 'audios/${DateTime.now().millisecondsSinceEpoch}_${file.name}';
    final ref = _storage.ref(path);

    // 2) 메타데이터
    final contentType =
        file.extension?.toLowerCase() == 'mp4' ? 'video/mp4' : 'audio/mpeg';
    final meta = SettableMetadata(contentType: contentType);

    // 3) 플랫폼 분기: Web ↔ Mobile
    TaskSnapshot snap;
    if (kIsWeb) {
      final data = file.bytes;
      if (data == null) throw Exception('웹에서 파일 데이터를 가져올 수 없습니다.');
      snap = await ref.putData(data, meta);
    } else {
      final filePath = file.path;
      if (filePath == null) throw Exception('모바일에서 파일 경로를 가져올 수 없습니다.');
      final videoFile = File(filePath);

      // 1) Resumable Upload 태스크 생성
      final uploadTask = ref.putFile(videoFile, meta);

      uploadTask.snapshotEvents.listen((event) {
        final transferred = event.bytesTransferred;
        final total = event.totalBytes;
        final percent = (transferred / total) * 100;
        print('[AudioService] 업로드 진행률: ${percent.toStringAsFixed(1)}%');
      }, onError: (e) {
        print('[AudioService] 업로드 중 에러: $e');
      });

      // 3) 업로드 완료 대기
      snap = await uploadTask;
    }
    // ─── URL 얻어서 Firestore에 기록 ───
    final url = await snap.ref.getDownloadURL();
    print('[AudioService] 다운로드 URL: $url');

    await _db.collection('audios').add({
      'title': title,
      'url': url,
      'createdAt': FieldValue.serverTimestamp(),
    });
    print('[AudioService] Firestore 저장 완료');
  }

  Stream<List<Map<String, dynamic>>> audioListStream() {
    return _db
        .collection('audios')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.where((d) {
              final t = d.data()['title'];
              return t is String && t.trim().isNotEmpty;
            }).map((d) {
              final data = d.data();
              final ts = data['createdAt'] as Timestamp?;
              final date = ts?.toDate().toLocal() ?? DateTime.now();
              return {
                'id': d.id,
                'title': data['title'] as String,
                'url': data['url'] as String? ?? '',
                'createdAt': date,
              };
            }).toList());
  }
}
