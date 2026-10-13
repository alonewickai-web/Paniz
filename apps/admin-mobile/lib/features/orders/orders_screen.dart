import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/admin_api.dart';
import '../activity/audit_log_screen.dart';
import '../../core/providers.dart';
import '../../core/ui_helpers.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});
  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  String _filter = 'all';
  final _filters = const <String, String>{
    'all': 'همه',
    'pending_payment': 'در انتظار پرداخت',
    'paid': 'پرداخت‌شده',
    'preparing': 'آماده‌سازی',
    'shipped': 'ارسال‌شده',
    'delivered': 'تحویل‌شده',
    'cancelled': 'لغوشده',
  };

  Future<void> _advance(JsonMap order) async {
    final current = '${order['status'] ?? ''}';
    final next = switch (current) {
      'pending_payment' => 'cancelled',
      'paid' => 'confirmed',
      'confirmed' => 'preparing',
      'preparing' => 'shipped',
      'shipped' => 'delivered',
      'delivered' => 'returned',
      _ => null,
    };
    if (next == null) return;

    final needsTracking = next == 'shipped';
    final trackingController = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              next == 'cancelled' ? 'لغو درخواست سفارش؟' : 'تغییر وضعیت سفارش',
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${order['orderNumber']} · ${statusLabel(current)} ← ${statusLabel(next)}',
                ),
                if (current == 'pending_payment') ...[
                  const SizedBox(height: 10),
                  const Text(
                    'این سفارش پرداخت نشده است. با لغو، رزرو موجودی آزاد می‌شود.',
                  ),
                ],
                if (current == 'delivered') ...[
                  const SizedBox(height: 10),
                  const Text(
                    'ثبت مرجوعی در این مرحله فقط وضعیت را تغییر می‌دهد؛ فرایند بازپرداخت جداگانه هنوز فعال نیست.',
                  ),
                ],
                if (needsTracking) ...[
                  const SizedBox(height: 14),
                  TextField(
                    controller: trackingController,
                    decoration: const InputDecoration(
                      labelText: 'کد رهگیری مرسوله',
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('بازگشت'),
              ),
              FilledButton(
                onPressed: () {
                  if (needsTracking && trackingController.text.trim().isEmpty)
                    return;
                  Navigator.pop(context, true);
                },
                child: const Text('ثبت وضعیت'),
              ),
            ],
          ),
    );
    if (accepted != true || !mounted) {
      trackingController.dispose();
      return;
    }
    try {
      await ref
          .read(adminApiProvider)
          .updateOrderStatus(
            '${order['id']}',
            next,
            trackingCode: needsTracking ? trackingController.text.trim() : null,
          );
      ref.invalidate(ordersProvider);
      ref.invalidate(dashboardProvider);
      if (mounted)
        showAppMessage(
          context,
          'وضعیت سفارش به «${statusLabel(next)}» تغییر کرد.',
        );
    } catch (error) {
      if (mounted)
        showAppMessage(context, AdminApi.friendlyError(error), error: true);
    } finally {
      trackingController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(ordersProvider);
    final admin = ref.watch(authProvider).value;
    return orders.when(
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
                    onPressed: () => ref.invalidate(ordersProvider),
                    icon: const Icon(Icons.refresh),
                    label: const Text('تلاش دوباره'),
                  ),
                ],
              ),
            ),
          ),
      data: (items) {
        final filtered =
            _filter == 'all'
                ? items
                : items.where((order) => order['status'] == _filter).toList();
        return RefreshIndicator(
          onRefresh: () => ref.refresh(ordersProvider.future),
          color: Theme.of(context).colorScheme.primary,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'سفارش‌های فروشگاه',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${persianNumber(filtered.length)} سفارش در این فهرست',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 13),
              SizedBox(
                height: 42,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children:
                      _filters.entries
                          .map(
                            (filter) => Padding(
                              padding: const EdgeInsetsDirectional.only(end: 7),
                              child: ChoiceChip(
                                label: Text(filter.value),
                                selected: _filter == filter.key,
                                onSelected:
                                    (_) => setState(() => _filter = filter.key),
                              ),
                            ),
                          )
                          .toList(),
                ),
              ),
              const SizedBox(height: 13),
              if (filtered.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('سفارشی با این وضعیت نیست.')),
                  ),
                )
              else
                ...filtered.map(
                  (order) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _OrderCard(
                      order: order,
                      onAdvance:
                          admin?.can('orders.status') == true &&
                                  (order['status'] != 'pending_payment' ||
                                      admin?.can('orders.cancel') == true) &&
                                  (order['status'] != 'delivered' ||
                                      admin?.can('orders.refund') == true)
                              ? () => _advance(order)
                              : null,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onAdvance});
  final JsonMap order;
  final VoidCallback? onAdvance;

  @override
  Widget build(BuildContext context) {
    final status = '${order['status'] ?? ''}';
    final items =
        order['items'] is List
            ? (order['items'] as List).whereType<Map>().toList()
            : const [];
    final next = switch (status) {
      'pending_payment' => 'لغو سفارش',
      'paid' => 'تأیید سفارش',
      'confirmed' => 'شروع آماده‌سازی',
      'preparing' => 'ثبت ارسال',
      'shipped' => 'ثبت تحویل',
      'delivered' => 'ثبت مرجوعی',
      _ => null,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${order['orderNumber'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor(context, status).withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    statusLabel(status),
                    style: TextStyle(
                      fontSize: 11,
                      color: statusColor(context, status),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            TextButton.icon(
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder:
                          (_) => AdminRecordScreen(
                            kind: 'order',
                            id: '${order['id']}',
                          ),
                    ),
                  ),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('جزئیات سفارش'),
            ),
            const SizedBox(height: 9),
            Text(
              '${order['recipientName'] ?? ''} · ${order['recipientPhone'] ?? ''}',
              style: const TextStyle(fontSize: 12),
            ),
            if (items.isNotEmpty) ...[
              const Divider(height: 18),
              ...items
                  .take(3)
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Text(
                        '${item['name']} · ${item['color']} / ${item['size']} × ${persianNumber(item['quantity'])}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
              if (items.length > 3)
                Text(
                  'و ${persianNumber(items.length - 3)} مورد دیگر',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    order['totalToman'] == null
                        ? 'اطلاعات مالی محدود است'
                        : toman(order['totalToman']),
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                if (next != null && onAdvance != null)
                  OutlinedButton(onPressed: onAdvance, child: Text(next)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
