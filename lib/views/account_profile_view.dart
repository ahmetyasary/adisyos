import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:orderix/core/errors/auth_exception.dart';
import 'package:orderix/features/auth/presentation/controller/auth_controller.dart';
import 'package:orderix/services/settings_service.dart';
import 'package:orderix/themes/app_colors.dart';
import 'package:orderix/widgets/app_toast.dart';
import 'package:orderix/widgets/responsive_content.dart';

Color get _bg => AppColors.bg;
Color get _card => AppColors.card;
Color get _textPrimary => AppColors.textPrimary;
Color get _textSec => AppColors.textSec;
Color get _border => AppColors.border;
const _orange = Color(0xFFFF9500);

Future<void> openAccountProfile(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const AccountProfileView()),
  );
}

class AccountProfileView extends StatefulWidget {
  const AccountProfileView({super.key});

  @override
  State<AccountProfileView> createState() => _AccountProfileViewState();
}

class _AccountProfileViewState extends State<AccountProfileView> {
  late final TextEditingController _nameCtrl;
  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _currentPinCtrl = TextEditingController();
  final _newPinCtrl = TextEditingController();
  final _confirmPinCtrl = TextEditingController();

  bool _savingProfile = false;
  bool _savingPassword = false;
  bool _savingPin = false;
  bool _uploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
      text: SettingsService.to.profileDisplayName.value,
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    _currentPinCtrl.dispose();
    _newPinCtrl.dispose();
    _confirmPinCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (file == null) return;
      setState(() => _uploadingAvatar = true);
      final bytes = await file.readAsBytes();
      final url = await SettingsService.to.uploadProfileAvatar(bytes);
      if (!mounted) return;
      if (url == null) {
        AppToast.error('Fotoğraf yüklenemedi');
      } else {
        AppToast.success('Profil fotoğrafı güncellendi');
      }
    } catch (e) {
      AppToast.error('Fotoğraf seçilemedi');
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _savingProfile = true);
    try {
      await SettingsService.to.setProfileDisplayName(_nameCtrl.text);
      AppToast.success('Profil kaydedildi');
    } catch (_) {
      AppToast.error('Profil kaydedilemedi');
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _savePassword() async {
    final current = _currentPassCtrl.text;
    final next = _newPassCtrl.text;
    final confirm = _confirmPassCtrl.text;
    if (current.isEmpty || next.isEmpty) {
      AppToast.warning('Mevcut ve yeni şifreyi girin');
      return;
    }
    if (next.length < 6) {
      AppToast.warning('Yeni şifre en az 6 karakter olmalı');
      return;
    }
    if (next != confirm) {
      AppToast.warning('Yeni şifreler eşleşmiyor');
      return;
    }
    setState(() => _savingPassword = true);
    try {
      await AuthController.to.changeLoginPassword(
        currentPassword: current,
        newPassword: next,
      );
      _currentPassCtrl.clear();
      _newPassCtrl.clear();
      _confirmPassCtrl.clear();
      AppToast.success('Giriş şifresi güncellendi');
    } on AuthException catch (e) {
      AppToast.error(e.messageKey.tr);
    } catch (_) {
      AppToast.error('Şifre güncellenemedi');
    } finally {
      if (mounted) setState(() => _savingPassword = false);
    }
  }

  Future<void> _saveAdminPin() async {
    final settings = SettingsService.to;
    final next = _newPinCtrl.text.trim();
    final confirm = _confirmPinCtrl.text.trim();
    if (!RegExp(r'^\d{4}$').hasMatch(next)) {
      AppToast.warning('PIN 4 haneli rakam olmalı');
      return;
    }
    if (next != confirm) {
      AppToast.warning('PIN’ler eşleşmiyor');
      return;
    }
    if (next == '1234') {
      AppToast.warning('1234 kullanılamaz. Daha güvenli bir PIN seçin.');
      return;
    }
    if (settings.hasAdminPin) {
      final current = _currentPinCtrl.text.trim();
      if (!settings.verifyAdminPin(current)) {
        AppToast.error('Mevcut yönetici PIN’i hatalı');
        return;
      }
    }
    setState(() => _savingPin = true);
    try {
      await settings.setAdminPin(next, mustChange: false);
      _currentPinCtrl.clear();
      _newPinCtrl.clear();
      _confirmPinCtrl.clear();
      AppToast.success('Yönetici PIN’i güncellendi');
    } catch (_) {
      AppToast.error('PIN kaydedilemedi');
    } finally {
      if (mounted) setState(() => _savingPin = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final email = AuthController.to.user.value?.email ?? '';

    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.only(top: top, left: 4, right: 8),
            decoration: BoxDecoration(
              color: _card,
              border: Border(bottom: BorderSide(color: _border)),
            ),
            child: SizedBox(
              height: 52,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(CupertinoIcons.back, color: _textPrimary),
                  ),
                  Expanded(
                    child: Text(
                      'Hesap Profili',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              children: [
                ResponsiveContent(
                  width: ContentWidth.form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ProfileCard(
                        email: email,
                        uploading: _uploadingAvatar,
                        onPickAvatar: _pickAvatar,
                      ),
                      const SizedBox(height: 20),
                      _SectionCard(
                        title: 'Profil',
                        child: Column(
                          children: [
                            _LabeledField(
                              label: 'İsim',
                              controller: _nameCtrl,
                              hint: 'Görünen ad',
                              textCapitalization: TextCapitalization.words,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              email,
                              style: TextStyle(fontSize: 12, color: _textSec),
                            ),
                            const SizedBox(height: 16),
                            _PrimaryButton(
                              label: 'Profili Kaydet',
                              loading: _savingProfile,
                              onPressed: _saveProfile,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SectionCard(
                        title: 'Ana Giriş Şifresi',
                        subtitle: 'E-posta ile giriş yaptığınız hesap şifresi',
                        child: Column(
                          children: [
                            _LabeledField(
                              label: 'Mevcut şifre',
                              controller: _currentPassCtrl,
                              obscure: true,
                            ),
                            const SizedBox(height: 12),
                            _LabeledField(
                              label: 'Yeni şifre',
                              controller: _newPassCtrl,
                              obscure: true,
                            ),
                            const SizedBox(height: 12),
                            _LabeledField(
                              label: 'Yeni şifre tekrar',
                              controller: _confirmPassCtrl,
                              obscure: true,
                            ),
                            const SizedBox(height: 16),
                            _PrimaryButton(
                              label: 'Şifreyi Güncelle',
                              loading: _savingPassword,
                              onPressed: _savePassword,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SectionCard(
                        title: 'Yönetici PIN’i',
                        subtitle:
                            'Personel ekranından yöneticiyi ayıran iç şifre',
                        child: Column(
                          children: [
                            if (SettingsService.to.hasAdminPin) ...[
                              _LabeledField(
                                label: 'Mevcut PIN',
                                controller: _currentPinCtrl,
                                obscure: true,
                                keyboardType: TextInputType.number,
                                maxLength: 4,
                                digitsOnly: true,
                              ),
                              const SizedBox(height: 12),
                            ],
                            _LabeledField(
                              label: 'Yeni PIN',
                              controller: _newPinCtrl,
                              obscure: true,
                              keyboardType: TextInputType.number,
                              maxLength: 4,
                              digitsOnly: true,
                            ),
                            const SizedBox(height: 12),
                            _LabeledField(
                              label: 'Yeni PIN tekrar',
                              controller: _confirmPinCtrl,
                              obscure: true,
                              keyboardType: TextInputType.number,
                              maxLength: 4,
                              digitsOnly: true,
                            ),
                            const SizedBox(height: 16),
                            _PrimaryButton(
                              label: SettingsService.to.hasAdminPin
                                  ? 'PIN’i Güncelle'
                                  : 'PIN Oluştur',
                              loading: _savingPin,
                              onPressed: _saveAdminPin,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.email,
    required this.uploading,
    required this.onPickAvatar,
  });

  final String email;
  final bool uploading;
  final VoidCallback onPickAvatar;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final name = SettingsService.to.profileLabelFor(email);
      final avatarUrl = SettingsService.to.profileAvatarUrl.value;
      final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: uploading ? null : onPickAvatar,
              child: Stack(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: avatarUrl.isEmpty
                          ? const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFFFFB340), Color(0xFFFF9500)],
                            )
                          : null,
                      image: avatarUrl.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(avatarUrl),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: avatarUrl.isEmpty
                        ? Center(
                            child: Text(
                              initial,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 28,
                              ),
                            ),
                          )
                        : null,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: _orange,
                        shape: BoxShape.circle,
                        border: Border.all(color: _card, width: 2),
                      ),
                      child: uploading
                          ? const Padding(
                              padding: EdgeInsets.all(5),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(CupertinoIcons.camera_fill,
                              size: 13, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Fotoğrafa dokunarak değiştirin',
                    style: TextStyle(fontSize: 12, color: _textSec),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: TextStyle(fontSize: 12, color: _textSec)),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.maxLength,
    this.digitsOnly = false,
    this.textCapitalization = TextCapitalization.none,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final int? maxLength;
  final bool digitsOnly;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _textSec,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          maxLength: maxLength,
          textCapitalization: textCapitalization,
          inputFormatters:
              digitsOnly ? [FilteringTextInputFormatter.digitsOnly] : null,
          style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w500),
          cursorColor: _orange,
          decoration: InputDecoration(
            hintText: hint,
            counterText: '',
            hintStyle: TextStyle(color: _textSec),
            filled: true,
            fillColor: AppColors.chipBg,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _orange,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _orange.withValues(alpha: 0.5),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}
