// lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── 사용자 ──
  Future<void> createUserRecord(String uid, String email, String role) =>
      _db.collection('users').doc(uid).set({
        'email': email,
        'role': role,
      });

  Future<String> fetchUserRole(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return (doc.data()?['role'] as String?) ?? 'member';
  }

  // ── 출석 ──
  String _attId(String uid) {
    final d = DateTime.now().toIso8601String().split('T').first;
    return '${uid}_$d';
  }

  Future<bool> hasAttendedToday(String uid) async {
    final doc = await _db.collection('attendance').doc(_attId(uid)).get();
    return (doc.data()?['attended'] as bool?) ?? false;
  }

  Future<void> markAttendance(String uid) {
    return _db.collection('attendance').doc(_attId(uid)).set({
      'attended': true,
    });
  }

  Future<void> addReason(String uid, String reason) {
    return _db.collection('attendance').doc(_attId(uid)).update({
      'reason': reason,
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

  // ── 과제 목록 스트림 ──
  Stream<List<Task>> taskList() {
    return _db.collection('tasks').snapshots().map(
        (snap) => snap.docs.map((doc) => Task.fromFirestore(doc)).toList());
  }
}
