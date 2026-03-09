// lib/pages/login.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 📌 1. shared_preferences 임포트 추가

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool _loading = false;

  Future<void> login() async {
    setState(() => _loading = true);
    try {
      // 1) Firebase Auth로 로그인
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );
      // 2. 로그인 성공 시 sharedPrefences에 상태 저장
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);

      // 3. UserProvider에 uid/role 로드
      await context.read<UserProvider>().loadCurrentUser();

      // 4. 캘린더 페이지로 이동
      Navigator.of(context).pushReplacementNamed('/calendar');
    } on FirebaseAuthException catch (e) {
      String errorMessage = '로그인에 실패했습니다.';

      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        errorMessage = '이메일 혹은 비밀번호가 틀렸습니다.';
      } else if (e.code == 'invalid-email') {
        errorMessage = '유효하지 않은 이메일 형식입니다.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    } catch (e) {
      // 개발 시점에 디버그 콘솔에서 확인하기 위해 출력 (사용자에겐 안 보임)
      debugPrint('Login Error Detail: $e');

      // 사용자에게는 정제된 메시지 노출
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('일시적인 오류가 발생했습니다. 다시 시도해주세요.')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('로그인')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: '이메일'),
            ),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: '비밀번호'),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            _loading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: login,
                    child: const Text('로그인'),
                  ),
            TextButton(
              onPressed: () => Navigator.of(context).pushNamed('/signup'),
              child: const Text('회원가입하기'),
            ),
          ],
        ),
      ),
    );
  }
}
