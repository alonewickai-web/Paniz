import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/admin_api.dart';
import '../../core/paniz_theme.dart';
import '../../core/providers.dart';
import '../../core/ui_helpers.dart';

class ReviewManagementScreen extends ConsumerStatefulWidget {
  const ReviewManagementScreen({super.key});

  @override
  ConsumerState<ReviewManagementScreen> createState() =>
      _ReviewManagementScreenState();
}

class _ReviewManagementScreenState extends ConsumerState<ReviewManagementScreen> {
  static const _filters = <String, String>{
    'pending': 'در انتظار بررسی',
    'approved': 'تأییدشده',
    'rejected': 'ردشده',
    'all': 'همه',
  };

  String _status = 'pending';
  List<JsonMap> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final items = await ref.read(adminApiProvider).reviews(status: _status);
      if (mounted) setState(() { _items = items; _loading = false; });
    } catch (error) {
      if (mounted) setState(() { _error = AdminApi.friendlyError(error); _loading = false; });
    }
  }

  Future<void> _setStatus(JsonMap review, String next) async {
    try {
      await ref.read(adminApiProvider).updateReviewStatus('${review['id']}', next);
      await _load();
      if (mounted) showAppMessage(context, 'وضعیت نظر به «${_filters[next]}» تغییر کرد.');
    } catch (error) {
      if (mounted) showAppMessage(context, AdminApi.friendlyError(error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = context.paniz;
    final canModerate = ref.watch(authProvider).value?.can('products.edit') ?? false;
    return Column(
      children: [
        SizedBox(
          height: 58,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            scrollDirection: Axis.horizontal,
            children: _filters.entries.map((entry) => Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ChoiceChip(
                label: Text(entry.value),
                selected: _status == entry.key,
                onSelected: (_) { setState(() => _status = entry.key); _load(); },
              ),
            )).toList(),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('تلاش دوباره')),
                      ]),
                    ))
                  : _items.isEmpty
                      ? Center(child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.rate_review_outlined, size: 42, color: color.muted),
                            const SizedBox(height: 12),
                            Text(_status == 'pending' ? 'نظرِ در انتظار بررسی وجود ندارد.' : 'نظری برای نمایش پیدا نشد.'),
                          ]),
                        ))
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                            itemCount: _items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) => _reviewCard(_items[index], color, canModerate),
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _reviewCard(JsonMap review, PanizPalette color, bool canModerate) {
    final status = '${review['status'] ?? 'pending'}';
    final rating = int.tryParse('${review['rating'] ?? 0}') ?? 0;
    final orderText = '${review['orderNumber'] ?? ''} · ${review['color'] ?? ''} / ${review['size'] ?? ''}';
    final createdAt = DateTime.tryParse('${review['createdAt'] ?? ''}')?.toLocal();
    final date = createdAt == null ? '' : '${persianNumber(createdAt.year)}/${persianNumber(createdAt.month.toString().padLeft(2, '0'))}/${persianNumber(createdAt.day.toString().padLeft(2, '0'))}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${review['product']?['name'] ?? 'محصول'}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
              const SizedBox(height: 4),
              Text('${review['customerName'] ?? 'مشتری'} · $orderText', style: TextStyle(color: color.muted, fontSize: 11)),
            ])),
            Text(date, style: TextStyle(color: color.muted, fontSize: 10)),
          ]),
          const SizedBox(height: 10),
          Row(children: List.generate(5, (index) => Icon(Icons.star_rounded, size: 18, color: index < rating ? const Color(0xffd59a22) : color.line))),
          if ('${review['title'] ?? ''}'.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('${review['title']}', style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
          if ('${review['body'] ?? ''}'.trim().isNotEmpty) ...[
            const SizedBox(height: 5),
            Text('${review['body']}', style: const TextStyle(height: 1.7)),
          ],
          const SizedBox(height: 10),
          Row(children: [
            _statusChip(status, color),
            const Spacer(),
            if (canModerate && status != 'approved') TextButton.icon(onPressed: () => _setStatus(review, 'approved'), icon: const Icon(Icons.check_circle_outline), label: const Text('تأیید')),
            if (canModerate && status != 'rejected') TextButton.icon(onPressed: () => _setStatus(review, 'rejected'), icon: const Icon(Icons.block_outlined), label: const Text('رد نظر')),
            if (canModerate && status != 'pending') IconButton(tooltip: 'بازگرداندن به صف بررسی', onPressed: () => _setStatus(review, 'pending'), icon: const Icon(Icons.undo_rounded)),
          ]),
        ]),
      ),
    );
  }

  Widget _statusChip(String status, PanizPalette color) {
    final (label, foreground, background) = switch (status) {
      'approved' => ('تأییدشده', color.success, color.mint.withValues(alpha: .18)),
      'rejected' => ('ردشده', color.error, color.rose.withValues(alpha: .25)),
      _ => ('در انتظار بررسی', color.warning, color.peach.withValues(alpha: .22)),
    };
    return DecoratedBox(
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(20)),
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), child: Text(label, style: TextStyle(color: foreground, fontSize: 11, fontWeight: FontWeight.w700))),
    );
  }
}
