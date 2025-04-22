import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({Key? key}) : super(key: key);
  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController(); // ← 추가
  String _role = 'member';

  Future<void> signUp() async {
    final email = _emailCtrl.text.trim();
    final pw = _passwordCtrl.text;
    final name = _nameCtrl.text.trim(); // ← 추가

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이름을 입력해주세요')),
      );
      return;
    }

    try {
      // 1) Firebase Auth 회원가입
      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: pw);
      final uid = cred.user!.uid;

      // 2) Firestore에 유저 정보 저장 (이름 포함)
      await FirestoreService().createUserRecord(
        uid: uid,
        email: email,
        role: _role,
        name: name, // ← 추가
      );

      // 3) 성공 알림 & 1초 뒤 로그인 페이지로
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AlertDialog(content: Text('회원가입 완료되었습니다')),
      );
      await Future.delayed(const Duration(seconds: 1));
      Navigator.of(context).pop(); // 다이얼로그 닫기
      Navigator.pushReplacementNamed(context, '/login');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        showDialog(
          context: context,
          builder: (_) => const AlertDialog(content: Text('이미 가입되어있습니다')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('회원가입 실패: ${e.message}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류 발생: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('회원가입')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: '이름'),
            ), // ← 추가
            TextField(
              controller: _emailCtrl,
              decoration: const InputDecoration(labelText: '이메일'),
            ),
            TextField(
              controller: _passwordCtrl,
              decoration: const InputDecoration(labelText: '비밀번호'),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            DropdownButton<String>(
              value: _role,
              items: const [
                DropdownMenuItem(value: 'admin', child: Text('임원')),
                DropdownMenuItem(value: 'member', child: Text('일반 회원')),
              ],
              onChanged: (v) => setState(() => _role = v!),
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: signUp, child: const Text('회원가입')),
          ],
        ),
      ),
    );
  }
}
