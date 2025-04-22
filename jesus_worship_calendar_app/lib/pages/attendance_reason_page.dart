// lib/pages/attendance_reason_page.dart
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class AttendanceReasonPage extends StatefulWidget {
  final String uid;
  final String status; // 'late' or 'absent'

  const AttendanceReasonPage({
    Key? key,
    required this.uid,
    required this.status,
  }) : super(key: key);

  @override
  _AttendanceReasonPageState createState() => _AttendanceReasonPageState();
}

class _AttendanceReasonPageState extends State<AttendanceReasonPage> {
  final _ctrl = TextEditingController();
  bool _loading = false;

  Future<void> _submit() async {
    final reason = _ctrl.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사유를 입력해주세요')),
      );
      return;
    }
    setState(() => _loading = true);
    await FirestoreService().recordAttendance(
      uid: widget.uid,
      status: widget.status,
      reason: reason,
    );
    setState(() => _loading = false);
    Navigator.of(context).pop(); // 사유 페이지 닫기
    Navigator.of(context).pop(); // 출석 페이지 닫고 메인으로
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.status == 'late' ? '지각 사유' : '결석 사유';
    return Scaffold(
      appBar: AppBar(title: Text(label)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _ctrl,
              decoration: InputDecoration(labelText: label),
              maxLines: 3,
            ),
            const Spacer(),
            _loading
                ? const CircularProgressIndicator()
                : ElevatedButton(onPressed: _submit, child: const Text('제출')),
          ],
        ),
      ),
    );
  }
}
