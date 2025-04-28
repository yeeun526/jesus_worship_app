import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/task.dart';
import '../models/event.dart';
import '../models/user.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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
  // ── 학생 목록 가져오기 ──
  /// users 컬렉션에서 role=='student' 인 문서만 조회
  Future<List<UserModel>> getStudents() async {
    final snap =
        await _db.collection('users').where('role', isEqualTo: 'student').get();

    return snap.docs.map((doc) {
      final data = doc.data();
      return UserModel(
        uid: doc.id,
        email: data['email'] as String,
        role: data['role'] as String,
        name: data['name'] as String?,
      );
    }).toList();
  }

  // ── 오늘 학생의 출석 상태 조회 (기존) ──
  String _attId(String uid) {
    final d = DateTime.now().toIso8601String().split('T').first;
    return '${uid}_$d';
  }

  Future<String?> todayStatus(String uid) async {
    final docSnap = await _db.collection('attendance').doc(_attId(uid)).get();
    if (!docSnap.exists) return null;
    return docSnap.get('attended') as String?;
  }

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

  // ── 음원 ──
  Future<List<String>> searchAudios(String q) async {
    final snap = await _db
        .collection('audios')
        .where('title', isGreaterThanOrEqualTo: q)
        .where('title', isLessThanOrEqualTo: q + '\uf8ff')
        .get();
    return snap.docs.map((d) => d.data()['title'] as String).toList();
  }

  Future<bool> audioExists(String title) async {
    final snap =
        await _db.collection('audios').where('title', isEqualTo: title).get();
    return snap.docs.isNotEmpty;
  }

  Future<void> addAudio(String title) {
    return _db.collection('audios').add({
      'title': title,
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
