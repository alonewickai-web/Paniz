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
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue:
                          _categoryId == 'all' ||
                                  categories.containsKey(_categoryId)
                              ? _categoryId
                              : 'all',
                      isExpanded: true,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 11,
                        ),
                        labelText: 'دسته‌بندی',
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: 'all',
                          child: Text(
                            'همهٔ دسته‌ها',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        ...categories.entries.map(
                          (entry) => DropdownMenuItem(
                            value: entry.key,
                            child: Text(
                              entry.value,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged:
                          (value) =>
                              setState(() => _categoryId = value ?? 'all'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _stockState,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 11,
                        ),
                        labelText: 'وضعیت',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text(
                            'همهٔ وضعیت‌ها',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'in_stock',
                          child: Text('موجود', overflow: TextOverflow.ellipsis),
                        ),
                        DropdownMenuItem(
                          value: 'out_of_stock',
                          child: Text(
                            'ناموجود',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      onChanged:
                          (value) =>
                              setState(() => _stockState = value ?? 'all'),
                    ),
                  ),
                ],
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
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cardWidth = (constraints.maxWidth - 10) / 2;
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children:
                          visible
                              .map(
                                (entry) => SizedBox(
                                  width: cardWidth,
                                  child: _InventoryCard(
                                    entry: entry,
                                    onAdjust:
                                        () => _adjust(
                                          entry.variant,
                                          '${entry.product['name'] ?? ''}',
                                        ),
                                  ),
                                ),
                              )
                              .toList(),
                    );
                  },
                ),
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
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onAdjust,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _InventoryImageCarousel(
              images:
                  entry.product['images'] is List
                      ? (entry.product['images'] as List)
                          .whereType<Map>()
                          .map((image) => Map<String, dynamic>.from(image))
                          .toList()
                      : const [],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${entry.product['name'] ?? 'بدون نام'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'کد: ${variant['sku'] ?? '—'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    'سایز: ${variant['sizeLabel'] ?? '—'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 17,
                        color:
                            available > 0
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          'موجودی ${persianNumber(available)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color:
                                available > 0
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                      const Icon(Icons.edit_outlined, size: 16),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InventoryImageCarousel extends StatefulWidget {
  const _InventoryImageCarousel({required this.images});
  final List<JsonMap> images;

  @override
  State<_InventoryImageCarousel> createState() =>
      _InventoryImageCarouselState();
}

class _InventoryImageCarouselState extends State<_InventoryImageCarousel> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final images =
        widget.images
            .where((image) => '${image['imagePath'] ?? ''}'.trim().isNotEmpty)
            .toList();
    final colors = Theme.of(context).colorScheme;
    if (images.isEmpty) {
      return Container(
        height: 148,
        color: colors.surfaceContainerHighest,
        child: Icon(
          Icons.image_not_supported_outlined,
          color: colors.onSurfaceVariant,
          size: 36,
        ),
      );
    }
    return SizedBox(
      height: 148,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            itemCount: images.length,
            onPageChanged: (page) => setState(() => _page = page),
            itemBuilder:
                (context, index) => Image.network(
                  AdminApi.imageUrl('${images[index]['imagePath']}'),
                  fit: BoxFit.cover,
                  errorBuilder:
                      (_, __, ___) => Container(
                        color: colors.surfaceContainerHighest,
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                ),
          ),
          if (images.length > 1)
            Positioned(
              bottom: 7,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  images.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: _page == index ? 14 : 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color:
                          _page == index
                              ? colors.primary
                              : colors.surface.withValues(alpha: .8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
        ],
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
