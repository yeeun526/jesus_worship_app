// lib/pages/calendar_page.dart
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/event.dart';
import '../services/firestore_service.dart';
import '../widgets/permission_widget.dart';

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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('메인 캘린더')),
      body: StreamBuilder<List<Event>>(
        stream: _fs.eventList(),
        builder: (context, snap) {
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());

          // 이벤트를 날짜별로 그룹핑
          final events = snap.data!;
          final Map<DateTime, List<Event>> eventsMap = {};
          for (var e in events) {
            final day = DateTime(e.date.year, e.date.month, e.date.day);
            eventsMap.putIfAbsent(day, () => []).add(e);
          }

          return Column(
            children: [
              // ◀ 버튼을 캘린더 위에 배치
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

              // 캘린더
              TableCalendar<Event>(
                firstDay: DateTime.utc(2000, 1, 1),
                lastDay: DateTime.utc(2100, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (d) => isSameDay(d, _selectedDay),
                eventLoader: (day) =>
                    eventsMap[DateTime(day.year, day.month, day.day)] ?? [],
                onDaySelected: (selected, focused) {
                  setState(() {
                    _selectedDay = selected;
                    _focusedDay = focused;
                  });
                },
                headerStyle: const HeaderStyle(formatButtonVisible: false),
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (context, date, events) {
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

              // 선택된 날짜의 이벤트 리스트
              Expanded(
                child: _selectedDay == null
                    ? const Center(child: Text('날짜를 선택하세요'))
                    : ListView(
                        children: (eventsMap[_selectedDay!] ?? []).map((e) {
                          return ListTile(
                            title: Text(e.title),
                            subtitle: Text(
                              '${e.date.hour.toString().padLeft(2, '0')}:'
                              '${e.date.minute.toString().padLeft(2, '0')}',
                            ),
                            onTap: () => _showEventDetail(context, e),
                          );
                        }).toList(),
                      ),
              ),
            ],
          );
        },
      ),

      // 일정 추가 버튼 (관리자만)
      floatingActionButton: PermissionWidget(
        requiredRole: 'admin',
        child: FloatingActionButton(
          onPressed: () {
            final day = _selectedDay ??
                DateTime(_focusedDay.year, _focusedDay.month, _focusedDay.day);
            _onAddEvent(day);
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Future<void> _onAddEvent(DateTime day) async {
    final titleCtrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('일정 추가'),
        content: TextField(
          controller: titleCtrl,
          decoration: const InputDecoration(labelText: '일정 제목'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, titleCtrl.text.trim()),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      final event = Event(
        id: '',
        title: result,
        date: DateTime(day.year, day.month, day.day, DateTime.now().hour,
            DateTime.now().minute),
        createdBy: _user?.uid,
      );
      await _fs.addEvent(event);
    }
  }

  void _showEventDetail(BuildContext ctx, Event e) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: Text(e.title),
        content: Text(
          '${e.date.year}-${e.date.month.toString().padLeft(2, '0')}-'
          '${e.date.day.toString().padLeft(2, '0')} '
          '${e.date.hour.toString().padLeft(2, '0')}:'
          '${e.date.minute.toString().padLeft(2, '0')}',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('닫기')),
        ],
      ),
    );
  }
}
