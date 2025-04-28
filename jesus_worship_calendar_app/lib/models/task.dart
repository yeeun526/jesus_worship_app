import 'package:cloud_firestore/cloud_firestore.dart';

class Task {
  final String id;
  final String title;
  final DateTime dueDate;
  final Map<String, dynamic> submissions;

  Task({
    required this.id,
    required this.title,
    required this.dueDate,
    required this.submissions,
  });

  /// Firestore 문서(DocumentSnapshot)에서 Task 객체로 변환
  factory Task.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    // Timestamp → DateTime으로 변환
    final ts = data['dueDate'] as Timestamp;
    return Task(
      id: doc.id,
      title: data['title'] as String,
      dueDate: ts.toDate(),
      submissions: Map<String, dynamic>.from(data['submissions'] as Map),
    );
  }

  /// Task 객체를 Firestore에 쓸 수 있는 Map으로 변환
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'dueDate': Timestamp.fromDate(dueDate),
      'submissions': submissions,
    };
  }
}
