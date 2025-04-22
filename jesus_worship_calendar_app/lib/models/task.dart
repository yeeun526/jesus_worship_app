// lib/models/task.dart
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

  factory Task.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Task(
      id: doc.id,
      title: data['title'] as String? ?? '',
      dueDate: (data['dueDate'] as Timestamp).toDate(),
      submissions: Map<String, dynamic>.from(data['submissions'] ?? {}),
    );
  }
}
