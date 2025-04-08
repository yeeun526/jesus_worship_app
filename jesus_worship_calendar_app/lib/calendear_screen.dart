import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'attendance_page.dart';
import 'video_page.dart';
import 'music_page.dart';
import 'settings_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({Key? key}) : super(key: key);

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay = DateTime.now(); // ✅ 추가
  DateTime? _pickedDateTime;
  final Map<DateTime, List<String>> _events = {};

  List<String> _getEventsForDay(DateTime day) {
    final normalized = DateTime.utc(day.year, day.month, day.day);
    return _events[normalized] ?? [];
  }

  Future<void> _loadEvents() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('events').get();
    final Map<DateTime, List<String>> loadedEvents = {};

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final timestamp = data['date'] as Timestamp;
      final event = data['event'] as String;
      final date = DateTime.utc(timestamp.toDate().year,
          timestamp.toDate().month, timestamp.toDate().day);

      if (loadedEvents[date] != null) {
        loadedEvents[date]!.add(event);
      } else {
        loadedEvents[date] = [event];
      }
    }

    setState(() {
      _events.clear();
      _events.addAll(loadedEvents);
    });
  }

  Future<void> _addEvent(String event, DateTime selectedDateTime) async {
    final selected = DateTime.utc(
      selectedDateTime.year,
      selectedDateTime.month,
      selectedDateTime.day,
    );

    await FirebaseFirestore.instance.collection('events').add({
      'date': selectedDateTime,
      'event': event,
    });

    setState(() {
      if (_events[selected] != null) {
        _events[selected]!.add(event);
      } else {
        _events[selected] = [event];
      }
    });

    await _loadEvents(); // ✅ 이거 꼭 호출!
  }

  void _showAddEventDialog() {
    final TextEditingController _controller = TextEditingController();
    _pickedDateTime = DateTime.now(); // 초기값 설정

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('일정 추가'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  labelText: '일정 제목',
                  hintText: '예: 율동 연습',
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (date != null) {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (time != null) {
                      setState(() {
                        _pickedDateTime = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          time.hour,
                          time.minute,
                        );
                      });
                    }
                  }
                },
                child: const Text('날짜 및 시간 선택'),
              ),
              const SizedBox(height: 8),
              if (_pickedDateTime != null)
                Text(
                  "선택된 시간: ${DateFormat('yyyy-MM-dd HH:mm').format(_pickedDateTime!)}",
                  style: const TextStyle(fontSize: 12),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                if (_controller.text.isNotEmpty && _pickedDateTime != null) {
                  _addEvent(
                    "${_controller.text} (${DateFormat('HH:mm').format(_pickedDateTime!)})",
                    _pickedDateTime!,
                  );
                  Navigator.of(context).pop();
                }
              },
              child: const Text('추가'),
            ),
          ],
        ),
      ),
    );
  }

  void _onNavTapped(int index) {
    switch (index) {
      case 0:
        Navigator.push(context,
            MaterialPageRoute(builder: (context) => const AttendancePage()));
        break;
      case 1:
        Navigator.push(context,
            MaterialPageRoute(builder: (context) => const VideoPage()));
        break;
      case 2:
        Navigator.push(context,
            MaterialPageRoute(builder: (context) => const MusicPage()));
        break;
      case 3:
        Navigator.push(context,
            MaterialPageRoute(builder: (context) => const SettingsPage()));
        break;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('jesus worship team'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            eventLoader: _getEventsForDay,

            // ✅ 요거 추가! -> 2weeks 버튼 없앰앰
            availableCalendarFormats: const {
              CalendarFormat.month: 'Month',
            },

            calendarStyle: const CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Colors.orangeAccent,
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Colors.deepPurple,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: _getEventsForDay(_selectedDay!)
                  .map((event) => ListTile(
                        leading: const Icon(Icons.event_note),
                        title: Text(event),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddEventDialog,
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,
        onTap: _onNavTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.check_circle), label: '출석'),
          BottomNavigationBarItem(icon: Icon(Icons.videocam), label: '영상'),
          BottomNavigationBarItem(icon: Icon(Icons.music_note), label: '음원'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: '설정'),
        ],
      ),
    );
  }
}
