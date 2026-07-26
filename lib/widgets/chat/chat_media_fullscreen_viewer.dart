import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'chat_network_image.dart';

/// Full-screen image / video viewer with pinch-zoom for images.
class ChatMediaFullscreenViewer extends StatefulWidget {
  const ChatMediaFullscreenViewer({
    super.key,
    required this.url,
    this.isVideo = false,
    this.heroTag,
  });

  final String url;
  final bool isVideo;
  final Object? heroTag;

  static Future<void> open(
    BuildContext context, {
    required String url,
    bool isVideo = false,
    Object? heroTag,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (_, __, ___) => ChatMediaFullscreenViewer(
          url: url,
          isVideo: isVideo,
          heroTag: heroTag,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  State<ChatMediaFullscreenViewer> createState() =>
      _ChatMediaFullscreenViewerState();
}

class _ChatMediaFullscreenViewerState extends State<ChatMediaFullscreenViewer> {
  VideoPlayerController? _video;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await c.initialize();
      c.setLooping(true);
      await c.play();
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() {
        _video = c;
        _ready = true;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = widget.isVideo ? _buildVideo() : _buildImage();
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: widget.heroTag != null
              ? Hero(tag: widget.heroTag!, child: body)
              : body,
        ),
      ),
    );
  }

  Widget _buildImage() {
    return InteractiveViewer(
      minScale: 0.8,
      maxScale: 4,
      child: ChatNetworkImage(
        url: widget.url,
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _buildVideo() {
    if (_error != null) {
      return Text(_error!, style: const TextStyle(color: Colors.white70));
    }
    if (!_ready || _video == null) {
      return const CircularProgressIndicator(color: Colors.white);
    }
    final c = _video!;
    return GestureDetector(
      onTap: () {
        if (c.value.isPlaying) {
          c.pause();
        } else {
          c.play();
        }
        setState(() {});
      },
      child: AspectRatio(
        aspectRatio: c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(c),
            if (!c.value.isPlaying)
              const Icon(Icons.play_circle_fill, color: Colors.white70, size: 64),
          ],
        ),
      ),
    );
  }
}
