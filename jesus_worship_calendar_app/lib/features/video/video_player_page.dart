import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../core/services/firestore_service.dart';
import '../../core/widgets/permission_widget.dart';

class VideoPlayerPage extends StatefulWidget {
  final String videoUrl;
  final String videoId;
  final String title;

  const VideoPlayerPage({
    super.key,
    required this.videoUrl,
    required this.videoId,
    required this.title,
  });

  @override
  _VideoPlayerPageState createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late VideoPlayerController _controller;
  bool _isPlaying = false;
  final _service = FirestoreService();

  // 배속 관련
  final List<double> _rates =
      List<double>.generate(11, (index) => 0.5 + index / 10);
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

  Future<void> _deleteVideo() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('동영상 삭제'),
        content: Text('“${widget.title}” 동영상을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _service.deleteVideo(widget.videoId, widget.videoUrl);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('동영상 삭제 실패: $error')),
      );
    }
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
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          PermissionWidget(
            requiredRole: 'admin',
            child: IconButton(
              tooltip: '동영상 삭제',
              icon: const Icon(Icons.delete_outline),
              onPressed: _deleteVideo,
            ),
          ),
        ],
      ),
      body: _controller.value.isInitialized
          ? Column(
              children: [
                // 영상 영역 (스크롤 가능)
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: AspectRatio(
                        aspectRatio: _controller.value.aspectRatio,
                        child: VideoPlayer(_controller),
                      ),
                    ),
                  ),
                ),

                // 하단 고정 컨트롤러 영역
                SafeArea(
                  top: false,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 실행바
                        VideoProgressIndicator(
                          _controller,
                          allowScrubbing: true,
                          colors: const VideoProgressColors(
                            playedColor: Colors.blue,
                            bufferedColor: Colors.grey,
                            backgroundColor: Colors.black26,
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                        ),

                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 시간 표시
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDuration(_controller.value.position),
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  Text(
                                    _formatDuration(_controller.value.duration),
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // 재생/일시정지 버튼과 배속 버튼
                              Row(
                                children: [
                                  // 재생/일시정지 버튼
                                  IconButton(
                                    icon: Icon(_isPlaying
                                        ? Icons.pause
                                        : Icons.play_arrow),
                                    onPressed: _togglePlayPause,
                                    iconSize: 36,
                                  ),
                                  const SizedBox(width: 8),

                                  // 배속 버튼들
                                  Expanded(
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: _rates.map((r) {
                                          final selected = (r == _currentRate);
                                          return Padding(
                                            padding:
                                                const EdgeInsets.only(right: 8),
                                            child: ChoiceChip(
                                              label: Text(
                                                _rateLabel(r),
                                                style: TextStyle(
                                                  fontWeight: selected
                                                      ? FontWeight.bold
                                                      : null,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              selected: selected,
                                              onSelected: (_) => _applySpeed(r),
                                              materialTapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                              visualDensity:
                                                  VisualDensity.compact,
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
