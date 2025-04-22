import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // ← 추가

import 'package:provider/provider.dart';
import 'providers/user_provider.dart';

import 'pages/login.dart';
import 'pages/sign_up.dart';
import 'pages/calendar_page.dart';
import 'pages/attendance_page.dart';
import 'pages/audio_page.dart';
import 'pages/video_page.dart';
import 'pages/task_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase 초기화 (firebase_options 사용 시 options: DefaultFirebaseOptions.currentPlatform)
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
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'jesus worship team',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.deepPurple),

      // 첫 화면은 로그인
      initialRoute: '/login',
      routes: {
        '/login': (_) => const LoginPage(),
        '/signup': (_) => const SignUpPage(),
        '/calendar': (_) => const CalendarPage(),
        '/attendance': (_) => const AttendancePage(),
        '/audio': (_) => const AudioPage(),
        '/video': (_) => const VideoPage(),
        '/task': (_) => const TaskPage(),
        // '/event_add' 등 추가 라우트도 여기에…
      },
    );
  }
}
