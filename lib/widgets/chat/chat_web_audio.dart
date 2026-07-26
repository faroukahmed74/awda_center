import 'chat_web_audio_stub.dart'
    if (dart.library.html) 'chat_web_audio_web.dart' as web_audio;

/// Plays a remote audio URL using the browser Audio element (web only).
Future<void> playWebAudio(String url) => web_audio.playWebAudio(url);

Future<void> pauseWebAudio() => web_audio.pauseWebAudio();

Future<void> stopWebAudio() => web_audio.stopWebAudio();

bool get isWebAudioPlaying => web_audio.isWebAudioPlaying;

Stream<bool> get webAudioPlayingStream => web_audio.webAudioPlayingStream;
