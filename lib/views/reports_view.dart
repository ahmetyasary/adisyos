import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:adisyos/services/sales_history_service.dart';
import 'package:adisyos/themes/app_theme.dart';
import 'daily_report_view.dart';
import 'monthly_report_view.dart';
import 'yearly_report_view.dart';

// ── Design tokens ──────────────────────────────────────────
const _bg          = Color(0xFFF5F6FA);
const _card        = Colors.white;
const _orange      = Color(0xFFF5A623);
const _orangeLight = Color(0xFFFFF3E0);
const _textPrimary = Color(0xFF1A1A2E);
const _textSec     = Color(0xFF9B9B9B);
const _border      = Color(0xFFEEEEEE);

class ReportsView extends StatelessWidget {
  const ReportsView({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
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
                              value: '₺${todayTotal.toStringAsFixed(2)}',
                              sub: '${todaySales.length} işlem',
                              icon: Icons.today_rounded,
                              accent: AppTheme.successColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              label: 'Bu Ay',
                              value: '₺${monthTotal.toStringAsFixed(2)}',
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
    return Container(
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
          BoxShadow(
            color: Colors.white,
            blurRadius: 0,
            offset: Offset(0, -1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: accent, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: _textSec,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: _textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: const TextStyle(color: _textSec, fontSize: 12),
          ),
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
            border: Border.all(color: _border),
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
              BoxShadow(
                color: Colors.white,
                blurRadius: 0,
                offset: Offset(0, -1),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 26),
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
