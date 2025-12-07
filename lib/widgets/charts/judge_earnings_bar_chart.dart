import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../models/event_report.dart';

class JudgeEarningsBarChart extends StatefulWidget {
  final EventReport report;

  const JudgeEarningsBarChart({
    super.key,
    required this.report,
  });

  @override
  State<JudgeEarningsBarChart> createState() => _JudgeEarningsBarChartState();
}

class _JudgeEarningsBarChartState extends State<JudgeEarningsBarChart> {
  int touchedGroupIndex = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.report.judgeBreakdowns.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text('No judge data to display'),
        ),
      );
    }

    final judges = widget.report.judgeBreakdowns.values.toList();

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1.5,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: _getMaxY(judges),
              barTouchData: BarTouchData(
                touchCallback: (FlTouchEvent event, barTouchResponse) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        barTouchResponse == null ||
                        barTouchResponse.spot == null) {
                      touchedGroupIndex = -1;
                      return;
                    }
                    touchedGroupIndex =
                        barTouchResponse.spot!.touchedBarGroupIndex;
                  });
                },
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final judge = judges[groupIndex];
                    String label;
                    switch (rodIndex) {
                      case 0:
                        label = 'Fees: \$${judge.totalFees.toStringAsFixed(2)}';
                        break;
                      case 1:
                        label = 'Expenses: \$${judge.totalExpenses.toStringAsFixed(2)}';
                        break;
                      case 2:
                        label = 'Check: \$${judge.totalOwed.toStringAsFixed(2)}';
                        break;
                      default:
                        label = '';
                    }
                    return BarTooltipItem(
                      label,
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index >= 0 && index < judges.length) {
                        final judge = judges[index];
                        // Show first name or first 8 characters
                        final name = judge.judgeName.split(' ').first;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            name.length > 8 ? '${name.substring(0, 8)}...' : name,
                            style: const TextStyle(fontSize: 10),
                          ),
                        );
                      }
                      return const Text('');
                    },
                    reservedSize: 30,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        '\$${value.toInt()}',
                        style: const TextStyle(fontSize: 10),
                      );
                    },
                    reservedSize: 40,
                  ),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: _getBarGroups(judges),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: _getMaxY(judges) / 5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildLegend(),
      ],
    );
  }

  List<BarChartGroupData> _getBarGroups(List<JudgeFinancialSummary> judges) {
    return judges.asMap().entries.map((entry) {
      final index = entry.key;
      final judge = entry.value;
      final isTouched = index == touchedGroupIndex;

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: judge.totalFees,
            color: Colors.green,
            width: isTouched ? 12 : 10,
          ),
          BarChartRodData(
            toY: judge.totalExpenses,
            color: Colors.orange,
            width: isTouched ? 12 : 10,
          ),
          BarChartRodData(
            toY: judge.totalOwed,
            color: Colors.blue,
            width: isTouched ? 12 : 10,
          ),
        ],
        barsSpace: 4,
      );
    }).toList();
  }

  double _getMaxY(List<JudgeFinancialSummary> judges) {
    double max = 0;
    for (final judge in judges) {
      if (judge.totalOwed > max) max = judge.totalOwed;
    }
    // Add 20% padding to top
    return max * 1.2;
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLegendItem('Fees (1099)', Colors.green),
        const SizedBox(width: 16),
        _buildLegendItem('Expenses', Colors.orange),
        const SizedBox(width: 16),
        _buildLegendItem('Check Amount', Colors.blue),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}
