// audio.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Audio {
  final String id;
  final String title;
  final String url;

  Audio({
    required this.id,
    required this.title,
    required this.url,
  });

  /// 기존에 쓰시던 Map 기반 생성자
  factory Audio.fromMap(Map<String, dynamic> data, String id) => Audio(
        id: id,
        title: data['title'] as String? ?? 'Unknown',
        url: data['url'] as String,
      );

  /// Firestore DocumentSnapshot 기반 생성자
  factory Audio.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw StateError('Missing data for Audio id=${doc.id}');
    }
    return Audio(
      id: doc.id,
      title: data['title'] as String? ?? 'Untitled',
      url: data['url'] as String,
    );
  }
}
