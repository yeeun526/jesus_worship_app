import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jesus_worship_calendar_app/core/services/firestore_service.dart';
import 'package:jesus_worship_calendar_app/features/auth/privacy_consent_page.dart';

void main() {
  test('현재 정책 버전의 동의 기록은 재로그인 시 다시 동의 화면을 요구하지 않는다', () {
    final consent = {
      'policyVersion': FirestoreService.privacyPolicyVersion,
      'privacyNoticeAcknowledged': true,
      'ageGroup': '14OrOlder',
    };

    expect(FirestoreService.isPrivacyConsentComplete(consent), isTrue);
  });

  test('다른 정책 버전이나 미완료된 동의 기록은 다시 확인해야 한다', () {
    final outdatedConsent = {
      'policyVersion': 'old-version',
      'privacyNoticeAcknowledged': true,
      'ageGroup': '14OrOlder',
    };
    final incompleteMinorConsent = {
      'policyVersion': FirestoreService.privacyPolicyVersion,
      'privacyNoticeAcknowledged': true,
      'ageGroup': 'under14',
      'guardianConsent': true,
      'guardianName': '보호자',
    };

    expect(
      FirestoreService.isPrivacyConsentComplete(outdatedConsent),
      isFalse,
    );
    expect(
      FirestoreService.isPrivacyConsentComplete(incompleteMinorConsent),
      isFalse,
    );
  });

  Future<void> pumpConsentPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(home: PrivacyConsentPage()),
    );
  }

  testWidgets('기본 안내와 처리방침 링크를 표시한다', (tester) async {
    await pumpConsentPage(tester);

    expect(find.text('개인정보 확인 및 동의'), findsOneWidget);
    expect(find.text('개인정보 처리방침 전문 보기'), findsOneWidget);
    expect(find.text('출석정보 처리에 별도로 동의합니다 (선택)'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
  });

  testWidgets('만 14세 이상은 출석 동의 없이 확인 후 계속할 수 있다', (tester) async {
    await pumpConsentPage(tester);

    await tester.tap(find.text('개인정보 처리방침을 확인했습니다 (필수)'));
    await tester.tap(find.text('만 14세 이상'));
    await tester.pumpAndSettle();

    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull);
    expect(find.text('법정대리인 이름'), findsNothing);
  });

  testWidgets('만 14세 미만은 법정대리인 정보를 입력해야 계속할 수 있다', (tester) async {
    await pumpConsentPage(tester);

    await tester.tap(find.text('개인정보 처리방침을 확인했습니다 (필수)'));
    await tester.tap(find.text('만 14세 미만'));
    await tester.pumpAndSettle();

    expect(find.text('법정대리인 이름'), findsOneWidget);
    expect(find.text('법정대리인 연락 이메일'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);

    await tester.enterText(find.byType(TextField).first, '보호자');
    await tester.enterText(find.byType(TextField).last, 'guardian@example.com');
    await tester.tap(
      find.textContaining('본인은 이 이용자의 법정대리인이며'),
    );
    await tester.pumpAndSettle();

    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull);
    expect(
      find.text('법정대리인으로서 이 이용자의 출석정보 처리에 별도로 동의합니다 (선택)'),
      findsOneWidget,
    );
  });
}
