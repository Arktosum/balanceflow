import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme.dart';
import '../../../shared/models.dart';
import 'analytics_widgets.dart';

class OverviewTab extends StatelessWidget {
  final Map<String, dynamic>? summary;
  final List<Transaction> transactions;
  final String period;
  final bool loading;

  const OverviewTab({
    super.key,
    required this.summary,
    required this.transactions,
    required this.period,
    required this.loading,
  });

  // ── Build trend data from transactions ─────────────────────────────────────

  List<_TrendPoint> _buildTrend() {
    if (transactions.isEmpty) return [];

    // Determine bucket key function based on period
    String Function(DateTime) key;
    if (period == 'week') {
      key = (d) =>
          '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
    } else if (period == 'month') {
      key = (d) => '${d.day}';
    } else {
      // year / all / custom — bucket by month
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      key = (d) => months[d.month - 1];
    }

    final income = <String, double>{};
    final expense = <String, double>{};

    for (final tx in transactions) {
      if (tx.status != 'completed') continue;
      final k = key(tx.date);
      if (tx.type == 'income') {
        income[k] = (income[k] ?? 0) + tx.amount;
      } else if (tx.type == 'expense') {
        expense[k] = (expense[k] ?? 0) + tx.amount;
      }
    }

    final keys = {...income.keys, ...expense.keys}.toList()..sort();
    return keys
        .map((k) => _TrendPoint(
              label: k,
              income: income[k] ?? 0,
              expense: expense[k] ?? 0,
            ))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Column(
        children: [
          const AnalyticsShimmer(height: 120),
          const SizedBox(height: 16),
          const AnalyticsShimmer(height: 240),
        ],
      );
    }

    final income = toDouble(summary?['total_income']);
    final expenses = toDouble(summary?['total_expenses']);
    final net = toDouble(summary?['net_change']);
    final txCount = (summary?['transaction_count'] as int?) ?? 0;
    final trend = _buildTrend();

    return Column(
      children: [
        SummaryChips(
          income: income,
          expenses: expenses,
          net: net,
          txCount: txCount,
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Income vs Expenses',
          child:
              trend.isEmpty ? const _EmptyChart() : _TrendChart(points: trend),
        ),
      ],
    );
  }
}

// ── Trend chart ───────────────────────────────────────────────────────────────

class _TrendPoint {
  final String label;
  final double income;
  final double expense;
  const _TrendPoint(
      {required this.label, required this.income, required this.expense});
}

class _TrendChart extends StatelessWidget {
  final List<_TrendPoint> points;
  const _TrendChart({required this.points});

  double get _maxY {
    double m = 0;
    for (final p in points) {
      if (p.income > m) m = p.income;
      if (p.expense > m) m = p.expense;
    }
    return m == 0 ? 100 : m * 1.2;
  }

  @override
  Widget build(BuildContext context) {
    final maxY = _maxY;
    // Only show every nth label to avoid crowding
    final step = points.length > 15 ? (points.length / 7).ceil() : 1;

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.surfaceHigh,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final p = points[group.x];
                final label = rodIndex == 0 ? 'Income' : 'Expenses';
                final value = rodIndex == 0 ? p.income : p.expense;
                final color =
                    rodIndex == 0 ? AppColors.income : AppColors.expense;
                return BarTooltipItem(
                  '$label\n${_fmt(value)}',
                  TextStyle(
                      color: color, fontSize: 12, fontWeight: FontWeight.w600),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 48,
                getTitlesWidget: (v, _) => Text(
                  _fmtAxis(v),
                  style:
                      const TextStyle(color: AppColors.textMuted, fontSize: 10),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i % step != 0) return const SizedBox.shrink();
                  if (i < 0 || i >= points.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      points[i].label,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 10),
                    ),
                  );
                },
              ),
            ),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 4,
            getDrawingHorizontalLine: (_) => FlLine(
              color: AppColors.border,
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(points.length, (i) {
            final p = points[i];
            return BarChartGroupData(
              x: i,
              barsSpace: 3,
              barRods: [
                BarChartRodData(
                  toY: p.income,
                  color: AppColors.income.withOpacity(0.8),
                  width: 8,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(4)),
                ),
                BarChartRodData(
                  toY: p.expense,
                  color: AppColors.expense.withOpacity(0.8),
                  width: 8,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  String _fmt(double v) {
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(1)}K';
    return '₹${v.toStringAsFixed(0)}';
  }

  String _fmtAxis(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(0)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 100,
      child: Center(
        child: Text(
          'No data for this period',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      ),
    );
  }
}
