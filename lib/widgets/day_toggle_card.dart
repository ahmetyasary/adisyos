import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:orderix/features/auth/presentation/controller/auth_controller.dart';
import 'package:orderix/services/day_service.dart';
import 'package:orderix/services/staff_service.dart';
import 'package:orderix/services/table_service.dart';
import 'package:orderix/widgets/app_dialog.dart';
import 'package:orderix/widgets/app_toast.dart';
import 'package:orderix/widgets/shell_leading.dart';
import 'package:orderix/themes/app_colors.dart';

// ── Apple-inspired design tokens ──────────────────────────────
Color get _card => AppColors.card;
const _orange = Color(0xFFFF9500);
const _green = Color(0xFF34C759);
const _red = Color(0xFFFF3B30);
Color get _labelPrimary => AppColors.textPrimary;
Color get _labelSecondary => AppColors.textSec;

/// Dashboard hero stays a dark panel with white type in both themes.
Color get _heroBg =>
    AppColors.isDark ? const Color(0xFF2C2C2E) : const Color(0xFF1C1C1E);

/// Single card that switches between "start the day" and "day is active /
/// end the day". Self-contained — owns its own start/end logic so it can be
/// dropped at the top of any screen (Dashboard for admins, Tables for staff).
///
/// [hero] renders the large dark "Güne Başlayın" hero used on the dashboard;
/// the default compact pill is used elsewhere (e.g. the staff tables screen).
/// [dense] further shrinks padding for screens that need more workspace below.
class DayToggleCard extends StatelessWidget {
  const DayToggleCard({super.key, this.hero = false, this.dense = false});

  final bool hero;
  final bool dense;

  /// Unique identifier for the current session's day tracking.
  /// Staff → their profile name (set via PIN).
  /// Admin (no staff selected) → their login email.
  String get _currentIdentifier {
    final staffName = StaffService.to.currentStaffIdentifier;
    return staffName.isNotEmpty
        ? staffName
        : (AuthController.to.user.value?.email ?? '');
  }

  /// Elapsed time since the day started, robust to the started_at round-trip.
  ///
  /// [DayService.startDay] writes a *local* wall-clock (`DateTime.now()`), but
  /// Supabase's `timestamptz` column returns it tagged as UTC. Parsing that
  /// back shifts the instant by the local offset, which produced a negative
  /// "elapsed". When the parsed value is UTC we rebuild it from its wall-clock
  /// components as local time to recover the original; negatives are clamped.
  Duration _activeElapsed(Map<String, dynamic>? day) {
    var st = DateTime.tryParse(day?['started_at'] as String? ?? '');
    if (st == null) return Duration.zero;
    if (st.isUtc) {
      st = DateTime(st.year, st.month, st.day, st.hour, st.minute, st.second);
    }
    final e = DateTime.now().difference(st);
    return e.isNegative ? Duration.zero : e;
  }

  Future<void> _startDay() async {
    final success = await DayService.to.startDay(_currentIdentifier);
    if (success) {
      AppToast.success('İyi çalışmalar!',
          title: 'Gün Başlatıldı', duration: const Duration(seconds: 2));
    }
  }

  Future<void> _endDay() async {
    // Block if any table still has an active order
    final hasOrders = TableService.to.tables.any(
      (t) => t['isOccupied'] == true,
    );
    if (hasOrders) {
      Get.dialog(
        Dialog(
          backgroundColor: _card,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: _orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.table_bar_rounded,
                      size: 32, color: _orange),
                ),
                const SizedBox(height: 18),
                Text(
                  'Açık Masa Var',
                  style: GoogleFonts.poppins(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    color: _labelPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tüm masalar kapatılmadan\ngün bitirilemez.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: _labelSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: Get.back,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _orange,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Tamam',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }

    final confirmed = await AppDialog.confirm(
      icon: CupertinoIcons.moon_stars_fill,
      iconColor: const Color(0xFFFF3B30),
      title: 'Günü Bitir',
      message:
          'Günü bitirmek istediğinize emin misiniz?\nGün bitince yeni sipariş alınamaz.',
      confirmText: 'Günü Bitir',
      cancelText: 'Vazgeç',
      destructive: true,
    );
    if (!confirmed) return;

    final success = await DayService.to.endDay(_currentIdentifier);
    if (success) {
      AppToast.info('Günü kapattınız. Yarın görüşmek üzere!',
          title: 'Gün Bitirildi', duration: const Duration(seconds: 2));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final staffName = StaffService.to.currentStaffIdentifier;
      final identifier = staffName.isNotEmpty
          ? staffName
          : (AuthController.to.user.value?.email ?? '');
      final dayStarted = DayService.to.isDayStartedBy(identifier);
      final isLoading = DayService.to.isLoading.value;
      final day = DayService.to.getActiveDayFor(identifier);

      if (hero) {
        return _buildHero(context, dayStarted, isLoading, day);
      }

      if (!dayStarted) {
        return _buildCompactStart(isLoading);
      }

      final elapsed = _activeElapsed(day);
      return _buildCompactActive(
        hours: elapsed.inHours,
        minutes: elapsed.inMinutes % 60,
      );
    });
  }

  Widget _buildCompactStart(bool isLoading) {
    final padV = dense ? 10.0 : 16.0;
    final padH = dense ? 14.0 : 20.0;
    final iconBox = dense ? 36.0 : 46.0;
    return GestureDetector(
      onTap: isLoading ? null : _startDay,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(dense ? 14 : 18),
          border: Border.all(color: _orange.withValues(alpha: 0.3), width: 1),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 20,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: iconBox,
              height: iconBox,
              decoration: BoxDecoration(
                color: _orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(dense ? 10 : 14),
              ),
              child: Icon(
                CupertinoIcons.sun_max_fill,
                color: _orange,
                size: dense ? 18 : 24,
              ),
            ),
            SizedBox(width: dense ? 12 : 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Günü Başlat',
                    style: TextStyle(
                      fontSize: dense ? 14 : 16,
                      fontWeight: FontWeight.w700,
                      color: _labelPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (!dense) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Sipariş almak için günü başlatın',
                      style: TextStyle(fontSize: 12, color: _labelSecondary),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (isLoading)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(_orange),
                ),
              )
            else
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: dense ? 12 : 14, vertical: dense ? 7 : 9),
                decoration: BoxDecoration(
                  color: _orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(CupertinoIcons.play_arrow_solid,
                        size: 16, color: _orange),
                    const SizedBox(width: 6),
                    Text(
                      'Başlat',
                      style: TextStyle(
                        fontSize: dense ? 12 : 13,
                        fontWeight: FontWeight.w600,
                        color: _orange,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactActive({required int hours, required int minutes}) {
    final padV = dense ? 10.0 : 16.0;
    final padH = dense ? 14.0 : 20.0;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(dense ? 14 : 18),
        border: Border.all(
          color: const Color(0xFF34C759).withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: dense ? 8 : 10,
            height: dense ? 8 : 10,
            decoration: const BoxDecoration(
              color: Color(0xFF34C759),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Color(0x4034C759), blurRadius: 8),
              ],
            ),
          ),
          SizedBox(width: dense ? 10 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gün Aktif',
                  style: TextStyle(
                    fontSize: dense ? 13 : 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF34C759),
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '${hours}sa ${minutes}dk aktif',
                  style: TextStyle(
                    fontSize: dense ? 11 : 12,
                    color: _labelSecondary,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _endDay,
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: dense ? 12 : 16, vertical: dense ? 7 : 9),
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B30).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(CupertinoIcons.stop_fill,
                      size: 14, color: Color(0xFFFF3B30)),
                  const SizedBox(width: 5),
                  Text(
                    dense ? 'Bitir' : 'Günü Bitir',
                    style: TextStyle(
                      fontSize: dense ? 12 : 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFFF3B30),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero variant (dashboard) ─────────────────────────────────

  Widget _buildHero(
    BuildContext context,
    bool dayStarted,
    bool isLoading,
    Map<String, dynamic>? day,
  ) {
    String? elapsedLabel;
    if (dayStarted) {
      final e = _activeElapsed(day);
      elapsedLabel = '${e.inHours}sa ${e.inMinutes % 60}dk aktif';
    }

    final title = dayStarted ? 'Gün Aktif' : 'Güne Başlayın';
    final subtitle = dayStarted
        ? 'Siparişleri yönetmeye devam edin.'
        : 'Siparişleri yönetmeye hazır mısınız?';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _heroBg,
        borderRadius: BorderRadius.circular(22),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Subtle decorative motif (no asset dependency).
          Positioned(
            right: -16,
            bottom: -18,
            child: Icon(
              CupertinoIcons.money_dollar_circle_fill,
              size: 132,
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (dayStarted && elapsedLabel != null) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                            color: _green, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        elapsedLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    if (!dayStarted)
                      _HeroPrimaryButton(
                        label: 'Günü Başlat',
                        icon: CupertinoIcons.play_arrow_solid,
                        loading: isLoading,
                        onTap: _startDay,
                      )
                    else ...[
                      Expanded(
                        child: _HeroPrimaryButton(
                          label: 'Siparişleri Görüntüle',
                          icon: CupertinoIcons.arrow_right,
                          expand: true,
                          onTap: () => ShellScope.maybeOf(context)
                              ?.selectSection('tables'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _HeroSecondaryButton(
                        label: 'Günü Bitir',
                        onTap: _endDay,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPrimaryButton extends StatelessWidget {
  const _HeroPrimaryButton({
    required this.label,
    required this.onTap,
    this.icon,
    this.loading = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool loading;

  /// When true the button fills its parent's width and the label ellipsizes
  /// instead of overflowing (used when sharing a row with the end-day button).
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: _orange,
          borderRadius: BorderRadius.circular(13),
        ),
        child: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  if (icon != null) ...[
                    const SizedBox(width: 8),
                    Icon(icon, size: 18, color: Colors.white),
                  ],
                ],
              ),
      ),
    );
  }
}

class _HeroSecondaryButton extends StatelessWidget {
  const _HeroSecondaryButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: _red.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFFFF6961),
          ),
        ),
      ),
    );
  }
}
