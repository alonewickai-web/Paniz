import 'dart:math' as math;
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/admin_api.dart';
import '../../core/providers.dart';

class SeoAnalyticsScreen extends ConsumerStatefulWidget {
  const SeoAnalyticsScreen({super.key, required this.admin});
  final AdminIdentity admin;

  @override
  ConsumerState<SeoAnalyticsScreen> createState() => _SeoAnalyticsScreenState();
}

class _SeoAnalyticsScreenState extends ConsumerState<SeoAnalyticsScreen> {
  String _range = '28';
  DateTimeRange? _customRange;
  String _chartMetric = 'googleClicks';
  bool _barChart = false;
  int _selectedPoint = -1;
  String _querySort = 'clicks';
  String _productSort = 'gaPageViews';
  String _category = 'همه';
  String _productSearch = '';
  String _productFilter = 'all';
  int _visibleProducts = 25;
  int _visibleQueries = 25;
  bool _exporting = false;
  String _exportType = 'products';

  String get _rangeKey {
    if (_range != 'custom' || _customRange == null) return _range;
    return 'custom:${_dateKey(_customRange!.start)}:${_dateKey(_customRange!.end)}';
  }

  Future<void> _selectCustomRange() async {
    final now = DateTime.now();
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1, now.month, now.day),
      lastDate: now,
      initialDateRange: _customRange,
      helpText: 'بازهٔ دلخواه گزارش',
      saveText: 'نمایش گزارش',
    );
    if (selected == null || !mounted) return;
    setState(() {
      _range = 'custom';
      _customRange = selected;
      _selectedPoint = -1;
    });
  }

  Future<void> _exportReport(String type, {bool excel = false}) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final api = ref.read(adminApiProvider);
      final from =
          _range == 'custom' && _customRange != null
              ? _dateKey(_customRange!.start)
              : null;
      final to =
          _range == 'custom' && _customRange != null
              ? _dateKey(_customRange!.end)
              : null;
      final category =
          type == 'products' && _category != 'همه' ? _category : null;
      final bytes =
          excel
              ? await api.seoAnalyticsXlsx(
                range: _range,
                type: type,
                from: from,
                to: to,
                category: category,
              )
              : Uint8List.fromList(
                utf8.encode(
                  await api.seoAnalyticsCsv(
                    range: _range,
                    type: type,
                    from: from,
                    to: to,
                    category: category,
                  ),
                ),
              );
      const channel = MethodChannel('paniz/admin-reports');
      final saved = await channel.invokeMethod<bool>('saveReport', {
        'bytes': bytes,
        'filename': 'paniz-seo-$type.${excel ? 'xlsx' : 'csv'}',
        'mimeType':
            excel
                ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
                : 'text/csv',
      });
      if (mounted && saved == true)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('فایل گزارش ذخیره شد.')));
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AdminApi.friendlyError(error))));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.admin.can('reports.view')) {
      return const Center(
        child: Text('دسترسی به گزارش سئو برای این حساب فعال نیست.'),
      );
    }
    final report = ref.watch(seoAnalyticsProvider(_rangeKey));
    return report.when(
      loading: () => const _SeoLoading(),
      error:
          (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off_rounded, size: 42),
                  const SizedBox(height: 14),
                  Text(
                    AdminApi.friendlyError(error),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed:
                        () => ref.invalidate(seoAnalyticsProvider(_rangeKey)),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('تلاش دوباره'),
                  ),
                ],
              ),
            ),
          ),
      data: (data) => _buildReport(context, data),
    );
  }

  Widget _buildReport(BuildContext context, JsonMap data) {
    final sources = _map(data['sources']);
    final googleSource = _map(sources['searchConsole']);
    final analyticsSource = _map(sources['analytics']);
    final metrics = _map(data['metrics']);
    final google = _map(metrics['google']);
    final analytics = _map(metrics['analytics']);
    final store = _map(metrics['store']);
    final comparison = _map(metrics['comparison']);
    final daily = _rows(data['daily']);
    final pages = _sortedPages(_rows(data['pages']));
    final queries = _sortedQueries(_rows(data['queries']));
    final products = _sortedProducts(_rows(data['products']));
    final alerts = _rows(data['alerts']);
    final audit = _map(data['audit']);
    final range = _map(data['range']);
    final notes =
        (data['notes'] as List? ?? const []).map((item) => '$item').toList();

    final cards = <_Kpi>[
      _Kpi(
        'بازدیدکنندگان',
        analytics['users'],
        Icons.people_outline_rounded,
        'GA4',
        comparison['users'],
      ),
      _Kpi(
        'کلیک‌های گوگل',
        google['clicks'],
        Icons.touch_app_outlined,
        'Search Console',
        comparison['googleClicks'],
      ),
      _Kpi(
        'نمایش در گوگل',
        google['impressions'],
        Icons.visibility_outlined,
        'Search Console',
        comparison['googleImpressions'],
      ),
      _Kpi(
        'میانگین رتبه',
        google['averagePosition'],
        Icons.leaderboard_outlined,
        'Search Console',
        comparison['averagePosition'],
        decimal: true,
        inverse: true,
      ),
      _Kpi(
        'نرخ کلیک',
        google['ctrPercent'],
        Icons.ads_click_outlined,
        'Search Console',
        comparison['googleCtr'],
        percentage: true,
      ),
      _Kpi(
        'کاربران فعال',
        analytics['activeUsers'],
        Icons.person_pin_circle_outlined,
        'GA4',
        comparison['activeUsers'],
      ),
      _Kpi(
        'نرخ تبدیل فروش',
        store['conversionPercent'],
        Icons.shopping_bag_outlined,
        'فروشگاه ÷ GA4',
        comparison['conversionPercent'],
        percentage: true,
      ),
      _Kpi(
        'درآمد جست‌وجوی گوگل',
        store['organicRevenueToman'],
        Icons.payments_outlined,
        'GA4 · تومان',
        comparison['organicRevenue'],
        currency: true,
      ),
    ];

    return RefreshIndicator(
      onRefresh:
          () =>
              ref.refresh(seoAnalyticsProvider(_rangeKey).future).then((_) {}),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(
            'سئو و تحلیل بازدید',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            'آمار جست‌وجو، رفتار بازدیدکنندگان و فروش‌های پرداخت‌شده',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in [
                ('7', '۷ روز'),
                ('28', '۲۸ روز'),
                ('90', '۹۰ روز'),
              ])
                ChoiceChip(
                  label: Text(entry.$2),
                  selected: _range == entry.$1,
                  onSelected:
                      (_) => setState(() {
                        _range = entry.$1;
                        _selectedPoint = -1;
                      }),
                ),
              ActionChip(
                avatar: const Icon(Icons.date_range_outlined, size: 18),
                label: Text(
                  _range == 'custom' && _customRange != null
                      ? '${_fa(_dateKey(_customRange!.start))} تا ${_fa(_dateKey(_customRange!.end))}'
                      : 'بازهٔ دلخواه',
                ),
                onPressed: _selectCustomRange,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'از ${_fa(range['start'])} تا ${_fa(range['end'])}',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          if (data['lastSyncedAt'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'آخرین دریافت گزارش گوگل: ${_fa('${data['lastSyncedAt']}'.replaceFirst('T', ' ').split('.').first)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 14),
          _SourceCard(
            title: 'Google Search Console',
            source: googleSource,
            icon: Icons.search_rounded,
          ),
          const SizedBox(height: 8),
          _SourceCard(
            title: 'Google Analytics 4',
            source: analyticsSource,
            icon: Icons.insights_rounded,
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final card in cards)
                    SizedBox(width: width, child: _KpiCard(kpi: card)),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Text(
            'کاربر جدید: ${_number(analytics['newUsers'])} · نشست: ${_number(analytics['sessions'])} · رویداد خرید موفق GA4: ${_number(analytics['ecommercePurchases'])}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          _sectionHeading('روند بازدید و جست‌وجو', Icons.show_chart_rounded),
          const SizedBox(height: 10),
          _buildChart(context, daily),
          const SizedBox(height: 16),
          _sectionHeading('منابع ورود و دستگاه‌ها', Icons.devices_outlined),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                for (final row in _rows(data['trafficSources']))
                  ListTile(
                    title: Text(_sourceName('${row['source'] ?? ''}')),
                    trailing: Text('${_number(row['sessions'])} نشست'),
                  ),
                for (final row in _rows(data['devices']))
                  ListTile(
                    title: Text(_sourceName('${row['device'] ?? ''}')),
                    subtitle: Text('${_number(row['users'])} کاربر'),
                    trailing: Text('${_number(row['sessions'])} نشست'),
                  ),
                if (_rows(data['trafficSources']).isEmpty &&
                    _rows(data['devices']).isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(18),
                    child: Text(
                      'پس از اتصال GA4، منابع ورود و دستگاه‌ها نمایش داده می‌شوند.',
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _sectionHeading('صفحه‌های پربازدید', Icons.open_in_new_rounded),
          const SizedBox(height: 8),
          _buildPages(context, pages, analyticsSource),
          const SizedBox(height: 20),
          _sectionHeading('هشدارها و بررسی فنی', Icons.fact_check_outlined),
          const SizedBox(height: 8),
          if (alerts.isEmpty)
            const _EmptyCard(text: 'برای این بازه هشداری ثبت نشده است.'),
          for (final alert in alerts)
            Card(
              child: ListTile(
                leading: Icon(
                  alert['level'] == 'warning'
                      ? Icons.warning_amber_rounded
                      : Icons.info_outline_rounded,
                  color:
                      alert['level'] == 'warning'
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.primary,
                ),
                title: Text('${alert['message'] ?? ''}'),
                subtitle: Text('${alert['source'] ?? ''}'),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'محصول منتشرشده: ${_number(audit['publishedProducts'])} · بدون عنوان اختصاصی: ${_number(audit['missingSeoTitle'])} · بدون توضیح اختصاصی: ${_number(audit['missingSeoDescription'])} · تصویر بدون alt: ${_number(audit['imagesMissingAlt'])}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          _sectionHeading(
            'عبارت‌های جست‌وجوی گوگل',
            Icons.manage_search_rounded,
          ),
          const SizedBox(height: 8),
          _buildQueries(context, queries, googleSource),
          const SizedBox(height: 20),
          _sectionHeading('عملکرد محصولات', Icons.checkroom_outlined),
          const SizedBox(height: 8),
          _buildProducts(context, products),
          const SizedBox(height: 20),
          _sectionHeading('گزارش‌ها', Icons.file_download_outlined),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _exportType,
                    decoration: const InputDecoration(labelText: 'گزارش خروجی'),
                    items: const [
                      DropdownMenuItem(
                        value: 'products',
                        child: Text('عملکرد محصولات'),
                      ),
                      DropdownMenuItem(
                        value: 'queries',
                        child: Text('عبارت‌های جست‌وجو'),
                      ),
                      DropdownMenuItem(
                        value: 'pages',
                        child: Text('صفحه‌های پربازدید'),
                      ),
                      DropdownMenuItem(
                        value: 'summary',
                        child: Text('خلاصه و مقایسهٔ دوره‌ها'),
                      ),
                    ],
                    onChanged:
                        (value) =>
                            setState(() => _exportType = value ?? 'products'),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed:
                            _exporting
                                ? null
                                : () => _exportReport(_exportType),
                        icon: const Icon(Icons.file_download_outlined),
                        label: const Text('ذخیرهٔ CSV'),
                      ),
                      FilledButton.icon(
                        onPressed:
                            _exporting
                                ? null
                                : () => _exportReport(_exportType, excel: true),
                        icon: const Icon(Icons.table_chart_outlined),
                        label: const Text('ذخیرهٔ Excel'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          for (final note in notes)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '• $note',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChart(BuildContext context, List<JsonMap> daily) {
    final columns = <(String, String, String)>[
      ('googleClicks', 'previousGoogleClicks', 'کلیک گوگل'),
      ('googleImpressions', 'previousGoogleImpressions', 'نمایش در گوگل'),
      ('visitors', 'previousVisitors', 'بازدیدکنندگان GA4'),
    ];
    final active = columns.firstWhere((entry) => entry.$1 == _chartMetric);
    final current = daily.map((item) => _double(item[active.$1])).toList();
    final previous = daily.map((item) => _double(item[active.$2])).toList();
    final hasData = current.any((value) => value != null);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 5,
              children: [
                for (final item in columns)
                  ChoiceChip(
                    label: Text(item.$3),
                    selected: _chartMetric == item.$1,
                    onSelected:
                        (_) => setState(() {
                          _chartMetric = item.$1;
                          _selectedPoint = -1;
                        }),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Expanded(
                  child: Text('این دوره: خط پررنگ · دورهٔ قبل: خط کم‌رنگ'),
                ),
                IconButton(
                  tooltip: 'نمودار خطی',
                  onPressed: () => setState(() => _barChart = false),
                  icon: Icon(
                    Icons.show_chart_rounded,
                    color:
                        !_barChart
                            ? Theme.of(context).colorScheme.primary
                            : null,
                  ),
                ),
                IconButton(
                  tooltip: 'نمودار ستونی',
                  onPressed: () => setState(() => _barChart = true),
                  icon: Icon(
                    Icons.bar_chart_rounded,
                    color:
                        _barChart
                            ? Theme.of(context).colorScheme.primary
                            : null,
                  ),
                ),
              ],
            ),
            if (!hasData)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 25),
                child: Center(
                  child: Text('هنوز دادهٔ متصل برای این نمودار وجود ندارد.'),
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = math.max(
                    constraints.maxWidth,
                    daily.length * (_barChart ? 14.0 : 10.0),
                  );
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Semantics(
                      label:
                          'نمودار ${active.$3}؛ برای مقدار دقیق روی روز موردنظر بزنید',
                      child: GestureDetector(
                        onTapDown: (details) {
                          final index =
                              ((details.localPosition.dx - 12) /
                                      math.max(1, width - 24) *
                                      math.max(1, daily.length - 1))
                                  .round()
                                  .clamp(0, daily.length - 1)
                                  .toInt();
                          setState(() => _selectedPoint = index);
                        },
                        child: CustomPaint(
                          key: const ValueKey('seo-chart'),
                          size: Size(width, 205),
                          painter: _SeoChartPainter(
                            current: current,
                            previous: previous,
                            selected: _selectedPoint,
                            bar: _barChart,
                            primary: Theme.of(context).colorScheme.primary,
                            secondary: Theme.of(context).colorScheme.tertiary,
                            grid: Theme.of(context).dividerColor,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            if (hasData && daily.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _fa(daily.first['date']),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  Text(
                    _fa(daily.last['date']),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            if (_selectedPoint >= 0 && _selectedPoint < daily.length)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${_fa(daily[_selectedPoint]['date'])}: ${_number(current[_selectedPoint])} · دورهٔ قبل: ${_number(previous[_selectedPoint])}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQueries(
    BuildContext context,
    List<JsonMap> queries,
    JsonMap source,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _querySort,
              decoration: const InputDecoration(labelText: 'مرتب‌سازی کلمات'),
              items: const [
                DropdownMenuItem(value: 'clicks', child: Text('بیشترین کلیک')),
                DropdownMenuItem(
                  value: 'impressions',
                  child: Text('بیشترین نمایش'),
                ),
                DropdownMenuItem(
                  value: 'averagePosition',
                  child: Text('بهترین رتبه'),
                ),
              ],
              onChanged:
                  (value) => setState(() => _querySort = value ?? 'clicks'),
            ),
            const SizedBox(height: 8),
            if (queries.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  source['state'] == 'connected'
                      ? 'گوگل برای این بازه عبارتی گزارش نکرده است.'
                      : 'برای دیدن عبارت‌ها، Search Console را متصل کن.',
                  textAlign: TextAlign.center,
                ),
              ),
            for (final row in queries.take(_visibleQueries)) ...[
              ListTile(
                dense: true,
                title: Text(
                  '${row['query'] ?? ''}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  'کلیک ${_number(row['clicks'])} · نمایش ${_number(row['impressions'])} · CTR ${_number(row['ctrPercent'])}٪ · رتبه ${_number(row['averagePosition'])}',
                ),
                trailing: Text(_changeLabel(row['clicksChangePercent'])),
              ),
              const Divider(height: 1),
            ],
            if (queries.length > _visibleQueries)
              TextButton(
                onPressed: () => setState(() => _visibleQueries += 25),
                child: const Text('نمایش عبارت‌های بیشتر'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProducts(BuildContext context, List<JsonMap> products) {
    final categories =
        <String>{
          'همه',
          ...products
              .map((item) => '${item['category'] ?? ''}')
              .where((value) => value.isNotEmpty),
        }.toList();
    if (!categories.contains(_category)) _category = 'همه';
    final filtered =
        products.where((item) {
          final categoryMatches =
              _category == 'همه' || item['category'] == _category;
          final query = _productSearch.trim().toLowerCase();
          final nameMatches =
              query.isEmpty ||
              '${item['name']} ${item['slug']}'.toLowerCase().contains(query);
          final impressions = _double(item['googleImpressions']);
          final clicks = _double(item['googleClicks']);
          final performanceMatches =
              _productFilter == 'all' ||
              (_productFilter == 'low-ctr' &&
                  impressions != null &&
                  impressions >= 20 &&
                  clicks != null &&
                  clicks / impressions < .01) ||
              (_productFilter == 'unmeasured' && clicks == null);
          return categoryMatches && nameMatches && performanceMatches;
        }).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                labelText: 'جست‌وجوی محصول',
              ),
              onChanged:
                  (value) => setState(() {
                    _productSearch = value;
                    _visibleProducts = 25;
                  }),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _category,
                    decoration: const InputDecoration(labelText: 'دسته‌بندی'),
                    items:
                        categories
                            .map(
                              (item) => DropdownMenuItem(
                                value: item,
                                child: Text(
                                  item,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                    onChanged:
                        (value) => setState(() {
                          _category = value ?? 'همه';
                          _visibleProducts = 25;
                        }),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _productSort,
                    decoration: const InputDecoration(labelText: 'مرتب‌سازی'),
                    items: const [
                      DropdownMenuItem(
                        value: 'gaPageViews',
                        child: Text('پربازدیدترین'),
                      ),
                      DropdownMenuItem(
                        value: 'googleClicks',
                        child: Text('بیشترین کلیک'),
                      ),
                      DropdownMenuItem(
                        value: 'googleImpressions',
                        child: Text('بیشترین نمایش'),
                      ),
                      DropdownMenuItem(
                        value: 'paidOrders',
                        child: Text('پرفروش‌ترین'),
                      ),
                    ],
                    onChanged:
                        (value) => setState(
                          () => _productSort = value ?? 'gaPageViews',
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final filter in [
                  ('all', 'همه'),
                  ('low-ctr', 'نمایش زیاد و کلیک کم'),
                  ('unmeasured', 'بدون دادهٔ جست‌وجو'),
                ])
                  ChoiceChip(
                    label: Text(filter.$2),
                    selected: _productFilter == filter.$1,
                    onSelected:
                        (_) => setState(() {
                          _productFilter = filter.$1;
                          _visibleProducts = 25;
                        }),
                  ),
              ],
            ),
            if (filtered.isEmpty)
              const Padding(
                padding: EdgeInsets.all(18),
                child: Text(
                  'محصولی برای این فیلتر پیدا نشد.',
                  textAlign: TextAlign.center,
                ),
              ),
            for (final row in filtered.take(_visibleProducts)) ...[
              ListTile(
                onTap: () => _showProductDetails(context, row),
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
                leading: SizedBox(
                  width: 54,
                  height: 54,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child:
                        row['imagePath'] is String &&
                                '${row['imagePath']}'.isNotEmpty
                            ? Image.network(
                              AdminApi.imageUrl('${row['imagePath']}'),
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (_, _, _) => const Icon(
                                    Icons.image_not_supported_outlined,
                                  ),
                            )
                            : const Icon(Icons.image_not_supported_outlined),
                  ),
                ),
                title: Text(
                  '${row['name'] ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  'کلیک ${_number(row['googleClicks'])} · نمایش ${_number(row['googleImpressions'])} · بازدید ${_number(row['gaPageViews'])}\nرتبه ${_number(row['averagePosition'])} · فروش ${_number(row['unitsSold'])} عدد · تبدیل ${_number(row['productConversionPercent'])}٪',
                ),
                isThreeLine: true,
              ),
              const Divider(height: 1),
            ],
            if (filtered.length > _visibleProducts)
              TextButton(
                onPressed: () => setState(() => _visibleProducts += 25),
                child: const Text('نمایش محصولات بیشتر'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPages(
    BuildContext context,
    List<JsonMap> pages,
    JsonMap source,
  ) => Card(
    child: Column(
      children: [
        if (pages.isEmpty)
          Padding(
            padding: const EdgeInsets.all(18),
            child: Text(
              source['state'] == 'connected'
                  ? 'برای این بازه صفحه‌ای در گزارش GA4 ثبت نشده است.'
                  : 'پس از اتصال GA4، صفحه‌های پربازدید اینجا نمایش داده می‌شوند.',
              textAlign: TextAlign.center,
            ),
          ),
        for (final page in pages.take(20))
          ListTile(
            onTap: () => _showPageDetails(context, page),
            leading: const Icon(Icons.article_outlined),
            title: Text(
              '${page['title'] ?? 'صفحه'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${page['path'] ?? ''}\nکلیک گوگل ${_number(page['googleClicks'])} · نمایش ${_number(page['googleImpressions'])}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            isThreeLine: true,
            trailing: Text('${_number(page['gaPageViews'])} بازدید'),
          ),
      ],
    ),
  );

  List<JsonMap> _sortedPages(List<JsonMap> rows) {
    rows.sort(
      (left, right) => (_double(right['gaPageViews']) ?? -1).compareTo(
        _double(left['gaPageViews']) ?? -1,
      ),
    );
    return rows;
  }

  void _showProductDetails(BuildContext context, JsonMap product) {
    _showDetails(
      context,
      title: '${product['name'] ?? 'محصول'}',
      path:
          '${product['url'] ?? 'https://panizstyle.ir/products/${product['slug'] ?? ''}'}',
      rows: [
        ('کلیک گوگل', product['googleClicks']),
        ('نمایش گوگل', product['googleImpressions']),
        ('میانگین رتبه', product['averagePosition']),
        ('بازدید صفحه از GA4', product['gaPageViews']),
        ('سفارش پرداخت‌شده', product['paidOrders']),
        ('تعداد کالای فروش‌رفته', product['unitsSold']),
        (
          'نرخ تبدیل محصول',
          product['productConversionPercent'] == null
              ? null
              : '${_number(product['productConversionPercent'])}٪',
        ),
      ],
    );
  }

  void _showPageDetails(BuildContext context, JsonMap page) => _showDetails(
    context,
    title: '${page['title'] ?? 'صفحه'}',
    path: 'https://panizstyle.ir${page['path'] ?? ''}',
    rows: [
      ('بازدید صفحه از GA4', page['gaPageViews']),
      ('کلیک گوگل', page['googleClicks']),
      ('نمایش گوگل', page['googleImpressions']),
      ('میانگین رتبه', page['averagePosition']),
    ],
  );

  void _showDetails(
    BuildContext context, {
    required String title,
    required String path,
    required List<(String, Object?)> rows,
  }) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder:
          (context) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  SelectableText(path, textDirection: TextDirection.ltr),
                  const Divider(height: 24),
                  for (final row in rows)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(child: Text(row.$1)),
                          Text(
                            row.$2 is String ? '${row.$2}' : _number(row.$2),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    'مقادیر «—» برای این صفحه از منبع مربوطه گزارش نشده‌اند.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
    );
  }

  List<JsonMap> _sortedQueries(List<JsonMap> rows) {
    rows.sort((left, right) {
      final leftValue = _double(left[_querySort]);
      final rightValue = _double(right[_querySort]);
      if (_querySort == 'averagePosition')
        return (leftValue ?? double.infinity).compareTo(
          rightValue ?? double.infinity,
        );
      return (rightValue ?? -1).compareTo(leftValue ?? -1);
    });
    return rows;
  }

  List<JsonMap> _sortedProducts(List<JsonMap> rows) {
    rows.sort(
      (left, right) => (_double(right[_productSort]) ?? -1).compareTo(
        _double(left[_productSort]) ?? -1,
      ),
    );
    return rows;
  }
}

class _Kpi {
  const _Kpi(
    this.title,
    this.value,
    this.icon,
    this.source,
    this.change, {
    this.percentage = false,
    this.currency = false,
    this.decimal = false,
    this.inverse = false,
  });
  final String title;
  final Object? value;
  final IconData icon;
  final String source;
  final Object? change;
  final bool percentage;
  final bool currency;
  final bool decimal;
  final bool inverse;
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.kpi});
  final _Kpi kpi;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            kpi.icon,
            color: Theme.of(context).colorScheme.primary,
            size: 22,
          ),
          const SizedBox(height: 9),
          Text(
            kpi.title,
            maxLines: 2,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 5),
          Text(
            '${_number(kpi.value)}${kpi.value == null
                ? ''
                : kpi.percentage
                ? '٪'
                : kpi.currency
                ? ' تومان'
                : ''}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text(
            kpi.source,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (kpi.change != null && kpi.value != null)
            Text(
              _changeLabel(kpi.change),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color:
                    (((_double(kpi.change) ?? 0) < 0) != kpi.inverse)
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.primary,
              ),
            ),
        ],
      ),
    ),
  );
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.title,
    required this.source,
    required this.icon,
  });
  final String title;
  final JsonMap source;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final state = '${source['state'] ?? ''}';
    final connected = state == 'connected';
    final label =
        connected
            ? 'متصل'
            : state == 'error'
            ? 'خطا در دریافت'
            : 'نیازمند اتصال';
    return Card(
      child: ListTile(
        leading: Icon(
          icon,
          color:
              connected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.error,
        ),
        title: Text(title),
        subtitle: Text(
          connected
              ? 'گزارش واقعی گوگل دریافت شد'
              : '${source['reason'] ?? 'تنظیمات اتصال کامل نیست.'}',
        ),
        trailing: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color:
                connected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.error,
          ),
        ),
      ),
    );
  }
}

class _SeoLoading extends StatelessWidget {
  const _SeoLoading();
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const LinearProgressIndicator(),
      const SizedBox(height: 18),
      Text(
        'در حال دریافت گزارش سئو و بازدید…',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 18),
      for (var index = 0; index < 4; index++) ...[
        const Card(child: SizedBox(height: 92)),
        const SizedBox(height: 8),
      ],
    ],
  );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: const EdgeInsets.all(18), child: Text(text)),
  );
}

class _SeoChartPainter extends CustomPainter {
  const _SeoChartPainter({
    required this.current,
    required this.previous,
    required this.selected,
    required this.bar,
    required this.primary,
    required this.secondary,
    required this.grid,
  });
  final List<double?> current;
  final List<double?> previous;
  final int selected;
  final bool bar;
  final Color primary;
  final Color secondary;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    final chart = Rect.fromLTWH(12, 10, size.width - 24, size.height - 24);
    final maxValue = math.max(
      1.0,
      [...current, ...previous].whereType<double>().fold<double>(0, math.max),
    );
    for (var index = 0; index <= 3; index++) {
      final y = chart.bottom - chart.height / 3 * index;
      canvas.drawLine(
        Offset(chart.left, y),
        Offset(chart.right, y),
        Paint()
          ..color = grid.withAlpha(90)
          ..strokeWidth = 1,
      );
    }
    Offset point(int index, double value) => Offset(
      chart.left +
          (current.length < 2
              ? chart.width / 2
              : index * chart.width / (current.length - 1)),
      chart.bottom - value / maxValue * chart.height,
    );
    if (bar) {
      final step = chart.width / math.max(1, current.length);
      for (var index = 0; index < current.length; index++) {
        final x = chart.left + step * index + step / 2;
        final first = current[index];
        final second = index < previous.length ? previous[index] : null;
        if (first != null)
          canvas.drawRect(
            Rect.fromLTWH(
              x - step * .36,
              chart.bottom - first / maxValue * chart.height,
              math.max(1, step * .34),
              first / maxValue * chart.height,
            ),
            Paint()..color = primary,
          );
        if (second != null)
          canvas.drawRect(
            Rect.fromLTWH(
              x + step * .02,
              chart.bottom - second / maxValue * chart.height,
              math.max(1, step * .34),
              second / maxValue * chart.height,
            ),
            Paint()..color = secondary.withAlpha(160),
          );
      }
    } else {
      for (final series in [
        (current, primary, 3.0),
        (previous, secondary.withAlpha(170), 2.0),
      ]) {
        final values = series.$1;
        final paint =
            Paint()
              ..color = series.$2
              ..strokeWidth = series.$3
              ..style = PaintingStyle.stroke
              ..strokeCap = StrokeCap.round;
        final path = Path();
        var open = false;
        for (var index = 0; index < values.length; index++) {
          final value = values[index];
          if (value == null) {
            open = false;
            continue;
          }
          final offset = point(index, value);
          if (open) {
            path.lineTo(offset.dx, offset.dy);
          } else {
            path.moveTo(offset.dx, offset.dy);
            open = true;
          }
        }
        canvas.drawPath(path, paint);
      }
    }
    if (selected >= 0 && selected < current.length) {
      final value = current[selected];
      if (value != null) {
        final dot = point(selected, value);
        canvas.drawCircle(dot, 6, Paint()..color = primary);
        canvas.drawCircle(dot, 3, Paint()..color = Colors.white);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SeoChartPainter old) =>
      old.current != current ||
      old.previous != previous ||
      old.selected != selected ||
      old.bar != bar ||
      old.primary != primary ||
      old.secondary != secondary ||
      old.grid != grid;
}

Widget _sectionHeading(String title, IconData icon) => Builder(
  builder:
      (context) => Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
);

JsonMap _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
List<JsonMap> _rows(Object? value) =>
    value is List ? value.map(_map).toList() : <JsonMap>[];
double? _double(Object? value) =>
    value is num ? value.toDouble() : double.tryParse('$value');
String _dateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
String _fa(Object? value) => '${value ?? ''}'.replaceAllMapped(
  RegExp(r'[0-9]'),
  (match) => '۰۱۲۳۴۵۶۷۸۹'[int.parse(match.group(0)!)],
);
String _number(Object? value) {
  if (value == null) return '—';
  final number = value is num ? value : num.tryParse('$value');
  if (number == null) return _fa(value);
  final text =
      number is int || number % 1 == 0
          ? number.toInt().toString()
          : number.toStringAsFixed(2);
  final parts = text.split('.');
  final whole = parts.first.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '٬',
  );
  return _fa(parts.length > 1 ? '$whole٫${parts[1]}' : whole);
}

String _changeLabel(Object? value) {
  final number = _double(value);
  if (number == null) return '—';
  return '${number >= 0 ? '+' : ''}${_number(number)}٪';
}

String _sourceName(String value) =>
    const <String, String>{
      'Direct': 'ورود مستقیم',
      'Organic Search': 'جست‌وجوی طبیعی',
      'Paid Search': 'جست‌وجوی تبلیغاتی',
      'Referral': 'ارجاع از سایت دیگر',
      'Organic Social': 'شبکه‌های اجتماعی',
      'Paid Social': 'تبلیغات شبکه‌های اجتماعی',
      'Email': 'ایمیل',
      'Display': 'تبلیغات نمایشی',
      'Unassigned': 'منبع مشخص نشده',
      'desktop': 'رایانه',
      'mobile': 'گوشی',
      'tablet': 'تبلت',
    }[value] ??
    value;
