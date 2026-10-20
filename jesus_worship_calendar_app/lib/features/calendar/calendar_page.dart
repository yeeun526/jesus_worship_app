import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/firestore_service.dart';
import '../../core/widgets/permission_widget.dart';
import '../../core/providers/user_provider.dart';
import 'event.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});
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
    _selectedDay =
        DateTime(_focusedDay.year, _focusedDay.month, _focusedDay.day);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('jesus worship'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.privacy_tip_outlined),
            tooltip: '개인정보 동의 설정',
            onPressed: () => Navigator.pushNamed(context, '/privacy-consent'),
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: '계정 관리',
            onPressed: () => Navigator.pushNamed(context, '/account'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: '로그아웃',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('isLoggedIn', false);
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (_) => false,
                );
              }
            },
          ),
        ],
      ),

      body: StreamBuilder<List<Event>>(
        stream: _fs.eventList(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final events = snap.data!;
          List<Event> _getEventsForDay(DateTime day) =>
              events.where((e) => isSameDay(e.date, day)).toList();

          return SafeArea(
            child: LayoutBuilder(
              builder: (context, cons) {
                final double totalH = cons.maxHeight;
                const double btnBarH = 64; // 하단 버튼 바 높이
                const double divH = 1; // Divider 높이

                // 캘린더 높이: 화면의 45% 사용, 300~420px 범위로 클램프
                double calendarH = (totalH * 0.45).clamp(300.0, 420.0);

                return Column(
                  children: [
                    // ── 캘린더(고정 높이) ──
                    SizedBox(
                      height: calendarH,
                      child: TableCalendar<Event>(
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

                        headerStyle:
                            const HeaderStyle(formatButtonVisible: false),
                        // 패키지 버전에 따라 없을 수도 있음(없으면 지워도 동작)
                        shouldFillViewport: true,
                        calendarBuilders: CalendarBuilders(
                          markerBuilder: (ctx, date, dayEvents) {
                            if (dayEvents.isNotEmpty) {
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
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                    ),

                    const Divider(height: divH),

                    // ── 선택일의 일정을 아래에서 끌어 올려 확인하는 패널 ──
                    Expanded(
                      child: _selectedDay == null
                          ? const Center(child: Text('날짜를 선택하세요'))
                          : DraggableScrollableSheet(
                              initialChildSize: 0.22,
                              minChildSize: 0.16,
                              maxChildSize: 1,
                              snap: true,
                              snapSizes: const [0.22, 1],
                              builder: (sheetContext, scrollController) {
                                final dayEvents =
                                    _getEventsForDay(_selectedDay!);
                                return Material(
                                  color: Theme.of(context).colorScheme.surface,
                                  elevation: 8,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(18),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: CustomScrollView(
                                    controller: scrollController,
                                    slivers: [
                                      SliverToBoxAdapter(
                                        child: Column(
                                          children: [
                                            const SizedBox(height: 8),
                                            Container(
                                              width: 36,
                                              height: 4,
                                              decoration: BoxDecoration(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .outlineVariant,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                            ListTile(
                                              dense: true,
                                              title: Text(
                                                DateFormat(
                                                        'M월 d일 EEEE', 'ko_KR')
                                                    .format(_selectedDay!),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium,
                                              ),
                                              subtitle: Text(
                                                '일정 ${dayEvents.length}개',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (dayEvents.isEmpty)
                                        const SliverFillRemaining(
                                          hasScrollBody: false,
                                          child: Center(
                                            child: Text('등록된 일정이 없습니다.'),
                                          ),
                                        )
                                      else
                                        SliverList(
                                          delegate: SliverChildBuilderDelegate(
                                            (ctx, i) {
                                              final event = dayEvents[i];
                                              return ListTile(
                                                title: Text(event.title),
                                                subtitle: Text(
                                                  '${event.date.hour.toString().padLeft(2, '0')}:'
                                                  '${event.date.minute.toString().padLeft(2, '0')}',
                                                ),
                                                onTap: context
                                                            .watch<
                                                                UserProvider>()
                                                            .role ==
                                                        'admin'
                                                    ? () =>
                                                        _showEditDialog(event)
                                                    : null,
                                              );
                                            },
                                            childCount: dayEvents.length,
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),

                    const Divider(height: divH),

                    // ── 하단 네비 버튼 바(고정 높이) ──
                    SizedBox(
                      height: btnBarH,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _NavBtn(
                                text: '음원',
                                onTap: () =>
                                    Navigator.pushNamed(context, '/audio')),
                            _NavBtn(
                                text: '영상',
                                onTap: () =>
                                    Navigator.pushNamed(context, '/video')),
                            _NavBtn(
                                text: '출석부',
                                onTap: () => Navigator.pushNamed(
                                    context, '/attendance_check')),
                            PermissionWidget(
                              requiredRole: 'admin',
                              child: _NavBtn(
                                text: '학생 추가',
                                onTap: _showAddStudentDialog,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),

      // ── 일정 추가 버튼 (관리자만) ──
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 70.0, right: 10.0),
        child: PermissionWidget(
          requiredRole: 'admin',
          child: FloatingActionButton(
            onPressed: () {
              final day = _selectedDay ?? DateTime.now();
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
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: '일정 제목'),
              ),
              const SizedBox(height: 12),
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
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                if (titleCtrl.text.trim().isEmpty) {
                  // 📌 베이시스: 제목 미입력 시 피드백 제공 (스낵바)
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('일정 제목을 입력해주세요.')),
                  );
                  return; // 창을 닫지 않고 함수 종료
                }
                Navigator.pop(ctx, true); // 제목이 있을 때만 true 반환하며 닫기
              },
              child: const Text('저장'),
            ),
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
    titleCtrl.dispose();
  }

  Future<void> _showEditDialog(Event e) async {
    DateTime selectedDate = e.date;
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(e.date);
    final titleCtrl = TextEditingController(text: e.title); // 📌 기존 제목 채우기

    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('일정 수정'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: '일정 제목'),
              ),
              const SizedBox(height: 12),
              // 날짜 선택 Row (기존 _showAddDialog와 로직 동일)
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
              // 시간 선택 Row
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
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: ctx,
                  builder: (confirmContext) => AlertDialog(
                    title: const Text('일정 삭제'),
                    content: Text('“${e.title}” 일정을 삭제하시겠습니까?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(confirmContext, false),
                        child: const Text('취소'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(confirmContext, true),
                        child: const Text('삭제'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await _fs.deleteEvent(e.id);
                  if (ctx.mounted) Navigator.pop(ctx, 'deleted');
                }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('삭제'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                if (titleCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('제목을 입력해주세요.')));
                  return;
                }
                Navigator.pop(ctx, 'save');
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );

    if (action == 'save') {
      final updatedDt = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedTime.hour,
        selectedTime.minute,
      );

      // 📌 기존 e.id와 e.createdBy를 유지하는 것이 포인트!
      final updatedEvent = Event(
        id: e.id,
        title: titleCtrl.text.trim(),
        date: updatedDt,
        createdBy: e.createdBy,
      );

      await _fs.updateEvent(updatedEvent);
    }
    titleCtrl.dispose();
  }

  Future<void> _showAddStudentDialog() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var isCreating = false;

    final details = await showDialog<({String email, String password})>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => PopScope(
          canPop: !isCreating,
          child: AlertDialog(
            title: const Text('학생 추가'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: '학생 이름'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? '이름을 입력해 주세요.'
                        : null,
                  ),
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: '학생 로그인 이메일'),
                    validator: (value) {
                      final email = value?.trim() ?? '';
                      return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                              .hasMatch(email)
                          ? null
                          : '유효한 이메일을 입력해 주세요.';
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed:
                    isCreating ? null : () => Navigator.pop(dialogContext),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: isCreating
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => isCreating = true);
                        try {
                          final credentials = await _fs.createStudentAccount(
                            name: nameController.text.trim(),
                            email: emailController.text.trim(),
                          );
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext, credentials);
                          }
                        } catch (error) {
                          if (dialogContext.mounted) {
                            setDialogState(() => isCreating = false);
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(content: Text('학생 계정 생성 실패: $error')),
                            );
                          }
                        }
                      },
                child: isCreating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('계정 만들기'),
              ),
            ],
          ),
        ),
      ),
    );

    nameController.dispose();
    emailController.dispose();
    if (details == null || !mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('학생 계정이 생성됐습니다'),
          content: SelectableText(
            '이메일: ${details.email}\n'
            '임시 비밀번호: ${details.password}\n\n'
            '임시 비밀번호는 이 화면에서만 확인할 수 있으니 안전한 방법으로 전달해 주세요.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('확인'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 하단 네비 버튼 공통 스타일
class _NavBtn extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _NavBtn({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ElevatedButton(
        onPressed: onTap,
        child: Text(text),
      ),
    );
  }
}
