import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../models/event.dart';
import '../services/firestore_service.dart';
import '../widgets/permission_widget.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({Key? key}) : super(key: key);
  @override
  _CalendarPageState createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  final _fs = FirestoreService();
  final _user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    // 앱 시작 시 오늘을 선택된 날짜로 세팅
    _selectedDay = DateTime(
      _focusedDay.year,
      _focusedDay.month,
      _focusedDay.day,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ── AppBar: 제목 + 로그아웃 버튼 ──
      appBar: AppBar(
        title: const Text('jesus worship'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: '로그아웃',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),

      // ── Body: 캘린더 + 이벤트 리스트 ──
      body: StreamBuilder<List<Event>>(
        stream: _fs.eventList(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final events = snap.data!;
          // 선택된 날짜와 같은 날의 이벤트만 필터링
          List<Event> _getEventsForDay(DateTime day) =>
              events.where((e) => isSameDay(e.date, day)).toList();

          return Column(
            children: [
              // 1) TableCalendar
              TableCalendar<Event>(
                firstDay: DateTime.utc(2000, 1, 1),
                lastDay: DateTime.utc(2100, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (d) => isSameDay(d, _selectedDay),
                eventLoader: (day) => _getEventsForDay(day),
                onDaySelected: (selected, focused) {
                  setState(() {
                    _selectedDay = selected;
                    _focusedDay = focused;
                  });
                },
                headerStyle: const HeaderStyle(formatButtonVisible: false),
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (ctx, date, events) {
                    if (events.isNotEmpty) {
                      return Positioned(
                        bottom: 1,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.blueAccent,
                          ),
                        ),
                      );
                    }
                    return const SizedBox();
                  },
                ),
              ),

              const Divider(height: 1),

              // 2) 선택된 날짜의 이벤트 리스트
              Expanded(
                child: _selectedDay == null
                    ? const Center(child: Text('날짜를 선택하세요'))
                    : ListView(
                        children: _getEventsForDay(_selectedDay!).map((e) {
                          return ListTile(
                              title: Text(e.title),
                              subtitle: Text(
                                '${e.date.hour.toString().padLeft(2, '0')}:'
                                '${e.date.minute.toString().padLeft(2, '0')}',
                              ),
                              trailing: PermissionWidget(
                                  requiredRole: 'admin',
                                  child: IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.redAccent),
                                    onPressed: () => _confirmDelete(e),
                                  )));
                        }).toList(),
                      ),
              ),

              const Divider(height: 1),

              // 3) 하단 네비게이션 버튼
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    ElevatedButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/attendance'),
                      child: const Text('출석'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pushNamed(context, '/audio'),
                      child: const Text('음원'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pushNamed(context, '/video'),
                      child: const Text('영상'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pushNamed(context, '/task'),
                      child: const Text('과제'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),

      // ── 일정 추가 버튼 (관리자만) ──
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 40.0, right: 40.0),
        child: PermissionWidget(
          requiredRole: 'admin',
          child: FloatingActionButton(
            onPressed: () {
              final day = _selectedDay!;
              _showAddDialog(day);
            },
            child: const Icon(Icons.add),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  /// 일정 추가 다이얼로그 (제목 + 날짜 + 시간 선택)
  Future<void> _showAddDialog(DateTime initialDay) async {
    DateTime selectedDate = initialDay;
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(DateTime.now());
    final titleCtrl = TextEditingController();

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('일정 추가'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 제목 입력
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: '일정 제목'),
              ),
              const SizedBox(height: 12),
              // 날짜 선택
              Row(
                children: [
                  Text('날짜: ${DateFormat('yyyy-MM-dd').format(selectedDate)}'),
                  const Spacer(),
                  TextButton(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (d != null) setState(() => selectedDate = d);
                    },
                    child: const Text('변경'),
                  ),
                ],
              ),
              // 시간 선택
              Row(
                children: [
                  Text('시간: ${selectedTime.format(ctx)}'),
                  const Spacer(),
                  TextButton(
                    onPressed: () async {
                      final t = await showTimePicker(
                        context: ctx,
                        initialTime: selectedTime,
                      );
                      if (t != null) setState(() => selectedTime = t);
                    },
                    child: const Text('변경'),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('취소')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('저장')),
          ],
        ),
      ),
    );

    if (shouldSave == true && titleCtrl.text.trim().isNotEmpty) {
      final dt = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedTime.hour,
        selectedTime.minute,
      );
      final event = Event(
        id: '',
        title: titleCtrl.text.trim(),
        date: dt,
        createdBy: _user?.uid,
      );
      await _fs.addEvent(event);
    }
  }

  /// 삭제 확인 다이얼로그 후 Firestore에서 삭제
  Future<void> _confirmDelete(Event e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('일정 삭제'),
        content: Text('“${e.title}” 일정을 삭제하시겠습니까?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('삭제')),
        ],
      ),
    );
    if (ok == true) {
      await _fs.deleteEvent(e.id);
    }
  }
}
