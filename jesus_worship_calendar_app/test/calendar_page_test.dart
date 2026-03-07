import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jesus_worship_calendar_app/pages/calendar_page.dart';

void main() {
  testWidgets('캘린더 페이지가 정상적으로 로드되고 제목이 표시되는가', (WidgetTester tester) async {
    // 1. 앱을 가상으로 실행 (펌핑)
    // 실제 Firebase와 연결되어 있다면 Mocking이 필요하지만,
    // 우선 구조만 확인하는 테스트입니다.
    await tester.pumpWidget(const MaterialApp(home: CalendarPage()));

    // 2. 'jesus worship'이라는 텍스트가 AppBar에 있는지 확인 (테스트 오라클)
    expect(find.text('jesus worship'), findsOneWidget);

    // 3. 날짜가 선택되지 않았을 때 초기 메시지 확인
    // 현재 코드 상 initState에서 오늘 날짜를 선택하게 되어 있으므로
    // '날짜를 선택하세요'가 안 보일 수도 있습니다. 이런 로직의 모순을 찾는 게 QA입니다!
  });
}
