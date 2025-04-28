import 'package:cloud_firestore/cloud_firestore.dart';      // Firestore
import 'package:firebase_storage/firebase_storage.dart';    // Storage
import 'package:file_picker/file_picker.dart';              // FilePicker

class AudioService {
  final FirebaseFirestore _db      = FirebaseFirestore.instance;
  final FirebaseStorage   _storage = FirebaseStorage.instance;

  /// mp3/mp4 파일을 Storage에 업로드하고,
  /// Firestore 'audios' 컬렉션에 {title, url, createdAt} 기록
  Future<void> uploadAudio({
    required String title,
    required PlatformFile file,
  }) async {
    // 1) 저장 경로 생성 (타임스탬프 + 원본 파일명)
    final path = 'audios/${DateTime.now().millisecondsSinceEpoch}_${file.name}';

    // 2) 파일 바이트 데이터 검사
    final bytes = file.bytes;
    if (bytes == null) {
      throw Exception('파일 데이터를 가져올 수 없습니다.');
    }

    // 3) Firebase Storage에 업로드
    final ref = _storage.ref(path);
    final contentType =
        file.extension?.toLowerCase() == 'mp4' ? 'video/mp4' : 'audio/mpeg';
    final task = ref.putData(bytes, SettableMetadata(contentType: contentType));
    final snap = await task.whenComplete(() {});

    // 4) 업로드된 파일 다운로드 URL 가져오기
    final url = await snap.ref.getDownloadURL();

    // 5) Firestore에 메타데이터 저장
    await _db.collection('audios').add({
      'title'    : title,
      'url'      : url,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Firestore 'audios' 컬렉션을 실시간 구독, 제목 null/빈값 레코드는 걸러냄
  Stream<List<Map<String, dynamic>>> audioListStream() {
  return _db
    .collection('audios')
    .orderBy('createdAt', descending: true)
    .snapshots()
    .map((snap) {
      return snap.docs
        .where((d) {
          final t = d.data()['title'];
          return t is String && t.trim().isNotEmpty;
        })
        .map((d) {
          final data = d.data();

          // ① Timestamp? 을 안전하게 꺼내고
          final ts = data['createdAt'] as Timestamp?;

          // ② ts가 null 아니면 toDate(), toLocal() 호출
          //    null이면 DateTime.now()로 대체
          final date = ts
              ?.toDate()
              .toLocal()
            ?? DateTime.now();

          return {
            'id'       : d.id,
            'title'    : data['title']    as String,
            'url'      : data['url']      as String? ?? '',
            'createdAt': date,               // non-null DateTime
          };
        })
        .toList();
    });
}

}
