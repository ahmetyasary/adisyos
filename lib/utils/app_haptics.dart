import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:orderix/services/settings_service.dart';

/// Central haptic + sound helpers. Each feedback respects the matching
/// Settings toggle (`Titreşim` / `Ses`) independently.
class AppHaptics {
  AppHaptics._();

  static bool get _hapticsOn {
    if (!Get.isRegistered<SettingsService>()) return true;
    return SettingsService.to.hapticsEnabled.value;
  }

  static bool get _soundsOn {
    if (!Get.isRegistered<SettingsService>()) return true;
    return SettingsService.to.soundsEnabled.value;
  }

  static Future<void> _clickSound() async {
    if (!_soundsOn) return;
    await SystemSound.play(SystemSoundType.click);
  }

  static Future<void> light() async {
    if (_hapticsOn) await HapticFeedback.lightImpact();
    await _clickSound();
  }

  static Future<void> medium() async {
    if (_hapticsOn) await HapticFeedback.mediumImpact();
    await _clickSound();
  }

  static Future<void> selection() async {
    if (_hapticsOn) await HapticFeedback.selectionClick();
    await _clickSound();
  }

  /// Short “happy” pulse after a successful payment (or similar win).
  static Future<void> success() async {
    if (_hapticsOn) await HapticFeedback.lightImpact();
    await _clickSound();
    await Future<void>.delayed(const Duration(milliseconds: 45));
    if (_hapticsOn) await HapticFeedback.mediumImpact();
    await _clickSound();
  }

  /// Preview when turning Ses on in Settings (sound only).
  static Future<void> previewSound() async {
    await SystemSound.play(SystemSoundType.click);
    await Future<void>.delayed(const Duration(milliseconds: 45));
    await SystemSound.play(SystemSoundType.click);
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
    if (_hapticsOn) await HapticFeedback.lightImpact();
    await _clickSound();
  }
}
