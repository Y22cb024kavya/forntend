import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

enum AhviSpeechState { idle, initializing, listening, stopping, error }

abstract interface class AhviSpeechClient {
  bool get isListening;

  Future<bool> ensureReady();

  Future<void> start({
    required ValueChanged<String> onText,
    VoidCallback? onDone,
  });

  Future<void> stop();

  Future<void> cancel();
}

class AhviSpeechService implements AhviSpeechClient {
  AhviSpeechService._();

  static final AhviSpeechService instance = AhviSpeechService._();

  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _initialized = false;
  AhviSpeechState _state = AhviSpeechState.idle;
  VoidCallback? _activeOnDone;

  @override
  bool get isListening => _state == AhviSpeechState.listening;
  AhviSpeechState get state => _state;

  @override
  Future<bool> ensureReady() async {
    if (_initialized) return true;

    if (_state == AhviSpeechState.initializing) {
      while (_state == AhviSpeechState.initializing) {
        await Future<void>.delayed(const Duration(milliseconds: 80));
      }
      return _initialized;
    }

    _state = AhviSpeechState.initializing;

    try {
      final permission = await Permission.microphone.request();

      if (!permission.isGranted) {
        debugPrint('AHVI_STT microphone permission denied');
        _state = AhviSpeechState.error;
        return false;
      }

      _initialized = await _speech.initialize(
        onStatus: (status) {
          debugPrint('AHVI_STT status=$status');

          if (status == 'done' || status == 'notListening') _markDone();
        },
        onError: (error) {
          debugPrint('AHVI_STT error=$error');
          _markDone();
        },
      );

      debugPrint('AHVI_STT initialized=$_initialized');
      _state = _initialized ? AhviSpeechState.idle : AhviSpeechState.error;
      return _initialized;
    } catch (e) {
      debugPrint('AHVI_STT initialize exception=$e');
      _initialized = false;
      _state = AhviSpeechState.error;
      return false;
    } finally {
      if (_state == AhviSpeechState.initializing) {
        _state = _initialized ? AhviSpeechState.idle : AhviSpeechState.error;
      }
    }
  }

  @override
  Future<void> start({
    required ValueChanged<String> onText,
    VoidCallback? onDone,
  }) async {
    if (_state == AhviSpeechState.initializing) {
      while (_state == AhviSpeechState.initializing) {
        await Future<void>.delayed(const Duration(milliseconds: 80));
      }
    }

    if (_state == AhviSpeechState.stopping) return;

    final ready = await ensureReady();
    if (!ready) {
      return;
    }

    if (_state == AhviSpeechState.listening) {
      await stop();
    }

    _state = AhviSpeechState.listening;
    _activeOnDone = onDone;

    try {
      await _speech.listen(
        listenMode: stt.ListenMode.dictation,
        partialResults: true,
        onResult: (result) {
          final text = result.recognizedWords.trim();

          if (text.isNotEmpty) {
            onText(text);
          }

          if (result.finalResult) {
            _markDone();
          }
        },
      );
    } catch (e) {
      debugPrint('AHVI_STT listen exception=$e');
      _state = AhviSpeechState.error;
      _markDone();
    }
  }

  @override
  Future<void> stop() async {
    if (!_initialized) return;
    if (_state == AhviSpeechState.stopping) return;
    _state = AhviSpeechState.stopping;

    try {
      await _speech.stop();
    } catch (e) {
      debugPrint('AHVI_STT stop exception=$e');
    } finally {
      _markDone();
    }
  }

  @override
  Future<void> cancel() async {
    if (!_initialized) return;
    if (_state == AhviSpeechState.stopping) return;
    _state = AhviSpeechState.stopping;

    try {
      await _speech.cancel();
    } catch (e) {
      debugPrint('AHVI_STT cancel exception=$e');
    } finally {
      _markDone();
    }
  }

  void _markDone() {
    final done = _activeOnDone;
    _activeOnDone = null;
    if (_state != AhviSpeechState.error) {
      _state = AhviSpeechState.idle;
    }
    done?.call();
  }
}
