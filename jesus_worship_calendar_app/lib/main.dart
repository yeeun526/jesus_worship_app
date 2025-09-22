import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'providers/user_provider.dart';
import 'pages/login.dart';
import 'pages/sign_up.dart';
import 'pages/calendar_page.dart';
import 'pages/attendance_page.dart';
import 'pages/audio_page.dart';
import 'pages/video_page.dart';
import 'pages/attendance_check_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Intl 기본 로케일 (선택)
  Intl.defaultLocale = 'ko_KR';
  // 날짜/언어 데이터 초기화 (중요: runApp 전에 await)
  await initializeDateFormatting('ko_KR', null);

  // Firebase 초기화
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => UserProvider()..loadCurrentUser(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'jesus worship team',
      debugShowCheckedModeBanner: false,

      // (선택) Material3 + 톤 설정
      theme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        useMaterial3: true,
      ),

      // 현지화 설정 (중요)
      locale: const Locale('ko', 'KR'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ko', 'KR'),
        Locale('en', 'US'),
      ],

      // 첫 화면은 로그인
      initialRoute: '/login',
      routes: {
        '/login': (_) => const LoginPage(),
        '/signup': (_) => const SignUpPage(),
        '/calendar': (_) => const CalendarPage(),
        '/attendance': (_) => const AttendancePage(),
        '/attendance_check': (_) => const AttendanceCheckPage(), // ← 네가 정한 경로
        '/audio': (_) => const AudioPage(),
        '/video': (_) => const VideoPage(),
      },
    );
  }
}
