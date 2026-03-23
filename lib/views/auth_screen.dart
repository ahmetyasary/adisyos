import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:adisyos/core/errors/auth_exception.dart';
import 'package:adisyos/features/auth/domain/entities/auth_user.dart';
import 'package:adisyos/features/auth/presentation/controller/auth_controller.dart';
import 'package:adisyos/models/app_role.dart';
import 'package:adisyos/views/home_view.dart';
import 'package:adisyos/views/tables_view.dart';

// ── Apple-inspired design tokens ──────────────────────────────
const _bg          = Color(0xFFF2F2F7);
const _card        = Colors.white;
const _orange      = Color(0xFFFF9500);
const _textPrimary = Color(0xFF1C1C1E);
const _textSec     = Color(0xFF8E8E93);
const _border      = Color(0xFFE5E5EA);
const _error       = Color(0xFFFF3B30);

// ─────────────────────────────────────────────────────────────
// AuthScreen
// ─────────────────────────────────────────────────────────────

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  final _formKey      = GlobalKey<FormState>();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool    _obscurePassword = true;
  String? _errorMessage;

  late final AnimationController _fadeCtrl;
  late final Animation<double>   _fadeAnim;
  late final Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    _fadeAnim  = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end:   Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut));

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

  // ── Login ──────────────────────────────────────────────────

  Future<void> _onLoginPressed() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _errorMessage = null);

    try {
      final authUser = await AuthController.to.login(
        email:    _emailCtrl.text.trim(),
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

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // ── Decorative blobs ──────────────────────────────
          const _Decorations(),

          // ── Content ───────────────────────────────────────
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
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Brand above the card
                          _BrandHero(),
                          const SizedBox(height: 32),

                          // Login card
                          _LoginCard(
                            formKey:          _formKey,
                            emailCtrl:        _emailCtrl,
                            passwordCtrl:     _passwordCtrl,
                            obscurePassword:  _obscurePassword,
                            errorMessage:     _errorMessage,
                            onTogglePassword: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                            onLoginPressed:   _onLoginPressed,
                          ),

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
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _Decorations — subtle background shapes
// ─────────────────────────────────────────────────────────────

class _Decorations extends StatelessWidget {
  const _Decorations();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Stack(
      children: [
        // Top-right large blob
        Positioned(
          top: -size.height * 0.10,
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
        // Bottom-left small blob
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
// _BrandHero — icon + wordmark + tagline
// ─────────────────────────────────────────────────────────────

class _BrandHero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Icon badge
        Container(
          width:  72,
          height: 72,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFBF4D), _orange],
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                color:  Color(0x55FF9500),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
              BoxShadow(
                color:  Color(0x22FF9500),
                blurRadius: 6,
                offset: Offset(0, 2),
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

        // Wordmark
        Text(
          'adisyos',
          style: GoogleFonts.righteous(
            fontSize:    32,
            color:       _textPrimary,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 4),

        // Tagline
        Text(
          'auth_subtitle'.tr,
          style: const TextStyle(
            fontSize:    13,
            color:       _textSec,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _LoginCard
// ─────────────────────────────────────────────────────────────

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

  final GlobalKey<FormState>       formKey;
  final TextEditingController      emailCtrl;
  final TextEditingController      passwordCtrl;
  final bool                       obscurePassword;
  final String?                    errorMessage;
  final VoidCallback               onTogglePassword;
  final VoidCallback               onLoginPressed;

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
            // Section heading
            const Text(
              'Giriş Yap',
              style: TextStyle(
                fontSize:    22,
                fontWeight:  FontWeight.w800,
                color:       _textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Hesabınıza erişmek için giriş yapın',
              style: TextStyle(fontSize: 13, color: _textSec),
            ),
            const SizedBox(height: 28),

            // Email field
            _FieldLabel(label: 'auth_email'.tr),
            const SizedBox(height: 6),
            _AuthTextField(
              controller:      emailCtrl,
              hint:            'auth_email_hint'.tr,
              prefixIcon:      Icons.alternate_email_rounded,
              keyboardType:    TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.trim().isEmpty)    return 'auth_email_required'.tr;
                if (!v.contains('@') || !v.contains('.')) return 'auth_email_invalid'.tr;
                return null;
              },
            ),
            const SizedBox(height: 18),

            // Password field
            _FieldLabel(label: 'auth_password'.tr),
            const SizedBox(height: 6),
            _AuthTextField(
              controller:      passwordCtrl,
              hint:            '••••••••',
              prefixIcon:      Icons.lock_outline_rounded,
              obscureText:     obscurePassword,
              textInputAction: TextInputAction.done,
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
              onFieldSubmitted: (_) => onLoginPressed(),
            ),

            // Error banner
            if (errorMessage != null) ...[
              const SizedBox(height: 16),
              _ErrorBanner(message: errorMessage!),
            ],

            const SizedBox(height: 28),

            // Login button
            _LoginButton(onPressed: onLoginPressed),
          ],
        ),
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
// _AuthTextField
// ─────────────────────────────────────────────────────────────

class _AuthTextField extends StatelessWidget {
  const _AuthTextField({
    required this.controller,
    required this.hint,
    required this.prefixIcon,
    this.obscureText        = false,
    this.keyboardType,
    this.textInputAction,
    this.suffixIcon,
    this.validator,
    this.onFieldSubmitted,
  });

  final TextEditingController       controller;
  final String                      hint;
  final IconData                    prefixIcon;
  final bool                        obscureText;
  final TextInputType?              keyboardType;
  final TextInputAction?            textInputAction;
  final Widget?                     suffixIcon;
  final String? Function(String?)? validator;
  final void Function(String)?      onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller:      controller,
      obscureText:     obscureText,
      keyboardType:    keyboardType,
      textInputAction: textInputAction,
      validator:       validator,
      onFieldSubmitted: onFieldSubmitted,
      style: const TextStyle(
        fontSize:   14,
        color:      _textPrimary,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText:  hint,
        hintStyle: const TextStyle(color: _textSec, fontSize: 14),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 16, right: 12),
          child: Icon(prefixIcon, size: 20, color: _textSec),
        ),
        prefixIconConstraints: const BoxConstraints(),
        suffixIcon: suffixIcon,
        filled:    true,
        fillColor: const Color(0xFFF9F9FB),
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
        color:  _error.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _error.withValues(alpha: 0.20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 17, color: _error),
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
// _LoginButton
// ─────────────────────────────────────────────────────────────

class _LoginButton extends StatelessWidget {
  const _LoginButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isLoading = AuthController.to.isLoading.value;

      return GestureDetector(
        onTap: isLoading ? null : onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width:  double.infinity,
          height: 54,
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
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    'auth_login'.tr,
                    style: const TextStyle(
                      fontSize:    15,
                      fontWeight:  FontWeight.w700,
                      color:       Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
          ),
        ),
      );
    });
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
        const Text(
          'Adisyos v0.1 Beta · by Smartlogy',
          style: TextStyle(fontSize: 12, color: _textSec),
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
