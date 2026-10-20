import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/user_provider.dart';
import '../../core/services/firestore_service.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  final _service = FirestoreService();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final password = _passwordController.text;
    if (password.length < 8) {
      setState(() => _error = '새 비밀번호는 8자 이상 입력해 주세요.');
      return;
    }
    if (password != _confirmationController.text) {
      setState(() => _error = '비밀번호가 서로 일치하지 않습니다.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _service.completeStudentPasswordChange(password);
      if (!mounted) return;
      await context.read<UserProvider>().loadCurrentUser();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/calendar', (_) => false);
    } catch (error) {
      if (mounted) setState(() => _error = '비밀번호 변경에 실패했습니다: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('비밀번호 변경'),
          automaticallyImplyLeading: false,
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              '관리자가 발급한 임시 비밀번호를 안전하게 사용하려면 '
              '계속하기 전에 새 비밀번호를 설정해 주세요.',
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: '새 비밀번호 (8자 이상)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmationController,
              obscureText: true,
              decoration: const InputDecoration(labelText: '새 비밀번호 확인'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _loading ? null : _changePassword,
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('비밀번호 변경 후 계속'),
            ),
          ],
        ),
      ),
    );
  }
}
