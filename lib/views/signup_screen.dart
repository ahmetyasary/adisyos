import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:orderix/core/errors/auth_exception.dart';
import 'package:orderix/features/auth/presentation/controller/auth_controller.dart';
import 'package:orderix/guards/auth_middleware.dart';
import 'package:orderix/views/pin_screen.dart';
import 'package:orderix/utils/app_info.dart';

const _privacyUrl = 'https://orderix.tr/privacy';
const _termsUrl   = 'https://orderix.tr/termsofuse';

// ── Design tokens — identical to AuthScreen ───────────────────
const _bg          = Color(0xFFF2F2F7);
const _card        = Colors.white;
const _orange      = Color(0xFFFF9500);
const _textPrimary = Color(0xFF1C1C1E);
const _textSec     = Color(0xFF8E8E93);
const _border      = Color(0xFFE5E5EA);
const _error       = Color(0xFFFF3B30);
const _success     = Color(0xFF34C759);

// ─────────────────────────────────────────────────────────────
// SignUpScreen
// ─────────────────────────────────────────────────────────────

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen>
    with SingleTickerProviderStateMixin {
  final _formKey           = GlobalKey<FormState>();
  final _emailCtrl         = TextEditingController();
  final _passwordCtrl      = TextEditingController();
  final _confirmPassCtrl   = TextEditingController();

  bool    _obscurePassword        = true;
  bool    _obscureConfirmPassword = true;
  String? _errorMessage;
  bool    _needsEmailConfirmation = false;

  late final AnimationController _fadeCtrl;
  late final Animation<double>   _fadeAnim;
  late final Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    _fadeAnim  = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end:   Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  // ── Sign Up ────────────────────────────────────────────────

  Future<void> _onSignUpPressed() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _errorMessage = null);

    try {
      final needsConfirmation = await AuthController.to.signUp(
        email:    _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );

      if (!mounted) return;

      if (needsConfirmation) {
        // Email confirmation required — show success state in place.
        setState(() => _needsEmailConfirmation = true);
      } else {
        // No confirmation required — user is registered and has a session.
        // Login to hydrate the AuthController state, then proceed.
        await AuthController.to.login(
          email:    _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
        if (!mounted) return;
        Get.offAll(() => const PinScreen());
      }
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.messageKey.tr);
    } on Exception catch (e) {
      setState(() => _errorMessage = _friendlyError(e.toString()));
    }
  }

  String _friendlyError(String raw) {
    if (raw.contains('already registered') || raw.contains('already in use')) {
      return 'auth_error_email_taken'.tr;
    }
    if (raw.contains('network') || raw.contains('SocketException')) {
      return 'auth_error_network'.tr;
    }
    return 'auth_error_generic'.tr;
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          const _Decorations(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 40),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: AutofillGroup(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _BrandHero(),
                            const SizedBox(height: 32),

                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 400),
                              switchInCurve:  Curves.easeOut,
                              switchOutCurve: Curves.easeIn,
                              transitionBuilder: (child, animation) =>
                                  FadeTransition(opacity: animation, child: child),
                              child: _needsEmailConfirmation
                                  ? _SuccessCard(
                                      key: const ValueKey('success'),
                                      onBackToLogin: () =>
                                          Get.offAllNamed(AppRoutes.login),
                                    )
                                  : _SignUpCard(
                                      key: const ValueKey('form'),
                                      formKey:              _formKey,
                                      emailCtrl:            _emailCtrl,
                                      passwordCtrl:         _passwordCtrl,
                                      confirmPassCtrl:      _confirmPassCtrl,
                                      obscurePassword:      _obscurePassword,
                                      obscureConfirmPass:   _obscureConfirmPassword,
                                      errorMessage:         _errorMessage,
                                      onTogglePassword: () => setState(
                                          () => _obscurePassword = !_obscurePassword),
                                      onToggleConfirmPass: () => setState(
                                          () => _obscureConfirmPassword =
                                              !_obscureConfirmPassword),
                                      onSignUpPressed:   _onSignUpPressed,
                                    ),
                            ),

                            const SizedBox(height: 20),
                            if (!_needsEmailConfirmation) _LoginLink(),

                            const SizedBox(height: 28),
                            _BottomFooter(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Back button (top-left)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(left: 12, top: 8),
              child: _BackButton(onTap: () => Get.back()),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _BackButton — subtle circular back button
// ─────────────────────────────────────────────────────────────

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width:  44,
          height: 44,
          decoration: BoxDecoration(
            color: _card,
            shape: BoxShape.circle,
            border: Border.all(color: _border),
            boxShadow: const [
              BoxShadow(
                color:      Color(0x0A000000),
                blurRadius: 10,
                offset:     Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size:  18,
            color: _textPrimary,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _Decorations — same background blobs as AuthScreen
// ─────────────────────────────────────────────────────────────

class _Decorations extends StatelessWidget {
  const _Decorations();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Stack(
      children: [
        Positioned(
          top:   -size.height * 0.10,
          right: -size.width  * 0.22,
          child: Container(
            width:  size.width  * 0.65,
            height: size.width  * 0.65,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _orange.withValues(alpha: 0.07),
            ),
          ),
        ),
        Positioned(
          bottom: -size.height * 0.06,
          left:   -size.width  * 0.15,
          child: Container(
            width:  size.width  * 0.45,
            height: size.width  * 0.45,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _orange.withValues(alpha: 0.05),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _BrandHero — same icon + wordmark as AuthScreen
// ─────────────────────────────────────────────────────────────

class _BrandHero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width:  72,
          height: 72,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end:   Alignment.bottomRight,
              colors: [Color(0xFFFFBF4D), _orange],
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                color:      Color(0x55FF9500),
                blurRadius: 24,
                offset:     Offset(0, 10),
              ),
              BoxShadow(
                color:      Color(0x22FF9500),
                blurRadius: 6,
                offset:     Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.receipt_long_rounded,
            color: Colors.white,
            size:  36,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'orderix',
          style: GoogleFonts.righteous(
            fontSize:      32,
            color:         _textPrimary,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'auth_subtitle'.tr,
          style: const TextStyle(
            fontSize:      13,
            color:         _textSec,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _SignUpCard
// ─────────────────────────────────────────────────────────────

class _SignUpCard extends StatelessWidget {
  const _SignUpCard({
    super.key,
    required this.formKey,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.confirmPassCtrl,
    required this.obscurePassword,
    required this.obscureConfirmPass,
    required this.errorMessage,
    required this.onTogglePassword,
    required this.onToggleConfirmPass,
    required this.onSignUpPressed,
  });

  final GlobalKey<FormState>  formKey;
  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final TextEditingController confirmPassCtrl;
  final bool                  obscurePassword;
  final bool                  obscureConfirmPass;
  final String?               errorMessage;
  final VoidCallback          onTogglePassword;
  final VoidCallback          onToggleConfirmPass;
  final VoidCallback          onSignUpPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:        _card,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color:      Color(0x14000000),
            blurRadius: 32,
            offset:     Offset(0, 10),
          ),
          BoxShadow(
            color:      Color(0x08000000),
            blurRadius: 8,
            offset:     Offset(0, 3),
          ),
          BoxShadow(
            color:      Colors.white,
            blurRadius: 0,
            offset:     Offset(0, -1),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'auth_signup_title'.tr,
              style: const TextStyle(
                fontSize:      22,
                fontWeight:    FontWeight.w800,
                color:         _textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'auth_signup_subtitle'.tr,
              style: const TextStyle(fontSize: 13, color: _textSec),
            ),
            const SizedBox(height: 28),

            // Email
            _FieldLabel(label: 'auth_email'.tr),
            const SizedBox(height: 6),
            _SignUpTextField(
              controller:      emailCtrl,
              hint:            'auth_email_hint'.tr,
              prefixIcon:      Icons.alternate_email_rounded,
              keyboardType:    TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints:   const [AutofillHints.username, AutofillHints.email, AutofillHints.newUsername],
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'auth_email_required'.tr;
                if (!v.contains('@') || !v.contains('.')) return 'auth_email_invalid'.tr;
                return null;
              },
            ),
            const SizedBox(height: 18),

            // Password
            _FieldLabel(label: 'auth_password'.tr),
            const SizedBox(height: 6),
            _SignUpTextField(
              controller:      passwordCtrl,
              hint:            '••••••••',
              prefixIcon:      Icons.lock_outline_rounded,
              obscureText:     obscurePassword,
              textInputAction: TextInputAction.next,
              autofillHints:   const [AutofillHints.newPassword],
              suffixIcon: GestureDetector(
                onTap: onTogglePassword,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size:  20,
                    color: _textSec,
                  ),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'auth_password_required'.tr;
                if (v.length < 6)           return 'auth_password_short'.tr;
                return null;
              },
            ),
            const SizedBox(height: 18),

            // Confirm Password
            _FieldLabel(label: 'auth_confirm_password'.tr),
            const SizedBox(height: 6),
            _SignUpTextField(
              controller:      confirmPassCtrl,
              hint:            '••••••••',
              prefixIcon:      Icons.lock_outline_rounded,
              obscureText:     obscureConfirmPass,
              textInputAction: TextInputAction.done,
              autofillHints:   const [AutofillHints.newPassword],
              suffixIcon: GestureDetector(
                onTap: onToggleConfirmPass,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    obscureConfirmPass
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size:  20,
                    color: _textSec,
                  ),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'auth_password_required'.tr;
                if (v != passwordCtrl.text)  return 'auth_password_mismatch'.tr;
                return null;
              },
              onFieldSubmitted: (_) => onSignUpPressed(),
            ),

            // Error banner
            if (errorMessage != null) ...[
              const SizedBox(height: 16),
              _ErrorBanner(message: errorMessage!),
            ],

            const SizedBox(height: 28),

            // Submit button
            _SignUpButton(onPressed: onSignUpPressed),

            const SizedBox(height: 18),

            // Legal disclosure — App Store privacy/terms consent
            const _LegalDisclosure(),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _LegalDisclosure — Terms of Use & Privacy Policy consent
// ─────────────────────────────────────────────────────────────

class _LegalDisclosure extends StatelessWidget {
  const _LegalDisclosure();

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    const linkStyle = TextStyle(
      fontSize:       12,
      fontWeight:     FontWeight.w600,
      color:          _orange,
      decoration:     TextDecoration.underline,
      decorationColor:_orange,
      height:         1.5,
    );
    const textStyle = TextStyle(
      fontSize: 12,
      color:    _textSec,
      height:   1.5,
    );

    return Column(
      children: [
        Text(
          'legal_agree_prefix'.tr,
          textAlign: TextAlign.center,
          style:     textStyle,
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () => _open(_termsUrl),
              child: Text('terms_of_use'.tr, style: linkStyle),
            ),
            const Text(' · ', style: textStyle),
            GestureDetector(
              onTap: () => _open(_privacyUrl),
              child: Text('privacy_policy'.tr, style: linkStyle),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _SuccessCard — shown when email confirmation is required
// ─────────────────────────────────────────────────────────────

class _SuccessCard extends StatelessWidget {
  const _SuccessCard({super.key, required this.onBackToLogin});
  final VoidCallback onBackToLogin;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color:        _card,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color:      Color(0x14000000),
            blurRadius: 32,
            offset:     Offset(0, 10),
          ),
          BoxShadow(
            color:      Color(0x08000000),
            blurRadius: 8,
            offset:     Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(28, 40, 28, 32),
      child: Column(
        children: [
          // Success icon
          Container(
            width:  68,
            height: 68,
            decoration: BoxDecoration(
              color:        _success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.mark_email_read_rounded,
              color: _success,
              size:  34,
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            'auth_signup_success'.tr,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize:      20,
              fontWeight:    FontWeight.w800,
              color:         _textPrimary,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 10),

          // Body
          Text(
            'auth_signup_success_body'.tr,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color:    _textSec,
              height:   1.5,
            ),
          ),
          const SizedBox(height: 32),

          // Back to login button
          _PrimaryActionButton(
            label:   'auth_back_to_login'.tr,
            onPressed: onBackToLogin,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _FieldLabel
// ─────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize:   13,
        fontWeight: FontWeight.w600,
        color:      _textPrimary,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _SignUpTextField
// ─────────────────────────────────────────────────────────────

class _SignUpTextField extends StatefulWidget {
  const _SignUpTextField({
    required this.controller,
    required this.hint,
    required this.prefixIcon,
    this.obscureText        = false,
    this.keyboardType,
    this.textInputAction,
    this.suffixIcon,
    this.validator,
    this.onFieldSubmitted,
    this.autofillHints,
  });

  final TextEditingController      controller;
  final String                     hint;
  final IconData                   prefixIcon;
  final bool                       obscureText;
  final TextInputType?             keyboardType;
  final TextInputAction?           textInputAction;
  final Widget?                    suffixIcon;
  final String? Function(String?)? validator;
  final void Function(String)?     onFieldSubmitted;
  final Iterable<String>?          autofillHints;

  @override
  State<_SignUpTextField> createState() => _SignUpTextFieldState();
}

class _SignUpTextFieldState extends State<_SignUpTextField> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus != _isFocused) {
        setState(() => _isFocused = _focusNode.hasFocus);
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller:       widget.controller,
      focusNode:        _focusNode,
      obscureText:      widget.obscureText,
      keyboardType:     widget.keyboardType,
      textInputAction:  widget.textInputAction,
      validator:        widget.validator,
      onFieldSubmitted: widget.onFieldSubmitted,
      autofillHints:    widget.autofillHints,
      style: const TextStyle(
        fontSize:   14,
        color:      _textPrimary,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText:  widget.hint,
        hintStyle: const TextStyle(color: _textSec, fontSize: 14),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 16, right: 12),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Icon(
              widget.prefixIcon,
              key:   ValueKey<bool>(_isFocused),
              size:  20,
              color: _isFocused ? _orange : _textSec,
            ),
          ),
        ),
        prefixIconConstraints: const BoxConstraints(),
        suffixIcon: widget.suffixIcon,
        filled:     true,
        fillColor:  const Color(0xFFF9F9FB),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:   const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:   const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:   const BorderSide(color: _orange, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:   const BorderSide(color: _error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:   const BorderSide(color: _error, width: 1.5),
        ),
        errorStyle: const TextStyle(
          color:    _error,
          fontSize: 11,
          height:   1.4,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _ErrorBanner
// ─────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color:        _error.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: _error.withValues(alpha: 0.20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, size: 17, color: _error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color:      _error,
                fontSize:   13,
                fontWeight: FontWeight.w500,
                height:     1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _PrimaryActionButton — generic orange CTA used outside the
// signup submit flow (e.g. success card "Back to login").
// ─────────────────────────────────────────────────────────────

class _PrimaryActionButton extends StatefulWidget {
  const _PrimaryActionButton({
    required this.label,
    required this.onPressed,
  });

  final String        label;
  final VoidCallback  onPressed;

  @override
  State<_PrimaryActionButton> createState() => _PrimaryActionButtonState();
}

class _PrimaryActionButtonState extends State<_PrimaryActionButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => setState(() => _isPressed = true),
      onTapUp:     (_) => setState(() => _isPressed = false),
      onTapCancel: ()   => setState(() => _isPressed = false),
      onTap:       widget.onPressed,
      child: AnimatedScale(
        scale:    _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve:    Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width:    double.infinity,
          height:   54,
          decoration: BoxDecoration(
            color:        _orange,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color:      Color(0x55FF9500),
                blurRadius: 18,
                offset:     Offset(0, 7),
              ),
              BoxShadow(
                color:      Color(0x22FF9500),
                blurRadius: 5,
                offset:     Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              widget.label,
              style: const TextStyle(
                fontSize:      15,
                fontWeight:    FontWeight.w700,
                color:         Colors.white,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _SignUpButton
// ─────────────────────────────────────────────────────────────

class _SignUpButton extends StatefulWidget {
  const _SignUpButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  State<_SignUpButton> createState() => _SignUpButtonState();
}

class _SignUpButtonState extends State<_SignUpButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isLoading = AuthController.to.isSigningUp.value;
      final disabled  = isLoading;

      return GestureDetector(
        onTapDown:   disabled ? null : (_) => setState(() => _isPressed = true),
        onTapUp:     disabled ? null : (_) => setState(() => _isPressed = false),
        onTapCancel: disabled ? null : () => setState(() => _isPressed = false),
        onTap:       disabled ? null : widget.onPressed,
        child: AnimatedScale(
          scale:    _isPressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve:    Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width:    double.infinity,
            height:   54,
            decoration: BoxDecoration(
              color: isLoading
                  ? _orange.withValues(alpha: 0.55)
                  : _orange,
              borderRadius: BorderRadius.circular(16),
              boxShadow: isLoading
                  ? []
                  : const [
                      BoxShadow(
                        color:      Color(0x55FF9500),
                        blurRadius: 18,
                        offset:     Offset(0, 7),
                      ),
                      BoxShadow(
                        color:      Color(0x22FF9500),
                        blurRadius: 5,
                        offset:     Offset(0, 2),
                      ),
                    ],
            ),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width:  22,
                      height: 22,
                      child:  CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor:  AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'auth_signup'.tr,
                      style: const TextStyle(
                        fontSize:      15,
                        fontWeight:    FontWeight.w700,
                        color:         Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
            ),
          ),
        ),
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────
// _LoginLink — "Already have an account? Sign In"
// ─────────────────────────────────────────────────────────────

class _LoginLink extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'auth_have_account'.tr,
          style: const TextStyle(fontSize: 13, color: _textSec),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () => Get.back(),
          child: Text(
            'auth_login_link'.tr,
            style: const TextStyle(
              fontSize:   13,
              fontWeight: FontWeight.w700,
              color:      _orange,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _BottomFooter
// ─────────────────────────────────────────────────────────────

class _BottomFooter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width:  6,
          height: 6,
          decoration: const BoxDecoration(
            color: _orange, shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          AppInfo.brandLine,
          style: const TextStyle(fontSize: 12, color: _textSec),
        ),
        const SizedBox(width: 8),
        Container(
          width:  6,
          height: 6,
          decoration: const BoxDecoration(
            color: _orange, shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}
