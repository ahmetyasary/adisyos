import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:orderix/services/sales_history_service.dart';
import 'package:orderix/services/settings_service.dart';
import 'package:orderix/themes/app_theme.dart';
import 'package:orderix/widgets/shell_leading.dart';
import 'daily_report_view.dart';
import 'monthly_report_view.dart';
import 'yearly_report_view.dart';

// ── Apple-inspired design tokens ──────────────────────────────
const _bg = Colors.white;
const _card = Colors.white;
const _orange = Color(0xFFFF9500);
const _textPrimary = Color(0xFF1C1C1E);
const _textSec = Color(0xFF8E8E93);
const _border = Color(0xFFECECEF);

enum _ReportType { daily, monthly, yearly }

/// Width of the content area (i.e. the space to the right of the app
/// sidebar) above which the report list and detail are shown side-by-side
/// instead of pushing a new page. Tablet/desktop-only; phone layout below
/// this is untouched.
const double _kSplitViewBreakpoint = 700;

class ReportsView extends StatefulWidget {
  const ReportsView({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends State<ReportsView> {
  _ReportType? _selected = _ReportType.daily;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _PageHeader(title: 'reports'.tr, embedded: widget.embedded),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isSplit = constraints.maxWidth >= _kSplitViewBreakpoint;
                  final list = _buildList(now, isSplit);

                  if (!isSplit) return list;

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(width: 360, child: list),
                      const VerticalDivider(width: 1, color: _border),
                      Expanded(child: _buildDetail()),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(DateTime now, bool isSplit) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Quick stats row
          Obx(() {
            final cs = SettingsService.cs;
            final todaySales = SalesHistoryService.to.getSalesForDate(now);
            final todayTotal =
                SalesHistoryService.to.getTotalForSales(todaySales);
            final monthSales =
                SalesHistoryService.to.getSalesForMonth(now.year, now.month);
            final monthTotal =
                SalesHistoryService.to.getTotalForSales(monthSales);

            return Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Bugün',
                    value: '$cs${todayTotal.toStringAsFixed(2)}',
                    sub: '${todaySales.length} işlem',
                    icon: CupertinoIcons.today_fill,
                    accent: AppTheme.successColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'Bu Ay',
                    value: '$cs${monthTotal.toStringAsFixed(2)}',
                    sub: '${monthSales.length} işlem',
                    icon: CupertinoIcons.calendar_circle_fill,
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
            icon: CupertinoIcons.today_fill,
            title: 'daily_report'.tr,
            subtitle: 'Bugünkü satışlar, saatlik dağılım ve en çok satanlar',
            accent: AppTheme.successColor,
            selected: isSplit && _selected == _ReportType.daily,
            onTap: () => _open(_ReportType.daily, isSplit),
          ),
          const SizedBox(height: 12),
          _ReportTile(
            icon: CupertinoIcons.calendar_circle_fill,
            title: 'monthly_report'.tr,
            subtitle: 'Bu aylık günlük satış grafiği ve özeti',
            accent: _orange,
            selected: isSplit && _selected == _ReportType.monthly,
            onTap: () => _open(_ReportType.monthly, isSplit),
          ),
          const SizedBox(height: 12),
          _ReportTile(
            icon: CupertinoIcons.chart_bar_alt_fill,
            title: 'yearly_report'.tr,
            subtitle: 'Yıllık trend grafiği ve kategori dağılımı',
            accent: AppTheme.warningColor,
            selected: isSplit && _selected == _ReportType.yearly,
            onTap: () => _open(_ReportType.yearly, isSplit),
          ),
        ],
      ),
    );
  }

  void _open(_ReportType type, bool isSplit) {
    if (isSplit) {
      setState(() => _selected = type);
      return;
    }
    switch (type) {
      case _ReportType.daily:
        Get.to(() => const DailyReportView());
      case _ReportType.monthly:
        Get.to(() => const MonthlyReportView());
      case _ReportType.yearly:
        Get.to(() => const YearlyReportView());
    }
  }

  Widget _buildDetail() {
    return switch (_selected) {
      _ReportType.daily => const DailyReportView(inline: true),
      _ReportType.monthly => const MonthlyReportView(inline: true),
      _ReportType.yearly => const YearlyReportView(inline: true),
      null => const _EmptyDetail(),
    };
  }
}

class _EmptyDetail extends StatelessWidget {
  const _EmptyDetail();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(CupertinoIcons.chart_bar_alt_fill,
              size: 44, color: _textSec),
          const SizedBox(height: 16),
          Text(
            'Görüntülemek için bir rapor türü seçin',
            style: TextStyle(color: _textSec, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

// ── _PageHeader ────────────────────────────────────────────

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.title, this.actions, this.embedded = false});
  final String title;
  final List<Widget>? actions;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.only(top: topPad),
      decoration: const BoxDecoration(
        color: _card,
        border: Border(bottom: BorderSide(color: _border, width: 1)),
      ),
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            ShellLeading(embedded: embedded, color: _textPrimary),
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
        border: Border.fromBorderSide(BorderSide(color: _border, width: 1)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4)),
          BoxShadow(
              color: Color(0x05000000), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 24),
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
          Text(label,
              style: const TextStyle(
                  color: _textSec, fontSize: 11, fontWeight: FontWeight.w500)),
          Text(sub, style: const TextStyle(color: _textSec, fontSize: 11)),
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
    this.selected = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? accent.withValues(alpha: 0.06) : _card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.fromBorderSide(BorderSide(
                color: selected ? accent : _border, width: selected ? 1.5 : 1)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x08000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
              BoxShadow(
                color: Color(0x05000000),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: accent, size: 30),
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
              const Icon(CupertinoIcons.chevron_forward,
                  color: _textSec, size: 15),
            ],
          ),
        ),
      ),
    );
  }
}
