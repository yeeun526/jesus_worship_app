import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user.dart'; // UserModel
import '../providers/user_provider.dart';
import '../services/firestore_service.dart';

class AttendancePage extends StatelessWidget {
  const AttendancePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final role = context.watch<UserProvider>().role; // 현재 사용자 역할
    final uid = context.read<UserProvider>().uid!; // 현재 사용자 uid
    final fs = FirestoreService();

    // ── 1) 학생이 아니면 “출석 현황 표” 페이지──
    if (role != 'student') {
      return Scaffold(
        appBar: AppBar(title: const Text('출석 현황')),
        body: FutureBuilder<List<UserModel>>(
          future: fs.getStudents(),
          builder: (ctx, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final students = snap.data!;

            // DataTable을 가로 스크롤 가능하게 감싸기
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('이름')),
                  DataColumn(label: Text('출석 상태')),
                ],
                rows: students.map((stu) {
                  return DataRow(cells: [
                    // 이름 셀
                    DataCell(Text(stu.name ?? stu.email)),
                    // 상태 셀: FutureBuilder 사용
                    DataCell(
                      FutureBuilder<String?>(
                        future: fs.todayStatus(stu.uid),
                        builder: (c2, s2) {
                          if (!s2.hasData) return const Text('...');
                          final st = s2.data;
                          switch (st) {
                            case 'present':
                              return const Text('출석');
                            case 'late':
                              return const Text('지각');
                            case 'absent':
                              return const Text('결석');
                            default:
                              return const Text('미출석');
                          }
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

    // ── 2) 학생이면 “출석/지각/결석” 버튼 페이지──
    return Scaffold(
      appBar: AppBar(title: const Text('출석체크')),
      body: FutureBuilder<String?>(
        future: fs.todayStatus(uid),
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final status = snap.data;

          // 1) 이미 출석 여부를 체크했다면, 상태만 보여주기
          if (status != null) {
            String label;
            switch (status) {
              case 'present':
                label = '✅ 출석';
                break;
              case 'late':
                label = '⏰ 지각';
                break;
              case 'absent':
                label = '❌ 결석';
                break;
              default:
                label = '상태: $status';
                break;
            }
            return Center(
                child: Text(label, style: const TextStyle(fontSize: 18)));
          }
// 2) 아직 체크 전이면, 세 가지 버튼 제공
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 2-1) 정상 출석
                ElevatedButton(
                  onPressed: () async {
                    await fs.recordAttendance(uid: uid, status: 'present');
                    // 상태가 저장되면 FutureBuilder가 rebuild 됩니다
                  },
                  child: const Text('출석'),
                ),
                const SizedBox(height: 12),

                // 2-2) 지각 (사유 입력)
                ElevatedButton(
                  onPressed: () => _showReasonDialog(context, uid, 'late', fs),
                  child: const Text('지각'),
                ),
                const SizedBox(height: 12),

                // 2-3) 결석 (사유 입력)
                ElevatedButton(
                  onPressed: () =>
                      _showReasonDialog(context, uid, 'absent', fs),
                  child: const Text('결석'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 지각(late) 또는 결석(absent) 시 호출되는 사유 입력 다이얼로그
  void _showReasonDialog(
    BuildContext ctx,
    String uid,
    String status, // 'late' or 'absent'
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
          decoration: const InputDecoration(
            labelText: '사유를 입력해주세요',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              final reason = ctrl.text.trim();
              if (reason.isEmpty) return; // 사유 필수
              await fs.recordAttendance(
                uid: uid,
                status: status,
                reason: reason,
              );
              Navigator.pop(ctx);
            },
            child: const Text('제출'),
          ),
        ],
      ),
    );
  }
}
