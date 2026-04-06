import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/network/api_client.dart';
import '../../shared/models.dart';
import '../../shared/widgets/period_selector.dart';
import 'widgets/analytics_widgets.dart';
import 'widgets/overview_tab.dart';
import 'widgets/categories_tab.dart';
import 'widgets/items_tab.dart';
import 'widgets/merchants_tab.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  Period _period = Period.month;
  DateTimeRange? _customRange;
  int _tab = 0;

  // Data per tab — loaded lazily
  Map<String, dynamic>? _summary;
  List<Transaction> _transactions = [];
  Map<String, dynamic>? _categoryData;
  Map<String, dynamic>? _itemData;
  Map<String, dynamic>? _merchantData;

  // Loading flags per tab
  bool _loadingOverview = false;
  bool _loadingCategories = false;
  bool _loadingItems = false;
  bool _loadingMerchants = false;

  // Track which tabs have been loaded for this period
  final _loaded = <int>{};

  @override
  void initState() {
    super.initState();
    _loadTab(0);
  }

  String? get _from {
    if (_period == Period.custom) {
      return _customRange?.start.toUtc().toIso8601String();
    }
    final now = DateTime.now();
    return switch (_period) {
      Period.week =>
        now.subtract(const Duration(days: 7)).toUtc().toIso8601String(),
      Period.month =>
        DateTime(now.year, now.month, 1).toUtc().toIso8601String(),
      Period.year => DateTime(now.year, 1, 1).toUtc().toIso8601String(),
      Period.all => null,
      _ => null,
    };
  }

  String? get _to {
    if (_period == Period.custom) {
      return _customRange?.end.toUtc().toIso8601String();
    }
    return null;
  }

  void _onPeriodChanged(Period p, DateTimeRange? range) {
    setState(() {
      _period = p;
      _customRange = range;
      _loaded.clear();
    });
    _loadTab(_tab);
  }

  Future<void> _loadTab(int tab) async {
    if (_loaded.contains(tab)) return;
    final api = ref.read(apiClientProvider);
    final p = _period.apiValue;

    switch (tab) {
      case 0:
        setState(() => _loadingOverview = true);
        try {
          final results = await Future.wait([
            api.fetchAnalyticsSummary(period: p, from: _from, to: _to),
            api.fetchTransactions(from: _from, to: _to, limit: 500),
          ]);
          setState(() {
            _summary = results[0] as Map<String, dynamic>;
            _transactions = (results[1] as List)
                .map((e) => Transaction.fromJson(e as Map<String, dynamic>))
                .toList();
            _loadingOverview = false;
            _loaded.add(0);
          });
        } catch (_) {
          setState(() => _loadingOverview = false);
        }
        break;
      case 1:
        setState(() => _loadingCategories = true);
        try {
          final data = await api.fetchAnalyticsByCategory(
              period: p, from: _from, to: _to);
          setState(() {
            _categoryData = data as Map<String, dynamic>?;
            _loadingCategories = false;
            _loaded.add(1);
          });
        } catch (_) {
          setState(() => _loadingCategories = false);
        }
        break;
      case 2:
        setState(() => _loadingItems = true);
        try {
          final data =
              await api.fetchAnalyticsByItem(period: p, from: _from, to: _to);
          setState(() {
            _itemData = data as Map<String, dynamic>?;
            _loadingItems = false;
            _loaded.add(2);
          });
        } catch (_) {
          setState(() => _loadingItems = false);
        }
        break;
      case 3:
        setState(() => _loadingMerchants = true);
        try {
          final data = await api.fetchAnalyticsByMerchant(
              period: p, from: _from, to: _to);
          setState(() {
            _merchantData = data as Map<String, dynamic>?;
            _loadingMerchants = false;
            _loaded.add(3);
          });
        } catch (_) {
          setState(() => _loadingMerchants = false);
        }
        break;
    }
  }

  void _onTabChanged(int tab) {
    setState(() => _tab = tab);
    _loadTab(tab);
  }

  Future<void> _refresh() async {
    _loaded.clear();
    await _loadTab(_tab);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surfaceHigh,
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Analytics',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      PeriodSelector(
                        selected: _period,
                        customRange: _customRange,
                        onChanged: _onPeriodChanged,
                      ),
                      const SizedBox(height: 16),
                      AnalyticsTabBar(
                        selected: _tab,
                        onChanged: _onTabChanged,
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, bottom + 100),
                sliver: SliverToBoxAdapter(
                  child: _buildCurrentTab(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentTab() {
    return switch (_tab) {
      0 => OverviewTab(
          summary: _summary,
          transactions: _transactions,
          period: _period.apiValue,
          loading: _loadingOverview,
        ),
      1 => CategoriesTab(
          data: _categoryData,
          loading: _loadingCategories,
        ),
      2 => ItemsTab(
          data: _itemData,
          loading: _loadingItems,
        ),
      3 => MerchantsTab(
          data: _merchantData,
          loading: _loadingMerchants,
        ),
      _ => const SizedBox.shrink(),
    };
  }
}
