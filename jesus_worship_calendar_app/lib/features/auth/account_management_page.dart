import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/providers/user_provider.dart';

class AccountManagementPage extends StatelessWidget {
  const AccountManagementPage({super.key});

  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final role = context.watch<UserProvider>().role ?? 'member';

    return Scaffold(
      appBar: AppBar(title: const Text('계정 관리')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: const Text('이메일'),
            subtitle: Text(user?.email ?? '로그인 정보 없음'),
          ),
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: const Text('계정 유형'),
            subtitle: Text(role == 'admin' ? '관리자' : '학생/회원'),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('개인정보 동의 설정'),
            onTap: () => Navigator.pushNamed(context, '/privacy-consent'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('로그아웃'),
            onTap: () => _signOut(context),
          ),
        ],
      ),
    );
  }
}
