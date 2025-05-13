import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart' as fb_storage;
import 'package:file_picker/file_picker.dart';

import '../models/task.dart';
import '../models/event.dart';
import '../models/user.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final fb_storage.FirebaseStorage _storage =
      fb_storage.FirebaseStorage.instance;

  /// 실시간으로 events 컬렉션의 문서 목록을 Event 객체 리스트로 변환
  Stream<List<Event>> eventList() {
    return _db
        .collection('events')
        .orderBy('date')
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = doc.data();
              return Event(
                id: doc.id,
                title: data['title'] as String? ?? '',
                date: (data['date'] as Timestamp).toDate(),
                createdBy: data['createdBy'] as String?,
              );
            }).toList());
  }

  /// 단일 Event 객체를 add
  Future<void> addEvent(Event event) {
    return _db.collection('events').add({
      'title': event.title,
      'date': Timestamp.fromDate(event.date),
      'createdBy': event.createdBy,
    });
  }

  /// 이벤트 삭제
  Future<void> deleteEvent(String id) {
    return _db.collection('events').doc(id).delete();
  }

  // ── 1) 회원 가입 직후 users/{uid} 문서 생성 ──
  /// uid, email, role, (name) 필드를 users 컬렉션에 저장
  Future<void> createUserRecord({
    required String uid,
    required String email,
    required String role,
    String? name, // 이름 필드를 추가로 받고 싶다면 전달
  }) {
    return _db.collection('users').doc(uid).set({
      'email': email,
      'role': role,
      if (name != null) 'name': name,
    });
  }

  // ── 2) 로그인 시 사용자 역할(role) 조회 ──
  /// users/{uid} 문서에서 role 필드를 읽어서 반환
  /// 문서가 없거나 role이 없으면 'member' 기본값 반환
  Future<String> fetchUserRole(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    final data = doc.data();
    if (data == null) return 'member';
    return (data['role'] as String?) ?? 'member';
  }

  // ── 출석 ──
  // ── 오늘 출석 문서 ID 계산 (uid_YYYY-MM-DD) ──
  String _attId(String uid) {
    final d = DateTime.now().toIso8601String().split('T').first;
    return '${uid}_$d';
  }

  // ── 오늘의 출석 문서를 직접 가져오는 메서드 ──
  /// uid로 오늘의 attendance 문서를 조회해서 DocumentSnapshot으로 반환
  Future<DocumentSnapshot<Map<String, dynamic>>> getAttendanceRecord(
      String uid) {
    final docId = _attId(uid);
    return _db.collection('attendance').doc(docId).get();
  }

  /// 기존 todayStatus는 getAttendanceRecord를 사용하도록 변경
  Future<String?> todayStatus(String uid) async {
    final doc = await getAttendanceRecord(uid);
    if (!doc.exists) return null;
    return doc.get('attended') as String?;
  }

  /// 출석/지각/결석 저장
  Future<void> recordAttendance({
    required String uid,
    required String status,
    String? reason,
  }) {
    return _db.collection('attendance').doc(_attId(uid)).set({
      'attended': status,
      if (reason != null) 'reason': reason,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // ── 이미 정의된 학생 목록 조회 ──
  Future<List<UserModel>> getStudents() async {
    final snap =
        await _db.collection('users').where('role', isEqualTo: 'student').get();
    return snap.docs.map((d) {
      final data = d.data();
      return UserModel(
        uid: d.id,
        email: data['email'] as String,
        role: data['role'] as String,
        name: data['name'] as String?,
      );
    }).toList();
  }

  // ── 음원 ──
  /// 임원 전용: 제목 + mp3/mp4 파일을 업로드해서 Firestore에 레코드 추가
  Future<void> addAudioFile({
    required String title,
    required PlatformFile file,
  }) async {
    // 1) 파일 저장 경로 생성 (타임스탬프 + 원본 파일명)
    final path = 'audios/${DateTime.now().millisecondsSinceEpoch}_${file.name}';

    // 2) Storage에 업로드 (bytes가 null일 경우 에러)
    if (file.bytes == null) {
      throw Exception('파일 데이터가 없습니다.');
    }

    // 3) storage에 업로드
    final ref = _storage.ref(path);
    final meta = fb_storage.SettableMetadata(
      contentType: file.extension == 'mp4' ? 'video/mp4' : 'audio/mpeg',
    );
    final uploadTask = ref.putData(file.bytes!, meta);
    final snap = await uploadTask.whenComplete(() {});

    // 3) 업로드된 파일의 다운로드 URL 얻기
    final url = await snap.ref.getDownloadURL();

    // 4) Firestore에 메타데이터 저장
    await _db.collection('audios').add({
      'title': title,
      'url': url,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ── 영상 ──
  Future<List<String>> searchVideos(String q) async {
    final snap = await _db
        .collection('videos')
        .where('title', isGreaterThanOrEqualTo: q)
        .where('title', isLessThanOrEqualTo: q + '\uf8ff')
        .get();
    return snap.docs.map((d) => d.data()['title'] as String).toList();
  }

  Future<bool> videoExists(String title) async {
    final snap =
        await _db.collection('videos').where('title', isEqualTo: title).get();
    return snap.docs.isNotEmpty;
  }

  Future<void> addVideo(String title) {
    return _db.collection('videos').add({
      'title': title,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ── 과제 추가 ──
  Future<void> addTask(String title, DateTime dueDate) {
    return _db.collection('tasks').add({
      'title': title,
      'dueDate': Timestamp.fromDate(dueDate),
      'submissions': <String, dynamic>{},
      'createdBy': FirebaseAuth.instance.currentUser?.uid,
    });
  }

  /// 과제(tasks) 목록을 Task 모델 리스트로 스트림 반환
  Stream<List<Task>> taskList() {
    return _db
        .collection('tasks')
        .orderBy('dueDate') // 마감일 순 정렬(Optional)
        .snapshots()
        .map(
            (snap) => snap.docs.map((doc) => Task.fromFirestore(doc)).toList());
  }
}
