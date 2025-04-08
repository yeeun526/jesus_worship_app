import 'package:flutter/material.dart';

class VideoPage extends StatelessWidget {
  const VideoPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('영상 업로드'),
        centerTitle: true,
      ),
      body: const Center(
        child: Text(
          '여기에서 영상 업로드 기능이 들어갑니다.',
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}
