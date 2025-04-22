// lib/pages/attendance_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/firestore_service.dart';
import 'attendance_reason_page.dart';

class AttendancePage extends StatelessWidget {
  const AttendancePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final uid = context.read<UserProvider>().uid!;
    return Scaffold(
      appBar: AppBar(title: const Text('출석')),
      body: FutureBuilder<String?>(
        future: FirestoreService().todayStatus(uid),
        builder: (ctx, snap) {
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());
          final status = snap.data;
          // 이미 처리한 경우
          if (status != null) {
            return Center(child: Text('오늘 출석 상태: $status'));
          }
          // 아직 선택 전
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    // 정상 출석
                    FirestoreService()
                        .recordAttendance(uid: uid, status: 'present');
                    Navigator.of(context).pop(); // 메인으로
                  },
                  child: const Text('출석'),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    // 지각 → 이유 입력 화면으로
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            AttendanceReasonPage(uid: uid, status: 'late'),
                      ),
                    );
                  },
                  child: const Text('지각'),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    // 결석 → 이유 입력 화면으로
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            AttendanceReasonPage(uid: uid, status: 'absent'),
                      ),
                    );
                  },
                  child: const Text('결석'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
