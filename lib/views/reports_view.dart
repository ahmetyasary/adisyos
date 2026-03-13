import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:adisyos/services/sales_history_service.dart';
import 'package:adisyos/themes/app_theme.dart';
import 'daily_report_view.dart';
import 'monthly_report_view.dart';
import 'yearly_report_view.dart';

class ReportsView extends StatelessWidget {
  const ReportsView({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: Text('reports'.tr),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.secondary,
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
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
                      child: _buildStatCard(
                        context,
                        label: 'Bugün',
                        value: '₺${todayTotal.toStringAsFixed(2)}',
                        sub: '${todaySales.length} işlem',
                        icon: Icons.today,
                        color: AppTheme.successColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        context,
                        label: 'Bu Ay',
                        value: '₺${monthTotal.toStringAsFixed(2)}',
                        sub: '${monthSales.length} işlem',
                        icon: Icons.calendar_month,
                        color: AppTheme.accentColor,
                      ),
                    ),
                  ],
                );
              }),
              const SizedBox(height: 32),

              // Report type buttons
              _buildReportButton(
                context,
                icon: Icons.today,
                title: 'daily_report'.tr,
                subtitle: 'Bugünkü satışlar, saatlik dağılım ve en çok satanlar',
                color: AppTheme.successColor,
                onTap: () => Get.to(() => const DailyReportView()),
              ),
              const SizedBox(height: 16),
              _buildReportButton(
                context,
                icon: Icons.calendar_month,
                title: 'monthly_report'.tr,
                subtitle: 'Bu aylık günlük satış grafiği ve özeti',
                color: AppTheme.accentColor,
                onTap: () => Get.to(() => const MonthlyReportView()),
              ),
              const SizedBox(height: 16),
              _buildReportButton(
                context,
                icon: Icons.calendar_today,
                title: 'yearly_report'.tr,
                subtitle: 'Yıllık trend grafiği ve kategori dağılımı',
                color: AppTheme.warningColor,
                onTap: () => Get.to(() => const YearlyReportView()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String label,
    required String value,
    required String sub,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white.withValues(alpha: 0.8), size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            sub,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportButton(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.white.withValues(alpha: 0.6),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
