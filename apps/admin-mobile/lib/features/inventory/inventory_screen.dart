import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/admin_api.dart';
import '../../core/providers.dart';
import '../../core/ui_helpers.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});
  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  bool _onlyLowStock = true;

  Future<void> _adjust(JsonMap variant, String productName) async {
    final deltaController = TextEditingController();
    final noteController = TextEditingController();
    final change = await showDialog<(int, String)>(context: context, builder: (context) => AlertDialog(
      title: const Text('اصلاح موجودی'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('$productName · ${variant['colorName'] ?? ''} / ${variant['sizeLabel'] ?? ''}'),
        const SizedBox(height: 6),
        Text('موجودی قابل‌فروش: ${persianNumber(variant['availableQuantity'] ?? 0)} عدد'),
        const SizedBox(height: 14),
        TextField(controller: deltaController, keyboardType: const TextInputType.numberWithOptions(signed: true), textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'مقدار تغییر', helperText: 'مثبت برای افزودن؛ منفی برای کم‌کردن')),
        const SizedBox(height: 10),
        TextField(controller: noteController, maxLength: 500, decoration: const InputDecoration(labelText: 'دلیل اصلاح')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
        FilledButton(onPressed: () {
          final delta = int.tryParse(_asciiDigits(deltaController.text.trim()));
          final note = noteController.text.trim();
          if (delta == null || delta == 0 || note.isEmpty) return;
          Navigator.pop(context, (delta, note));
        }, child: const Text('ثبت گردش انبار')),
      ],
    ));
    deltaController.dispose();
    noteController.dispose();
    if (change == null || !mounted) return;
    try {
      await ref.read(adminApiProvider).adjustInventory('${variant['id']}', change.$1, change.$2);
      ref.invalidate(productsProvider);
      ref.invalidate(dashboardProvider);
      if (mounted) showAppMessage(context, 'موجودی اصلاح شد و گردش آن ثبت شد.');
    } catch (error) {
      if (mounted) showAppMessage(context, AdminApi.friendlyError(error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider);
    return products.when(
      loading: () => const Center(child: CircularProgressIndicator(color: panizRose)),
      error: (error, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(AdminApi.friendlyError(error), textAlign: TextAlign.center), const SizedBox(height: 12), OutlinedButton.icon(onPressed: () => ref.invalidate(productsProvider), icon: const Icon(Icons.refresh), label: const Text('تلاش دوباره'))]))),
      data: (items) {
        final variants = <({JsonMap product, JsonMap variant})>[];
        for (final product in items) {
          final productVariants = product['variants'] is List ? (product['variants'] as List).whereType<Map>().map((entry) => Map<String, dynamic>.from(entry)) : const <JsonMap>[];
          for (final variant in productVariants) {
            if (variant['isActive'] == true) variants.add((product: product, variant: variant));
          }
        }
        final visible = _onlyLowStock
            ? variants.where((entry) => (entry.variant['availableQuantity'] as num? ?? 0) <= (entry.variant['lowStockThreshold'] as num? ?? 0)).toList()
            : variants;
        return RefreshIndicator(
          onRefresh: () => ref.refresh(productsProvider.future),
          color: panizRose,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              const Text('مدیریت موجودی', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: panizInk)),
              const SizedBox(height: 5),
              Text('${persianNumber(variants.length)} تنوع فعال', style: const TextStyle(color: Color(0xFF807477))),
              const SizedBox(height: 10),
              SwitchListTile.adaptive(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                value: _onlyLowStock,
                activeTrackColor: panizRose,
                onChanged: (value) => setState(() => _onlyLowStock = value),
                title: const Text('فقط موجودی کم', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('موجودی قابل‌فروش تا آستانهٔ هشدار', style: TextStyle(fontSize: 11)),
              ),
              const SizedBox(height: 8),
              if (visible.isEmpty)
                Card(child: Padding(padding: const EdgeInsets.all(25), child: Center(child: Text(_onlyLowStock ? 'تنوعی زیر آستانهٔ هشدار نیست.' : 'تنوع فعالی ثبت نشده است.'))))
              else
                ...visible.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: _InventoryCard(entry: entry, onAdjust: () => _adjust(entry.variant, '${entry.product['name'] ?? ''}')),
                )),
            ],
          ),
        );
      },
    );
  }
}

class _InventoryCard extends StatelessWidget {
  const _InventoryCard({required this.entry, required this.onAdjust});
  final ({JsonMap product, JsonMap variant}) entry;
  final VoidCallback onAdjust;

  @override
  Widget build(BuildContext context) {
    final variant = entry.variant;
    final available = variant['availableQuantity'] as num? ?? 0;
    final threshold = variant['lowStockThreshold'] as num? ?? 0;
    final low = available <= threshold;
    return Card(child: ListTile(
      leading: CircleAvatar(backgroundColor: low ? const Color(0xFFFFE9ED) : panizMint, child: Icon(Icons.inventory_2_outlined, color: low ? panizError : const Color(0xFF138A65), size: 20)),
      title: Text('${entry.product['name'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
      subtitle: Text('${variant['colorName'] ?? ''} · ${variant['sizeLabel'] ?? ''} · ${variant['sku'] ?? ''}\nکل ${persianNumber(variant['stockQuantity'] ?? 0)}  |  رزرو ${persianNumber(variant['reservedQuantity'] ?? 0)}', style: const TextStyle(height: 1.6)),
      isThreeLine: true,
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('${persianNumber(available)}', style: TextStyle(color: low ? panizError : panizInk, fontWeight: FontWeight.w900, fontSize: 17)), const Text('قابل‌فروش', style: TextStyle(fontSize: 9))]),
      onTap: onAdjust,
    ));
  }
}

String _asciiDigits(String value) {
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  return value.replaceAllMapped(RegExp(r'[۰-۹٠-٩]'), (match) {
    final character = match[0]!;
    final index = persian.indexOf(character);
    return '${index >= 0 ? index : arabic.indexOf(character)}';
  });
}
