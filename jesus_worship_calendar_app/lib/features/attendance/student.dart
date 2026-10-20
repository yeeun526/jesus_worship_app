import 'package:cloud_firestore/cloud_firestore.dart';

class Student {
  final String uid;
  final String email;
  final String? name;
  final DateTime? createdAt;

  const Student({
    required this.uid,
    required this.email,
    this.name,
    this.createdAt,
  });

  /// Converts a users/{uid} document to a student.
  factory Student.fromFirestore(String id, Map<String, dynamic> data) {
    return Student(
      uid: id,
      email: (data['email'] as String?) ?? '',
      name: data['name'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  /// The name to display in attendance lists.
  String get displayName => name?.trim().isNotEmpty == true ? name! : email;
}
