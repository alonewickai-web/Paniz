import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/admin_api.dart';
import '../../core/providers.dart';
import '../../core/ui_helpers.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});
  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  bool _onlyUnderThree = false;
  String _categoryId = 'all';
  String _stockState = 'all';
  bool _searchExpanded = false;
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _adjust(JsonMap variant, String productName) async {
    final deltaController = TextEditingController();
    final noteController = TextEditingController();
    final change = await showDialog<(int, String)>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('اصلاح موجودی'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$productName · ${variant['colorName'] ?? ''} / ${variant['sizeLabel'] ?? ''}',
                ),
                const SizedBox(height: 6),
                Text(
                  'موجودی قابل‌فروش: ${persianNumber(variant['availableQuantity'] ?? 0)} عدد',
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: deltaController,
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                  ),
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'مقدار تغییر',
                    helperText: 'مثبت برای افزودن؛ منفی برای کم‌کردن',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteController,
                  maxLength: 500,
                  decoration: const InputDecoration(labelText: 'دلیل اصلاح'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('انصراف'),
              ),
              FilledButton(
                onPressed: () {
                  final delta = int.tryParse(
                    _asciiDigits(deltaController.text.trim()),
                  );
                  final note = noteController.text.trim();
                  if (delta == null || delta == 0 || note.isEmpty) return;
                  Navigator.pop(context, (delta, note));
                },
                child: const Text('ثبت گردش انبار'),
              ),
            ],
          ),
    );
    deltaController.dispose();
    noteController.dispose();
    if (change == null || !mounted) return;
    try {
      await ref
          .read(adminApiProvider)
          .adjustInventory('${variant['id']}', change.$1, change.$2);
      ref.invalidate(productsProvider);
      ref.invalidate(dashboardProvider);
      if (mounted) showAppMessage(context, 'موجودی اصلاح شد و گردش آن ثبت شد.');
    } catch (error) {
      if (mounted)
        showAppMessage(context, AdminApi.friendlyError(error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider);
    return products.when(
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
                    onPressed: () => ref.invalidate(productsProvider),
                    icon: const Icon(Icons.refresh),
                    label: const Text('تلاش دوباره'),
                  ),
                ],
              ),
            ),
          ),
      data: (items) {
        final variants = <({JsonMap product, JsonMap variant})>[];
        for (final product in items) {
          final productVariants =
              product['variants'] is List
                  ? (product['variants'] as List).whereType<Map>().map(
                    (entry) => Map<String, dynamic>.from(entry),
                  )
                  : const <JsonMap>[];
          for (final variant in productVariants) {
            if (variant['isActive'] == true)
              variants.add((product: product, variant: variant));
          }
        }
        final categories = <String, String>{};
        for (final product in items) {
          final id =
              '${product['categoryId'] ?? product['category']?['id'] ?? ''}';
          final name = '${product['category']?['name'] ?? ''}';
          if (id.isNotEmpty && name.isNotEmpty) categories[id] = name;
        }
        final query = _searchController.text.trim().toLowerCase();
        final visible =
            variants.where((entry) {
              final available =
                  (entry.variant['availableQuantity'] as num? ?? 0).toInt();
              final category =
                  '${entry.product['categoryId'] ?? entry.product['category']?['id'] ?? ''}';
              final searchable =
                  [
                    entry.product['name'],
                    entry.variant['sku'],
                    entry.variant['colorName'],
                    entry.variant['sizeLabel'],
                  ].whereType<Object>().join(' ').toLowerCase();
              if (_onlyUnderThree && available >= 3) return false;
              if (_categoryId != 'all' && category != _categoryId) return false;
              if (_stockState == 'in_stock' && available <= 0) return false;
              if (_stockState == 'out_of_stock' && available > 0) return false;
              if (query.isNotEmpty && !searchable.contains(query)) return false;
              return true;
            }).toList();
        return RefreshIndicator(
          onRefresh: () => ref.refresh(productsProvider.future),
          color: Theme.of(context).colorScheme.primary,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  if (!_searchExpanded)
                    Expanded(
                      child: Text(
                        'مدیریت موجودی',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: TapRegion(
                        onTapOutside: (_) {
                          _searchFocus.unfocus();
                          setState(() => _searchExpanded = false);
                        },
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocus,
                          autofocus: true,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'جست‌وجو در محصولات',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: IconButton(
                              tooltip: 'بستن جست‌وجو',
                              onPressed: () {
                                _searchController.clear();
                                _searchFocus.unfocus();
                                setState(() => _searchExpanded = false);
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (!_searchExpanded)
                    IconButton(
                      tooltip: 'جست‌وجو در محصولات',
                      onPressed: () {
                        setState(() => _searchExpanded = true);
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) _searchFocus.requestFocus();
                        });
                      },
                      icon: const Icon(Icons.search_rounded),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${persianNumber(visible.length)} از ${persianNumber(variants.length)} تنوع فعال',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue:
                    _categoryId == 'all' || categories.containsKey(_categoryId)
                        ? _categoryId
                        : 'all',
                decoration: const InputDecoration(
                  labelText: 'دسته‌بندی',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: [
                  const DropdownMenuItem(
                    value: 'all',
                    child: Text('همهٔ دسته‌بندی‌ها'),
                  ),
                  ...categories.entries.map(
                    (entry) => DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged:
                    (value) => setState(() => _categoryId = value ?? 'all'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _stockState,
                decoration: const InputDecoration(
                  labelText: 'وضعیت موجودی',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('همهٔ وضعیت‌ها')),
                  DropdownMenuItem(
                    value: 'in_stock',
                    child: Text('دارای موجودی'),
                  ),
                  DropdownMenuItem(
                    value: 'out_of_stock',
                    child: Text('اتمام موجودی'),
                  ),
                ],
                onChanged:
                    (value) => setState(() => _stockState = value ?? 'all'),
              ),
              const SizedBox(height: 10),
              _UnderThreeFilter(
                value: _onlyUnderThree,
                onChanged: (value) => setState(() => _onlyUnderThree = value),
              ),
              const SizedBox(height: 12),
              if (visible.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(25),
                    child: Center(
                      child: Text(
                        variants.isEmpty
                            ? 'تنوع فعالی ثبت نشده است.'
                            : 'با این فیلترها کالایی پیدا نشد.',
                      ),
                    ),
                  ),
                )
              else
                ...visible.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: _InventoryCard(
                      entry: entry,
                      onAdjust:
                          () => _adjust(
                            entry.variant,
                            '${entry.product['name'] ?? ''}',
                          ),
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

class _UnderThreeFilter extends StatelessWidget {
  const _UnderThreeFilter({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsetsDirectional.only(
        start: 12,
        end: 4,
        top: 4,
        bottom: 4,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.filter_alt_outlined, color: colors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'فقط موجودی زیر ۳ عدد',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                Text(
                  value
                      ? 'فعال · حداکثر ۲ عدد قابل‌فروش'
                      : 'غیرفعال · نمایش همهٔ موجودی‌ها',
                  style: TextStyle(
                    fontSize: 11,
                    color: value ? colors.primary : colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: colors.primary,
            activeTrackColor: colors.primaryContainer,
            inactiveTrackColor: colors.surfaceContainerHighest,
            inactiveThumbColor: colors.outline,
          ),
        ],
      ),
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
    final low = available < 3;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              low
                  ? Theme.of(context).colorScheme.errorContainer
                  : Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            Icons.inventory_2_outlined,
            color:
                low
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
            size: 20,
          ),
        ),
        title: Text(
          '${entry.product['name'] ?? ''}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${variant['colorName'] ?? ''} · ${variant['sizeLabel'] ?? ''} · ${variant['sku'] ?? ''}\nکل ${persianNumber(variant['stockQuantity'] ?? 0)}  |  رزرو ${persianNumber(variant['reservedQuantity'] ?? 0)}',
          style: const TextStyle(height: 1.6),
        ),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${persianNumber(available)}',
              style: TextStyle(
                color:
                    low
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w900,
                fontSize: 17,
              ),
            ),
            Text('قابل‌فروش', style: TextStyle(fontSize: 9)),
          ],
        ),
        onTap: onAdjust,
      ),
    );
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
