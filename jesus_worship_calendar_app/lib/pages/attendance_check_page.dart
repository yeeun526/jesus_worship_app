import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/attendance.dart'; // uid, email, name, displayName

/// 이름(행) × 일요일(열) 그리드 뷰 – 읽기 전용
/// status 스키마 권장:
/// attendance/{yyyy-MM}/days/{yyyy-MM-dd}.status = { uid: 'present'|'late'|'absent' }
/// 레거시 attendees={uid:true}도 present로 인식
class AttendanceCheckPage extends StatefulWidget {
  const AttendanceCheckPage({Key? key}) : super(key: key);

  @override
  State<AttendanceCheckPage> createState() => _AttendanceCheckPageState();
}

class _AttendanceCheckPageState extends State<AttendanceCheckPage> {
  final _db = FirebaseFirestore.instance;

  late DateTime _focusedMonth; // 헤더에 표시할 달(1일)
  bool _loading = false;

  // 데이터
  List<Student> _students = []; // 정렬된 학생 목록
  late List<DateTime> _sundays; // 이 달의 일요일들
  // ymd -> { uid -> 'present'|'late'|'absent' }
  Map<String, Map<String, String>> _monthStatus = {};

  // 스크롤 동기화(헤더 <-> 본문 가로)
  final ScrollController _hCtrl = ScrollController();

  // 셀 사이즈(그림 같은 느낌)
  static const double _nameColWidth = 120;
  static const double _cellWidth = 36;
  static const double _rowHeight = 40;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month, 1);
    _loadAll();
  }

  @override
  void dispose() {
    _hCtrl.dispose();
    super.dispose();
  }

  // ───────────────── data load ─────────────────

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      await _loadStudents();
      _sundays = _sundaysOfMonth(_focusedMonth);
      await _loadMonthStatus();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadStudents() async {
    final snap =
        await _db.collection('users').where('role', isEqualTo: 'student').get();

    _students = snap.docs.map((d) {
      final data = d.data();
      return Student.fromFirestore(d.id, data);
    }).toList();

    // 이름(또는 이메일) 오름차순
    _students.sort((a, b) =>
        a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));

    // (정원이 22명으로 고정이라면 아래 주석 해제 가능)
    // if (_students.length > 22) _students = _students.take(22).toList();
  }

  Future<void> _loadMonthStatus() async {
    final ym = _ym(_focusedMonth);
    final daysSnap =
        await _db.collection('attendance').doc(ym).collection('days').get();

    final result = <String, Map<String, String>>{};
    for (final doc in daysSnap.docs) {
      final data = doc.data();

      // 1) status 우선
      final Map<String, String> statusMap = {};
      final status = (data['status'] as Map<String, dynamic>?) ?? {};
      for (final e in status.entries) {
        final v = (e.value as String?) ?? '';
        if (v == 'present' || v == 'late' || v == 'absent') {
          statusMap[e.key] = v;
        }
      }

      // 2) 레거시 attendees(true=present)
      final attendees = (data['attendees'] as Map<String, dynamic>?) ?? {};
      for (final e in attendees.entries) {
        if (e.value == true && !statusMap.containsKey(e.key)) {
          statusMap[e.key] = 'present';
        }
      }

      // 3) 빠진 학생은 'absent'로 채워(표시만)
      for (final s in _students) {
        statusMap[s.uid] = statusMap[s.uid] ?? 'absent';
      }

      result[doc.id] = statusMap;
    }

    _monthStatus = result;
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

  (String, Color) _symbol(String status) {
    switch (status) {
      case 'present':
        return ('○', Colors.green);
      case 'late':
        return ('△', Colors.orange);
      case 'absent':
      default:
        return ('×', Colors.redAccent);
    }
  }

  // ───────────────── month nav ─────────────────

  Future<void> _prevMonth() async {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
    });
    setState(() => _loading = true);
    try {
      _sundays = _sundaysOfMonth(_focusedMonth);
      await _loadMonthStatus();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    // 가로 스크롤 맨 앞으로
    _hCtrl.jumpTo(0);
  }

  Future<void> _nextMonth() async {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
    });
    setState(() => _loading = true);
    try {
      _sundays = _sundaysOfMonth(_focusedMonth);
      await _loadMonthStatus();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    _hCtrl.jumpTo(0);
  }

  // ───────────────── UI ─────────────────

  @override
  Widget build(BuildContext context) {
    final titleText = DateFormat.yMMM('ko_KR').format(_focusedMonth);

    return Scaffold(
      appBar: AppBar(
        title: const Text('일요일 출석표'),
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/calendar');
          },
        ),
        actions: [
          IconButton(
              onPressed: _prevMonth, icon: const Icon(Icons.chevron_left)),
          Center(child: Text(titleText, style: const TextStyle(fontSize: 16))),
          IconButton(
              onPressed: _nextMonth, icon: const Icon(Icons.chevron_right)),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          if (_loading) const LinearProgressIndicator(minHeight: 2),

          // ── 헤더 행: (고정) 이름칸 + (가로 스크롤) 일요일 날짜들 ──
          _HeaderRow(
            sundays: _sundays,
            hCtrl: _hCtrl,
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
                        child: Text(
                          s.displayName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),

                      // 가로 스크롤 셀들 (헤더와 컨트롤러 공유)
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _hCtrl,
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _sundays.map((d) {
                              final ymd = _ymd(d);
                              final st = _monthStatus[ymd]?[s.uid] ?? 'absent';
                              final (ch, color) = _symbol(st);
                              return Container(
                                width: _cellWidth,
                                height: _rowHeight,
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
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────── header row ─────────────────

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.sundays,
    required this.hCtrl,
  });

  final List<DateTime> sundays;
  final ScrollController hCtrl;

  static const double _nameColWidth = _AttendanceCheckPageState._nameColWidth;
  static const double _cellWidth = _AttendanceCheckPageState._cellWidth;
  static const double _rowHeight = _AttendanceCheckPageState._rowHeight;

  String _label(DateTime d) {
    // 그림처럼 간단한 날짜(일)만 표시. 필요하면 'M.d'로 바꿔도 됨.
    return DateFormat('d').format(d); // 1, 8, 15 ...
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _rowHeight,
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

          // 가로 스크롤 날짜 헤더
          Expanded(
            child: SingleChildScrollView(
              controller: hCtrl,
              scrollDirection: Axis.horizontal,
              child: Row(
                children: sundays.map((d) {
                  return Container(
                    width: _cellWidth,
                    height: _rowHeight,
                    alignment: Alignment.center,
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceVariant
                        .withOpacity(.35),
                    child: Text(
                      _label(d),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
