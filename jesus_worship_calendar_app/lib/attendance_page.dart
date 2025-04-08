import 'package:flutter/material.dart';

class AttendancePage extends StatelessWidget {
  const AttendancePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('출석 체크'),
        centerTitle: true,
      ),
      body: const Center(
        child: Text(
          '출석 페이지입니다',
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}
