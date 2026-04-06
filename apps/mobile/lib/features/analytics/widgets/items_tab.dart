import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme.dart';
import '../../../shared/models.dart';
import 'analytics_widgets.dart';

class ItemsTab extends StatefulWidget {
  final Map<String, dynamic>? data;
  final bool loading;

  const ItemsTab({super.key, required this.data, required this.loading});

  @override
  State<ItemsTab> createState() => _ItemsTabState();
}

class _ItemsTabState extends State<ItemsTab> {
  String? _expandedItemId;

  List<Map<String, dynamic>> get _items {
    final items = widget.data?['top_items'] as List?;
    if (items == null) return [];
    return items.cast<Map<String, dynamic>>();
  }

  Map<String, dynamic> get _priceHistory {
    return (widget.data?['price_history'] as Map<String, dynamic>?) ?? {};
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return Column(
        children: List.generate(
          4,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AnalyticsShimmer(height: 72),
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Text('No item data for this period',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        ),
      );
    }

    return SectionCard(
      title: 'Top Items by Spend',
      child: Column(
        children: _items.map((item) {
          final id = item['item_id'] as String;
          final isExpanded = _expandedItemId == id;
          return _ItemTile(
            item: item,
            expanded: isExpanded,
            history: _priceHistory[id] as List? ?? [],
            onTap: () =>
                setState(() => _expandedItemId = isExpanded ? null : id),
          );
        }).toList(),
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool expanded;
  final List history;
  final VoidCallback onTap;

  const _ItemTile({
    required this.item,
    required this.expanded,
    required this.history,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final totalSpent = toDouble(item['total_spent']);
    final avgPrice = toDouble(item['avg_price']);
    final count = (item['purchase_count'] as int?) ?? 0;
    final name = item['item_name'] as String? ?? '—';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: expanded
              ? AppColors.primary.withOpacity(0.05)
              : AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: expanded
                ? AppColors.primary.withOpacity(0.3)
                : AppColors.border,
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            )),
                        const SizedBox(height: 3),
                        Text(
                          '$count purchase${count != 1 ? 's' : ''}  ·  avg ${fmtCurrency(avgPrice)}',
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        fmtCurrency(totalSpent),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Icon(
                        expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (expanded && history.length > 1) ...[
              const Divider(height: 1, color: AppColors.border),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: _PriceHistoryChart(history: history),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PriceHistoryChart extends StatelessWidget {
  final List history;
  const _PriceHistoryChart({required this.history});

  @override
  Widget build(BuildContext context) {
    final spots = history.asMap().entries.map((e) {
      final price = toDouble((e.value as Map)['price']);
      return FlSpot(e.key.toDouble(), price);
    }).toList();

    final prices = spots.map((s) => s.y).toList();
    final minY = prices.reduce((a, b) => a < b ? a : b);
    final maxY = prices.reduce((a, b) => a > b ? a : b);
    final padding = (maxY - minY) * 0.2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Price history',
            style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        SizedBox(
          height: 120,
          child: LineChart(
            LineChartData(
              minY: minY - padding,
              maxY: maxY + padding,
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => AppColors.surfaceHigh,
                  getTooltipItems: (spots) => spots
                      .map((s) => LineTooltipItem(
                            fmtCurrency(s.y),
                            const TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                          ))
                      .toList(),
                ),
              ),
              titlesData: const FlTitlesData(
                leftTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: AppColors.primary,
                  barWidth: 2.5,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                      radius: 3,
                      color: AppColors.primary,
                      strokeWidth: 0,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: AppColors.primary.withOpacity(0.08),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
