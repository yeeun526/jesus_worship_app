import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/services/firestore_service.dart';
import 'change_password_page.dart';
import 'login_page.dart';
import 'privacy_consent_page.dart';

class AuthenticatedGate extends StatefulWidget {
  const AuthenticatedGate({super.key});

  @override
  State<AuthenticatedGate> createState() => _AuthenticatedGateState();
}

class _AuthenticatedGateState extends State<AuthenticatedGate> {
  late final Future<bool> _passwordChangeRequired;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _passwordChangeRequired = user == null
        ? Future.value(false)
        : FirestoreService().requiresPasswordChange(user.uid);
  }

  @override
  Widget build(BuildContext context) {
    if (FirebaseAuth.instance.currentUser == null) {
      return const LoginPage();
    }

    return FutureBuilder<bool>(
      future: _passwordChangeRequired,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('계정 정보를 확인할 수 없습니다: ${snapshot.error}'),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data == true) return const ChangePasswordPage();
        return const ConsentGate();
      },
    );
  }
}
