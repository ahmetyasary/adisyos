import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:orderix/services/settings_service.dart';

/// Central haptic + sound helpers. Each feedback respects the matching
/// Settings toggles / intensity (`Titreşim` / `Ses` / `Bildirim sesi`).
class AppHaptics {
  AppHaptics._();

  static bool get _hapticsOn {
    if (!Get.isRegistered<SettingsService>()) return true;
    return SettingsService.to.hapticsEnabled.value;
  }

  static String get _hapticLevel {
    if (!Get.isRegistered<SettingsService>()) return 'high';
    return SettingsService.to.hapticIntensity.value;
  }

  static bool get _soundsOn {
    if (!Get.isRegistered<SettingsService>()) return true;
    return SettingsService.to.soundsEnabled.value;
  }

  static String get _soundLevel {
    if (!Get.isRegistered<SettingsService>()) return 'high';
    return SettingsService.to.soundIntensity.value;
  }

  static bool get _notifySoundsOn {
    if (!Get.isRegistered<SettingsService>()) return true;
    return SettingsService.to.notifySoundsEnabled.value;
  }

  static String get _notifyLevel {
    if (!Get.isRegistered<SettingsService>()) return 'high';
    return SettingsService.to.notifySoundIntensity.value;
  }

  static Future<void> _clickSound() async {
    if (!_soundsOn) return;
    final count = switch (_soundLevel) {
      'low' => 1,
      'medium' => 2,
      _ => 3,
    };
    for (var i = 0; i < count; i++) {
      await SystemSound.play(SystemSoundType.click);
      if (i < count - 1) {
        await Future<void>.delayed(const Duration(milliseconds: 35));
      }
    }
  }

  static Future<void> _impactSoft() async {
    switch (_hapticLevel) {
      case 'low':
        await HapticFeedback.selectionClick();
      case 'medium':
        await HapticFeedback.lightImpact();
      default:
        await HapticFeedback.mediumImpact();
    }
  }

  static Future<void> _impactMid() async {
    switch (_hapticLevel) {
      case 'low':
        await HapticFeedback.lightImpact();
      case 'medium':
        await HapticFeedback.mediumImpact();
      default:
        await HapticFeedback.heavyImpact();
    }
  }

  static Future<void> _impactStrong() async {
    switch (_hapticLevel) {
      case 'low':
        await HapticFeedback.mediumImpact();
      case 'medium':
        await HapticFeedback.heavyImpact();
      default:
        await HapticFeedback.heavyImpact();
        await Future<void>.delayed(const Duration(milliseconds: 28));
        await HapticFeedback.heavyImpact();
    }
  }

  static Future<void> light() async {
    if (_hapticsOn) await _impactSoft();
    await _clickSound();
  }

  static Future<void> medium() async {
    if (_hapticsOn) await _impactMid();
    await _clickSound();
  }

  static Future<void> selection() async {
    if (_hapticsOn) {
      if (_hapticLevel == 'high') {
        await HapticFeedback.lightImpact();
      } else {
        await HapticFeedback.selectionClick();
      }
    }
    await _clickSound();
  }

  /// Short “happy” pulse after a successful payment (or similar win).
  static Future<void> success() async {
    if (_hapticsOn) await _impactSoft();
    await _clickSound();
    await Future<void>.delayed(const Duration(milliseconds: 40));
    if (_hapticsOn) await _impactMid();
    await _clickSound();
    if (_hapticLevel == 'high') {
      await Future<void>.delayed(const Duration(milliseconds: 55));
      if (_hapticsOn) await _impactStrong();
      await _clickSound();
    }
  }

  /// Preview when turning Ses on / changing intensity in Settings.
  static Future<void> previewSound() async {
    final level = Get.isRegistered<SettingsService>()
        ? SettingsService.to.soundIntensity.value
        : 'high';
    final count = switch (level) {
      'low' => 1,
      'medium' => 2,
      _ => 3,
    };
    for (var i = 0; i < count; i++) {
      await SystemSound.play(SystemSoundType.click);
      if (i < count - 1) {
        await Future<void>.delayed(const Duration(milliseconds: 45));
      }
    }
  }

  /// Preview haptic intensity (settings chip tap).
  static Future<void> previewHaptic() async {
    if (!_hapticsOn) return;
    await _impactMid();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await _impactStrong();
  }

  /// In-app + stronger alert when a digital-menu order arrives.
  static Future<void> orderArrived() async {
    if (_hapticsOn) await _impactStrong();
    await _playNotifySounds();
    if (_hapticLevel == 'high' && _hapticsOn) {
      await Future<void>.delayed(const Duration(milliseconds: 70));
      await _impactMid();
    }
  }

  /// Preview notification sound intensity (settings).
  static Future<void> previewNotifySound() async {
    await _playNotifySounds(force: true);
  }

  static Future<void> _playNotifySounds({bool force = false}) async {
    if (!force && !_notifySoundsOn) return;
    final level = force
        ? (Get.isRegistered<SettingsService>()
            ? SettingsService.to.notifySoundIntensity.value
            : 'high')
        : _notifyLevel;
    final count = switch (level) {
      'low' => 1,
      'medium' => 2,
      _ => 3,
    };
    for (var i = 0; i < count; i++) {
      await SystemSound.play(SystemSoundType.alert);
      if (i < count - 1) {
        await Future<void>.delayed(Duration(milliseconds: 90 + i * 30));
      }
    }
  }

  /// Happy pulse when a business day is started.
  static Future<void> dayStarted() => success();

  /// Soft “tık… tık… tıık” when the day is ended (after confirm).
  static Future<void> dayEnded() async {
    if (_hapticsOn) await HapticFeedback.selectionClick();
    await _clickSound();
    await Future<void>.delayed(const Duration(milliseconds: 55));
    if (_hapticsOn) await HapticFeedback.selectionClick();
    await _clickSound();
    await Future<void>.delayed(const Duration(milliseconds: 95));
    if (_hapticsOn) await _impactSoft();
    await _clickSound();
    if (_hapticLevel == 'high') {
      await Future<void>.delayed(const Duration(milliseconds: 70));
      if (_hapticsOn) await _impactMid();
    }
  }
}
