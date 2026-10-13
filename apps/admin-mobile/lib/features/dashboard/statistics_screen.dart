import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/admin_api.dart';
import '../../core/providers.dart';
import '../../core/ui_helpers.dart';

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(dashboardProvider);
    final siteVisits = ref.watch(siteVisitAnalyticsProvider);
    return report.when(
      loading:
          () => Center(
            child: CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
      error:
          (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AdminApi.friendlyError(error),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => ref.invalidate(dashboardProvider),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('تلاش دوباره'),
                  ),
                ],
              ),
            ),
          ),
      data: (data) {
        final today = _map(data['today']);
        final month = _map(data['month']);
        final financialAccess = data['financialAccess'] == true;
        final counts = _map(data['orderCounts']);
        final totalOrders = counts.values.fold<int>(
          0,
          (total, value) => total + (value is num ? value.toInt() : 0),
        );
        final statuses = <(String, String, Color)>[
          (
            'pending_payment',
            'در انتظار پرداخت',
            Theme.of(context).colorScheme.tertiary,
          ),
          ('paid', 'پرداخت‌شده', Theme.of(context).colorScheme.primary),
          ('confirmed', 'تأییدشده', Theme.of(context).colorScheme.primary),
          (
            'preparing',
            'در حال آماده‌سازی',
            Theme.of(context).colorScheme.secondary,
          ),
          ('shipped', 'ارسال‌شده', Theme.of(context).colorScheme.tertiary),
          ('delivered', 'تحویل‌شده', Theme.of(context).colorScheme.primary),
          ('cancelled', 'لغوشده', Theme.of(context).colorScheme.error),
        ];
        return RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              ref.refresh(dashboardProvider.future),
              ref.refresh(siteVisitAnalyticsProvider.future),
            ]);
          },
          color: Theme.of(context).colorScheme.primary,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'آمار فروشگاه',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'فروش و بازدید واقعی فروشگاه',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              _SiteVisitsSection(
                report: siteVisits,
                onRetry: () => ref.invalidate(siteVisitAnalyticsProvider),
              ),
              const SizedBox(height: 16),
              if (financialAccess) _PeriodCard(
                title: 'امروز',
                tint: Theme.of(context).colorScheme.primaryContainer,
                amount: toman(today['paidSalesToman'] ?? 0),
                detail:
                    '${persianNumber(today['paidOrderCount'] ?? 0)} سفارش پرداخت‌شده',
                icon: Icons.today_rounded,
              ),
              if (financialAccess) const SizedBox(height: 10),
              if (financialAccess) _PeriodCard(
                title: 'این ماه',
                tint: Theme.of(context).colorScheme.secondaryContainer,
                amount: toman(month['paidSalesToman'] ?? 0),
                detail:
                    '${persianNumber(month['paidOrderCount'] ?? 0)} سفارش پرداخت‌شده',
                icon: Icons.calendar_month_rounded,
              ),
              if (data['orderCounts'] is Map && (data['orderCounts'] as Map).isNotEmpty) const SizedBox(height: 20),
              if (data['orderCounts'] is Map && (data['orderCounts'] as Map).isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'وضعیت سفارش‌ها',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                          Text(
                            '${persianNumber(totalOrders)} سفارش',
                            style: TextStyle(
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      ...statuses.map((item) {
                        final count =
                            counts[item.$1] is num
                                ? (counts[item.$1] as num).toInt()
                                : 0;
                        final ratio =
                            totalOrders == 0 ? 0.0 : count / totalOrders;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.$2,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    persianNumber(count),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 7),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: ratio,
                                  minHeight: 8,
                                  backgroundColor:
                                      Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHigh,
                                  color: item.$3,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}

class _SiteVisitsSection extends StatelessWidget {
  const _SiteVisitsSection({required this.report, required this.onRetry});

  final AsyncValue<JsonMap> report;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => report.when(
    loading:
        () => Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'بازدید سایت',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
                const SizedBox(height: 8),
                Text(
                  'در حال دریافت آمار بازدید…',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
    error:
        (error, _) => Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'بازدید سایت',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AdminApi.friendlyError(error),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('تلاش دوباره'),
                  ),
                ),
              ],
            ),
          ),
        ),
    data: (data) {
      final today = _map(data['today']);
      final last7 = _map(data['last7Days']);
      final last30 = _map(data['last30Days']);
      final daily =
          (data['daily'] is List ? data['daily'] as List : const [])
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList();
      final popularPages =
          (data['popularPages'] is List
                  ? data['popularPages'] as List
                  : const [])
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList();

      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.public_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'بازدید سایت',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          'بر پایهٔ بازدیدهای ثبت‌شده در سایت',
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'به‌روزرسانی آمار بازدید',
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = (constraints.maxWidth - 8) / 2;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _VisitMetric(
                        width: width,
                        title: 'بازدید امروز',
                        value: today['pageViews'],
                        icon: Icons.visibility_rounded,
                        tint: Theme.of(context).colorScheme.primaryContainer,
                      ),
                      _VisitMetric(
                        width: width,
                        title: 'بازدیدکنندهٔ امروز',
                        value: today['uniqueVisitors'],
                        icon: Icons.person_outline_rounded,
                        tint: Theme.of(context).colorScheme.secondaryContainer,
                      ),
                      _VisitMetric(
                        width: width,
                        title: 'بازدید ۷ روز',
                        value: last7['pageViews'],
                        icon: Icons.trending_up_rounded,
                        tint: Theme.of(context).colorScheme.tertiaryContainer,
                      ),
                      _VisitMetric(
                        width: width,
                        title: 'بازدیدکنندهٔ ۳۰ روز',
                        value: last30['uniqueVisitors'],
                        icon: Icons.groups_2_rounded,
                        tint:
                            Theme.of(context).colorScheme.surfaceContainerHigh,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              Text(
                'روند بازدید در ۷ روز اخیر',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              _VisitBarChart(daily: daily),
              const SizedBox(height: 17),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'صفحه‌های پربازدید در ۳۰ روز',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Text(
                    '${persianNumber(last30['pageViews'] ?? 0)} بازدید',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (popularPages.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'هنوز بازدیدی ثبت نشده است.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                ...popularPages
                    .take(5)
                    .map(
                      (page) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Row(
                          children: [
                            Icon(
                              Icons.insert_link_rounded,
                              size: 17,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                _pageTitle('${page['path'] ?? '/'}'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textDirection: TextDirection.ltr,
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              persianNumber(page['pageViews'] ?? 0),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color:
                                    Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
              const SizedBox(height: 7),
              Text(
                'بازدیدها با شناسهٔ ناشناس شمرده می‌شوند؛ اطلاعات شخصی یا پارامترهای آدرس ذخیره نمی‌شود.',
                style: TextStyle(
                  fontSize: 10,
                  height: 1.6,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _VisitMetric extends StatelessWidget {
  const _VisitMetric({
    required this.width,
    required this.title,
    required this.value,
    required this.icon,
    required this.tint,
  });

  final double width;
  final String title;
  final Object? value;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: tint,
      borderRadius: BorderRadius.circular(15),
    ),
    child: Row(
      children: [
        Icon(icon, size: 19, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                persianNumber(value ?? 0),
                maxLines: 1,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _VisitBarChart extends StatelessWidget {
  const _VisitBarChart({required this.daily});
  final List<JsonMap> daily;

  @override
  Widget build(BuildContext context) {
    final maximum = daily.fold<int>(0, (value, row) {
      final count = _count(row['pageViews']);
      return count > value ? count : value;
    });
    return SizedBox(
      height: 126,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children:
            daily.map((row) {
              final count = _count(row['pageViews']);
              final ratio = maximum == 0 ? 0.0 : count / maximum;
              final date = '${row['date'] ?? ''}';
              final shortDay = _weekdayShort(date);
              return Expanded(
                child: Semantics(
                  label:
                      '${_weekdayFull(date)}، ${persianNumber(count)} بازدید',
                  child: Tooltip(
                    message:
                        '${_weekdayFull(date)}: ${persianNumber(count)} بازدید',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            persianNumber(count),
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            style: TextStyle(
                              fontSize: 9,
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Container(
                            height:
                                maximum == 0
                                    ? 5
                                    : math.max(7.0, 78 * ratio).toDouble(),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary
                                  .withValues(alpha: count == 0 ? 0.25 : 0.85),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(6),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            shortDay,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }
}

String _weekdayFull(String isoDate) {
  final date = DateTime.tryParse(isoDate);
  if (date == null) return 'روز';
  const names = [
    '',
    'دوشنبه',
    'سه‌شنبه',
    'چهارشنبه',
    'پنجشنبه',
    'جمعه',
    'شنبه',
    'یکشنبه',
  ];
  return names[date.weekday];
}

String _weekdayShort(String isoDate) {
  final date = DateTime.tryParse(isoDate);
  if (date == null) return '—';
  const names = ['', 'د', 'س', 'چ', 'پ', 'ج', 'ش', 'ی'];
  return names[date.weekday];
}

String _pageTitle(String path) => path == '/' ? 'صفحهٔ اصلی' : path;

int _count(Object? value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;

class _PeriodCard extends StatelessWidget {
  const _PeriodCard({
    required this.title,
    required this.tint,
    required this.amount,
    required this.detail,
    required this.icon,
  });
  final String title;
  final Color tint;
  final String amount;
  final String detail;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  amount,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

JsonMap _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
