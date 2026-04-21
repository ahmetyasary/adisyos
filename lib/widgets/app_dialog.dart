import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Shared design tokens (matches the rest of the app) ────────
const _card           = Colors.white;
const _labelPrimary   = Color(0xFF1C1C1E);
const _labelSecondary = Color(0xFF8E8E93);
const _separator      = Color(0xFFE5E5EA);
const _orange         = Color(0xFFFF9500);
const _red            = Color(0xFFFF3B30);

/// iOS-style modal helpers used across the app. Replaces Material `AlertDialog`
/// so dialogs match the rest of the screens (64×64 icon badge, 20 radius,
/// Poppins title, 50/46 button heights with 14 radius).
class AppDialog {
  AppDialog._();

  /// Confirmation / information dialog with an icon badge, title, message and
  /// 1-2 buttons. Returns `true` if the user confirmed.
  ///
  /// - [destructive] renders the confirm button in iOS red.
  /// - Set [cancelText] to `null` to show an info dialog with only a confirm
  ///   button.
  static Future<bool> confirm({
    required IconData icon,
    required String title,
    required String message,
    required String confirmText,
    Color iconColor = _orange,
    String? cancelText = 'Vazgeç',
    bool destructive = false,
  }) async {
    final result = await Get.dialog<bool>(
      _AppDialogShell(
        child: _ConfirmBody(
          icon: icon,
          iconColor: iconColor,
          title: title,
          message: message,
          confirmText: confirmText,
          cancelText: cancelText,
          destructive: destructive,
        ),
      ),
      barrierDismissible: cancelText != null,
    );
    return result ?? false;
  }

  /// Form dialog — title + caller-provided body + full-width primary button
  /// and a cancel button. The caller owns validation; [onConfirm] should call
  /// `Get.back()` itself when the form is valid.
  static Future<void> form({
    required String title,
    required Widget body,
    required String confirmText,
    required VoidCallback onConfirm,
    String cancelText = 'Vazgeç',
  }) {
    return Get.dialog<void>(
      _AppDialogShell(
        child: _FormBody(
          title: title,
          body: body,
          confirmText: confirmText,
          cancelText: cancelText,
          onConfirm: onConfirm,
        ),
      ),
      barrierDismissible: true,
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Internals
// ──────────────────────────────────────────────────────────────

class _AppDialogShell extends StatelessWidget {
  const _AppDialogShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _card,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: child,
        ),
      ),
    );
  }
}

class _ConfirmBody extends StatelessWidget {
  const _ConfirmBody({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.confirmText,
    required this.cancelText,
    required this.destructive,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final String confirmText;
  final String? cancelText;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final confirmColor = destructive ? _red : _orange;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(icon, size: 32, color: iconColor),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 19,
            fontWeight: FontWeight.w600,
            color: _labelPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            color: _labelSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        if (cancelText != null)
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: OutlinedButton(
                    onPressed: () => Get.back(result: false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _labelPrimary,
                      side: const BorderSide(color: _separator),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      cancelText!,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => Get.back(result: true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: confirmColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      confirmText,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          )
        else
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () => Get.back(result: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: confirmColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                confirmText,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FormBody extends StatelessWidget {
  const _FormBody({
    required this.title,
    required this.body,
    required this.confirmText,
    required this.cancelText,
    required this.onConfirm,
  });

  final String title;
  final Widget body;
  final String confirmText;
  final String cancelText;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 19,
            fontWeight: FontWeight.w600,
            color: _labelPrimary,
          ),
        ),
        const SizedBox(height: 20),
        body,
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 46,
                child: OutlinedButton(
                  onPressed: () => Get.back(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _labelPrimary,
                    side: const BorderSide(color: _separator),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    cancelText,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: onConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _orange,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    confirmText,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// iOS-style bordered text field for use inside `AppDialog.form` bodies.
class AppDialogTextField extends StatelessWidget {
  const AppDialogTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hintText,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.sentences,
    this.keyboardType,
    this.obscureText = false,
    this.maxLength,
  });

  final TextEditingController controller;
  final String label;
  final String? hintText;
  final bool autofocus;
  final TextCapitalization textCapitalization;
  final TextInputType? keyboardType;
  final bool obscureText;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _labelSecondary,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          autofocus: autofocus,
          textCapitalization: textCapitalization,
          keyboardType: keyboardType,
          obscureText: obscureText,
          maxLength: maxLength,
          cursorColor: _orange,
          style: const TextStyle(
            fontSize: 15,
            color: _labelPrimary,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            counterText: '',
            hintStyle: const TextStyle(color: _labelSecondary, fontSize: 14),
            filled: true,
            fillColor: const Color(0xFFF2F2F7),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
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
