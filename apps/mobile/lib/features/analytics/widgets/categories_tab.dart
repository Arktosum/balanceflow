import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme.dart';
import '../../../shared/models.dart';
import 'analytics_widgets.dart';

class CategoriesTab extends StatefulWidget {
  final Map<String, dynamic>? data;
  final bool loading;

  const CategoriesTab({super.key, required this.data, required this.loading});

  @override
  State<CategoriesTab> createState() => _CategoriesTabState();
}

class _CategoriesTabState extends State<CategoriesTab> {
  int? _touchedIndex;

  List<Map<String, dynamic>> get _categories {
    final cats = widget.data?['categories'] as List?;
    if (cats == null) return [];
    return cats.cast<Map<String, dynamic>>();
  }

  double get _total => toDouble(widget.data?['total']);

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return Column(
        children: [
          const AnalyticsShimmer(height: 260),
          const SizedBox(height: 16),
          const AnalyticsShimmer(height: 200),
        ],
      );
    }

    if (_categories.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Text('No expense data for this period',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        ),
      );
    }

    return Column(
      children: [
        SectionCard(
          title: 'Spending by Category',
          child: _buildPieChart(),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Breakdown',
          child: _buildList(),
        ),
      ],
    );
  }

  Widget _buildPieChart() {
    return SizedBox(
      height: 220,
      child: PieChart(
        PieChartData(
          pieTouchData: PieTouchData(
            touchCallback: (event, response) {
              if (!event.isInterestedForInteractions) {
                setState(() => _touchedIndex = null);
                return;
              }
              setState(() => _touchedIndex =
                  response?.touchedSection?.touchedSectionIndex);
            },
          ),
          sections: List.generate(_categories.length, (i) {
            final cat = _categories[i];
            final total = toDouble(cat['total']);
            final pct = _total > 0 ? (total / _total * 100) : 0.0;
            final color = parseHexColor(cat['category_color'] as String?);
            final isTouched = _touchedIndex == i;

            return PieChartSectionData(
              value: total,
              color: color,
              radius: isTouched ? 90 : 75,
              title: isTouched ? '${pct.toStringAsFixed(1)}%' : '',
              titleStyle: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              badgeWidget: isTouched
                  ? null
                  : Text(
                      cat['category_icon'] as String? ?? '📁',
                      style: const TextStyle(fontSize: 14),
                    ),
              badgePositionPercentageOffset: 0.85,
            );
          }),
          centerSpaceRadius: 50,
          sectionsSpace: 2,
        ),
      ),
    );
  }

  Widget _buildList() {
    return Column(
      children: List.generate(_categories.length, (i) {
        final cat = _categories[i];
        final total = toDouble(cat['total']);
        final pct = (cat['percentage'] as int?) ?? 0;
        final color = parseHexColor(cat['category_color'] as String?);
        final count = (cat['transaction_count'] as int?) ?? 0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    cat['category_icon'] as String? ?? '📁',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      cat['category_name'] as String? ?? 'Uncategorised',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '₹${_fmtShort(total)}',
                    style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '$pct%',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const SizedBox(width: 26),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _total > 0 ? total / _total : 0,
                        backgroundColor: color.withOpacity(0.12),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                        minHeight: 4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$count tx',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        );
      }),
    );
  }

  String _fmtShort(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}
