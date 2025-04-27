import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class MonthlyReportView extends StatelessWidget {
  const MonthlyReportView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aylık Rapor'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Aylık Satış Grafiği',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 250,
                child: LineChart(
                  LineChartData(
                    lineBarsData: [
                      LineChartBarData(
                        spots: [
                          FlSpot(1, 30),
                          FlSpot(2, 50),
                          FlSpot(3, 40),
                          FlSpot(4, 80),
                          FlSpot(5, 60),
                          FlSpot(6, 90),
                          FlSpot(7, 70),
                          FlSpot(8, 100),
                          FlSpot(9, 80),
                          FlSpot(10, 60),
                          FlSpot(11, 40),
                          FlSpot(12, 50),
                        ],
                        isCurved: true,
                        color: Colors.orange,
                        barWidth: 4,
                        dotData: FlDotData(show: false),
                      ),
                    ],
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: true),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final months = [
                              'Oca',
                              'Şub',
                              'Mar',
                              'Nis',
                              'May',
                              'Haz',
                              'Tem',
                              'Ağu',
                              'Eyl',
                              'Eki',
                              'Kas',
                              'Ara'
                            ];
                            if (value >= 1 && value <= 12) {
                              return Text(months[value.toInt() - 1]);
                            }
                            return const SizedBox();
                          },
                        ),
                      ),
                      rightTitles:
                          AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles:
                          AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
