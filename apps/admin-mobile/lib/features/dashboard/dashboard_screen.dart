import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/admin_api.dart';
import '../../core/providers.dart';
import '../../core/ui_helpers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);
    return dashboard.when(
      loading: () => const Center(child: CircularProgressIndicator(color: panizRose)),
      error: (error, _) => _RetryPanel(message: AdminApi.friendlyError(error), onRetry: () => ref.invalidate(dashboardProvider)),
      data: (data) => RefreshIndicator(
        onRefresh: () => ref.refresh(dashboardProvider.future),
        color: panizRose,
        child: LayoutBuilder(builder: (context, constraints) {
          final columns = constraints.maxWidth > 850 ? 4 : 2;
          final today = data['today'] is Map ? Map<String, dynamic>.from(data['today'] as Map) : <String, dynamic>{};
          final month = data['month'] is Map ? Map<String, dynamic>.from(data['month'] as Map) : <String, dynamic>{};
          final lowStock = _asList(data['lowStock']);
          final recentOrders = _asList(data['recentOrders']);
          final counts = data['orderCounts'] is Map ? Map<String, dynamic>.from(data['orderCounts'] as Map) : <String, dynamic>{};
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFFFEDF0), Color(0xFFFFF5EB)], begin: Alignment.topRight, end: Alignment.bottomLeft),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('خوش برگشتی؛ نمای فروشگاه اینجاست', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: panizInk)),
                    const SizedBox(height: 6),
                    Text('${persianNumber(counts['pending_payment'] ?? 0)} سفارش در انتظار پرداخت است', style: const TextStyle(color: Color(0xFF74686C))),
                  ])),
                  const CircleAvatar(radius: 26, backgroundColor: Colors.white, child: Icon(Icons.storefront_rounded, color: panizRose)),
                ]),
              ),
              const SizedBox(height: 20),
              sectionTitle('خلاصهٔ فروش'),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: constraints.maxWidth > 600 ? 1.65 : 1.32,
                children: [
                  _MetricCard(title: 'فروش امروز', value: toman(today['paidSalesToman'] ?? 0), note: '${persianNumber(today['paidOrderCount'] ?? 0)} سفارش پرداخت‌شده', icon: Icons.payments_outlined, tint: panizMint),
                  _MetricCard(title: 'فروش این ماه', value: toman(month['paidSalesToman'] ?? 0), note: '${persianNumber(month['paidOrderCount'] ?? 0)} سفارش پرداخت‌شده', icon: Icons.trending_up_rounded, tint: panizLilac),
                  _MetricCard(title: 'سفارش‌های فعال', value: persianNumber(_activeOrders(counts)), note: 'در انتظار اقدام فروشگاه', icon: Icons.receipt_long_outlined, tint: const Color(0xFFFFF1E5)),
                  _MetricCard(title: 'کمبود موجودی', value: persianNumber(data['lowStockCount'] ?? 0), note: 'تنوع نیازمند بررسی', icon: Icons.inventory_2_outlined, tint: const Color(0xFFFFE9ED)),
                ],
              ),
              const SizedBox(height: 22),
              sectionTitle('نیازمند رسیدگی', trailing: Text('${persianNumber(lowStock.length)} مورد', style: const TextStyle(color: Color(0xFF83777A)))),
              const SizedBox(height: 10),
              if (lowStock.isEmpty)
                const _EmptyCard(icon: Icons.check_circle_outline_rounded, title: 'موجودی کالاها مناسب است')
              else
                ...lowStock.take(5).map((item) => _StockRow(item: item)),
              const SizedBox(height: 22),
              sectionTitle('سفارش‌های تازه'),
              const SizedBox(height: 10),
              if (recentOrders.isEmpty)
                const _EmptyCard(icon: Icons.receipt_long_outlined, title: 'هنوز سفارشی ثبت نشده')
              else
                ...recentOrders.take(6).map((order) => _OrderRow(order: order)),
              const SizedBox(height: 20),
            ],
          );
        }),
      ),
    );
  }

  static int _activeOrders(JsonMap counts) => counts.entries
      .where((entry) => const {'paid', 'confirmed', 'preparing', 'shipped'}.contains(entry.key))
      .fold<int>(0, (total, entry) => total + (entry.value is num ? (entry.value as num).toInt() : 0));
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.title, required this.value, required this.note, required this.icon, required this.tint});
  final String title;
  final String value;
  final String note;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) => Card(child: Padding(
    padding: const EdgeInsets.all(14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Row(children: [Container(width: 34, height: 34, decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(11)), child: Icon(icon, color: panizRose, size: 19)), const Spacer(), Flexible(child: Text(title, textAlign: TextAlign.end, style: const TextStyle(color: Color(0xFF756B6E), fontSize: 12))) ]),
      Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, color: panizInk, fontSize: 17)),
      Text(note, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Color(0xFF887D80))),
    ]),
  ));
}

class _StockRow extends StatelessWidget {
  const _StockRow({required this.item});
  final JsonMap item;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const CircleAvatar(backgroundColor: Color(0xFFFFE9ED), child: Icon(Icons.inventory_2_outlined, color: panizError, size: 19)),
      title: Text('${item['productName'] ?? 'محصول'} · ${item['color'] ?? ''} / ${item['size'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      subtitle: Text('کد ${item['sku'] ?? ''}'),
      trailing: Text('${persianNumber(item['availableQuantity'] ?? 0)} عدد', style: const TextStyle(color: panizError, fontWeight: FontWeight.w800)),
    ),
  );
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order});
  final JsonMap order;

  @override
  Widget build(BuildContext context) {
    final status = '${order['status'] ?? ''}';
    return Card(child: ListTile(
      leading: const CircleAvatar(backgroundColor: panizLilac, child: Icon(Icons.shopping_bag_outlined, color: Color(0xFF6E5A9D), size: 19)),
      title: Text('${order['orderNumber'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
      subtitle: Text('${order['recipientName'] ?? ''} · ${statusLabel(status)}'),
      trailing: Text(toman(order['totalToman'] ?? 0), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
    ));
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.icon, required this.title});
  final IconData icon;
  final String title;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(22), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: const Color(0xFF728B7E)), const SizedBox(width: 9), Text(title)])));
}

class _RetryPanel extends StatelessWidget {
  const _RetryPanel({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(24),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.cloud_off_rounded, color: panizError, size: 38),
      const SizedBox(height: 10),
      Text(message, textAlign: TextAlign.center),
      const SizedBox(height: 12),
      OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('تلاش دوباره')),
    ]),
  ));
}

List<JsonMap> _asList(Object? value) => value is List ? value.whereType<Map>().map((entry) => Map<String, dynamic>.from(entry)).toList() : const [];
