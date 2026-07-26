import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../services/chat_media_cache.dart';
import 'chat_web_audio.dart';

/// Inline chat voice/audio control.
/// Web uses the browser `<audio>` element (reliable with Storage download URLs).
/// Mobile uses just_audio + disk cache.
class ChatInlineAudio extends StatefulWidget {
  const ChatInlineAudio({
    super.key,
    required this.url,
    this.mimeType,
  });

  final String url;
  final String? mimeType;

  @override
  State<ChatInlineAudio> createState() => _ChatInlineAudioState();
}

class _ChatInlineAudioState extends State<ChatInlineAudio> {
  AudioPlayer? _player;
  bool _busy = false;
  bool _playing = false;
  String? _error;

  @override
  void dispose() {
    if (kIsWeb) {
      // Don't stop global web audio if another bubble started — only pause if ours.
      if (_playing) {
        pauseWebAudio();
      }
    }
    _player?.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (kIsWeb) {
        await _toggleWeb();
      } else {
        await _toggleNative();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'failed';
          _playing = false;
        });
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('Could not play audio')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleWeb() async {
    if (_playing) {
      await pauseWebAudio();
      if (mounted) setState(() => _playing = false);
      return;
    }
    await playWebAudio(widget.url);
    if (!mounted) return;
    setState(() => _playing = true);
  }

  Future<void> _toggleNative() async {
    final player = _player ??= AudioPlayer();
    if (!_ready(player)) {
      final info = await ChatMediaCache.instance.getFile(widget.url);
      if (info != null) {
        await player.setFilePath(info.file.path);
      } else {
        await player.setUrl(widget.url);
      }
    }
    if (player.playing) {
      await player.pause();
      if (mounted) setState(() => _playing = false);
    } else {
      await player.play();
      if (mounted) setState(() => _playing = true);
      player.playerStateStream.listen((s) {
        if (!mounted) return;
        setState(() => _playing = s.playing);
      });
    }
  }

  bool _ready(AudioPlayer player) {
    try {
      return player.duration != null || player.processingState != ProcessingState.idle;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = _error != null
        ? Icons.error_outline
        : (_playing ? Icons.pause_circle_filled : Icons.play_circle_filled);

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: _busy ? null : _toggle,
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: _busy
                    ? const Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(icon, size: 36, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.graphic_eq,
                size: 20,
                color: _error != null
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}
