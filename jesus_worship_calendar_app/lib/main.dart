import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';

import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/providers/user_provider.dart';
import 'features/auth/login_page.dart';
import 'features/auth/authenticated_gate.dart';
import 'features/auth/account_management_page.dart';
import 'features/auth/privacy_consent_page.dart';
import 'features/auth/sign_up_page.dart';
import 'features/audio/audio_page.dart';
import 'features/video/video_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Intl.defaultLocale = 'ko_KR';
  await initializeDateFormatting('ko_KR', null);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  runApp(
    ChangeNotifierProvider(
      create: (_) => UserProvider()..loadCurrentUser(),
      child: MyApp(isLoggedIn: isLoggedIn), // isLoggedIn 값을 MyApp에 전달
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;

  const MyApp({Key? key, required this.isLoggedIn}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'jesus worship team',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        useMaterial3: true,
      ),
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
      // isLoggedIn 값에 따라 초기 화면을 결정합니다.
      home: isLoggedIn ? const AuthenticatedGate() : const LoginPage(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/account': (context) => const AccountManagementPage(),
        '/signup': (context) => const SignUpPage(),
        '/calendar': (context) => const AuthenticatedGate(),
        '/privacy-consent': (context) => const PrivacyConsentPage(),
        '/attendance_check': (context) => const AttendanceConsentGate(),
        '/audio': (context) => const AudioPage(),
        '/video': (context) => const VideoPage(),
      },
    );
  }
}
