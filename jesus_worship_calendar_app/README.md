# jesus워십 일정 관리 앱

율동 팀의 일정, 출석, 음원 및 영상 자료를 관리하는 Flutter 앱입니다.

## 개발 환경

- Flutter SDK 및 Dart SDK: [`pubspec.yaml`](pubspec.yaml)의 `environment` 항목 참고
- Firebase 프로젝트 설정: 앱에서 사용하는 Firebase 서비스에 맞는 플랫폼별 설정이 필요합니다.

## Android 앱 ID

- 현재 Android 앱 ID: `com.jesusworship.jesus_worship_calendar_app`
- Firebase Console에 이 ID로 Android 앱을 등록한 뒤 새 `google-services.json`을 `android/app/`에 넣고, FlutterFire CLI로 `lib/firebase_options.dart`를 다시 생성해야 Android에서 Firebase를 사용할 수 있습니다.
- 이전 `google-services.json`은 `com.example.jesus_worship_calendar_app`에 등록된 설정이므로 새 설정으로 교체하기 전까지 Android 빌드/Firebase 실행이 정상 동작하지 않을 수 있습니다.

## 실행

저장소 루트가 아닌 이 디렉터리에서 명령을 실행합니다.

```bash
flutter pub get
flutter run
```

Firebase 설정이 없는 환경에서는 인증·Firestore·Storage 기능이 정상 동작하지 않을 수 있습니다. Firebase 설정 파일은 프로젝트에서 제공하거나, 각 개발 환경에 맞게 별도로 구성하세요.

## 검사 및 테스트

```bash
flutter analyze
flutter test
```

## 주요 디렉터리

- `lib/features/auth/`: 로그인 및 회원가입
- `lib/features/calendar/`: 캘린더 화면과 일정 모델
- `lib/features/attendance/`: 출석 화면과 학생 모델
- `lib/features/audio/`: 음원 화면과 음원 모델
- `lib/features/video/`: 영상 목록 및 재생 화면
- `lib/core/`: 공통 provider, 위젯, Firebase 서비스와 공용 모델
- `lib/main.dart`: 앱 초기화와 화면 라우트 등록
- `test/`: Flutter 테스트
- `docs/`: 테스트 및 QA 기록

루트 README에서 앱 소개와 시연 화면을 확인할 수 있습니다.
