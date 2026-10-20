import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/services/firestore_service.dart';
import '../../core/widgets/permission_widget.dart';
import 'student.dart';

/// 이름(행) × 일요일(열) 그리드 뷰 – 읽기/쓰기 통합 출석부
/// 셀을 탭하여 출석 상태(출석/결석)를 수정할 수 있습니다.
class AttendanceCheckPage extends StatefulWidget {
  const AttendanceCheckPage({super.key});

  @override
  State<AttendanceCheckPage> createState() => _AttendanceCheckPageState();
}

class _AttendanceCheckPageState extends State<AttendanceCheckPage> {
  final _db = FirebaseFirestore.instance;

  late DateTime _focusedMonth; // 헤더에 표시할 달(1일)
  late Future<void> _loadFuture; // 데이터 로딩 상태를 추적할 Future

  // 데이터
  List<Student> _students = []; // 정렬된 학생 목록
  late List<DateTime> _sundays = []; // 이 달의 일요일들
  // ymd -> { uid -> 'present'|'late'|'absent' }
  Map<String, Map<String, String>> _monthStatus = {};
  bool _deleteMode = false;
  String? _selectedStudentUid;

  // 셀 사이즈(그림 같은 느낌)
  static const double _nameColWidth = 104;
  static const double _rowHeight = 40;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    Intl.defaultLocale = 'ko_KR';
    _focusedMonth = DateTime(now.year, now.month, 1);
    _loadFuture = _loadAll(); // Future 객체 저장
  }

  // ───────────────── data load & update ─────────────────

  Future<void> _loadAll() async {
    try {
      await _loadStudents();
      _sundays = _sundaysOfMonth(_focusedMonth);
      await _loadMonthStatus();
    } catch (e) {
      debugPrint('데이터 로딩 오류: $e');
      rethrow;
    }
  }

  Future<void> _loadStudents() async {
    final snap =
        await _db.collection('users').where('role', isEqualTo: 'student').get();

    _students = snap.docs.map((d) {
      final data = d.data();
      // Student.fromFirestore는 외부 모델 파일에 정의되어 있다고 가정합니다.
      return Student.fromFirestore(d.id, data);
    }).toList();

    _students.sort((a, b) =>
        a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
  }

  Future<void> _loadMonthStatus() async {
    final ym = _ym(_focusedMonth);
    final daysSnap =
        await _db.collection('attendance').doc(ym).collection('days').get();

    final result = <String, Map<String, String>>{};
    for (final doc in daysSnap.docs) {
      final data = doc.data();
      final Map<String, String> statusMap = {};

      // 1) status 우선 (명시적인 출결 데이터만 수집)
      final status = (data['status'] as Map<String, dynamic>?) ?? {};
      for (final e in status.entries) {
        final v = (e.value as String?) ?? '';
        // 'late'는 데이터 수집에서 제외합니다.
        if (v == 'present' || v == 'absent') {
          statusMap[e.key] = v;
        }
      }

      // 2) 레거시 attendees(true=present) (명시적인 데이터만 수집)
      final attendees = (data['attendees'] as Map<String, dynamic>?) ?? {};
      for (final e in attendees.entries) {
        if (e.value == true && !statusMap.containsKey(e.key)) {
          statusMap[e.key] = 'present';
        }
      }

      result[doc.id] = statusMap;
    }

    _monthStatus = result;
  }

  // 🔥 Firebase 업데이트 함수
  Future<void> _updateAttendanceStatus({
    required String ymd, // yyyy-MM-dd
    required String studentUid,
    required String newStatus,
  }) async {
    final ym = _ym(_focusedMonth);
    final docRef =
        _db.collection('attendance').doc(ym).collection('days').doc(ymd);

    // 1. UI 즉시 업데이트 (Optimistic Update)
    setState(() {
      _monthStatus.putIfAbsent(ymd, () => {});
      _monthStatus[ymd]![studentUid] = newStatus;
    });

    // 2. Firestore에 업데이트
    try {
      await docRef.set(
        {
          'status': {studentUid: newStatus}
        },
        SetOptions(merge: true), // 기존 필드를 덮어쓰지 않고 병합합니다.
      );
    } catch (e) {
      debugPrint('출석 상태 업데이트 오류: $e');
    }
  }

  // ───────────────── helpers ─────────────────

  String _ym(DateTime d) => DateFormat('yyyy-MM').format(d);
  String _ymd(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  List<DateTime> _sundaysOfMonth(DateTime monthAnchor) {
    final first = DateTime(monthAnchor.year, monthAnchor.month, 1);
    final nextMonth = DateTime(monthAnchor.year, monthAnchor.month + 1, 1);
    final last = nextMonth.subtract(const Duration(days: 1));

    var d = first;
    while (d.weekday != DateTime.sunday) {
      d = d.add(const Duration(days: 1));
    }

    final list = <DateTime>[];
    while (!d.isAfter(last)) {
      list.add(d);
      d = d.add(const Duration(days: 7));
    }
    return list;
  }

  // 상태 순환 로직: 'present' (O) <-> 'absent' (X) (2단계 순환, 지각 제거)
  String _nextStatus(String? currentStatus) {
    // 기록이 없는 경우 (null)는 기본 'present'로 시작합니다.
    final effectiveStatus = currentStatus ?? 'present';

    switch (effectiveStatus) {
      case 'present':
      case 'late': // 기존에 'late'로 저장된 값이 있다면 'absent'로 넘어가도록 처리
        return 'absent';
      case 'absent':
      default: // 유효하지 않은 값이면 'present'로 시작
        return 'present';
    }
  }

  // 상태 코드에 따른 심볼과 색상을 반환합니다.
  (String, Color) _symbol(String? status) {
    // Firebase에서 불러온 상태가 null이거나 'late'인 경우 기본값 'present' (O)로 간주
    final effectiveStatus =
        (status == 'late' || status == null) ? 'present' : status;

    switch (effectiveStatus) {
      case 'present':
        return ('○', Colors.green);
      case 'absent':
        return ('×', Colors.redAccent);
      default:
        // 유효하지 않은 값이 들어왔을 경우
        return ('?', Colors.grey);
    }
  }

  // ───────────────── month nav ─────────────────

  Future<void> _prevMonth() async {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
      _loadFuture = _loadAll();
    });
  }

  Future<void> _nextMonth() async {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
      _loadFuture = _loadAll();
    });
  }

  bool _isBeforeStudentStart(Student student, DateTime sunday) {
    final createdAt = student.createdAt;
    if (createdAt == null) return false;
    final localCreatedAt = createdAt.toLocal();
    final startSunday = DateTime(
      localCreatedAt.year,
      localCreatedAt.month,
      localCreatedAt.day - (localCreatedAt.weekday % 7),
    );
    return sunday.isBefore(startSunday);
  }

  Future<void> _deleteSelectedStudent() async {
    final uid = _selectedStudentUid;
    Student? student;
    for (final item in _students) {
      if (item.uid == uid) {
        student = item;
        break;
      }
    }
    if (uid == null || student == null) return;
    final selectedStudent = student;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('학생 명단 삭제'),
        content: Text(
          '${selectedStudent.displayName} 학생의 출석부 명단과 모든 출석 기록을 삭제할까요? '
          'Firebase 로그인 계정은 삭제되지 않습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await FirestoreService().deleteStudentRosterAndAttendance(uid);
      if (!mounted) return;
      setState(() {
        _deleteMode = false;
        _selectedStudentUid = null;
        _loadFuture = _loadAll();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('학생 명단과 출석 기록을 삭제했습니다.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('학생 삭제에 실패했습니다: $error')),
      );
    }
  }

  // ───────────────── UI ─────────────────

  @override
  Widget build(BuildContext context) {
    final titleText = DateFormat.yMMM('ko_KR').format(_focusedMonth);
    // 현재 시점
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('출석 관리'),
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/calendar');
          },
        ),
        actions: [
          PermissionWidget(
            requiredRole: 'admin',
            child: IconButton(
              tooltip: _deleteMode ? '삭제 취소' : '학생 삭제',
              icon: Icon(_deleteMode ? Icons.close : Icons.person_remove),
              onPressed: () => setState(() {
                _deleteMode = !_deleteMode;
                _selectedStudentUid = null;
              }),
            ),
          ),
          IconButton(
              onPressed: _prevMonth, icon: const Icon(Icons.chevron_left)),
          Center(child: Text(titleText, style: const TextStyle(fontSize: 16))),
          IconButton(
              onPressed: _nextMonth, icon: const Icon(Icons.chevron_right)),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<void>(
        future: _loadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('데이터 로딩 오류: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red)),
              ),
            );
          }

          // 데이터 로딩 완료 (정상적으로 위젯 빌드)
          return Column(
            children: [
              // ── 헤더 행: (고정) 이름칸 + (가로 스크롤) 일요일 날짜들 ──
              _HeaderRow(
                sundays: _sundays,
                students: _students,
                monthStatus: _monthStatus,
                today: now,
              ),

              const Divider(height: 1),

              // ── 표 본문: 세로 스크롤 (가로는 헤더와 동기화) ──
              Expanded(
                child: ListView.builder(
                  itemCount: _students.length,
                  itemBuilder: (_, i) {
                    final s = _students[i];
                    return SizedBox(
                      height: _rowHeight,
                      child: Row(
                        children: [
                          // 고정 이름 칼럼
                          Container(
                            width: _nameColWidth,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            alignment: Alignment.centerLeft,
                            decoration: BoxDecoration(
                              color: i.isEven
                                  ? Theme.of(context)
                                      .colorScheme
                                      .surfaceVariant
                                      .withOpacity(.18)
                                  : Colors.transparent,
                            ),
                            child: InkWell(
                              onTap: _deleteMode
                                  ? () => setState(() {
                                        _selectedStudentUid =
                                            _selectedStudentUid == s.uid
                                                ? null
                                                : s.uid;
                                      })
                                  : null,
                              child: Row(
                                children: [
                                  if (_deleteMode)
                                    Icon(
                                      _selectedStudentUid == s.uid
                                          ? Icons.check_box
                                          : Icons.check_box_outline_blank,
                                      size: 18,
                                      color: _selectedStudentUid == s.uid
                                          ? Theme.of(context).colorScheme.error
                                          : null,
                                    ),
                                  if (_deleteMode) const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      s.displayName,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Date columns share the available width to avoid horizontal scrolling.
                          Expanded(
                            child: Row(
                              children: _sundays
                                  .map((d) {
                                    final ymd = _ymd(d);
                                    final isFutureDate = d.isAfter(now);
                                    final beforeStudentStart =
                                        _isBeforeStudentStart(s, d);

                                    (String, Color) displaySymbol;

                                    if (isFutureDate || beforeStudentStart) {
                                      displaySymbol = ('-', Colors.grey);
                                    } else {
                                      final currentStatus =
                                          _monthStatus[ymd]?[s.uid];
                                      displaySymbol = _symbol(currentStatus);
                                    }

                                    final (ch, color) = displaySymbol;

                                    return GestureDetector(
                                      onTap: isFutureDate || beforeStudentStart
                                          ? null
                                          : () {
                                              final currentStatus =
                                                  _monthStatus[ymd]?[s.uid];
                                              final nextStatus =
                                                  _nextStatus(currentStatus);
                                              _updateAttendanceStatus(
                                                ymd: ymd,
                                                studentUid: s.uid,
                                                newStatus: nextStatus,
                                              );
                                            },
                                      child: Container(
                                        width: null,
                                        height: _rowHeight,
                                        constraints: const BoxConstraints(
                                          minWidth: 0,
                                        ),
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          border: Border(
                                            right: BorderSide(
                                              color: Theme.of(context)
                                                  .dividerColor
                                                  .withOpacity(.6),
                                              width: 0.5,
                                            ),
                                          ),
                                          color: i.isEven
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .surfaceVariant
                                                  .withOpacity(.08)
                                              : null,
                                        ),
                                        child: Text(
                                          ch,
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: color,
                                            decoration: TextDecoration.none,
                                          ),
                                        ),
                                      ),
                                    );
                                  })
                                  .map((cell) => Expanded(child: cell))
                                  .toList(),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              if (_deleteMode)
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _selectedStudentUid == null
                            ? null
                            : _deleteSelectedStudent,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('선택한 학생 삭제'),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ───────────────── header row ─────────────────

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.sundays,
    required this.students,
    required this.monthStatus,
    required this.today,
  });

  final List<DateTime> sundays;
  final List<Student> students;
  final Map<String, Map<String, String>> monthStatus;
  final DateTime today;

  static const double _nameColWidth = 104;
  static const double _headerHeight = 56;

  String _label(DateTime d) {
    return DateFormat('d').format(d);
  }

  int _presentCount(DateTime day) {
    final dateKey = DateFormat('yyyy-MM-dd').format(day);
    final statuses = monthStatus[dateKey] ?? {};
    return _eligibleStudents(day).where((student) {
      final status = statuses[student.uid];
      return status == null || status == 'late' || status == 'present';
    }).length;
  }

  List<Student> _eligibleStudents(DateTime sunday) {
    return students.where((student) {
      final createdAt = student.createdAt;
      if (createdAt == null) return true;
      final localCreatedAt = createdAt.toLocal();
      final startSunday = DateTime(
        localCreatedAt.year,
        localCreatedAt.month,
        localCreatedAt.day - (localCreatedAt.weekday % 7),
      );
      return !sunday.isBefore(startSunday);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _headerHeight,
      child: Row(
        children: [
          // 고정 이름 헤더
          Container(
            width: _nameColWidth,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            color:
                Theme.of(context).colorScheme.surfaceVariant.withOpacity(.35),
            child: const Text(
              '이름',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),

          Expanded(
            child: Row(
              children: sundays.map((d) {
                final isFutureDate = d.isAfter(today);
                final eligibleCount = _eligibleStudents(d).length;
                return Expanded(
                  child: Container(
                    height: _headerHeight,
                    alignment: Alignment.center,
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceVariant
                        .withOpacity(.35),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _label(d),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          isFutureDate
                              ? '—/$eligibleCount'
                              : '${_presentCount(d)}/$eligibleCount',
                          style: Theme.of(context).textTheme.labelSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
