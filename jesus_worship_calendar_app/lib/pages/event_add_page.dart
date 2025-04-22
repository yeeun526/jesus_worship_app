// lib/pages/event_add_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/event.dart';
import '../services/firestore_service.dart';

class EventAddPage extends StatefulWidget {
  const EventAddPage({Key? key}) : super(key: key);
  @override
  _EventAddPageState createState() => _EventAddPageState();
}

class _EventAddPageState extends State<EventAddPage> {
  final _titleController = TextEditingController();
  DateTime? _selectedDate;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
    );
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  Future<void> _saveEvent() async {
    final title = _titleController.text.trim();
    final date = _selectedDate;

    if (title.isEmpty || date == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('제목과 날짜를 모두 입력해주세요')),
      );
      return;
    }

    final userId = FirebaseAuth.instance.currentUser?.uid;
    final event = Event(id: '', title: title, date: date, createdBy: userId);

    try {
      await FirestoreService().addEvent(event);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('일정이 추가되었습니다')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('일정 추가 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('일정 추가')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: '제목'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  _selectedDate == null
                      ? '날짜를 선택하세요'
                      : DateFormat('yyyy-MM-dd').format(_selectedDate!),
                ),
                const Spacer(),
                TextButton(onPressed: _pickDate, child: const Text('날짜 선택')),
              ],
            ),
            const Spacer(),
            ElevatedButton(onPressed: _saveEvent, child: const Text('저장')),
          ],
        ),
      ),
    );
  }
}
