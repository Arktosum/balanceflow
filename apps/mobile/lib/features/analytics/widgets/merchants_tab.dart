import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../shared/models.dart';
import 'analytics_widgets.dart';

class MerchantsTab extends StatelessWidget {
  final Map<String, dynamic>? data;
  final bool loading;

  const MerchantsTab({super.key, required this.data, required this.loading});

  List<Map<String, dynamic>> get _merchants {
    final m = data?['merchants'] as List?;
    if (m == null) return [];
    return m.cast<Map<String, dynamic>>();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Column(
        children: List.generate(
          5,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AnalyticsShimmer(height: 64),
          ),
        ),
      );
    }

    if (_merchants.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Text('No merchant data for this period',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        ),
      );
    }

    final maxTotal = _merchants.fold<double>(
        0, (m, e) => toDouble(e['total']) > m ? toDouble(e['total']) : m);

    return SectionCard(
      title: 'Top Merchants',
      child: Column(
        children: _merchants.asMap().entries.map((entry) {
          final i = entry.key;
          final m = entry.value;
          final total = toDouble(m['total']);
          final count = (m['transaction_count'] as int?) ?? 0;
          final name = m['merchant_name'] as String? ?? 'Unknown';
          final fraction = maxTotal > 0 ? total / maxTotal : 0.0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                // Rank
                SizedBox(
                  width: 24,
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            fmtCurrency(total),
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: fraction,
                                backgroundColor:
                                    AppColors.primary.withOpacity(0.1),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    AppColors.primary),
                                minHeight: 4,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '$count tx',
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
