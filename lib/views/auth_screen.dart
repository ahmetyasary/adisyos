import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:adisyos/core/errors/auth_exception.dart';
import 'package:adisyos/features/auth/domain/entities/auth_user.dart';
import 'package:adisyos/features/auth/presentation/controller/auth_controller.dart';
import 'package:adisyos/models/app_role.dart';
import 'package:adisyos/themes/app_theme.dart';
import 'package:adisyos/views/home_view.dart';
import 'package:adisyos/views/tables_view.dart';

// ─────────────────────────────────────────────
// AuthScreen
// ─────────────────────────────────────────────

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _obscurePassword = true;
  String? _errorMessage;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    // If a session is already active (e.g. app restart), skip login screen.
    // Wait one frame so the widget tree is ready before navigating.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = AuthController.to;
      if (auth.isAuthenticated) {
        if (auth.currentRole != null) {
          _navigateByRole(auth.currentRole!);
        } else {
          ever(auth.user, (AuthUser? u) {
            if (u != null) _navigateByRole(u.role);
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ── Login ─────────────────────────────────

  Future<void> _onLoginPressed() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _errorMessage = null);

    try {
      final authUser = await AuthController.to.login(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      _navigateByRole(authUser.role);
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.messageKey.tr);
    } on Exception catch (e) {
      setState(() => _errorMessage = _friendlyError(e.toString()));
    }
  }

  void _navigateByRole(AppRole role) {
    if (role == AppRole.admin) {
      Get.offAll(() => const HomeView());
    } else {
      Get.offAll(() => const TablesView());
    }
  }

  String _friendlyError(String raw) {
    if (raw.contains('Invalid login') || raw.contains('invalid_credentials')) {
      return 'auth_error_invalid'.tr;
    }
    if (raw.contains('Email not confirmed')) return 'auth_error_unconfirmed'.tr;
    if (raw.contains('network') || raw.contains('SocketException')) {
      return 'auth_error_network'.tr;
    }
    return 'auth_error_generic'.tr;
  }

  // ── Build ──────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _GradientBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: _LoginCard(
                    formKey: _formKey,
                    emailCtrl: _emailCtrl,
                    passwordCtrl: _passwordCtrl,
                    obscurePassword: _obscurePassword,
                    errorMessage: _errorMessage,
                    onTogglePassword: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    onLoginPressed: _onLoginPressed,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// _GradientBackground
// ─────────────────────────────────────────────

class _GradientBackground extends StatelessWidget {
  const _GradientBackground({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor,
            AppTheme.secondaryColor,
            Color(0xFF1A252F),
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────
// _LoginCard
// ─────────────────────────────────────────────

class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.formKey,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.obscurePassword,
    required this.errorMessage,
    required this.onTogglePassword,
    required this.onLoginPressed,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final bool obscurePassword;
  final String? errorMessage;
  final VoidCallback onTogglePassword;
  final VoidCallback onLoginPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _BrandHeader(),
              const SizedBox(height: 36),
              _AuthTextField(
                controller: emailCtrl,
                label: 'auth_email'.tr,
                hint: 'auth_email_hint'.tr,
                prefixIcon: Icons.alternate_email_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'auth_email_required'.tr;
                  if (!v.contains('@') || !v.contains('.')) return 'auth_email_invalid'.tr;
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _AuthTextField(
                controller: passwordCtrl,
                label: 'auth_password'.tr,
                hint: '••••••••',
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: obscurePassword,
                textInputAction: TextInputAction.done,
                suffixIcon: IconButton(
                  icon: Icon(
                    obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                    color: Colors.grey,
                  ),
                  onPressed: onTogglePassword,
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'auth_password_required'.tr;
                  if (v.length < 6) return 'auth_password_short'.tr;
                  return null;
                },
                onFieldSubmitted: (_) => onLoginPressed(),
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 16),
                _ErrorBanner(message: errorMessage!),
              ],
              const SizedBox(height: 28),
              _LoginButton(onPressed: onLoginPressed),
              const SizedBox(height: 24),
              _Footer(),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// _BrandHeader
// ─────────────────────────────────────────────

class _BrandHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primaryColor, AppTheme.accentColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(
            Icons.receipt_long_rounded,
            color: Colors.white,
            size: 32,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'adisyos',
          style: GoogleFonts.righteous(
            fontSize: 30,
            color: AppTheme.primaryColor,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'auth_subtitle'.tr,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade500,
                letterSpacing: 0.5,
              ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// _AuthTextField
// ─────────────────────────────────────────────

class _AuthTextField extends StatelessWidget {
  const _AuthTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.prefixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.suffixIcon,
    this.validator,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData prefixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final void Function(String)? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      validator: validator,
      onFieldSubmitted: onFieldSubmitted,
      style: Theme.of(context).textTheme.bodyMedium,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400),
        prefixIcon: Icon(prefixIcon, size: 20, color: scheme.primary),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: scheme.primary.withValues(alpha: 0.04),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// _ErrorBanner
// ─────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 18, color: AppTheme.errorColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.errorColor,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// _LoginButton
// ─────────────────────────────────────────────

class _LoginButton extends StatelessWidget {
  const _LoginButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isLoading = AuthController.to.isLoading.value;

      return SizedBox(
        width: double.infinity,
        height: 54,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: isLoading
                ? null
                : const LinearGradient(
                    colors: [AppTheme.primaryColor, AppTheme.accentColor],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
            borderRadius: BorderRadius.circular(14),
            color: isLoading ? Colors.grey.shade300 : null,
          ),
          child: ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                    ),
                  )
                : Text(
                    'auth_login'.tr,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
          ),
        ),
      );
    });
  }
}

// ─────────────────────────────────────────────
// _Footer
// ─────────────────────────────────────────────

class _Footer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text(
      'Adisyos v0.1 (Beta) by Smartlogy',
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Colors.grey.shade400,
          ),
    );
  }
}
