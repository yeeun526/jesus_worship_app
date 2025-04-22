// lib/pages/sign_up.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({Key? key}) : super(key: key);
  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  String role = 'member'; // 기본값

  Future<void> signUp() async {
    try {
      // 1) Firebase Auth 회원가입
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );
      final uid = cred.user!.uid;

      // 2) Firestore에 유저 정보 저장
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'email': emailController.text.trim(),
        'role': role,
      });

      // 3) '회원가입 완료되었습니다' 다이얼로그 띄우기
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AlertDialog(
          content: Text('회원가입 완료되었습니다'),
        ),
      );

      // 4) 1초 대기
      await Future.delayed(const Duration(seconds: 1));

      // 5) 다이얼로그 닫고 로그인 페이지로 이동
      Navigator.of(context).pop(); // AlertDialog 닫기
      Navigator.pushReplacementNamed(context, '/login');
    } on FirebaseAuthException catch (e) {
      // 이메일이 이미 사용 중일 때
      if (e.code == 'email-already-in-use') {
        showDialog(
          context: context,
          builder: (_) => const AlertDialog(
            content: Text('이미 가입되어있습니다'),
          ),
        );
      } else {
        // 기타 Auth 에러
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('회원가입 실패: ${e.message}')),
        );
      }
    } catch (e) {
      // 기타 예외
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('회원가입 중 오류 발생: $e')),
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
              controller: emailController,
              decoration: const InputDecoration(labelText: '이메일'),
            ),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: '비밀번호'),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            DropdownButton<String>(
              value: role,
              items: const [
                DropdownMenuItem(value: 'admin', child: Text('임원')),
                DropdownMenuItem(value: 'member', child: Text('일반 회원')),
              ],
              onChanged: (v) => setState(() => role = v!),
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: signUp, child: const Text('회원가입')),
          ],
        ),
      ),
    );
  }
}
