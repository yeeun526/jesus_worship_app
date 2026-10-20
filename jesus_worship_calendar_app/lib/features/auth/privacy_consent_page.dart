import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/firestore_service.dart';
import '../attendance/attendance_check_page.dart';
import '../calendar/calendar_page.dart';
import 'login_page.dart';

const privacyPolicyUrl =
    'https://github.com/yeeun526/jesus_worship_app/blob/main/privacy-policy.html';

class ConsentGate extends StatefulWidget {
  const ConsentGate({super.key});

  @override
  State<ConsentGate> createState() => _ConsentGateState();
}

class _ConsentGateState extends State<ConsentGate> {
  late Future<bool> _consentFuture;

  @override
  void initState() {
    super.initState();
    _consentFuture = _loadConsent();
  }

  Future<bool> _loadConsent() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Future.value(false);
    return FirestoreService().hasAcceptedPrivacyPolicy(user.uid);
  }

  void _retry() {
    setState(() => _consentFuture = _loadConsent());
  }

  @override
  Widget build(BuildContext context) {
    if (FirebaseAuth.instance.currentUser == null) {
      return const LoginPage();
    }

    return FutureBuilder<bool>(
      future: _consentFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ConsentLoadError(onRetry: _retry);
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.data!) return const PrivacyConsentPage();
        return const CalendarPage();
      },
    );
  }
}

class AttendanceConsentGate extends StatefulWidget {
  const AttendanceConsentGate({super.key});

  @override
  State<AttendanceConsentGate> createState() => _AttendanceConsentGateState();
}

class _AttendanceConsentGateState extends State<AttendanceConsentGate> {
  late Future<bool> _consentFuture;

  @override
  void initState() {
    super.initState();
    _consentFuture = _loadConsent();
  }

  Future<bool> _loadConsent() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Future.value(false);
    return FirestoreService().hasSensitiveAttendanceConsent(user.uid);
  }

  void _retry() {
    setState(() => _consentFuture = _loadConsent());
  }

  @override
  Widget build(BuildContext context) {
    if (FirebaseAuth.instance.currentUser == null) {
      return const LoginPage();
    }

    return FutureBuilder<bool>(
      future: _consentFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ConsentLoadError(onRetry: _retry);
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.data!) return const AttendanceConsentRequiredPage();
        return const AttendanceCheckPage();
      },
    );
  }
}

class PrivacyConsentPage extends StatefulWidget {
  const PrivacyConsentPage({super.key});

  @override
  State<PrivacyConsentPage> createState() => _PrivacyConsentPageState();
}

class _PrivacyConsentPageState extends State<PrivacyConsentPage> {
  final _guardianNameController = TextEditingController();
  final _guardianEmailController = TextEditingController();

  String? _ageGroup;
  bool _privacyNoticeAcknowledged = false;
  bool _guardianConsent = false;
  bool _attendanceConsent = false;
  bool _saving = false;
  String? _error;

  bool get _isUnder14 => _ageGroup == 'under14';

  bool get _canSubmit =>
      !_saving &&
      _privacyNoticeAcknowledged &&
      _ageGroup != null &&
      (!_isUnder14 ||
          (_guardianConsent &&
              _guardianNameController.text.trim().isNotEmpty &&
              RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                  .hasMatch(_guardianEmailController.text.trim())));

  @override
  void dispose() {
    _guardianNameController.dispose();
    _guardianEmailController.dispose();
    super.dispose();
  }

  Future<void> _openPolicy() async {
    final uri = Uri.parse(privacyPolicyUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('개인정보 처리방침을 열 수 없습니다.')),
        );
      }
    }
  }

  Future<void> _save() async {
    if (!_canSubmit) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await FirestoreService().savePrivacyConsent(
        uid: user.uid,
        ageGroup: _ageGroup!,
        sensitiveAttendanceConsent: _attendanceConsent,
        guardianName: _isUnder14 ? _guardianNameController.text : null,
        guardianEmail: _isUnder14 ? _guardianEmailController.text : null,
      );
      if (mounted) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/calendar', (_) => false);
      }
    } on FirebaseException catch (e) {
      debugPrint('Failed to save privacy consent: ${e.code} ${e.message}');
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '동의 내용을 저장하지 못했습니다. 네트워크를 확인하고 다시 시도해 주세요.';
        });
      }
    } catch (e, stackTrace) {
      debugPrint('Unexpected error saving privacy consent: $e\n$stackTrace');
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '동의 내용을 저장하지 못했습니다. 다시 시도해 주세요.';
        });
      }
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('개인정보 확인 및 동의'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(onPressed: _signOut, child: const Text('로그아웃')),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              '앱을 이용하기 전에 개인정보 처리 내용을 확인해 주세요.',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            const Text(
              '이름·이메일·역할은 계정과 앱 기능 제공을 위해 처리됩니다. '
              '출석 상태와 결석 사유는 출석 관리 기능에서만 사용되며, '
              '교회 활동을 드러낼 수 있는 정보이므로 별도로 동의를 받습니다.',
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _openPolicy,
                icon: const Icon(Icons.open_in_new),
                label: const Text('개인정보 처리방침 전문 보기'),
              ),
            ),
            CheckboxListTile(
              value: _privacyNoticeAcknowledged,
              onChanged: (value) =>
                  setState(() => _privacyNoticeAcknowledged = value ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('개인정보 처리방침을 확인했습니다 (필수)'),
            ),
            const Divider(height: 32),
            const Text(
              '이용 연령',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            RadioGroup<String>(
              groupValue: _ageGroup,
              onChanged: (value) => setState(() => _ageGroup = value),
              child: const Column(
                children: [
                  RadioListTile<String>(
                    value: '14OrOlder',
                    contentPadding: EdgeInsets.zero,
                    title: Text('만 14세 이상'),
                  ),
                  RadioListTile<String>(
                    value: 'under14',
                    contentPadding: EdgeInsets.zero,
                    title: Text('만 14세 미만'),
                  ),
                ],
              ),
            ),
            if (_isUnder14) ...[
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    '만 14세 미만 이용자는 법정대리인이 직접 내용을 확인하고 '
                    '제출해야 합니다. 보호자에게 기기를 전달해 주세요. '
                    '이 화면의 입력만으로 보호자 신원이 독립적으로 인증되는 것은 아닙니다.',
                  ),
                ),
              ),
              TextField(
                controller: _guardianNameController,
                onChanged: (_) => setState(() {}),
                autofillHints: const [AutofillHints.name],
                decoration: const InputDecoration(
                  labelText: '법정대리인 이름',
                ),
              ),
              TextField(
                controller: _guardianEmailController,
                onChanged: (_) => setState(() {}),
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: '법정대리인 연락 이메일',
                  helperText: '동의 확인이 필요한 경우에만 연락합니다.',
                ),
              ),
              CheckboxListTile(
                value: _guardianConsent,
                onChanged: (value) =>
                    setState(() => _guardianConsent = value ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(
                  '본인은 이 이용자의 법정대리인이며, 개인정보 처리방침을 확인하고 '
                  '만 14세 미만 이용자의 개인정보 처리에 동의합니다.',
                ),
              ),
            ],
            const Divider(height: 32),
            CheckboxListTile(
              value: _attendanceConsent,
              onChanged: (value) =>
                  setState(() => _attendanceConsent = value ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                _isUnder14
                    ? '법정대리인으로서 이 이용자의 출석정보 처리에 별도로 동의합니다 (선택)'
                    : '출석정보 처리에 별도로 동의합니다 (선택)',
              ),
              subtitle: const Text(
                '출석 날짜·상태와 입력한 결석 사유를 출석 관리 목적으로 처리합니다. '
                '동의하지 않아도 일정·음원·영상 기능은 이용할 수 있지만, 출석부는 사용할 수 없습니다.',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _canSubmit ? _save : null,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('확인하고 계속'),
            ),
          ],
        ),
      ),
    );
  }
}

class AttendanceConsentRequiredPage extends StatelessWidget {
  const AttendanceConsentRequiredPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('출석부')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.privacy_tip_outlined, size: 48),
              const SizedBox(height: 16),
              const Text(
                '출석정보 처리에 동의하지 않아 출석부를 사용할 수 없습니다. '
                '일정·음원·영상 기능은 계속 이용할 수 있습니다.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () =>
                    Navigator.of(context).pushNamed('/privacy-consent'),
                child: const Text('동의 설정 변경'),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pushReplacementNamed('/calendar'),
                child: const Text('캘린더로 돌아가기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConsentLoadError extends StatelessWidget {
  const _ConsentLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('동의 상태를 확인하지 못했습니다. 네트워크를 확인해 주세요.'),
              const SizedBox(height: 12),
              FilledButton(onPressed: onRetry, child: const Text('다시 시도')),
            ],
          ),
        ),
      ),
    );
  }
}
