// lib/pages/attendance_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// ↓ 이 줄을 꼭 추가해야 DocumentSnapshot 타입을 사용할 수 있습니다.
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user.dart';
import '../providers/user_provider.dart';
import '../services/firestore_service.dart';

class AttendancePage extends StatelessWidget {
  const AttendancePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final role = context.watch<UserProvider>().role;
    final fs   = FirestoreService();

    // ── 학생이 아니면 출석 현황 표 보여주기 ──
    if (role != 'student') {
      return Scaffold(
        appBar: AppBar(leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: '뒤로가기',
        onPressed: () => Navigator.pop(context),
      ),title: const Text('출석 현황')),
        body: FutureBuilder<List<UserModel>>(
          future: fs.getStudents(),
          builder: (ctx, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final students = snap.data!;

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('이름')),
                  DataColumn(label: Text('출석 상태')),
                  DataColumn(label: Text('사유')),
                ],
                rows: students.map((stu) {
                  // 오늘 출석 문서를 한 번만 불러옵니다.
                  final recFuture = fs.getAttendanceRecord(stu.uid);

                  return DataRow(cells: [
                    // 1) 이름
                    DataCell(Text(stu.name ?? stu.email)),

                    // 2) 출석 상태
                    DataCell(
                      FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        future: recFuture,
                        builder: (c2, s2) {
                          if (!s2.hasData) return const Text('...');
                          final doc = s2.data!;
                          if (!doc.exists) return const Text('미출석');
                          final st = doc.get('attended') as String;
                          switch (st) {
                            case 'present':
                              return const Text('출석');
                            case 'late':
                              return const Text('지각');
                            case 'absent':
                              return const Text('결석');
                            default:
                              return Text(st);
                          }
                        },
                      ),
                    ),

                    // 3) 사유
                    DataCell(
                      FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        future: recFuture,
                        builder: (c3, s3) {
                          if (!s3.hasData) return const Text('...');
                          final doc = s3.data!;
                          if (!doc.exists) return const Text('-');
                          final reason = doc.data()?['reason'] as String?;
                          return Text(reason ?? '-');
                        },
                      ),
                    ),
                  ]);
                }).toList(),
              ),
            );
          },
        ),
      );
    }

    // ── 학생이면 출석/지각/결석 체크 UI ──
    final uid = context.read<UserProvider>().uid!;
    return Scaffold(
      appBar: AppBar(title: const Text('출석 체크')),
      body: FutureBuilder<String?>(
        future: fs.todayStatus(uid),
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final status = snap.data;
          if (status != null) {
            String label;
            switch (status) {
              case 'present':
                label = '✅ 출석 완료';
                break;
              case 'late':
                label = '⏰ 지각 완료';
                break;
              case 'absent':
                label = '❌ 결석 완료';
                break;
              default:
                label = '상태: $status';
            }
            return Center(child: Text(label, style: const TextStyle(fontSize: 18)));
          }
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  onPressed: () => fs.recordAttendance(uid: uid, status: 'present'),
                  child: const Text('출석'),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => _showReasonDialog(context, uid, 'late', fs),
                  child: const Text('지각'),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => _showReasonDialog(context, uid, 'absent', fs),
                  child: const Text('결석'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showReasonDialog(
      BuildContext ctx,
      String uid,
      String status,
      FirestoreService fs,
  ) {
    final ctrl = TextEditingController();
    showDialog<void>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: Text(status == 'late' ? '지각 사유 입력' : '결석 사유 입력'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(labelText: '사유를 입력해주세요'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(
            onPressed: () {
              final reason = ctrl.text.trim();
              if (reason.isEmpty) return;
              fs.recordAttendance(uid: uid, status: status, reason: reason);
              Navigator.pop(ctx);
            },
            child: const Text('제출'),
          ),
        ],
      ),
    );
  }
}
