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
    return report.when(
      loading: () => Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary)),
      error: (error, _) => Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(AdminApi.friendlyError(error), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: () => ref.invalidate(dashboardProvider), icon: const Icon(Icons.refresh_rounded), label: const Text('تلاش دوباره')),
        ]),
      )),
      data: (data) {
        final today = _map(data['today']);
        final month = _map(data['month']);
        final counts = _map(data['orderCounts']);
        final totalOrders = counts.values.fold<int>(0, (total, value) => total + (value is num ? value.toInt() : 0));
        final statuses = <(String, String, Color)>[
          ('pending_payment', 'در انتظار پرداخت', Theme.of(context).colorScheme.tertiary),
          ('paid', 'پرداخت‌شده', Theme.of(context).colorScheme.primary),
          ('confirmed', 'تأییدشده', Theme.of(context).colorScheme.primary),
          ('preparing', 'در حال آماده‌سازی', Theme.of(context).colorScheme.secondary),
          ('shipped', 'ارسال‌شده', Theme.of(context).colorScheme.tertiary),
          ('delivered', 'تحویل‌شده', Theme.of(context).colorScheme.primary),
          ('cancelled', 'لغوشده', Theme.of(context).colorScheme.error),
        ];
        return RefreshIndicator(
          onRefresh: () => ref.refresh(dashboardProvider.future),
          color: Theme.of(context).colorScheme.primary,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Text('آمار فروشگاه', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.onSurface)),
              const SizedBox(height: 5),
              Text('خلاصهٔ فروش ثبت‌شده از اطلاعات واقعی سرور', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 16),
              _PeriodCard(
                title: 'امروز',
                tint: Theme.of(context).colorScheme.primaryContainer,
                amount: toman(today['paidSalesToman'] ?? 0),
                detail: '${persianNumber(today['paidOrderCount'] ?? 0)} سفارش پرداخت‌شده',
                icon: Icons.today_rounded,
              ),
              const SizedBox(height: 10),
              _PeriodCard(
                title: 'این ماه',
                tint: Theme.of(context).colorScheme.secondaryContainer,
                amount: toman(month['paidSalesToman'] ?? 0),
                detail: '${persianNumber(month['paidOrderCount'] ?? 0)} سفارش پرداخت‌شده',
                icon: Icons.calendar_month_rounded,
              ),
              const SizedBox(height: 20),
              Card(child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text('وضعیت سفارش‌ها', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Theme.of(context).colorScheme.onSurface))),
                    Text('${persianNumber(totalOrders)} سفارش', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                  ]),
                  const SizedBox(height: 15),
                  ...statuses.map((item) {
                    final count = counts[item.$1] is num ? (counts[item.$1] as num).toInt() : 0;
                    final ratio = totalOrders == 0 ? 0.0 : count / totalOrders;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(children: [
                        Row(children: [
                          Expanded(child: Text(item.$2, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface))),
                          Text(persianNumber(count), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface)),
                        ]),
                        const SizedBox(height: 7),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(value: ratio, minHeight: 8, backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh, color: item.$3),
                        ),
                      ]),
                    );
                  }),
                ]),
              )),
              const SizedBox(height: 12),
              Card(color: Theme.of(context).colorScheme.tertiaryContainer, child: Padding(
                padding: EdgeInsets.all(14),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.info_outline_rounded, color: Theme.of(context).colorScheme.onTertiaryContainer),
                  SizedBox(width: 10),
                  Expanded(child: Text('گزارش نمودار روزانه و خروجی مالی در API فعلی موجود نیست؛ این صفحه فقط آمارهای ثبت‌شدهٔ امروز، ماه و سفارش‌ها را نشان می‌دهد.', style: TextStyle(color: Theme.of(context).colorScheme.onTertiaryContainer, height: 1.6, fontSize: 12))),
                ]),
              )),
            ],
          ),
        );
      },
    );
  }
}

class _PeriodCard extends StatelessWidget {
  const _PeriodCard({required this.title, required this.tint, required this.amount, required this.detail, required this.icon});
  final String title;
  final Color tint;
  final String amount;
  final String detail;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(child: Padding(
    padding: const EdgeInsets.all(16),
    child: Row(children: [
      Container(width: 48, height: 48, decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(15)), child: Icon(icon, color: Theme.of(context).colorScheme.primary)),
      const SizedBox(width: 13),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
        const SizedBox(height: 4),
        Text(amount, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w900, fontSize: 18)),
        const SizedBox(height: 3),
        Text(detail, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11)),
      ])),
    ]),
  ));
}

JsonMap _map(Object? value) => value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
