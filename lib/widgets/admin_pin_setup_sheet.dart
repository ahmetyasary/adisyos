import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:orderix/services/settings_service.dart';
import 'package:orderix/themes/app_colors.dart';
import 'package:orderix/widgets/app_toast.dart';

Color get _card => AppColors.card;
Color get _textPrimary => AppColors.textPrimary;
Color get _textSec => AppColors.textSec;
Color get _border => AppColors.border;
const _orange = Color(0xFFFF9500);
const _errorColor = Color(0xFFFF3B30);

/// Forced / optional dialog to create or change the admin PIN.
///
/// Returns `true` when a valid PIN was saved.
Future<bool> showAdminPinSetup({
  bool forced = true,
  bool isCreate = true,
  String? title,
  String? message,
}) async {
  final result = await Get.dialog<bool>(
    PopScope(
      canPop: !forced,
      child: _AdminPinSetupDialog(
        forced: forced,
        isCreate: isCreate,
        title: title,
        message: message,
      ),
    ),
    barrierDismissible: !forced,
  );
  return result == true;
}

class _AdminPinSetupDialog extends StatefulWidget {
  const _AdminPinSetupDialog({
    required this.forced,
    required this.isCreate,
    this.title,
    this.message,
  });

  final bool forced;
  final bool isCreate;
  final String? title;
  final String? message;

  @override
  State<_AdminPinSetupDialog> createState() => _AdminPinSetupDialogState();
}

class _AdminPinSetupDialogState extends State<_AdminPinSetupDialog> {
  final _pinCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _pinCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final pin = _pinCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      setState(() => _error = 'PIN 4 haneli rakam olmalı');
      return;
    }
    if (pin != confirm) {
      setState(() => _error = 'PIN’ler eşleşmiyor');
      return;
    }
    if (pin == '1234') {
      setState(() => _error = '1234 kullanılamaz. Daha güvenli bir PIN seçin.');
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      await SettingsService.to.setAdminPin(pin, mustChange: false);
      if (!mounted) return;
      AppToast.success('Yönetici PIN’i kaydedildi');
      Get.back(result: true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'PIN kaydedilemedi. Tekrar deneyin.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title ??
        (widget.isCreate
            ? 'Yönetici PIN’i Oluştur'
            : 'Yönetici PIN’ini Değiştir');
    final message = widget.message ??
        (widget.isCreate
            ? 'Personel eklendiği için yönetici girişi artık PIN ile korunacak. 4 haneli bir PIN oluşturun.'
            : 'Güvenlik için geçici PIN’i değiştirmeniz gerekiyor.');

    return Dialog(
      backgroundColor: _card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: _orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(CupertinoIcons.lock_shield_fill,
                    size: 30, color: _orange),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: _textSec, height: 1.4),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _pinCtrl,
                autofocus: true,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: TextStyle(color: _textPrimary),
                cursorColor: _orange,
                decoration: InputDecoration(
                  labelText: 'Yeni PIN',
                  counterText: '',
                  labelStyle: TextStyle(color: _textSec),
                  filled: true,
                  fillColor: AppColors.chipBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _orange, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirmCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: TextStyle(color: _textPrimary),
                cursorColor: _orange,
                onSubmitted: (_) => _saving ? null : _save(),
                decoration: InputDecoration(
                  labelText: 'PIN Tekrar',
                  counterText: '',
                  labelStyle: TextStyle(color: _textSec),
                  filled: true,
                  fillColor: AppColors.chipBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _orange, width: 1.5),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _errorColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _orange,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _orange.withValues(alpha: 0.5),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Kaydet',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
              if (!widget.forced) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Get.back(result: false),
                  child: Text('Vazgeç', style: TextStyle(color: _textSec)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
