import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
        centerTitle: true,
      ),
      body: const Center(
        child: Text(
          '여기에서 앱 설정을 할 수 있습니다.',
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}
