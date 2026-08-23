import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:get/get.dart';
import 'package:orderix/features/ordi/data/ordi_actions.dart';
import 'package:orderix/services/settings_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Hold-to-talk STT + Turkish TTS for Ordi.
class OrdiVoiceService extends GetxService {
  static OrdiVoiceService get to => Get.find();

  final SpeechToText _stt = SpeechToText();
  final FlutterTts _tts = FlutterTts();

  final RxBool isListening = false.obs;
  final RxBool isSpeaking = false.obs;
  final RxBool isAvailable = false.obs;
  final RxString partialText = ''.obs;

  bool _sttReady = false;
  String _finalText = '';

  Future<OrdiVoiceService> init() async {
    if (kIsWeb) {
      // Mic STT / TTS plugins are limited on web; keep service registered but off.
      isAvailable.value = false;
      return this;
    }
    try {
      await _configureTts();
      _sttReady = await _stt.initialize(
        onError: (e) {
          if (kDebugMode) print('[OrdiVoice] STT error: $e');
          isListening.value = false;
        },
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            isListening.value = false;
          }
        },
      );
      isAvailable.value = _sttReady;
    } catch (e) {
      if (kDebugMode) print('[OrdiVoice] init: $e');
      isAvailable.value = false;
    }
    return this;
  }

  Future<void> _configureTts() async {
    await _tts.setLanguage('tr-TR');
    await _tts.setSpeechRate(0.48);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _tts.setStartHandler(() => isSpeaking.value = true);
    _tts.setCompletionHandler(() => isSpeaking.value = false);
    _tts.setCancelHandler(() => isSpeaking.value = false);
    _tts.setErrorHandler((msg) {
      if (kDebugMode) print('[OrdiVoice] TTS error: $msg');
      isSpeaking.value = false;
    });
  }

  Future<bool> ensureMicPermission() async {
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) return false;
    // iOS speech recognition is a separate permission; request best-effort.
    try {
      await Permission.speech.request();
    } catch (_) {}
    if (!_sttReady) {
      _sttReady = await _stt.initialize();
      isAvailable.value = _sttReady;
    }
    return _sttReady;
  }

  /// Picks the best on-device Turkish locale, or null if none is installed.
  Future<String?> _turkishLocaleId() async {
    final locales = await _stt.locales();
    if (locales.isEmpty) return null;

    String? exact;
    String? anyTr;
    for (final l in locales) {
      final id = l.localeId;
      final lower = id.toLowerCase().replaceAll('-', '_');
      if (lower == 'tr_tr') {
        exact = id;
        break;
      }
      if (anyTr == null && lower.startsWith('tr')) {
        anyTr = id;
      }
    }
    return exact ?? anyTr;
  }

  /// Starts listening until [stopListening] / [cancelListening].
  /// Returns false if mic/STT unavailable. [onLocaleMissing] fires when the
  /// device has no Turkish speech locale installed.
  Future<bool> startListening({
    void Function(String text)? onPartial,
    void Function()? onLocaleMissing,
  }) async {
    if (isListening.value) return true;
    final ok = await ensureMicPermission();
    if (!ok) return false;

    await stopSpeaking();
    _finalText = '';
    partialText.value = '';
    isListening.value = true;

    final localeId = await _turkishLocaleId();
    if (localeId == null) {
      onLocaleMissing?.call();
      if (kDebugMode) {
        print('[OrdiVoice] No Turkish STT locale on device');
      }
    } else if (kDebugMode) {
      print('[OrdiVoice] STT locale: $localeId');
    }

    await _stt.listen(
      onResult: (result) {
        final words = result.recognizedWords.trim();
        partialText.value = words;
        onPartial?.call(words);
        if (result.finalResult) {
          _finalText = words;
        }
      },
      listenOptions: SpeechListenOptions(
        localeId: localeId ?? 'tr_TR',
        listenMode: ListenMode.dictation,
        partialResults: true,
        cancelOnError: true,
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 8),
      ),
    );
    return true;
  }

  /// Stops listening and returns the best transcript so far.
  Future<String> stopListening() async {
    if (_stt.isListening) {
      await _stt.stop();
    }
    isListening.value = false;
    final text =
        (_finalText.isNotEmpty ? _finalText : partialText.value).trim();
    partialText.value = '';
    _finalText = '';
    return text;
  }

  Future<void> cancelListening() async {
    if (_stt.isListening) {
      await _stt.cancel();
    }
    isListening.value = false;
    partialText.value = '';
    _finalText = '';
  }

  /// Speaks [text] in Turkish. Strips light markdown for cleaner speech.
  /// Respects Settings → Ordi cevap sesi / ses yüksekliği.
  Future<void> speak(String text) async {
    if (Get.isRegistered<SettingsService>() &&
        !SettingsService.to.ordiTtsEnabled.value) {
      return;
    }
    final cleaned = _forSpeech(text);
    if (cleaned.isEmpty) return;
    await stopSpeaking();
    try {
      await _applyTtsVolume();
      await _tts.speak(cleaned);
    } catch (e) {
      if (kDebugMode) print('[OrdiVoice] speak: $e');
      isSpeaking.value = false;
    }
  }

  Future<void> _applyTtsVolume() async {
    final level = Get.isRegistered<SettingsService>()
        ? SettingsService.to.ordiTtsVolumeLevel
        : 1.0;
    await _tts.setVolume(level);
  }

  /// Short preview when changing volume in Settings.
  Future<void> previewVoice() async {
    if (Get.isRegistered<SettingsService>() &&
        !SettingsService.to.ordiTtsEnabled.value) {
      return;
    }
    await stopSpeaking();
    try {
      await _applyTtsVolume();
      await _tts.speak('Merhaba, ben Ordi.');
    } catch (e) {
      if (kDebugMode) print('[OrdiVoice] preview: $e');
      isSpeaking.value = false;
    }
  }

  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
    } catch (_) {}
    isSpeaking.value = false;
  }

  static String _forSpeech(String raw) {
    var t = OrdiActionRunner.stripLeakedToolText(raw);
    t = t.replaceAll(RegExp(r'\*\*(.+?)\*\*', dotAll: true), r'$1');
    t = t.replaceAll(RegExp(r'`([^`]*)`'), r'$1');
    t = t.replaceAll(RegExp(r'^\s*[-*•]\s+', multiLine: true), '');
    t = t.replaceAll(RegExp(r'\n{2,}'), '. ');
    t = t.replaceAll('\n', ' ');
    return t.trim();
  }

  @override
  void onClose() {
    unawaited(cancelListening());
    unawaited(stopSpeaking());
    super.onClose();
  }
}
