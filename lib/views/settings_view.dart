import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adisyos/themes/app_theme.dart';

// ── Design tokens ──────────────────────────────────────────
const _bg          = Color(0xFFF5F6FA);
const _card        = Colors.white;
const _orange      = Color(0xFFF5A623);
const _textPrimary = Color(0xFF1A1A2E);
const _textSec     = Color(0xFF9B9B9B);
const _border      = Color(0xFFEEEEEE);

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  String _selectedLanguage = 'tr';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _companyNameController.text = prefs.getString('companyName') ?? '';
        _discountController.text = prefs.getString('discountRate') ?? '';
        _selectedLanguage =
            prefs.getString('language') ?? (Get.locale?.languageCode ?? 'tr');
        _loading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('companyName', _companyNameController.text.trim());
    await prefs.setString('discountRate', _discountController.text.trim());
    await prefs.setString('language', _selectedLanguage);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(
          child: CircularProgressIndicator(color: _orange),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Page header ──────────────────────────────
            Container(
              height: 60,
              decoration: BoxDecoration(
                color: _card,
                border: const Border(bottom: BorderSide(color: _border)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0D000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 18, color: _textPrimary),
                    onPressed: () => Get.back(),
                  ),
                  Text(
                    'settings'.tr,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 8),
                ],
              ),
            ),

            // ── Content ──────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SectionLabel(label: 'İşletme'),
                    const SizedBox(height: 10),
                    _SettingsCard(
                      children: [
                        _FieldRow(
                          label: 'company_name'.tr,
                          icon: Icons.store_rounded,
                          child: _StyledTextField(
                            controller: _companyNameController,
                            hint: 'company_name_hint'.tr,
                            textCapitalization: TextCapitalization.words,
                          ),
                        ),
                        _Divider(),
                        _FieldRow(
                          label: 'default_discount_rate'.tr,
                          icon: Icons.percent_rounded,
                          child: _StyledTextField(
                            controller: _discountController,
                            hint: 'default_discount_hint'.tr,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            suffixText: '%',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _SectionLabel(label: 'Dil'),
                    const SizedBox(height: 10),
                    _SettingsCard(
                      children: [
                        _FieldRow(
                          label: 'language'.tr,
                          icon: Icons.language_rounded,
                          child: _StyledDropdown(
                            value: _selectedLanguage,
                            items: const [
                              DropdownMenuItem(
                                  value: 'tr', child: Text('Türkçe')),
                              DropdownMenuItem(
                                  value: 'en', child: Text('English')),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _selectedLanguage = value);
                                if (value == 'tr') {
                                  Get.updateLocale(const Locale('tr', 'TR'));
                                } else {
                                  Get.updateLocale(const Locale('en', 'US'));
                                }
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Save button
                    SizedBox(
                      height: 52,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_orange, Color(0xFFFF8C00)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x44F5A623),
                              blurRadius: 16,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () async {
                            await _saveSettings();
                            if (context.mounted) {
                              Get.snackbar(
                                'success'.tr,
                                'Ayarlar kaydedildi',
                                snackPosition: SnackPosition.BOTTOM,
                                backgroundColor: AppTheme.successColor,
                                colorText: Colors.white,
                              );
                              Get.back();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            'save_settings'.tr,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: _textSec,
        letterSpacing: 1,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
          BoxShadow(
            color: Color(0x07000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
          BoxShadow(
            color: Colors.white,
            blurRadius: 0,
            offset: Offset(0, -1),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.label,
    required this.icon,
    required this.child,
  });
  final String label;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: _orange),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _textSec,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, color: _border, indent: 16, endIndent: 16);
  }
}

class _StyledTextField extends StatelessWidget {
  const _StyledTextField({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.suffixText,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final String? suffixText;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: _textPrimary,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _textSec, fontSize: 13),
        suffixText: suffixText,
        suffixStyle: const TextStyle(color: _textSec),
        filled: true,
        fillColor: _bg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _orange, width: 1.5),
        ),
      ),
    );
  }
}

class _StyledDropdown extends StatelessWidget {
  const _StyledDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String value;
  final List<DropdownMenuItem<String>> items;
  final void Function(String?) onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items,
      onChanged: onChanged,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: _textPrimary,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: _bg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _orange, width: 1.5),
        ),
      ),
    );
  }
}
