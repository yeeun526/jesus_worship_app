import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart' as fb_storage;
import 'package:file_picker/file_picker.dart';
import 'dart:io';

import '../models/task.dart';
import '../models/event.dart';
import '../models/user.dart';
import '../models/audio.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final fb_storage.FirebaseStorage _storage =
      fb_storage.FirebaseStorage.instance;

  FirestoreService();

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

  // 4) Audio(음원) 관련
  /// * 음원 업로드
  ///  - Storage에 파일 저장
  ///  - 다운로드 URL을 받아와서 Firestore 'audios' 컬렉션에 메타데이터 저장
  Future<void> addAudioFile({
    required String title,
    required PlatformFile file,
  }) async {
    // 1) 파일 경로 생성 (audios/{timestamp}_{원본파일명})
    final fileName = file.name;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = 'audios/${timestamp}_$fileName';

    // 2) bytes가 null이면 에러
    if (file.bytes == null) {
      throw Exception('파일 데이터가 없습니다.');
    }

    // 3) Storage에 업로드
    final ref = _storage.ref().child(path);
    final meta = fb_storage.SettableMetadata(
      contentType: (file.extension == 'mp4') ? 'video/mp4' : 'audio/mpeg',
    );
    final uploadTask = ref.putData(file.bytes!, meta);

    // 4) 업로드 완료 대기
    final snap = await uploadTask.whenComplete(() {});

    // 5) 다운로드 URL 가져오기
    final url = await snap.ref.getDownloadURL();

    // 6) Firestore에 메타데이터 저장
    await _db.collection('audios').add({
      'title': title,
      'url': url,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// * 모든 음원 목록 가져오기 (최신 순)
  Future<List<Audio>> fetchAllAudios() async {
    final snap = await _db
        .collection('audios')
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((doc) => Audio.fromFirestore(doc)).toList();
  }

  /// * 제목(q)으로 검색하여 AudioModel 리스트 반환
  Future<List<Audio>> searchAudios(String q) async {
    final snap = await _db
        .collection('audios')
        .where('title', isGreaterThanOrEqualTo: q)
        .where('title', isLessThanOrEqualTo: q + '\uf8ff')
        .orderBy('title')
        .get();
    return snap.docs.map((doc) => Audio.fromFirestore(doc)).toList();
  }

  /// * 중복 제목 검사
  Future<bool> audioExists(String title) async {
    final snap =
        await _db.collection('audios').where('title', isEqualTo: title).get();
    return snap.docs.isNotEmpty;
  }

  /// 오디오 삭제 메서드
  Future<void> deleteAudioFile(String audioId) async {
    await _db.collection('audios').doc(audioId).delete();
  }

  // ── 영상 ──
  // 동영상 업로드 메서드
  Future<void> addVideo(Map<String, dynamic> data, PlatformFile file) async {
    // 1) 동영상 파일 경로 생성
    final fileName = file.name;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = 'videos/${timestamp}_$fileName';

    // 2) 파일 업로드
    final ref = _storage.ref().child(path);
    final uploadTask = ref.putData(file.bytes!);

    // 3) 업로드 완료 대기
    final snap = await uploadTask.whenComplete(() {});

    // 4) 다운로드 URL 가져오기
    final url = await snap.ref.getDownloadURL();

    // 5) Firestore에 메타데이터 저장
    await _db.collection('videos').add({
      'title': data['title'],
      'url': url,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

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

  // 동영상 목록을 가져오는 메서드
  Future<List<Map<String, dynamic>>> fetchVideos() async {
    try {
      // 'videos' 컬렉션에서 모든 동영상 문서 가져오기
      final snapshot = await _db.collection('videos').get();

      // 동영상 데이터를 List<Map<String, dynamic>> 형태로 변환하여 반환
      return snapshot.docs.map((doc) {
        return {
          'id': doc.id, // 동영상 ID
          'title': doc['title'], // 동영상 제목
          'url': doc['url'], // 동영상 URL
        };
      }).toList();
    } catch (e) {
      throw Exception('동영상 목록 가져오기 실패: $e');
    }
  }

  // 동영상 삭제
  Future<void> deleteVideo(String videoId, String videoUrl) async {
    try {
      // Firestore에서 동영상 메타데이터 삭제
      await _db.collection('videos').doc(videoId).delete();

      // Firebase Storage에서 동영상 파일 삭제
      final ref = _storage.refFromURL(videoUrl); // 동영상 URL을 사용해 참조 가져오기
      await ref.delete(); // Firebase Storage에서 동영상 파일 삭제

      print('동영상 삭제 완료');
    } catch (e) {
      throw Exception('동영상 삭제 실패: $e');
    }
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
