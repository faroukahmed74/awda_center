import 'dart:async';

Future<void> playWebAudio(String url) async {
  throw UnsupportedError('Web audio only');
}

Future<void> pauseWebAudio() async {}

Future<void> stopWebAudio() async {}

bool get isWebAudioPlaying => false;

Stream<bool> get webAudioPlayingStream => const Stream<bool>.empty();
