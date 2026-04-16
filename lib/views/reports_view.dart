import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:orderix/services/sales_history_service.dart';
import 'package:orderix/services/settings_service.dart';
import 'package:orderix/themes/app_theme.dart';
import 'daily_report_view.dart';
import 'monthly_report_view.dart';
import 'yearly_report_view.dart';

// ── Apple-inspired design tokens ──────────────────────────────
const _bg          = Color(0xFFF2F2F7);
const _card        = Colors.white;
const _orange      = Color(0xFFFF9500);
const _textPrimary = Color(0xFF1C1C1E);
const _textSec     = Color(0xFF8E8E93);

class ReportsView extends StatelessWidget {
  const ReportsView({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _PageHeader(title: 'reports'.tr),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Quick stats row
                    Obx(() {
                      final cs = SettingsService.cs;
                      final todaySales =
                          SalesHistoryService.to.getSalesForDate(now);
                      final todayTotal =
                          SalesHistoryService.to.getTotalForSales(todaySales);
                      final monthSales = SalesHistoryService.to
                          .getSalesForMonth(now.year, now.month);
                      final monthTotal =
                          SalesHistoryService.to.getTotalForSales(monthSales);

                      return Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              label: 'Bugün',
                              value: '$cs${todayTotal.toStringAsFixed(2)}',
                              sub: '${todaySales.length} işlem',
                              icon: Icons.today_rounded,
                              accent: AppTheme.successColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              label: 'Bu Ay',
                              value: '$cs${monthTotal.toStringAsFixed(2)}',
                              sub: '${monthSales.length} işlem',
                              icon: Icons.calendar_month_rounded,
                              accent: _orange,
                            ),
                          ),
                        ],
                      );
                    }),
                    const SizedBox(height: 28),

                    // Section label
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Rapor Türü',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _textSec,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),

                    // Report type buttons
                    _ReportTile(
                      icon: Icons.today_rounded,
                      title: 'daily_report'.tr,
                      subtitle:
                          'Bugünkü satışlar, saatlik dağılım ve en çok satanlar',
                      accent: AppTheme.successColor,
                      onTap: () => Get.to(() => const DailyReportView()),
                    ),
                    const SizedBox(height: 12),
                    _ReportTile(
                      icon: Icons.calendar_month_rounded,
                      title: 'monthly_report'.tr,
                      subtitle: 'Bu aylık günlük satış grafiği ve özeti',
                      accent: _orange,
                      onTap: () => Get.to(() => const MonthlyReportView()),
                    ),
                    const SizedBox(height: 12),
                    _ReportTile(
                      icon: Icons.calendar_today_rounded,
                      title: 'yearly_report'.tr,
                      subtitle: 'Yıllık trend grafiği ve kategori dağılımı',
                      accent: AppTheme.warningColor,
                      onTap: () => Get.to(() => const YearlyReportView()),
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

// ── _PageHeader ────────────────────────────────────────────

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.title, this.actions});
  final String title;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.only(top: topPad),
      decoration: const BoxDecoration(
        color: _card,
        boxShadow: [
          BoxShadow(color: Color(0x0C000000), blurRadius: 16, offset: Offset(0, 2)),
          BoxShadow(color: Color(0x05000000), blurRadius: 4,  offset: Offset(0, 1)),
        ],
      ),
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 18, color: _textPrimary),
              onPressed: () => Get.back(),
            ),
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const Spacer(),
            if (actions != null) ...actions!,
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

// ── _StatCard ──────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.sub,
    required this.icon,
    required this.accent,
  });

  final String label;
  final String value;
  final String sub;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 20, offset: Offset(0, 4)),
          BoxShadow(color: Color(0x05000000), blurRadius: 5,  offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color.lerp(accent, Colors.white, 0.28)!, accent],
              ),
              borderRadius: BorderRadius.circular(11),
              boxShadow: [BoxShadow(color: accent.withOpacity(0.28), blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: _textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: _textSec, fontSize: 11, fontWeight: FontWeight.w500)),
          Text(sub,   style: const TextStyle(color: _textSec, fontSize: 11)),
        ],
      ),
    );
  }
}

// ── _ReportTile ────────────────────────────────────────────

class _ReportTile extends StatelessWidget {
  const _ReportTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 18,
                offset: Offset(0, 7),
              ),
              BoxShadow(
                color: Color(0x08000000),
                blurRadius: 5,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color.lerp(accent, Colors.white, 0.28)!, accent],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: accent.withOpacity(0.30), blurRadius: 12, offset: const Offset(0, 5))],
                ),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(color: _textSec, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios_rounded,
                  color: _textSec, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}
