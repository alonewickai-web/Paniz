import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/admin_api.dart';
import '../../core/paniz_theme.dart';
import '../../core/providers.dart';
import '../../core/ui_helpers.dart';
import '../activity/audit_log_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({
    super.key,
    this.onProducts,
    this.onOrders,
    this.onInventory,
    this.onSms,
    this.onRubika,
    this.onActivity,
  });
  final VoidCallback? onProducts;
  final VoidCallback? onOrders;
  final VoidCallback? onInventory;
  final VoidCallback? onSms;
  final VoidCallback? onRubika;
  final VoidCallback? onActivity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);
    final admin = ref.watch(authProvider).value;
    return dashboard.when(
      loading: () => const _DashboardSkeleton(),
      error:
          (error, _) => _DashboardError(
            message: AdminApi.friendlyError(error),
            onRetry: () => ref.invalidate(dashboardProvider),
          ),
      data:
          (data) => RefreshIndicator.adaptive(
            onRefresh: () => ref.refresh(dashboardProvider.future),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxWidth =
                    constraints.maxWidth > 920 ? 880.0 : double.infinity;
                final today = _map(data['today']);
                final month = _map(data['month']);
                final lowStock = _asList(data['lowStock']);
                final recentOrders = _asList(data['recentOrders']);
                final counts = _map(data['orderCounts']);
                final activeOrders = _activeOrders(counts);
                final gridColumns = constraints.maxWidth >= 720 ? 4 : 2;
                final mainSales = '${toman(today['paidSalesToman'] ?? 0)}';

                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxWidth),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'سلام، روزت بخیر',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.headlineSmall?.copyWith(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        shamsiDate(DateTime.now()),
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium?.copyWith(
                                          color: context.paniz.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 11,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.paniz.primarySoft,
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.cloud_done_outlined,
                                        color: context.paniz.primary,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'متصل',
                                        style: TextStyle(
                                          color: context.paniz.primary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            if (data['financialAccess'] == true)
                              _SalesHero(
                                sales: mainSales,
                                orderCount:
                                    '${persianNumber(today['paidOrderCount'] ?? 0)} سفارش پرداخت‌شده',
                                pendingPayments:
                                    '${persianNumber(counts['pending_payment'] ?? 0)} سفارش در انتظار پرداخت',
                              ),
                            const SizedBox(height: 20),
                            sectionTitle('وضعیت فروشگاه'),
                            const SizedBox(height: 10),
                            GridView.count(
                              crossAxisCount: gridColumns,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              childAspectRatio:
                                  constraints.maxWidth >= 720 ? 1.65 : 1.42,
                              children: [
                                if (data['activeProductCount'] != null)
                                  _MetricTile(
                                    title: 'محصولات فعال',
                                    value: persianNumber(
                                      data['activeProductCount'],
                                    ),
                                    detail: 'قابل نمایش در فروشگاه',
                                    icon: Icons.checkroom_outlined,
                                    tint: context.paniz.lilac.withValues(
                                      alpha: .34,
                                    ),
                                  ),
                                if (admin?.can('orders.view') == true)
                                  _MetricTile(
                                    title: 'سفارش‌های جاری',
                                    value: persianNumber(activeOrders),
                                    detail: 'نیازمند پیگیری',
                                    icon: Icons.receipt_long_rounded,
                                    tint: context.paniz.peach.withValues(
                                      alpha: .32,
                                    ),
                                  ),
                                if (data['lowStockCount'] != null)
                                  _MetricTile(
                                    title: 'هشدار موجودی',
                                    value: persianNumber(
                                      data['lowStockCount'] ?? 0,
                                    ),
                                    detail: 'تنوع زیر آستانه',
                                    icon: Icons.inventory_2_outlined,
                                    tint: context.paniz.coral.withValues(
                                      alpha: .3,
                                    ),
                                  ),
                                if (data['customerCount'] != null)
                                  _MetricTile(
                                    title: 'مشتریان',
                                    value: persianNumber(data['customerCount']),
                                    detail: 'مشتری فعال فروشگاه',
                                    icon: Icons.people_outline,
                                    tint: context.paniz.mint.withValues(
                                      alpha: .34,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 22),
                            sectionTitle('دسترسی سریع'),
                            const SizedBox(height: 10),
                            _QuickActions(
                              onProducts: onProducts,
                              onOrders: onOrders,
                              onInventory: onInventory,
                              onSms: onSms,
                              onRubika: onRubika,
                            ),
                            if (data['financialAccess'] == true) ...[
                              const SizedBox(height: 16),
                              Card(
                                child: ListTile(
                                  leading: const Icon(
                                    Icons.calendar_month_outlined,
                                  ),
                                  title: const Text('فروش این ماه'),
                                  subtitle: Text(
                                    '${persianNumber(month['paidOrderCount'] ?? 0)} سفارش پرداخت‌شده',
                                  ),
                                  trailing: Text(
                                    toman(month['paidSalesToman'] ?? 0),
                                  ),
                                ),
                              ),
                            ],
                            if (data['lowStockCount'] != null) ...[
                              const SizedBox(height: 22),
                              sectionTitle(
                                'هشدارهای موجودی',
                                trailing: Text(
                                  '${persianNumber(lowStock.length)} مورد',
                                  style: TextStyle(
                                    color: context.paniz.muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              if (lowStock.isEmpty)
                                const PanizEmptyState(
                                  icon: Icons.check_circle_outline_rounded,
                                  title: 'موجودی مناسبه',
                                  description:
                                      'در حال حاضر تنوعی پایین‌تر از آستانهٔ هشدار نیست.',
                                )
                              else
                                ...lowStock
                                    .take(4)
                                    .map((item) => _StockRow(item: item)),
                            ],
                            if (admin?.can('orders.view') == true) ...[
                              const SizedBox(height: 22),
                              sectionTitle(
                                'آخرین سفارش‌ها',
                                trailing: TextButton(
                                  onPressed: onOrders,
                                  child: const Text('همهٔ سفارش‌ها'),
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (recentOrders.isEmpty)
                                const PanizEmptyState(
                                  icon: Icons.receipt_long_outlined,
                                  title: 'هنوز سفارشی ثبت نشده',
                                  description:
                                      'با ثبت اولین خرید مشتری، وضعیت سفارش اینجا نمایش داده می‌شود.',
                                )
                              else
                                ...recentOrders
                                    .take(5)
                                    .map((order) => _OrderRow(order: order)),
                            ],
                            if (onActivity != null) ...[
                              const SizedBox(height: 22),
                              sectionTitle(
                                'آخرین فعالیت‌ها',
                                trailing: TextButton(
                                  onPressed: onActivity,
                                  child: const Text('مشاهده همه'),
                                ),
                              ),
                              const _RecentActivities(),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
    );
  }

  static int _activeOrders(JsonMap counts) => counts.entries
      .where(
        (entry) => const {
          'paid',
          'confirmed',
          'preparing',
          'shipped',
        }.contains(entry.key),
      )
      .fold<int>(
        0,
        (total, entry) =>
            total + (entry.value is num ? (entry.value as num).toInt() : 0),
      );
}

class _SalesHero extends StatelessWidget {
  const _SalesHero({
    required this.sales,
    required this.orderCount,
    required this.pendingPayments,
  });
  final String sales;
  final String orderCount;
  final String pendingPayments;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors:
            context.isDarkMode
                ? const [Color(0xFF174A42), Color(0xFF16312D)]
                : const [Color(0xFF0F766E), Color(0xFF145B54)],
        begin: AlignmentDirectional.topStart,
        end: AlignmentDirectional.bottomEnd,
      ),
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: context.paniz.primary.withValues(alpha: .16),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'فروش امروز',
                style: TextStyle(
                  color: Color(0xFFD5ECE8),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.account_balance_wallet_outlined,
                color: Colors.white,
                size: 21,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          sales,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'مجموع پرداخت‌های ثبت‌شده امروز',
          style: TextStyle(color: Color(0xFFDAEAE7), fontSize: 12),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _HeroLabel(
              icon: Icons.check_circle_outline_rounded,
              text: orderCount,
            ),
            _HeroLabel(
              icon: Icons.hourglass_empty_rounded,
              text: pendingPayments,
            ),
          ],
        ),
      ],
    ),
  );
}

class _HeroLabel extends StatelessWidget {
  const _HeroLabel({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .11),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: const Color(0xFFDAEAE7)),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.title,
    required this.value,
    required this.detail,
    required this.icon,
    required this.tint,
  });
  final String title;
  final String value;
  final String detail;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: context.paniz.primary, size: 20),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  title,
                  textAlign: TextAlign.end,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: context.paniz.muted,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: context.paniz.muted),
          ),
        ],
      ),
    ),
  );
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    this.onProducts,
    this.onOrders,
    this.onInventory,
    this.onSms,
    this.onRubika,
  });
  final VoidCallback? onProducts;
  final VoidCallback? onOrders;
  final VoidCallback? onInventory;
  final VoidCallback? onSms;
  final VoidCallback? onRubika;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 420;
      final actions = [
        if (onProducts != null)
          _QuickAction(
            icon: Icons.checkroom_outlined,
            title: 'محصولات',
            tint: context.paniz.primarySoft,
            onTap: onProducts,
          ),
        if (onOrders != null)
          _QuickAction(
            icon: Icons.receipt_long_outlined,
            title: 'سفارش‌ها',
            tint: context.paniz.rose.withValues(alpha: .45),
            onTap: onOrders,
          ),
        if (onSms != null)
          _QuickAction(
            icon: Icons.sms_outlined,
            title: 'ارسال پیامک',
            tint: context.paniz.mint.withValues(alpha: .35),
            onTap: onSms,
          ),
        if (onRubika != null)
          _QuickAction(
            icon: Icons.campaign_outlined,
            title: 'روبیکا',
            tint: context.paniz.lilac.withValues(alpha: .35),
            onTap: onRubika,
          ),
        if (onInventory != null && onSms == null)
          _QuickAction(
            icon: Icons.inventory_2_outlined,
            title: 'موجودی',
            tint: context.paniz.peach.withValues(alpha: .35),
            onTap: onInventory,
          ),
      ];
      return Row(
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(width: 9),
            Expanded(child: compact ? actions[i].compact(context) : actions[i]),
          ],
        ],
      );
    },
  );
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.title,
    required this.tint,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final Color tint;
  final VoidCallback? onTap;

  Widget compact(BuildContext context) => _build(context, compact: true);

  @override
  Widget build(BuildContext context) => _build(context, compact: false);

  Widget _build(BuildContext context, {required bool compact}) => Material(
    color: context.paniz.surface,
    borderRadius: BorderRadius.circular(17),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Container(
        constraints: BoxConstraints(minHeight: compact ? 92 : 82),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 13,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: context.paniz.line),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: context.paniz.primary, size: 19),
            ),
            const SizedBox(height: 7),
            Text(
              title,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _StockRow extends StatelessWidget {
  const _StockRow({required this.item});
  final JsonMap item;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: context.paniz.error.withValues(alpha: .11),
          child: Icon(
            Icons.inventory_2_outlined,
            color: context.paniz.error,
            size: 20,
          ),
        ),
        title: Text(
          '${item['productName'] ?? 'محصول'}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${item['color'] ?? ''} · ${item['size'] ?? ''} · ${item['sku'] ?? ''}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          '${persianNumber(item['availableQuantity'] ?? 0)} عدد',
          style: TextStyle(
            color: context.paniz.error,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ),
    ),
  );
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order});
  final JsonMap order;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: context.paniz.primarySoft,
          child: Icon(
            Icons.shopping_bag_outlined,
            color: context.paniz.primary,
            size: 20,
          ),
        ),
        title: Text(
          '${order['orderNumber'] ?? ''}',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        subtitle: Text(
          '${order['recipientName'] ?? ''} · ${statusLabel('${order['status'] ?? ''}')}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing:
            order['totalToman'] == null
                ? null
                : Text(
                  toman(order['totalToman']),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
      ),
    ),
  );
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const PanizSkeletonBlock(width: 150, height: 26),
      const SizedBox(height: 8),
      const PanizSkeletonBlock(width: 210, height: 15),
      const SizedBox(height: 18),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PanizSkeletonBlock(width: 100),
              const SizedBox(height: 14),
              const PanizSkeletonBlock(width: 190, height: 30),
              const SizedBox(height: 14),
              const PanizSkeletonBlock(height: 30),
            ],
          ),
        ),
      ),
      const SizedBox(height: 18),
      const PanizSkeletonBlock(width: 130, height: 21),
      const SizedBox(height: 10),
      for (var i = 0; i < 2; i++) ...[
        Row(
          children: [
            for (var j = 0; j < 2; j++) ...[
              if (j > 0) const SizedBox(width: 10),
              const Expanded(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PanizSkeletonBlock(width: 40, height: 40, radius: 14),
                        SizedBox(height: 14),
                        PanizSkeletonBlock(width: 95, height: 17),
                        SizedBox(height: 8),
                        PanizSkeletonBlock(width: 70, height: 12),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
      ],
    ],
  );
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: context.paniz.error.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.cloud_off_outlined,
              color: context.paniz.error,
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'دریافت اطلاعات ممکن نشد',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.paniz.muted),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('تلاش دوباره'),
          ),
        ],
      ),
    ),
  );
}

List<JsonMap> _asList(Object? value) =>
    value is List
        ? value
            .whereType<Map>()
            .map((entry) => Map<String, dynamic>.from(entry))
            .toList()
        : const [];
JsonMap _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

final _recentActivityProvider = FutureProvider.autoDispose<JsonMap>(
  (ref) => ref.watch(adminApiProvider).auditLogs(),
);

class _RecentActivities extends ConsumerWidget {
  const _RecentActivities();
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(_recentActivityProvider)
      .when(
        loading: () => const LinearProgressIndicator(),
        error:
            (error, _) => ListTile(
              title: Text(AdminApi.friendlyError(error)),
              trailing: IconButton(
                tooltip: 'تلاش دوباره',
                icon: const Icon(Icons.refresh),
                onPressed: () => ref.invalidate(_recentActivityProvider),
              ),
            ),
        data: (data) {
          final rows = _asList(data['data']);
          return rows.isEmpty
              ? const PanizEmptyState(
                icon: Icons.history,
                title: 'هنوز فعالیتی ثبت نشده',
                description: 'تغییرات کارکنان اینجا نمایش داده می‌شود.',
              )
              : Column(
                children:
                    rows
                        .take(5)
                        .map((row) => AdminActivityCard(activity: row))
                        .toList(),
              );
        },
      );
}
