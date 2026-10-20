# jesus워십 일정 관리 앱

율동 팀의 일정, 출석, 음원 및 영상 자료를 관리하는 Flutter 앱입니다.

## 개발 환경

- Flutter SDK 및 Dart SDK: [`pubspec.yaml`](pubspec.yaml)의 `environment` 항목 참고
- Firebase 프로젝트 설정: 앱에서 사용하는 Firebase 서비스에 맞는 플랫폼별 설정이 필요합니다.

## Android 앱 ID

- 현재 Android 앱 ID: `com.jesusworship.jesus_worship_calendar_app`
- Firebase Android 앱을 프로젝트에 등록하고 `android/app/google-services.json` 및 `lib/firebase_options.dart`에 새 앱 ID 설정을 반영했습니다.

## Android 출시용 AAB

Windows PowerShell에서 앱 디렉터리 기준으로 아래 스크립트를 실행합니다.

```powershell
.\android\build_release.ps1
```

스크립트는 처음 실행할 때 업로드 키 비밀번호를 안전 입력으로 두 번 요청하고,
저장소 밖의 `%USERPROFILE%\.android\jesus_worship_upload_key.jks`에 키를 만듭니다.
비밀번호는 디스크나 소스 코드에 저장하지 않고, 해당 실행 프로세스에서만 Gradle에 전달합니다.
같은 스크립트를 다시 실행하면 기존 키를 덮어쓰지 않고 재사용 여부를 확인합니다.

Google Play Console에 업로드할 파일은 `build\app\outputs\bundle\release\app-release.aab`입니다.
업로드 키 파일과 비밀번호를 서로 안전한 장소에 백업하고, Git이나 채팅에 올리지 마세요.
첫 출시 때 Play App Signing을 사용하도록 설정하세요. 앱 업데이트에는 같은 업로드 키가 필요합니다.

## Firebase Functions

관리자 학생 추가 기능은 `functions/`의 callable functions를 사용합니다.
Firebase CLI와 Node.js 20 이상이 필요하며, Cloud Functions 배포가 가능한 요금제를 설정한 뒤
아래 명령으로 함수를 배포하세요.

```powershell
cd functions
npm install
cd ..
firebase deploy --only firestore:rules,functions --project jesus-worship-d3648
```

함수는 로그인된 사용자의 Firestore 역할이 `admin`인지 확인한 뒤 학생 계정을 생성하거나
출석부 명단 및 출석 기록을 삭제합니다. 학생 삭제는 Firebase Authentication 로그인 계정을
삭제하지 않습니다. 새 학생은 첫 로그인 시 임시 비밀번호를 변경해야 합니다.

공개 회원가입에서는 `학생` 또는 `부모`만 선택할 수 있습니다. 최초 관리자는 이메일
`test@naver.com`으로 가입한 뒤 Firebase Console에서 해당 `users/{uid}` 문서의 `role`을
`admin`으로 직접 지정하세요. `firestore.rules`는 사용자가 자기 역할을 변경하거나
관리자 문서를 직접 만들지 못하도록 제한합니다. 규칙을 배포하기 전에 Firebase Console의
현재 규칙을 검토하고, 프로젝트의 기존 데이터 흐름과 비교하세요. 이 규칙은 이 앱에서
확인한 Firestore 컬렉션 권한을 정의하며, 다른 서비스가 같은 프로젝트를 사용한다면
해당 접근 규칙을 먼저 병합해야 합니다.

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
