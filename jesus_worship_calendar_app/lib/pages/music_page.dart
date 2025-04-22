import 'package:flutter/material.dart';

class MusicPage extends StatelessWidget {
  const MusicPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('음원 리스트'),
        centerTitle: true,
      ),
      body: const Center(
          // child: Text(
          //   '여기에서 음원 리스트를 확인할 수 있습니다.',
          //   style: TextStyle(fontSize: 20),
          // ),

          ),
    );
  }
}
