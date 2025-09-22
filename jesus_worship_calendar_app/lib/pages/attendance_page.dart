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

    // 기기 하단(노치/홈인디케이터/제스처바) 여백 + 추가 마진
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final bottomPadding = safeBottom + 24.0;

    // ── 임원/관리자: 학생 목록 표 + 상태 수정 ──
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
        body: SafeArea(
          bottom: true,
          child: FutureBuilder<List<UserModel>>(
            future: fs.getStudents(),
            builder: (ctx, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              List<UserModel> students = snap.data!;

              // 이름순 정렬 (null 대비)
              students.sort((a, b) => (a.name ?? a.email)
                  .toLowerCase()
                  .compareTo((b.name ?? b.email).toLowerCase()));

              // DataTable은 가로 폭이 넘칠 수 있어 수평 스크롤도 감싸줌
              return SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 12,
                  right: 12,
                  top: 12,
                  bottom: bottomPadding, // 👈 하단 여백
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTableTheme(
                    data: const DataTableThemeData(
                      dataRowMinHeight: 56, // 터치 영역 키우기
                      dataRowMaxHeight: 64,
                    ),
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('이름')),
                        DataColumn(label: Text('출석 상태')),
                        DataColumn(label: Text('출석 상태 수정')),
                      ],
                      rows: students.map((stu) {
                        return DataRow(
                          cells: [
                            DataCell(Text(stu.name ?? stu.email)),
                            DataCell(
                              FutureBuilder<
                                  DocumentSnapshot<Map<String, dynamic>>>(
                                future: fs.getAttendanceRecord(stu.uid),
                                builder: (ctx, snapshot) {
                                  if (snapshot.connectionState !=
                                      ConnectionState.done) {
                                    return const Text('...');
                                  }
                                  final doc = snapshot.data;
                                  if (doc == null || !doc.exists) {
                                    return const Text('-');
                                  }
                                  final status =
                                      (doc.data()?['attended'] as String?) ??
                                          '';
                                  return Text(
                                    _getAttendanceStatusText(status),
                                    style: TextStyle(
                                      color: _getAttendanceStatusColor(status),
                                    ),
                                  );
                                },
                              ),
                            ),
                            DataCell(
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _showUpdateAttendanceDialog(
                                    context, stu, fs),
                                tooltip: '상태 수정',
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    // ── 학생: 본인 상태 보기 ──
    final uid = context.read<UserProvider>().uid!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('출석 체크'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pushNamed(context, '/calendar'),
        ),
      ),
      body: SafeArea(
        bottom: true,
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: bottomPadding, // 👈 하단 여백
          ),
          child: FutureBuilder<String?>(
            future: fs.todayStatus(uid),
            builder: (ctx, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final status = snap.data;
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
                  label = status == null ? '상태 없음' : '상태: $status';
              }
              return Center(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 18),
                  textAlign: TextAlign.center,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // 출석 상태 → 텍스트
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

  // 출석 상태 → 색상
  Color _getAttendanceStatusColor(String status) {
    switch (status) {
      case 'present':
        return Colors.blue;
      case 'late':
        return Colors.blue;
      case 'absent':
        return Colors.red;
      default:
        return Colors.black;
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
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () async {
                await fs.recordAttendance(uid: stu.uid, status: 'present');
                if (mounted) Navigator.pop(ctx);
                setState(() {});
              },
              child: const Text('출석'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                await fs.recordAttendance(uid: stu.uid, status: 'late');
                if (mounted) Navigator.pop(ctx);
                setState(() {});
              },
              child: const Text('지각'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                await fs.recordAttendance(uid: stu.uid, status: 'absent');
                if (mounted) Navigator.pop(ctx);
                setState(() {});
              },
              child: const Text('결석'),
            ),
          ],
        ),
      ),
    );
  }
}
