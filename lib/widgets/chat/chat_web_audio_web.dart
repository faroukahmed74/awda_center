import 'dart:async';
import 'dart:html' as html;

html.AudioElement? _el;
final _playing = StreamController<bool>.broadcast();

Future<void> playWebAudio(String url) async {
  await stopWebAudio();

  // Do NOT set crossOrigin — browser <audio> can play Firebase download URLs
  // without CORS; anonymous CORS mode often blocks playback.
  final el = html.AudioElement(url)
    ..preload = 'auto'
    ..controls = false;
  _el = el;
  html.document.body?.append(el);
  el.style
    ..display = 'none'
    ..position = 'fixed'
    ..left = '-9999px';

  final ready = Completer<void>();
  late final StreamSubscription<html.Event> subCan;
  late final StreamSubscription<html.Event> subData;
  late final StreamSubscription<html.Event> subErr;

  void completeOk([_]) {
    if (!ready.isCompleted) ready.complete();
  }

  void completeErr([_]) {
    if (!ready.isCompleted) {
      ready.completeError(StateError('audio_load_failed'));
    }
  }

  subCan = el.onCanPlay.listen(completeOk);
  subData = el.onLoadedData.listen(completeOk);
  subErr = el.onError.listen(completeErr);

  el.load();

  try {
    await ready.future.timeout(const Duration(seconds: 8));
  } on TimeoutException {
    // Some browsers never fire canplay for Storage URLs — still try play().
  } finally {
    await subCan.cancel();
    await subData.cancel();
    await subErr.cancel();
  }

  try {
    await el.play();
  } catch (e) {
    el.remove();
    if (identical(_el, el)) _el = null;
    rethrow;
  }

  _playing.add(true);
  el.onEnded.listen((_) {
    _playing.add(false);
    el.remove();
    if (identical(_el, el)) _el = null;
  });
  el.onPause.listen((_) {
    if (el.ended) return;
    _playing.add(false);
  });
  el.onPlay.listen((_) => _playing.add(true));
}

Future<void> pauseWebAudio() async {
  _el?.pause();
  _playing.add(false);
}

Future<void> stopWebAudio() async {
  final el = _el;
  _el = null;
  if (el == null) return;
  try {
    el.pause();
    el.removeAttribute('src');
    el.load();
  } catch (_) {}
  el.remove();
  _playing.add(false);
}

bool get isWebAudioPlaying => !(_el?.paused ?? true);

Stream<bool> get webAudioPlayingStream => _playing.stream;
