import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class DailyReportView extends StatelessWidget {
  const DailyReportView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Günlük Rapor'),
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
                'Günlük Satış Grafiği',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 250,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: 100,
                    barTouchData: BarTouchData(enabled: false),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: true),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final days = [
                              'Pzt',
                              'Sal',
                              'Çar',
                              'Per',
                              'Cum',
                              'Cmt',
                              'Paz'
                            ];
                            return Text(days[value.toInt() % 7]);
                          },
                        ),
                      ),
                      rightTitles:
                          AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles:
                          AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: [
                      BarChartGroupData(x: 0, barRods: [
                        BarChartRodData(toY: 50, color: Colors.blue)
                      ]),
                      BarChartGroupData(x: 1, barRods: [
                        BarChartRodData(toY: 80, color: Colors.blue)
                      ]),
                      BarChartGroupData(x: 2, barRods: [
                        BarChartRodData(toY: 30, color: Colors.blue)
                      ]),
                      BarChartGroupData(x: 3, barRods: [
                        BarChartRodData(toY: 60, color: Colors.blue)
                      ]),
                      BarChartGroupData(x: 4, barRods: [
                        BarChartRodData(toY: 90, color: Colors.blue)
                      ]),
                      BarChartGroupData(x: 5, barRods: [
                        BarChartRodData(toY: 40, color: Colors.blue)
                      ]),
                      BarChartGroupData(x: 6, barRods: [
                        BarChartRodData(toY: 70, color: Colors.blue)
                      ]),
                    ],
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
