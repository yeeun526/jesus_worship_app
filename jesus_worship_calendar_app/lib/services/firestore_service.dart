import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart' as fb_storage;
import 'package:file_picker/file_picker.dart';
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;

import '../models/task.dart';
import '../models/event.dart';
import '../models/user.dart';
import '../models/audio.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final fb_storage.FirebaseStorage _storage =
      fb_storage.FirebaseStorage.instance;

  FirestoreService();

  // ───────────────────────────────── Events ─────────────────────────────────

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

  Future<void> addEvent(Event event) {
    return _db.collection('events').add({
      'title': event.title,
      'date': Timestamp.fromDate(event.date),
      'createdBy': event.createdBy,
    });
  }

  Future<void> deleteEvent(String id) {
    return _db.collection('events').doc(id).delete();
  }

  // ───────────────────────────────── Users ─────────────────────────────────

  Future<void> createUserRecord({
    required String uid,
    required String email,
    required String role,
    String? name,
  }) {
    return _db.collection('users').doc(uid).set({
      'email': email,
      'role': role,
      if (name != null) 'name': name,
    });
  }

  Future<String> fetchUserRole(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    final data = doc.data();
    if (data == null) return 'member';
    return (data['role'] as String?) ?? 'member';
  }

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

  // ─────────────────────────────── Attendance ───────────────────────────────

  String _attId(String uid) {
    final d = DateTime.now().toIso8601String().split('T').first;
    return '${uid}_$d';
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getAttendanceRecord(
      String uid) {
    final docId = _attId(uid);
    return _db.collection('attendance').doc(docId).get();
  }

  Future<String?> todayStatus(String uid) async {
    final doc = await getAttendanceRecord(uid);
    if (!doc.exists) return null;
    return doc.get('attended') as String?;
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

  // ──────────────────────────────── Audios ─────────────────────────────────

  /// 파일 업로드 (경로 기반 우선, 실패 시 bytes 폴백, 진행률 콜백 지원)
  Future<void> addAudioFile({
    required String title,
    required PlatformFile file,
    void Function(double progress)? onProgress, // 0.0 ~ 1.0
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final safeName = file.name.replaceAll(RegExp(r'[^\w\.\-]'), '_');
    final storagePath = 'audios/${timestamp}_$safeName';

    final ext = (file.extension ?? '').toLowerCase();
    final contentType = _guessAudioContentType(ext);

    final ref = _storage.ref(storagePath);
    final meta = fb_storage.SettableMetadata(contentType: contentType);

    fb_storage.UploadTask uploadTask;

    if (kIsWeb) {
      if (file.bytes == null) {
        throw Exception('웹에서는 withData:true가 필요합니다 (bytes가 null).');
      }
      uploadTask = ref.putData(file.bytes!, meta);
    } else {
      final path = file.path;
      if (path != null && path.isNotEmpty) {
        try {
          final f = File(path);
          if (await f.exists()) {
            uploadTask = ref.putFile(f, meta);
          } else {
            if (file.bytes != null) {
              uploadTask = ref.putData(file.bytes!, meta);
            } else {
              final bytes = await File(path).readAsBytes();
              uploadTask = ref.putData(bytes, meta);
            }
          }
        } catch (_) {
          if (file.bytes == null) {
            throw Exception('파일을 열 수 없습니다. bytes가 필요합니다.');
          }
          uploadTask = ref.putData(file.bytes!, meta);
        }
      } else {
        if (file.bytes == null) {
          throw Exception('파일 데이터가 없습니다. (bytes/path 모두 null)');
        }
        uploadTask = ref.putData(file.bytes!, meta);
      }
    }

    if (onProgress != null) {
      uploadTask.snapshotEvents.listen((s) {
        final total = s.totalBytes;
        if (total > 0) onProgress(s.bytesTransferred / total);
      });
    }

    final snap = await uploadTask.whenComplete(() {});
    final url = await snap.ref.getDownloadURL();

    await _db.collection('audios').add({
      'title': title,
      'url': url,
      'ext': ext,
      'size': file.size,
      'storagePath': storagePath,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// 경로 업로드 (웹 미지원) — path 패키지 사용
  Future<void> addAudioFileFromPath({
    required String title,
    required String filePath,
    void Function(double progress)? onProgress,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError(
          'addAudioFileFromPath is not supported on Web. Use addAudioFile with bytes instead.');
    }

    final f = File(filePath);
    if (!await f.exists()) {
      throw Exception('파일이 존재하지 않습니다: $filePath');
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final name = p.basename(filePath);
    final safeName = name.replaceAll(RegExp(r'[^\w\.\-]'), '_');
    final storagePath = 'audios/${timestamp}_$safeName';

    final ext = _extOf(name);
    final contentType = _guessAudioContentType(ext);

    final ref = _storage.ref(storagePath);
    final meta = fb_storage.SettableMetadata(contentType: contentType);

    final task = ref.putFile(f, meta);

    if (onProgress != null) {
      task.snapshotEvents.listen((s) {
        final total = s.totalBytes;
        if (total > 0) onProgress(s.bytesTransferred / total);
      });
    }

    final snap = await task.whenComplete(() {});
    final url = await snap.ref.getDownloadURL();

    await _db.collection('audios').add({
      'title': title,
      'url': url,
      'ext': ext,
      'size': await f.length(),
      'storagePath': storagePath,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<Audio>> fetchAllAudios() async {
    final snap = await _db
        .collection('audios')
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((doc) => Audio.fromFirestore(doc)).toList();
  }

  Future<List<Audio>> searchAudios(String q) async {
    final snap = await _db
        .collection('audios')
        .where('title', isGreaterThanOrEqualTo: q)
        .where('title', isLessThanOrEqualTo: q + '\uf8ff')
        .orderBy('title')
        .get();
    return snap.docs.map((doc) => Audio.fromFirestore(doc)).toList();
  }

  /// Firestore 문서 + Storage 원본 동시 삭제
  Future<void> deleteAudioFile(String audioId) async {
    final docRef = _db.collection('audios').doc(audioId);
    final doc = await docRef.get();

    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      final storagePath = data['storagePath'] as String?;
      final url = data['url'] as String?;

      try {
        if (storagePath != null && storagePath.isNotEmpty) {
          await _storage.ref(storagePath).delete();
        } else if (url != null && url.isNotEmpty) {
          await _storage.refFromURL(url).delete();
        }
      } catch (_) {
        // Storage 삭제 실패해도 Firestore 문서는 지움
      }
    }

    await docRef.delete();
  }

  // ──────────────────────────────── Videos ─────────────────────────────────

  /// 경로/bytes 모두 대응 + 진행률 콜백 + storagePath 저장 (Web/모바일 겸용)
  Future<void> addVideo({
    required Map<String, dynamic> data, // 최소: {'title': ...}
    required PlatformFile file,
    void Function(double progress)? onProgress,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final safeName = file.name.replaceAll(RegExp(r'[^\w\.\-]'), '_');
    final storagePath = 'videos/${timestamp}_$safeName';

    final ext = (file.extension ?? '').toLowerCase();
    final contentType = _guessVideoContentType(ext);

    final ref = _storage.ref(storagePath);
    final meta = fb_storage.SettableMetadata(contentType: contentType);

    fb_storage.UploadTask task;

    if (kIsWeb) {
      if (file.bytes == null) {
        throw Exception('웹에서는 withData:true가 필요합니다 (bytes가 null).');
      }
      task = ref.putData(file.bytes!, meta);
    } else {
      final path = file.path;
      if (path != null && path.isNotEmpty) {
        try {
          final f = File(path);
          if (await f.exists()) {
            task = ref.putFile(f, meta);
          } else if (file.bytes != null) {
            task = ref.putData(file.bytes!, meta);
          } else {
            final bytes = await File(path).readAsBytes();
            task = ref.putData(bytes, meta);
          }
        } catch (_) {
          if (file.bytes == null) {
            throw Exception('동영상 파일을 열 수 없습니다. bytes가 필요합니다.');
          }
          task = ref.putData(file.bytes!, meta);
        }
      } else {
        if (file.bytes == null) {
          throw Exception('동영상 파일 데이터가 없습니다. (bytes/path 모두 null)');
        }
        task = ref.putData(file.bytes!, meta);
      }
    }

    if (onProgress != null) {
      task.snapshotEvents.listen((s) {
        final t = s.totalBytes;
        if (t > 0) onProgress(s.bytesTransferred / t);
      });
    }

    final snap = await task.whenComplete(() {});
    final url = await snap.ref.getDownloadURL();

    await _db.collection('videos').add({
      'title': data['title'],
      'url': url,
      'ext': ext,
      'size': file.size,
      'storagePath': storagePath,
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

  Future<List<Map<String, dynamic>>> fetchVideos() async {
    try {
      final snapshot = await _db.collection('videos').get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'title': data['title'],
          'url': data['url'],
        };
      }).toList();
    } catch (e) {
      throw Exception('동영상 목록 가져오기 실패: $e');
    }
  }

  /// Firestore 문서 + Storage 원본 동시 삭제
  Future<void> deleteVideo(String videoId, String videoUrl) async {
    try {
      final docRef = _db.collection('videos').doc(videoId);
      final doc = await docRef.get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final storagePath = data['storagePath'] as String?;
        try {
          if (storagePath != null && storagePath.isNotEmpty) {
            await _storage.ref(storagePath).delete();
          } else if (videoUrl.isNotEmpty) {
            await _storage.refFromURL(videoUrl).delete();
          }
        } catch (_) {
          // Storage 삭제 실패해도 Firestore 문서는 지움
        }
      }
      await _db.collection('videos').doc(videoId).delete();
    } catch (e) {
      throw Exception('동영상 삭제 실패: $e');
    }
  }

  // ───────────────────────────────── Tasks ─────────────────────────────────

  Future<void> addTask(String title, DateTime dueDate) {
    return _db.collection('tasks').add({
      'title': title,
      'dueDate': Timestamp.fromDate(dueDate),
      'submissions': <String, dynamic>{},
      'createdBy': FirebaseAuth.instance.currentUser?.uid,
    });
  }

  Stream<List<Task>> taskList() {
    return _db.collection('tasks').orderBy('dueDate').snapshots().map(
        (snap) => snap.docs.map((doc) => Task.fromFirestore(doc)).toList());
  }

  // ──────────────────────────────── Helpers ────────────────────────────────

  String _extOf(String name) {
    final i = name.lastIndexOf('.');
    return i >= 0 ? name.substring(i + 1).toLowerCase() : '';
  }

  String _guessAudioContentType(String ext) {
    switch (ext) {
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'aac':
        return 'audio/aac';
      case 'm4a':
        return 'audio/mp4'; // m4a는 통상 audio/mp4
      case 'mp4':
        return 'video/mp4'; // 혹시 오디오 확장자 배열을 잘못 넘겼을 경우 대비
      default:
        return 'application/octet-stream';
    }
  }

  String _guessVideoContentType(String ext) {
    switch (ext) {
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'avi':
        return 'video/x-msvideo';
      case 'webm':
        return 'video/webm';
      default:
        return 'application/octet-stream';
    }
  }
}
