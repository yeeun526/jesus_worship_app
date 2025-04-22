// lib/models/event.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Event {
  final String id;
  final String title;
  final DateTime date;
  final String? createdBy;

  Event({
    required this.id,
    required this.title,
    required this.date,
    this.createdBy,
  });

  factory Event.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Event(
      id: doc.id,
      title: data['title'] as String,
      date: (data['date'] as Timestamp).toDate(),
      createdBy: data['createdBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'date': Timestamp.fromDate(date),
        'createdBy': createdBy,
      };
}
