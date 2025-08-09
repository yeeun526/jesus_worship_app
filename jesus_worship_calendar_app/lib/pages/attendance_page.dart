import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user.dart';
import '../providers/user_provider.dart';
import '../services/firestore_service.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({Key? key}) : super(key: key);

  @override
  _AttendancePageState createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  @override
  Widget build(BuildContext context) {
    final role = context.watch<UserProvider>().role;
    final fs = FirestoreService();

    // ── 임원이면 학생을 선택하여 출석 현황을 볼 수 있게 ──
    if (role != 'student') {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: '뒤로가기',
            onPressed: () => Navigator.pushNamed(context, '/calendar'),
          ),
          title: const Text('출석 현황'),
        ),
        body: FutureBuilder<List<UserModel>>(
          future: fs.getStudents(),
          builder: (ctx, snap) {
            if (!snap.hasData)
              return const Center(child: CircularProgressIndicator());
            List<UserModel> students = snap.data!;

            // 이름순으로 정렬
            students.sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));

            return SingleChildScrollView(
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('이름')),
                  DataColumn(label: Text('출석 상태')),
                  DataColumn(label: Text('출석 상태 수정')),
                ],
                rows: students.map((stu) {
                  return DataRow(cells: [
                    DataCell(Text(stu.name ?? stu.email)),
                    DataCell(
                        FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      future: fs.getAttendanceRecord(stu.uid),
                      builder: (ctx, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Text('...');
                        }

                        if (snapshot.hasData) {
                          final doc = snapshot.data;
                          if (!doc!.exists) return const Text('-');
                          final status = doc['attended'] ?? '';
                          return Text(
                            _getAttendanceStatusText(status),
                            style: TextStyle(
                                color: _getAttendanceStatusColor(status)),
                          );
                        }
                        return const Text('...');
                      },
                    )),
                    DataCell(IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () {
                        _showUpdateAttendanceDialog(context, stu, fs);
                      },
                    )),
                  ]);
                }).toList(),
              ),
            );
          },
        ),
      );
    }

    // ── 학생 출석 체크 UI ──
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
          String label = '';
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
          return Center(
            child: Text(
              label,
              style: const TextStyle(fontSize: 18),
            ),
          );
        },
      ),
    );
  }

  // 출석 상태에 맞는 텍스트 반환
  String _getAttendanceStatusText(String status) {
    switch (status) {
      case 'present':
        return '출석';
      case 'late':
        return '지각';
      case 'absent':
        return '결석';
      default:
        return '-';
    }
  }

  // 출석 상태에 맞는 색상 반환
  Color _getAttendanceStatusColor(String status) {
    switch (status) {
      case 'present':
        return Colors.blue; // 출석 상태는 파란색
      case 'late':
        return Colors.blue; // 지각 상태는 파란색
      case 'absent':
        return Colors.red; // 결석 상태는 빨간색
      default:
        return Colors.black; // 기본 색상은 검정색
    }
  }

  // 출석 상태 수정 다이얼로그
  void _showUpdateAttendanceDialog(
    BuildContext ctx,
    UserModel stu,
    FirestoreService fs,
  ) {
    showDialog<void>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('출석 상태 수정'),
        content: Column(
          children: [
            ElevatedButton(
              onPressed: () async {
                await fs.recordAttendance(uid: stu.uid, status: 'present');
                Navigator.pop(ctx); // 다이얼로그 닫기
                setState(() {}); // 상태 수정 후 페이지 새로고침
              },
              child: const Text('출석'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                await fs.recordAttendance(uid: stu.uid, status: 'late');
                Navigator.pop(ctx); // 다이얼로그 닫기
                setState(() {}); // 상태 수정 후 페이지 새로고침
              },
              child: const Text('지각'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                await fs.recordAttendance(uid: stu.uid, status: 'absent');
                Navigator.pop(ctx); // 다이얼로그 닫기
                setState(() {}); // 상태 수정 후 페이지 새로고침
              },
              child: const Text('결석'),
            ),
          ],
        ),
      ),
    );
  }
}
