import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../models/event_report.dart';

class ExpensePieChart extends StatefulWidget {
  final EventReport report;

  const ExpensePieChart({
    super.key,
    required this.report,
  });

  @override
  State<ExpensePieChart> createState() => _ExpensePieChartState();
}

class _ExpensePieChartState extends State<ExpensePieChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.report.expensesByCategory.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text('No expenses to display'),
        ),
      );
    }

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1.3,
          child: PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        pieTouchResponse == null ||
                        pieTouchResponse.touchedSection == null) {
                      touchedIndex = -1;
                      return;
                    }
                    touchedIndex =
                        pieTouchResponse.touchedSection!.touchedSectionIndex;
                  });
                },
              ),
              borderData: FlBorderData(show: false),
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: _getSections(),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildLegend(),
      ],
    );
  }

  List<PieChartSectionData> _getSections() {
    final total = widget.report.totalExpenses;
    final entries = widget.report.expensesByCategory.entries.toList();

    return entries.asMap().entries.map((entry) {
      final index = entry.key;
      final categoryEntry = entry.value;
      final isTouched = index == touchedIndex;
      final fontSize = isTouched ? 16.0 : 12.0;
      final radius = isTouched ? 60.0 : 50.0;
      final percentage = (categoryEntry.value / total * 100).toStringAsFixed(1);

      return PieChartSectionData(
        color: _getCategoryColor(index),
        value: categoryEntry.value,
        title: '$percentage%',
        radius: radius,
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: const [Shadow(color: Colors.black26, blurRadius: 2)],
        ),
      );
    }).toList();
  }

  Widget _buildLegend() {
    final entries = widget.report.expensesByCategory.entries.toList();

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: entries.asMap().entries.map((entry) {
        final index = entry.key;
        final categoryEntry = entry.value;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: _getCategoryColor(index),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '${_getCategoryDisplayName(categoryEntry.key)}: \$${categoryEntry.value.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        );
      }).toList(),
    );
  }

  Color _getCategoryColor(int index) {
    final colors = [
      Colors.blue,
      Colors.orange,
      Colors.green,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.amber,
      Colors.pink,
    ];
    return colors[index % colors.length];
  }

  String _getCategoryDisplayName(String category) {
    switch (category) {
      case 'airfare':
        return 'Airfare';
      case 'mileage':
        return 'Mileage';
      case 'parking':
        return 'Parking';
      case 'mealsAndPerDiem':
        return 'Meals & Per Diem';
      case 'lodging':
        return 'Lodging';
      case 'other':
        return 'Other';
      default:
        return category;
    }
  }
}
