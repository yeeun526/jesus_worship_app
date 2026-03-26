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
  final _nameCtrl = TextEditingController();
  String _role = 'student';

  Future<void> signUp() async {
    final email = _emailCtrl.text.trim();
    final pw = _passwordCtrl.text;
    final name = _nameCtrl.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이름을 입력해주세요')),
      );
      return;
    }

    // [결함 1 수정] 이메일 빈값 체크
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이메일을 입력해주세요')),
      );
      return;
    }

    // [결함 3 수정] 정식 도메인 화이트리스트 검증
    const allowedTlds = {
      // 일반 TLD
      'com', 'net', 'org', 'edu', 'gov', 'mil', 'int',
      // 국가 TLD (한국 포함 주요국)
      'kr', 'us', 'uk', 'jp', 'cn', 'de', 'fr', 'au', 'ca', 'in',
      // 복합 도메인 (co.kr 등)
      'co.kr', 'or.kr', 'go.kr', 'ac.kr', 'ne.kr',
      'co.uk', 'co.jp', 'co.au',
      // 기타 주요 TLD
      'io', 'me', 'info', 'biz', 'tv', 'app', 'dev',
    };

    // 이메일에서 @ 뒤 도메인 추출 후 TLD 확인
    final atIndex = email.lastIndexOf('@');
    final domain = email.substring(atIndex + 1).toLowerCase(); // ex) naver.com
    final isValidTld =
        allowedTlds.any((tld) => domain == tld || domain.endsWith('.$tld'));
    // 기본 형식 체크 (로컬파트@도메인 구조)
    final basicRegex = RegExp(r'^[\w.+-]+@[\w.-]+$');

    if (!basicRegex.hasMatch(email) || !isValidTld) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('허용되지 않는 이메일 도메인입니다 (예: user@example.com)'),
        ),
      );
      return;
    }

    // [결함 2 수정] 비밀번호 길이 체크 (서버 요청 전 차단)
    if (pw.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('비밀번호는 최소 6자 이상이어야 합니다')),
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
        name: name,
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
            ),
            TextField(
              controller: _emailCtrl,
              decoration: const InputDecoration(
                labelText: '이메일',
                helperText: '예: user@example.com',
              ),
            ),
            TextField(
              controller: _passwordCtrl,
              decoration: const InputDecoration(
                labelText: '비밀번호',
                helperText: '최소 6자 이상의 비밀번호를 입력하세요',
              ),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            DropdownButton<String>(
              value: _role,
              items: const [
                DropdownMenuItem(value: 'admin', child: Text('임원')),
                DropdownMenuItem(value: 'student', child: Text('학생')),
                DropdownMenuItem(value: 'parent', child: Text('부모')),
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
