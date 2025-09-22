// lib/pages/video_player_page.dart

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerPage extends StatefulWidget {
  final String videoUrl;

  const VideoPlayerPage({Key? key, required this.videoUrl}) : super(key: key);

  @override
  _VideoPlayerPageState createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late VideoPlayerController _controller;
  bool _isPlaying = false;

  // 배속 관련
  final List<double> _rates = const [0.5, 0.6, 0.7, 0.8, 0.9, 1.0];
  double _currentRate = 1.0;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.videoUrl)
      ..initialize().then((_) {
        setState(() {});
      });
    _controller.addListener(() {
      setState(() {}); // 실행바와 시간 업데이트
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // 재생/일시정지 토글
  void _togglePlayPause() {
    setState(() {
      if (_isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
      _isPlaying = !_isPlaying;
    });
  }

  // 배속 적용
  Future<void> _applySpeed(double rate) async {
    setState(() => _currentRate = rate);
    await _controller.setPlaybackSpeed(rate);
  }

  String _rateLabel(double r) {
    final s = r.toStringAsFixed(r == 1.0 ? 0 : 1);
    return '${s}x';
  }

  String _formatDuration(Duration position) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(position.inMinutes.remainder(60));
    final seconds = twoDigits(position.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('동영상 재생'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: _controller.value.isInitialized
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  ),
                  // 실행바
                  VideoProgressIndicator(
                    _controller,
                    allowScrubbing: true,
                    colors: const VideoProgressColors(
                      playedColor: Colors.blue,
                      bufferedColor: Colors.grey,
                      backgroundColor: Colors.black26,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // 배속 버튼
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    alignment: WrapAlignment.center,
                    children: _rates.map((r) {
                      final selected = (r == _currentRate);
                      return ChoiceChip(
                        label: Text(
                          _rateLabel(r),
                          style: TextStyle(
                            fontWeight: selected ? FontWeight.bold : null,
                          ),
                        ),
                        selected: selected,
                        onSelected: (_) => _applySpeed(r),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  // 재생/일시정지 버튼
                  IconButton(
                    icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                    onPressed: _togglePlayPause,
                    iconSize: 40,
                  ),
                  Text(
                    '${_formatDuration(_controller.value.position)} / ${_formatDuration(_controller.value.duration)}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}
