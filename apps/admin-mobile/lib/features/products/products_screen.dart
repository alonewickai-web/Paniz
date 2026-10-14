import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../core/admin_image_picker_field.dart';
import '../../core/admin_api.dart';
import '../../core/admin_network_image.dart';
import '../../core/providers.dart';
import '../../core/ui_helpers.dart';
import 'product_colors.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  bool _saving = false;
  final Set<String> _publishingProductIds = {};

  Future<void> _createProduct() async {
    final created = await Navigator.push<JsonMap>(
      context,
      MaterialPageRoute(builder: (_) => const _CreateProductDialog()),
    );
    if (created == null || !mounted) return;
    ref.invalidate(productsProvider);
    ref.invalidate(dashboardProvider);
    showAppMessage(context, 'کد محصول: ${created['sku']}');
  }

  Future<void> _toggleStatus(JsonMap product, bool active) async {
    final next = active ? 'published' : 'draft';
    try {
      await ref.read(adminApiProvider).updateProduct('${product['id']}', {
        'status': next,
      });
      ref.invalidate(productsProvider);
      if (mounted)
        showAppMessage(
          context,
          next == 'published'
              ? 'محصول در سایت منتشر شد.'
              : 'محصول به پیش‌نویس برگشت.',
        );
    } catch (error) {
      if (mounted)
        showAppMessage(context, AdminApi.friendlyError(error), error: true);
    }
  }

  Future<void> _publishProduct(JsonMap product) async {
    final productId = '${product['id'] ?? ''}';
    final productName = '${product['name'] ?? 'محصول'}';
    if (productId.isEmpty || _publishingProductIds.contains(productId)) return;

    if (product['status'] != 'published') {
      showAppMessage(
        context,
        'برای انتشار در روبیکا، اول محصول را در سایت فعال کن.',
        error: true,
      );
      return;
    }

    final images =
        product['images'] is List
            ? (product['images'] as List)
                .whereType<Map>()
                .map((image) => Map<String, dynamic>.from(image))
                .toList()
            : <JsonMap>[];
    final image = images.cast<JsonMap?>().firstWhere(
      (item) => item?['isPrimary'] == true,
      orElse: () => images.isEmpty ? null : images.first,
    );
    final imagePath = '${image?['imagePath'] ?? ''}'.trim();
    if (imagePath.isEmpty) {
      showAppMessage(
        context,
        'برای انتشار «$productName» اول یک تصویر به محصول اضافه کن.',
        error: true,
      );
      return;
    }

    setState(() => _publishingProductIds.add(productId));
    try {
      await ref.read(adminApiProvider).createSocialPost({
        'caption': '',
        'productId': productId,
        'imageUrl': AdminApi.imageUrl(imagePath),
        'channels': ['rubika'],
      });
      if (mounted) {
        showAppMessage(
          context,
          '«$productName» همراه تصویر مستقیم برای انتشار روبیکا فرستاده شد.',
        );
      }
    } catch (error) {
      if (mounted) {
        showAppMessage(context, AdminApi.friendlyError(error), error: true);
      }
    } finally {
      if (mounted) setState(() => _publishingProductIds.remove(productId));
    }
  }

  Future<void> _toggleVariantStatus(JsonMap variant, bool active) async {
    try {
      await ref.read(adminApiProvider).updateVariant('${variant['id']}', {
        'isActive': active,
      });
      ref.invalidate(productsProvider);
      ref.invalidate(dashboardProvider);
      if (mounted)
        showAppMessage(
          context,
          active ? 'این تنوع فعال شد.' : 'این تنوع غیرفعال شد.',
        );
    } catch (error) {
      if (mounted)
        showAppMessage(context, AdminApi.friendlyError(error), error: true);
    }
  }

  Future<void> _editProduct(JsonMap product) async {
    final changes = await showDialog<JsonMap>(
      context: context,
      builder: (_) => _EditProductDialog(product: product),
    );
    if (changes == null || !mounted) return;
    try {
      await ref
          .read(adminApiProvider)
          .updateProduct('${product['id']}', changes);
      ref.invalidate(productsProvider);
      ref.invalidate(storeConfigurationProvider);
      if (mounted) showAppMessage(context, 'اطلاعات محصول ذخیره شد.');
    } catch (error) {
      if (mounted)
        showAppMessage(context, AdminApi.friendlyError(error), error: true);
    }
  }

  Future<void> _editVariant(JsonMap variant) async {
    final result = await showDialog<JsonMap>(
      context: context,
      builder: (_) => _EditVariantDialog(variant: variant),
    );
    if (result == null || !mounted) return;
    try {
      final changes = Map<String, dynamic>.from(result);
      final requestedStock = changes.remove('stockQuantity') as int?;
      await ref
          .read(adminApiProvider)
          .updateVariant('${variant['id']}', changes);
      final currentStock =
          int.tryParse('${variant['stockQuantity'] ?? 0}') ?? 0;
      final stockDelta =
          requestedStock == null ? 0 : requestedStock - currentStock;
      if (stockDelta != 0) {
        await ref
            .read(adminApiProvider)
            .adjustInventory(
              '${variant['id']}',
              stockDelta,
              'اصلاح موجودی از فرم ویرایش تنوع',
            );
      }
      ref.invalidate(productsProvider);
      ref.invalidate(dashboardProvider);
      if (mounted) showAppMessage(context, 'مشخصات تنوع ذخیره شد.');
    } catch (error) {
      if (mounted)
        showAppMessage(context, AdminApi.friendlyError(error), error: true);
    }
  }

  Future<void> _saveProductColorOrder(
    JsonMap product,
    List<JsonMap> orderedColors,
  ) async {
    try {
      for (final entry in orderedColors.indexed) {
        await ref.read(adminApiProvider).updateVariant('${entry.$2['id']}', {
          'colorSortOrder': entry.$1,
        });
      }
      ref.invalidate(productsProvider);
      if (mounted) showAppMessage(context, 'ترتیب رنگ‌ها ذخیره شد.');
    } catch (error) {
      if (mounted)
        showAppMessage(context, AdminApi.friendlyError(error), error: true);
      rethrow;
    }
  }

  Future<void> _adjustVariantInventory(JsonMap product, JsonMap variant) async {
    final change = await showDialog<JsonMap>(
      context: context,
      builder:
          (_) => _AdjustVariantInventoryDialog(
            productName: '${product['name'] ?? ''}',
            variant: variant,
          ),
    );
    if (change == null || !mounted) return;
    try {
      await ref
          .read(adminApiProvider)
          .adjustInventory(
            '${variant['id']}',
            change['delta'] as int,
            '${change['note']}',
          );
      ref.invalidate(productsProvider);
      ref.invalidate(dashboardProvider);
      if (mounted) showAppMessage(context, 'موجودی این تنوع ثبت و به‌روز شد.');
    } catch (error) {
      if (mounted)
        showAppMessage(context, AdminApi.friendlyError(error), error: true);
    }
  }

  Future<void> _addVariant(JsonMap product) async {
    final input = await showDialog<JsonMap>(
      context: context,
      builder:
          (_) => _AddVariantDialog(productName: '${product['name'] ?? ''}'),
    );
    if (input == null || !mounted) return;
    try {
      final created = await ref
          .read(adminApiProvider)
          .addProductVariant('${product['id']}', input);
      ref.invalidate(productsProvider);
      ref.invalidate(dashboardProvider);
      if (mounted)
        showAppMessage(context, 'کد تنوع جدید: ' + created['sku'].toString());
    } catch (error) {
      if (mounted)
        showAppMessage(context, AdminApi.friendlyError(error), error: true);
    }
  }

  Future<void> _addImage(JsonMap product) async {
    final input = await showDialog<JsonMap>(
      context: context,
      builder:
          (_) => _AddProductImageDialog(
            productName: '${product['name'] ?? ''}',
            colorNames: _productColorNames(product),
          ),
    );
    if (input == null || !mounted) return;
    try {
      await ref
          .read(adminApiProvider)
          .addProductImage('${product['id']}', input);
      ref.invalidate(productsProvider);
      if (mounted) showAppMessage(context, 'تصویر به گالری محصول اضافه شد.');
    } catch (error) {
      if (mounted)
        showAppMessage(context, AdminApi.friendlyError(error), error: true);
    }
  }

  Future<void> _editImage(JsonMap product, JsonMap image) async {
    final changes = await showDialog<JsonMap>(
      context: context,
      builder:
          (_) => _EditProductImageDialog(
            productName: '${product['name'] ?? ''}',
            image: image,
            colorNames: _productColorNames(product),
          ),
    );
    if (changes == null || !mounted) return;
    try {
      await ref
          .read(adminApiProvider)
          .updateProductImage('${product['id']}', '${image['id']}', changes);
      ref.invalidate(productsProvider);
      if (mounted) showAppMessage(context, 'تصویر و تنظیماتش ذخیره شد.');
    } catch (error) {
      if (mounted)
        showAppMessage(context, AdminApi.friendlyError(error), error: true);
    }
  }

  Future<void> _makePrimaryImage(JsonMap product, JsonMap image) async {
    try {
      await ref.read(adminApiProvider).updateProductImage(
        '${product['id']}',
        '${image['id']}',
        {'isPrimary': true},
      );
      ref.invalidate(productsProvider);
      if (mounted)
        showAppMessage(
          context,
          'تصویر انتخاب‌شده به تصویر اصلی و اولین عکس تبدیل شد.',
        );
    } catch (error) {
      if (mounted)
        showAppMessage(context, AdminApi.friendlyError(error), error: true);
    }
  }

  Future<void> _deleteImage(JsonMap product, JsonMap image) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('حذف تصویر؟'),
            content: Text('تصویر از گالری «${product['name']}» حذف می‌شود.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('بازگشت'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('حذف تصویر'),
              ),
            ],
          ),
    );
    if (accepted != true || !mounted) return;
    try {
      await ref
          .read(adminApiProvider)
          .deleteProductImage('${product['id']}', '${image['id']}');
      ref.invalidate(productsProvider);
      if (mounted) showAppMessage(context, 'تصویر حذف شد.');
    } catch (error) {
      if (mounted)
        showAppMessage(context, AdminApi.friendlyError(error), error: true);
    }
  }

  Future<void> _archive(JsonMap product) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('بایگانی محصول؟'),
            content: Text(
              '«${product['name']}» از ویترین خارج می‌شود و سابقهٔ سفارش‌هایش حفظ می‌شود.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('بازگشت'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('بایگانی'),
              ),
            ],
          ),
    );
    if (accepted != true || !mounted) return;
    try {
      await ref.read(adminApiProvider).archiveProduct('${product['id']}');
      ref.invalidate(productsProvider);
      if (mounted) showAppMessage(context, 'محصول بایگانی شد.');
    } catch (error) {
      if (mounted)
        showAppMessage(context, AdminApi.friendlyError(error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider);
    return Stack(
      children: [
        products.when(
          loading:
              () => Center(
                child: CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
          error:
              (error, _) => _InlineError(
                message: AdminApi.friendlyError(error),
                onRetry: () => ref.invalidate(productsProvider),
              ),
          data:
              (items) => RefreshIndicator(
                onRefresh: () => ref.refresh(productsProvider.future),
                color: Theme.of(context).colorScheme.primary,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'کاتالوگ فروشگاه',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 19,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                '${persianNumber(items.length)} محصول',
                                style: TextStyle(
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'به‌روزرسانی',
                          onPressed: () => ref.invalidate(productsProvider),
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 13),
                    if (items.isEmpty)
                      const _ProductsEmpty()
                    else
                      ...items.map(
                        (product) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ProductCard(
                            product: product,
                            onPublish: () => _publishProduct(product),
                            publishing: _publishingProductIds.contains(
                              '${product['id']}',
                            ),
                            onStatus:
                                (active) => _toggleStatus(product, active),
                            onEditProduct: () => _editProduct(product),
                            onArchive: () => _archive(product),
                            onEditVariant: _editVariant,
                            onAdjustVariant:
                                (variant) =>
                                    _adjustVariantInventory(product, variant),
                            onAddVariant: () => _addVariant(product),
                            onSaveColorOrder:
                                (colors) =>
                                    _saveProductColorOrder(product, colors),
                            onAddImage: () => _addImage(product),
                            onEditImage: (image) => _editImage(product, image),
                            onDeleteImage:
                                (image) => _deleteImage(product, image),
                            onMakePrimaryImage:
                                (image) => _makePrimaryImage(product, image),
                            onToggleVariant:
                                (variant, active) =>
                                    _toggleVariantStatus(variant, active),
                          ),
                        ),
                      ),
                    if (_saving)
                      LinearProgressIndicator(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                  ],
                ),
              ),
        ),
        if (ref.watch(authProvider).value?.can('products.create') == true)
          PositionedDirectional(
            end: 18,
            bottom: 18,
            child: FloatingActionButton.extended(
              onPressed: _saving ? null : _createProduct,
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('محصول جدید'),
            ),
          ),
      ],
    );
  }
}

class _ProductCard extends ConsumerWidget {
  const _ProductCard({
    required this.product,
    required this.onPublish,
    required this.publishing,
    required this.onStatus,
    required this.onEditProduct,
    required this.onArchive,
    required this.onEditVariant,
    required this.onAdjustVariant,
    required this.onAddVariant,
    required this.onSaveColorOrder,
    required this.onAddImage,
    required this.onEditImage,
    required this.onDeleteImage,
    required this.onMakePrimaryImage,
    required this.onToggleVariant,
  });
  final JsonMap product;
  final VoidCallback onPublish;
  final bool publishing;
  final ValueChanged<bool> onStatus;
  final VoidCallback onEditProduct;
  final VoidCallback onArchive;
  final ValueChanged<JsonMap> onEditVariant;
  final ValueChanged<JsonMap> onAdjustVariant;
  final VoidCallback onAddVariant;
  final Future<void> Function(List<JsonMap> orderedColors) onSaveColorOrder;
  final VoidCallback onAddImage;
  final ValueChanged<JsonMap> onEditImage;
  final ValueChanged<JsonMap> onDeleteImage;
  final ValueChanged<JsonMap> onMakePrimaryImage;
  final void Function(JsonMap variant, bool active) onToggleVariant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final admin = ref.watch(authProvider).value;
    bool can(String key) => admin?.can(key) == true;
    final images =
        product['images'] is List
            ? (product['images'] as List)
                .whereType<Map>()
                .map((entry) => Map<String, dynamic>.from(entry))
                .toList()
            : const <JsonMap>[];
    final variants =
        product['variants'] is List
            ? (product['variants'] as List)
                .whereType<Map>()
                .map((entry) => Map<String, dynamic>.from(entry))
                .toList()
            : const <JsonMap>[];
    final status = '${product['status'] ?? ''}';
    final imagePath = images
        .map((image) => '${image['imagePath'] ?? ''}'.trim())
        .firstWhere((path) => path.isNotEmpty, orElse: () => '');
    return Card(
      child: ExpansionTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child:
              imagePath.isEmpty
                  ? Container(
                    width: 52,
                    height: 58,
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    child: Icon(
                      Icons.checkroom_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  )
                  : AdminNetworkImage(
                    imagePath: imagePath,
                    width: 52,
                    height: 58,
                    cacheWidth: 180,
                    fit: BoxFit.contain,
                    placeholderColor:
                        Theme.of(context).colorScheme.secondaryContainer,
                  ),
        ),
        title: Text(
          '${product['name'] ?? ''}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${product['category']?['name'] ?? 'بدون دسته'} · ${persianNumber(variants.length)} تنوع · ${status == 'published' ? 'فعال' : 'پیش‌نویس'}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (can('marketing.rubika.publish'))
              TextButton.icon(
                onPressed: publishing ? null : onPublish,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  visualDensity: VisualDensity.compact,
                ),
                icon:
                    publishing
                        ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.send_outlined, size: 16),
                label: const Text('انتشار', style: TextStyle(fontSize: 12)),
              ),
            const Icon(Icons.expand_more_rounded, size: 20),
          ],
        ),
        childrenPadding: const EdgeInsetsDirectional.fromSTEB(14, 0, 14, 14),
        children: [
          const Divider(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: can('products.edit') ? onEditProduct : null,
                  icon: const Icon(Icons.edit_outlined, size: 17),
                  label: const Text('ویرایش کالا'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActiveStateSwitch(
                  title: 'نمایش در سایت',
                  value: status == 'published',
                  onChanged: can('products.publish') ? onStatus : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: can('products.edit') ? onAddVariant : null,
                  icon: const Icon(Icons.add_box_outlined, size: 18),
                  label: const Text('افزودن تنوع'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: can('products.edit') ? onAddImage : null,
                  icon: const Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 18,
                  ),
                  label: const Text('افزودن تصویر'),
                ),
              ),
              IconButton(
                tooltip: 'بایگانی محصول',
                onPressed: can('products.archive') ? onArchive : null,
                icon: const Icon(Icons.archive_outlined),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              'گالری تصاویر (${persianNumber(images.length)})',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),
          _ProductImageCarousel(
            images: images,
            onEdit: onEditImage,
            onDelete: onDeleteImage,
            onMakePrimary: onMakePrimaryImage,
          ),
          const SizedBox(height: 8),
          _ProductVariantsSection(
            variants: variants,
            canEdit: can('products.edit'),
            canEditPrice: can('products.edit') && can('products.change_price'),
            canAdjustStock: can('products.change_stock'),
            onSaveColorOrder: onSaveColorOrder,
            onEditVariant: onEditVariant,
            onAdjustVariant: onAdjustVariant,
            onToggleVariant: onToggleVariant,
          ),
        ],
      ),
    );
  }
}

class _ProductColorGroup {
  _ProductColorGroup({
    required this.key,
    required this.name,
    required this.hex,
    required this.variants,
  });

  final String key;
  final String name;
  final Object? hex;
  final List<JsonMap> variants;

  JsonMap get representative => variants.first;
}

List<_ProductColorGroup> _groupProductColors(List<JsonMap> variants) {
  final groups = <_ProductColorGroup>[];
  final indices = <String, int>{};
  for (final variant in variants) {
    final name = '${variant['colorName'] ?? ''}'.trim();
    final normalized = normalizeProductColorText(name);
    final key = normalized.isEmpty ? 'بدون رنگ' : normalized;
    final existingIndex = indices[key];
    if (existingIndex == null) {
      indices[key] = groups.length;
      groups.add(
        _ProductColorGroup(
          key: key,
          name: name.isEmpty ? 'بدون رنگ' : name,
          hex: variant['colorHex'],
          variants: [variant],
        ),
      );
    } else {
      groups[existingIndex].variants.add(variant);
    }
  }
  return groups;
}

class _ProductVariantsSection extends StatefulWidget {
  const _ProductVariantsSection({
    required this.variants,
    required this.canEdit,
    required this.canEditPrice,
    required this.canAdjustStock,
    required this.onSaveColorOrder,
    required this.onEditVariant,
    required this.onAdjustVariant,
    required this.onToggleVariant,
  });

  final List<JsonMap> variants;
  final bool canEdit;
  final bool canEditPrice;
  final bool canAdjustStock;
  final Future<void> Function(List<JsonMap> orderedColors) onSaveColorOrder;
  final ValueChanged<JsonMap> onEditVariant;
  final ValueChanged<JsonMap> onAdjustVariant;
  final void Function(JsonMap variant, bool active) onToggleVariant;

  @override
  State<_ProductVariantsSection> createState() =>
      _ProductVariantsSectionState();
}

class _ProductVariantsSectionState extends State<_ProductVariantsSection> {
  late List<_ProductColorGroup> _groups = _groupProductColors(widget.variants);
  bool _reorderingColors = false;
  bool _savingOrder = false;

  @override
  void didUpdateWidget(covariant _ProductVariantsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_reorderingColors && !_savingOrder) {
      _groups = _groupProductColors(widget.variants);
    }
  }

  Future<void> _saveOrder() async {
    setState(() => _savingOrder = true);
    try {
      await widget.onSaveColorOrder(
        _groups.map((group) => group.representative).toList(),
      );
      if (mounted) setState(() => _reorderingColors = false);
    } catch (_) {
      // The parent shows the API error; keep reorder mode open so it can be retried.
    } finally {
      if (mounted) setState(() => _savingOrder = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.variants.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'رنگ‌ها و سایزها (${persianNumber(widget.variants.length)} تنوع)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (_groups.length > 1 && widget.canEdit && !_reorderingColors)
              OutlinedButton.icon(
                onPressed: () => setState(() => _reorderingColors = true),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                icon: const Icon(Icons.swap_vert_rounded, size: 18),
                label: const Text('مرتب‌سازی رنگ‌ها'),
              ),
          ],
        ),
        const SizedBox(height: 6),
        if (_reorderingColors) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Column(
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    'دستگیرهٔ کنار هر رنگ را بگیر و آن را به جایگاه دلخواه بکش.',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: _groups.length,
                  onReorderItem: (oldIndex, newIndex) {
                    if (oldIndex == newIndex) return;
                    setState(() {
                      final group = _groups.removeAt(oldIndex);
                      _groups.insert(newIndex, group);
                    });
                  },
                  itemBuilder: (context, index) {
                    final group = _groups[index];
                    final sizes = group.variants
                        .map((variant) => '${variant['sizeLabel'] ?? ''}')
                        .where((size) => size.trim().isNotEmpty)
                        .toSet()
                        .join('، ');
                    return Card(
                      key: ValueKey('product-color-${group.key}'),
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      child: ListTile(
                        minLeadingWidth: 34,
                        leading: CircleAvatar(
                          radius: 17,
                          backgroundColor: colorScheme.secondaryContainer,
                          child: Text(
                            persianNumber(index + 1),
                            style: TextStyle(
                              color: colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        title: Row(
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: _productColorFromHex(
                                  group.hex,
                                  colorScheme.surfaceContainerHighest,
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: colorScheme.outlineVariant,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                group.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          'سایزها: ${sizes.isEmpty ? '—' : sizes} · ${persianNumber(group.variants.length)} تنوع',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: ReorderableDragStartListener(
                          index: index,
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: Icon(
                              Icons.drag_handle_rounded,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            _savingOrder
                                ? null
                                : () => setState(() {
                                  _reorderingColors = false;
                                  _groups = _groupProductColors(
                                    widget.variants,
                                  );
                                }),
                        child: const Text('لغو'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _savingOrder ? null : _saveOrder,
                        icon:
                            _savingOrder
                                ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Icon(Icons.check_rounded, size: 18),
                        label: Text(
                          _savingOrder ? 'در حال ذخیره' : 'ذخیرهٔ ترتیب',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ] else
          ...widget.variants.map((variant) => _variantTile(context, variant)),
      ],
    );
  }

  Widget _variantTile(BuildContext context, JsonMap variant) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: _productColorFromHex(
                variant['colorHex'],
                colorScheme.surfaceContainerHighest,
              ),
              shape: BoxShape.circle,
              border: Border.all(color: colorScheme.outlineVariant),
            ),
          ),
          title: Text(
            '${variant['colorName'] ?? ''} · ${variant['sizeLabel'] ?? ''}  (${variant['sku'] ?? ''})',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            '${toman(variant['priceToman'] ?? 0)} · قابل‌فروش ${persianNumber(variant['availableQuantity'] ?? 0)} · رزرو ${persianNumber(variant['reservedQuantity'] ?? 0)}${variant['isActive'] == true ? '' : ' · غیرفعال'}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Wrap(
            spacing: 0,
            children: [
              IconButton(
                tooltip: 'ویرایش همهٔ مشخصات تنوع',
                onPressed:
                    widget.canEditPrice
                        ? () => widget.onEditVariant(variant)
                        : null,
                icon: Icon(Icons.edit_outlined, color: colorScheme.primary),
              ),
              IconButton(
                tooltip: 'اصلاح موجودی این تنوع',
                onPressed:
                    widget.canAdjustStock
                        ? () => widget.onAdjustVariant(variant)
                        : null,
                icon: Icon(
                  Icons.inventory_2_outlined,
                  color: colorScheme.tertiary,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 40, bottom: 8),
          child: _ActiveStateSwitch(
            title: 'وضعیت این تنوع',
            value: variant['isActive'] == true,
            onChanged:
                widget.canEdit
                    ? (active) => widget.onToggleVariant(variant, active)
                    : null,
          ),
        ),
        const Divider(height: 8),
      ],
    );
  }
}

class _ProductImageCarousel extends StatefulWidget {
  const _ProductImageCarousel({
    required this.images,
    required this.onEdit,
    required this.onDelete,
    required this.onMakePrimary,
  });
  final List<JsonMap> images;
  final ValueChanged<JsonMap> onEdit;
  final ValueChanged<JsonMap> onDelete;
  final ValueChanged<JsonMap> onMakePrimary;

  @override
  State<_ProductImageCarousel> createState() => _ProductImageCarouselState();
}

class _ProductImageCarouselState extends State<_ProductImageCarousel> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final images = widget.images;
    if (images.isEmpty) {
      return const SizedBox(
        height: 150,
        child: Center(child: Text('هنوز تصویری ثبت نشده است')),
      );
    }
    if (_page >= images.length) _page = images.length - 1;
    final image = images[_page];
    final bytes = int.tryParse('${image['fileSizeBytes'] ?? 0}') ?? 0;
    final colorName = '${image['colorName'] ?? ''}'.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 190,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                PageView.builder(
                  itemCount: images.length,
                  onPageChanged: (value) => setState(() => _page = value),
                  itemBuilder:
                      (context, index) => Container(
                        color:
                            Theme.of(context).colorScheme.surfaceContainerLow,
                        child: AdminNetworkImage(
                          imagePath: '${images[index]['imagePath'] ?? ''}',
                          fit: BoxFit.contain,
                        ),
                      ),
                ),
                PositionedDirectional(
                  top: 8,
                  end: 8,
                  child: _imageBadge(
                    context,
                    '${persianNumber(_page + 1)} از ${persianNumber(images.length)}',
                  ),
                ),
                PositionedDirectional(
                  start: 6,
                  top: 6,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton.filledTonal(
                        tooltip: 'ویرایش تصویر',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => widget.onEdit(image),
                        icon: const Icon(Icons.edit_outlined, size: 17),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'حذف تصویر',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => widget.onDelete(image),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 17,
                        ),
                      ),
                      if (image['isPrimary'] != true)
                        IconButton.filledTonal(
                          tooltip: 'انتخاب به‌عنوان تصویر اصلی',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => widget.onMakePrimary(image),
                          icon: const Icon(
                            Icons.star_outline_rounded,
                            size: 17,
                          ),
                        ),
                    ],
                  ),
                ),
                PositionedDirectional(
                  bottom: 8,
                  start: 8,
                  end: 8,
                  child: _imageBadge(
                    context,
                    [
                      if (colorName.isNotEmpty) colorName,
                      if (bytes > 0)
                        '${persianNumber((bytes / 1024).ceil())} کیلوبایت',
                      if (image['isPrimary'] == true) 'تصویر اصلی',
                    ].join(' · '),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (images.length > 1) ...[
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 5,
            children: [
              for (var index = 0; index < images.length; index++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: index == _page ? 18 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color:
                        index == _page
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _imageBadge(BuildContext context, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: .9),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      text.isEmpty ? 'بدون برچسب' : text,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
    ),
  );
}

class _ActiveStateSwitch extends StatelessWidget {
  const _ActiveStateSwitch({
    required this.title,
    required this.value,
    required this.onChanged,
  });
  final String title;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsetsDirectional.only(
        start: 10,
        end: 4,
        top: 2,
        bottom: 2,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  value ? 'فعال' : 'غیرفعال',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
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

class _CreateProductDialog extends ConsumerStatefulWidget {
  const _CreateProductDialog();
  @override
  ConsumerState<_CreateProductDialog> createState() =>
      _CreateProductDialogState();
}

class _CreateProductDialogState extends ConsumerState<_CreateProductDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _cost = TextEditingController(text: '0');
  final _stock = TextEditingController(text: '0');
  ProductColorOption? _selectedColor = productColorPalette.first;
  String? _categoryId;
  String _size = 'M';
  bool _numericRange = false;
  final _rangeStart = TextEditingController();
  final _rangeEnd = TextEditingController();
  final List<_ProductImageDraft> _images = [_ProductImageDraft()];
  int _primaryImageIndex = 0;
  int _previewImageIndex = 0;
  bool _imageError = false;
  int _step = 0;
  bool _submitting = false;

  static const _sizes = <(String, String)>[
    ('XS', 'XS'),
    ('S', 'S'),
    ('M', 'M'),
    ('L', 'L'),
    ('XL', 'XL'),
    ('XXL', 'XXL'),
    ('XXXL', 'XXXL'),
    ('34', '۳۴'),
    ('36', '۳۶'),
    ('38', '۳۸'),
    ('40', '۴۰'),
    ('42', '۴۲'),
    ('44', '۴۴'),
    ('46', '۴۶'),
    ('48', '۴۸'),
    ('50', '۵۰'),
    ('52', '۵۲'),
    ('Free Size', 'فری‌سایز'),
    ('__numeric_range__', 'محدودهٔ عددی'),
  ];

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _cost.dispose();
    _stock.dispose();
    _rangeStart.dispose();
    _rangeEnd.dispose();
    super.dispose();
  }

  void _setImagePath(int index, String? path) {
    setState(() {
      final previous = _images[index];
      _images[index] = _ProductImageDraft(
        imagePath: path,
        fileSizeBytes: path == null ? null : previous.fileSizeBytes,
        colorName: previous.colorName,
      );
      if (_images[index].imagePath?.isNotEmpty == true) _imageError = false;
    });
  }

  void _setImageSize(int index, int? fileSizeBytes) {
    setState(() {
      _images[index] = _ProductImageDraft(
        imagePath: _images[index].imagePath,
        fileSizeBytes: fileSizeBytes,
        colorName: _images[index].colorName,
      );
    });
  }

  void _setImageColor(int index, String? colorName) {
    setState(() {
      _images[index] = _ProductImageDraft(
        imagePath: _images[index].imagePath,
        fileSizeBytes: _images[index].fileSizeBytes,
        colorName: colorName,
      );
    });
  }

  void _removeImageSlot(int index) {
    setState(() {
      _images.removeAt(index);
      if (_images.isEmpty) _images.add(const _ProductImageDraft());
      if (_primaryImageIndex == index)
        _primaryImageIndex = 0;
      else if (_primaryImageIndex > index)
        _primaryImageIndex--;
      _imageError = false;
    });
  }

  String get _resolvedCreateSize =>
      _numericRange
          ? '${_asciiDigits(_rangeStart.text.trim())} تا ${_asciiDigits(_rangeEnd.text.trim())}'
          : _size;

  Widget _createSizeRangeField(
    TextEditingController controller,
    String label,
  ) => TextFormField(
    controller: controller,
    keyboardType: TextInputType.number,
    textAlign: TextAlign.center,
    decoration: InputDecoration(labelText: label),
    validator: (value) {
      final number = int.tryParse(_asciiDigits(value ?? '').trim());
      if (number == null || number < 20 || number > 80)
        return 'عدد بین ۲۰ و ۸۰';
      final start = int.tryParse(_asciiDigits(_rangeStart.text.trim()));
      final end = int.tryParse(_asciiDigits(_rangeEnd.text.trim()));
      if (start != null && end != null && start > end)
        return 'عدد آغاز باید کوچک‌تر باشد';
      return null;
    },
  );

  Future<void> _manageCategories() async {
    final result = await showDialog<Object?>(
      context: context,
      builder: (_) => _ManageCategoriesDialog(selectedId: _categoryId),
    );
    if (!mounted) return;
    if (result is String) setState(() => _categoryId = result);
    if (result is _CategoryRemoved && result.id == _categoryId)
      setState(() => _categoryId = null);
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('ثبت محصول جدید')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            child: Form(
              key: _form,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final stage
                            in [
                              'اطلاعات',
                              'تنوع و قیمت',
                              'تصاویر',
                              'ثبت',
                            ].indexed)
                          Chip(
                            label: Text(
                              '${persianNumber(stage.$1 + 1)}. ${stage.$2}',
                            ),
                            backgroundColor:
                                stage.$1 == _step
                                    ? Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer
                                    : null,
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (_step == 0) ...[
                      _field(_name, 'نام محصول', required: true),
                      const SizedBox(height: 10),
                      categories.when(
                        loading: () => const LinearProgressIndicator(),
                        error:
                            (error, _) => Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  AdminApi.friendlyError(error),
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed:
                                      () => ref.invalidate(
                                        storeConfigurationProvider,
                                      ),
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text(
                                    'بارگذاری دوباره دسته‌بندی‌ها',
                                  ),
                                ),
                              ],
                            ),
                        data:
                            (items) => Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                DropdownButtonFormField<String>(
                                  initialValue:
                                      items.any(
                                            (item) =>
                                                item['id'].toString() ==
                                                _categoryId,
                                          )
                                          ? _categoryId
                                          : null,
                                  decoration: const InputDecoration(
                                    labelText: 'دسته‌بندی',
                                  ),
                                  items:
                                      items
                                          .map(
                                            (item) => DropdownMenuItem(
                                              value: item['id'].toString(),
                                              child: Text(
                                                item['name'].toString(),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                  onChanged:
                                      (value) =>
                                          setState(() => _categoryId = value),
                                  validator:
                                      (value) =>
                                          value == null
                                              ? 'یک دسته‌بندی انتخاب یا اضافه کنید'
                                              : null,
                                ),
                                Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  child: TextButton.icon(
                                    onPressed:
                                        ref
                                                    .read(authProvider)
                                                    .value
                                                    ?.can('store.content') ==
                                                true
                                            ? _manageCategories
                                            : null,
                                    icon: const Icon(
                                      Icons.category_outlined,
                                      size: 19,
                                    ),
                                    label: const Text(
                                      'افزودن یا حذف دسته‌بندی',
                                    ),
                                  ),
                                ),
                                if (items.isEmpty)
                                  Text(
                                    'هنوز دسته‌بندی فعالی ندارید؛ از دکمهٔ بالا یک دسته بسازید.',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall?.copyWith(
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                      ),
                    ],
                    if (_step == 2) _imageGalleryPicker(context),
                    if (_step == 1) ...[
                      Row(
                        children: [
                          Expanded(
                            child: ProductColorField(
                              initialValue: productColorPalette.first.name,
                              selectedColor: _selectedColor,
                              onSelected:
                                  (color) =>
                                      setState(() => _selectedColor = color),
                              onQueryChanged: (query) {
                                if (_selectedColor != null &&
                                    normalizeProductColorText(query) !=
                                        normalizeProductColorText(
                                          _selectedColor!.name,
                                        )) {
                                  setState(() => _selectedColor = null);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue:
                                  _numericRange ? '__numeric_range__' : _size,
                              decoration: const InputDecoration(
                                labelText: 'سایز',
                              ),
                              items:
                                  _sizes
                                      .map(
                                        (size) => DropdownMenuItem(
                                          value: size.$1,
                                          child: Text(size.$2),
                                        ),
                                      )
                                      .toList(),
                              onChanged: (value) {
                                if (value != null)
                                  setState(() {
                                    _numericRange =
                                        value == '__numeric_range__';
                                    if (!_numericRange) _size = value;
                                  });
                              },
                            ),
                          ),
                        ],
                      ),
                      if (_numericRange) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _createSizeRangeField(
                                _rangeStart,
                                'از سایز',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _createSizeRangeField(
                                _rangeEnd,
                                'تا سایز',
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _field(
                              _price,
                              'قیمت به تومان',
                              required: true,
                              currency: true,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _field(
                              _stock,
                              'موجودی اولیه',
                              required: true,
                              numeric: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _field(
                        _cost,
                        'قیمت خرید هر عدد به تومان',
                        required: true,
                        currency: true,
                      ),
                    ],
                    if (_step == 3) ...[
                      Text(
                        _name.text,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      ListTile(
                        title: Text(
                          '${_selectedColor?.name ?? ''} · $_resolvedCreateSize',
                        ),
                        subtitle: Text('موجودی: ${persianNumber(_stock.text)}'),
                        trailing: Text(
                          toman(
                            int.tryParse(
                                  _asciiDigits(_price.text).replaceAll(',', ''),
                                ) ??
                                0,
                          ),
                        ),
                      ),
                      ListTile(
                        dense: true,
                        title: const Text('بهای خرید هر عدد'),
                        trailing: Text(
                          toman(
                            int.tryParse(
                                  _asciiDigits(_cost.text).replaceAll(',', ''),
                                ) ??
                                0,
                          ),
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        children:
                            _images
                                .where((image) => image.imagePath != null)
                                .map(
                                  (image) => SizedBox(
                                    width: 80,
                                    height: 100,
                                    child: AdminNetworkImage(
                                      imagePath: image.imagePath!,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                )
                                .toList(),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primaryContainer.withValues(alpha: .55),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.auto_awesome_rounded,
                              color: Theme.of(context).colorScheme.primary,
                              size: 19,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'کد محصول بعد از ثبت به‌صورت خودکار، مانند PDC-001، ساخته می‌شود.',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              TextButton(
                onPressed:
                    _submitting
                        ? null
                        : _step > 0
                        ? () => setState(() => _step--)
                        : () => Navigator.pop(context),
                child: Text(_step > 0 ? 'مرحلهٔ قبل' : 'انصراف'),
              ),
              FilledButton.icon(
                onPressed:
                    _submitting
                        ? null
                        : () async {
                          if (!_form.currentState!.validate()) return;
                          if (_step == 1 && _selectedColor == null) {
                            showAppMessage(
                              context,
                              'یک رنگ معتبر انتخاب کنید.',
                              error: true,
                            );
                            return;
                          }
                          if (_step == 2 &&
                              !_images.any(
                                (image) => image.imagePath?.isNotEmpty == true,
                              )) {
                            setState(() => _imageError = true);
                            return;
                          }
                          if (_step < 3) {
                            setState(() => _step++);
                            return;
                          }
                          final validImages = <JsonMap>[];
                          final selectedPrimary = _images.indexWhere(
                            (image) =>
                                image.imagePath?.isNotEmpty == true &&
                                _images.indexOf(image) == _primaryImageIndex,
                          );
                          final primaryIndex =
                              selectedPrimary >= 0
                                  ? selectedPrimary
                                  : _images.indexWhere(
                                    (image) =>
                                        image.imagePath?.isNotEmpty == true,
                                  );
                          for (var i = 0; i < _images.length; i++) {
                            final image = _images[i];
                            final path = image.imagePath?.trim();
                            if (path == null || path.isEmpty) continue;
                            validImages.add({
                              'imagePath': path,
                              'altText': _name.text.trim(),
                              'fileSizeBytes': image.fileSizeBytes ?? 0,
                              'colorName': image.colorName,
                              'sortOrder': i,
                              'isPrimary': i == primaryIndex,
                            });
                          }
                          if (validImages.isEmpty) {
                            setState(() => _imageError = true);
                            showAppMessage(
                              context,
                              'حداقل یک تصویر برای محصول انتخاب کن.',
                              error: true,
                            );
                            return;
                          }
                          final price = _asciiDigits(
                            _price.text.trim(),
                          ).replaceAll(',', '');
                          final cost = _asciiDigits(
                            _cost.text.trim(),
                          ).replaceAll(',', '');
                          final stock = int.tryParse(
                            _asciiDigits(_stock.text.trim()),
                          );
                          if (int.tryParse(price) == null ||
                              int.tryParse(cost) == null ||
                              stock == null)
                            return;
                          final values = <String, dynamic>{
                            'name': _name.text.trim(),
                            'categoryId': _categoryId,
                            'status': 'draft',
                            'purchaseCostToman': cost,
                            'images': validImages,
                            'variants': [
                              {
                                'colorName': _selectedColor!.name,
                                'colorHex': _selectedColor!.hex,
                                'sizeLabel': _resolvedCreateSize,
                                'priceToman': price,
                                'stockQuantity': stock,
                              },
                            ],
                          };
                          setState(() => _submitting = true);
                          try {
                            final created = await ref
                                .read(adminApiProvider)
                                .createProduct(values);
                            if (mounted) Navigator.pop(context, created);
                          } catch (error) {
                            if (mounted)
                              showAppMessage(
                                context,
                                AdminApi.friendlyError(error),
                                error: true,
                              );
                          } finally {
                            if (mounted) setState(() => _submitting = false);
                          }
                        },
                icon: const Icon(Icons.save_outlined),
                label: Text(
                  _submitting
                      ? 'در حال ثبت…'
                      : _step == 3
                      ? 'ثبت پیش‌نویس محصول'
                      : 'مرحلهٔ بعد',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imageGalleryPicker(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'تصاویر محصول',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              persianNumber(
                _images
                    .where((image) => image.imagePath?.isNotEmpty == true)
                    .length,
              ),
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
            ),
          ],
        ),
        if (_images.any((image) => image.imagePath?.isNotEmpty == true)) ...[
          const SizedBox(height: 8),
          Builder(
            builder: (context) {
              final readyImages =
                  _images
                      .asMap()
                      .entries
                      .where(
                        (entry) => entry.value.imagePath?.isNotEmpty == true,
                      )
                      .toList();
              if (_previewImageIndex >= readyImages.length) {
                _previewImageIndex = readyImages.length - 1;
              }
              final active = readyImages[_previewImageIndex].value;
              final bytes = active.fileSizeBytes ?? 0;
              final color = active.colorName ?? 'همهٔ رنگ‌ها';
              return Column(
                children: [
                  SizedBox(
                    height: 165,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          PageView.builder(
                            itemCount: readyImages.length,
                            onPageChanged:
                                (index) =>
                                    setState(() => _previewImageIndex = index),
                            itemBuilder:
                                (context, index) => Container(
                                  color: colors.surfaceContainerLow,
                                  child: AdminNetworkImage(
                                    imagePath:
                                        readyImages[index].value.imagePath!,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                          ),
                          PositionedDirectional(
                            top: 8,
                            end: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: colors.surface.withValues(alpha: .92),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${persianNumber(_previewImageIndex + 1)} از ${persianNumber(readyImages.length)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          PositionedDirectional(
                            bottom: 8,
                            start: 8,
                            end: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: colors.surface.withValues(alpha: .92),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$color${bytes > 0 ? ' · ${persianNumber((bytes / 1024).ceil())} کیلوبایت' : ''}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'برای جابه‌جایی عکس‌ها به چپ و راست بکشید',
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
        const SizedBox(height: 8),
        for (var index = 0; index < _images.length; index++) ...[
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color:
                    _imageError && _images[index].imagePath == null
                        ? colors.error
                        : colors.outlineVariant,
              ),
            ),
            child: Column(
              children: [
                AdminImagePickerField(
                  label: 'تصویر ${persianNumber(index + 1)}',
                  imagePath: _images[index].imagePath,
                  aspectRatio: 4 / 5,
                  onChanged: (path) => _setImagePath(index, path),
                  onFileSizeChanged: (size) => _setImageSize(index, size),
                ),
                if (_images[index].fileSizeBytes case final bytes?
                    when bytes > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        'حجم فایل: ${persianNumber((bytes / 1024).ceil())} کیلوبایت',
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _images[index].colorName ?? '',
                  decoration: const InputDecoration(
                    labelText: 'عکس مربوط به کدام رنگ است؟',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('همهٔ رنگ‌ها / تصویر عمومی'),
                    ),
                    ...productColorPalette.map(
                      (option) => DropdownMenuItem(
                        value: option.name,
                        child: Text(option.name),
                      ),
                    ),
                  ],
                  onChanged:
                      (value) => _setImageColor(
                        index,
                        value == null || value.isEmpty ? null : value,
                      ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: ChoiceChip(
                          selected: _primaryImageIndex == index,
                          onSelected:
                              _images[index].imagePath?.isNotEmpty == true
                                  ? (_) =>
                                      setState(() => _primaryImageIndex = index)
                                  : null,
                          avatar:
                              _primaryImageIndex == index
                                  ? const Icon(Icons.check_rounded, size: 17)
                                  : const Icon(
                                    Icons.vertical_align_top_rounded,
                                    size: 17,
                                  ),
                          label: const Text(
                            'تصویر اصلی و اولین عکس',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'حذف این جای تصویر',
                      onPressed:
                          _images.length > 1
                              ? () => _removeImageSlot(index)
                              : () => _setImagePath(index, null),
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        if (_imageError)
          Text(
            'حداقل یک تصویر لازم است.',
            style: TextStyle(color: colors.error, fontSize: 12),
          ),
        OutlinedButton.icon(
          onPressed:
              () => setState(() => _images.add(const _ProductImageDraft())),
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: const Text('افزودن تصویر'),
        ),
      ],
    );
  }
}

class _ProductImageDraft {
  const _ProductImageDraft({
    this.imagePath,
    this.fileSizeBytes,
    this.colorName,
  });
  final String? imagePath;
  final int? fileSizeBytes;
  final String? colorName;
}

List<String> _productColorNames(JsonMap product) {
  final variants = product['variants'];
  if (variants is! List) return const [];
  return variants
      .whereType<Map>()
      .map((variant) => '${variant['colorName'] ?? ''}'.trim())
      .where((name) => name.isNotEmpty)
      .toSet()
      .toList();
}

Widget _imageColorDropdown({
  required List<String> colorNames,
  required String? value,
  required ValueChanged<String?> onChanged,
}) {
  final options =
      colorNames
          .map((name) => name.trim())
          .where((name) => name.isNotEmpty)
          .toSet()
          .toList();
  if (value != null && value.trim().isNotEmpty && !options.contains(value)) {
    options.add(value);
  }
  return DropdownButtonFormField<String>(
    initialValue: value ?? '',
    decoration: const InputDecoration(labelText: 'عکس مربوط به کدام رنگ است؟'),
    items: [
      const DropdownMenuItem(
        value: '',
        child: Text('همهٔ رنگ‌ها / تصویر عمومی'),
      ),
      ...options.map(
        (name) => DropdownMenuItem(value: name, child: Text(name)),
      ),
    ],
    onChanged:
        (selected) =>
            onChanged(selected == null || selected.isEmpty ? null : selected),
  );
}

class _CategoryRemoved {
  const _CategoryRemoved(this.id);
  final String id;
}

class _ManageCategoriesDialog extends ConsumerWidget {
  const _ManageCategoriesDialog({required this.selectedId});
  final String? selectedId;

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _NewCategoryDialog(),
    );
    if (name == null || name.trim().isEmpty || !context.mounted) return;
    try {
      final created = await ref.read(adminApiProvider).createCategory({
        'name': name.trim(),
        'isActive': true,
      });
      ref.invalidate(storeConfigurationProvider);
      ref.invalidate(categoriesProvider);
      if (context.mounted) Navigator.pop(context, created['id'].toString());
    } catch (error) {
      if (context.mounted)
        showAppMessage(context, AdminApi.friendlyError(error), error: true);
    }
  }

  Future<void> _archive(
    BuildContext context,
    WidgetRef ref,
    JsonMap category,
  ) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('حذف دسته‌بندی؟'),
            content: Text(
              'دستهٔ «' +
                  category['name'].toString() +
                  '» از انتخاب‌های جدید حذف می‌شود. محصولات و سفارش‌های قبلی حفظ می‌شوند.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('انصراف'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('حذف دسته'),
              ),
            ],
          ),
    );
    if (accepted != true || !context.mounted) return;
    try {
      final id = category['id'].toString();
      await ref.read(adminApiProvider).archiveCategory(id);
      ref.invalidate(storeConfigurationProvider);
      ref.invalidate(categoriesProvider);
      if (context.mounted) Navigator.pop(context, _CategoryRemoved(id));
    } catch (error) {
      if (context.mounted)
        showAppMessage(context, AdminApi.friendlyError(error), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    return AlertDialog(
      title: const Text('مدیریت دسته‌بندی‌ها'),
      content: SizedBox(
        width: 420,
        height: 330,
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton.tonalIcon(
                onPressed: () => _add(context, ref),
                icon: const Icon(Icons.add_rounded),
                label: const Text('دسته‌بندی جدید'),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: categories.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error:
                    (error, _) =>
                        Center(child: Text(AdminApi.friendlyError(error))),
                data:
                    (items) =>
                        items.isEmpty
                            ? const Center(
                              child: Text('دسته‌بندی فعالی وجود ندارد.'),
                            )
                            : ListView.separated(
                              itemCount: items.length,
                              separatorBuilder:
                                  (_, __) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final category = items[index];
                                final id = category['id'].toString();
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(
                                    id == selectedId
                                        ? Icons.check_circle_rounded
                                        : Icons.category_outlined,
                                    color:
                                        id == selectedId
                                            ? Theme.of(
                                              context,
                                            ).colorScheme.primary
                                            : Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                  ),
                                  title: Text(category['name'].toString()),
                                  trailing: IconButton(
                                    tooltip: 'حذف دسته‌بندی',
                                    onPressed:
                                        () => _archive(context, ref, category),
                                    icon: Icon(
                                      Icons.delete_outline_rounded,
                                      color:
                                          Theme.of(context).colorScheme.error,
                                    ),
                                  ),
                                );
                              },
                            ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('بستن'),
        ),
      ],
    );
  }
}

class _NewCategoryDialog extends StatefulWidget {
  const _NewCategoryDialog();
  @override
  State<_NewCategoryDialog> createState() => _NewCategoryDialogState();
}

class _NewCategoryDialogState extends State<_NewCategoryDialog> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('افزودن دسته‌بندی'),
    content: TextField(
      controller: _name,
      autofocus: true,
      textInputAction: TextInputAction.done,
      decoration: const InputDecoration(labelText: 'نام دسته‌بندی'),
      onSubmitted: (value) {
        if (value.trim().isNotEmpty) Navigator.pop(context, value.trim());
      },
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('انصراف'),
      ),
      FilledButton(
        onPressed: () {
          if (_name.text.trim().isNotEmpty)
            Navigator.pop(context, _name.text.trim());
        },
        child: const Text('ثبت دسته'),
      ),
    ],
  );
}

class _EditProductDialog extends ConsumerStatefulWidget {
  const _EditProductDialog({required this.product});
  final JsonMap product;

  @override
  ConsumerState<_EditProductDialog> createState() => _EditProductDialogState();
}

class _EditProductDialogState extends ConsumerState<_EditProductDialog> {
  static const _noCategoryValue = '__no_category__';
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: '${widget.product['name'] ?? ''}',
  );
  late final _slug = TextEditingController(
    text: '${widget.product['slug'] ?? ''}',
  );
  late final _shortDescription = TextEditingController(
    text: '${widget.product['shortDescription'] ?? ''}',
  );
  late final _description = TextEditingController(
    text: '${widget.product['description'] ?? ''}',
  );
  late final _material = TextEditingController(
    text: '${widget.product['material'] ?? ''}',
  );
  late final _care = TextEditingController(
    text: '${widget.product['careInstructions'] ?? ''}',
  );
  late final _seoTitle = TextEditingController(
    text: '${widget.product['seoTitle'] ?? ''}',
  );
  late final _seoDescription = TextEditingController(
    text: '${widget.product['seoDescription'] ?? ''}',
  );
  late final _sizeGuide = TextEditingController(
    text: _formatSizeGuide(widget.product['sizeGuide']),
  );
  late final String? _originalCategoryId =
      widget.product['categoryId']?.toString() ??
      (widget.product['category'] as Map?)?['id']?.toString();
  late String _categoryId = _originalCategoryId ?? _noCategoryValue;
  late bool _published = widget.product['status'] == 'published';
  bool _advancedExpanded = false;

  @override
  void dispose() {
    _name.dispose();
    _slug.dispose();
    _shortDescription.dispose();
    _description.dispose();
    _material.dispose();
    _care.dispose();
    _seoTitle.dispose();
    _seoDescription.dispose();
    _sizeGuide.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    return AlertDialog(
      title: const Text('ویرایش اطلاعات کالا'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(_name, 'عنوان کالا', required: true),
                const SizedBox(height: 10),
                _field(
                  _slug,
                  'نشانی انگلیسی کالا',
                  direction: TextDirection.ltr,
                  validator: (value) {
                    final slug = value?.trim() ?? '';
                    return RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(slug)
                        ? null
                        : 'فقط حروف کوچک انگلیسی، عدد و خط تیره وارد کن';
                  },
                ),
                const SizedBox(height: 10),
                categories.when(
                  loading: () => const LinearProgressIndicator(),
                  error:
                      (error, _) => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            AdminApi.friendlyError(error),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => ref.invalidate(categoriesProvider),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('بارگذاری دوبارهٔ دسته‌بندی‌ها'),
                          ),
                        ],
                      ),
                  data: (items) {
                    final options = List<JsonMap>.from(items);
                    final current = widget.product['category'];
                    options.insert(0, {
                      'id': _noCategoryValue,
                      'name': 'بدون دسته‌بندی',
                    });
                    if (current is Map &&
                        _originalCategoryId != null &&
                        !options.any(
                          (item) =>
                              item['id'].toString() == _originalCategoryId,
                        )) {
                      options.add({
                        'id': _originalCategoryId,
                        'name': '${current['name'] ?? 'دستهٔ قبلی'} · غیرفعال',
                        'inactive': true,
                      });
                    }
                    return DropdownButtonFormField<String>(
                      initialValue:
                          options.any(
                                (item) => item['id'].toString() == _categoryId,
                              )
                              ? _categoryId
                              : _noCategoryValue,
                      decoration: const InputDecoration(labelText: 'دسته‌بندی'),
                      items:
                          options
                              .map(
                                (item) => DropdownMenuItem<String>(
                                  value: item['id'].toString(),
                                  enabled: item['inactive'] != true,
                                  child: Text('${item['name'] ?? ''}'),
                                ),
                              )
                              .toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => _categoryId = value);
                      },
                    );
                  },
                ),
                const SizedBox(height: 10),
                _field(_shortDescription, 'توضیح کوتاه'),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _description,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 16000,
                  decoration: const InputDecoration(labelText: 'توضیحات کامل'),
                ),
                const SizedBox(height: 10),
                _field(_material, 'جنس پارچه'),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _care,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 8000,
                  decoration: const InputDecoration(
                    labelText: 'راهنمای نگهداری',
                  ),
                ),
                const SizedBox(height: 8),
                _ActiveStateSwitch(
                  title: 'نمایش و فروش در سایت',
                  value: _published,
                  onChanged: (value) => setState(() => _published = value),
                ),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  initiallyExpanded: _advancedExpanded,
                  onExpansionChanged:
                      (expanded) =>
                          setState(() => _advancedExpanded = expanded),
                  title: const Text('سئو و راهنمای سایز'),
                  children: [
                    _field(_seoTitle, 'عنوان سئو'),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _seoDescription,
                      minLines: 2,
                      maxLines: 4,
                      maxLength: 500,
                      decoration: const InputDecoration(labelText: 'توضیح سئو'),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _sizeGuide,
                      minLines: 3,
                      maxLines: 7,
                      decoration: const InputDecoration(
                        labelText: 'راهنمای سایز (JSON اختیاری)',
                        helperText: 'نمونه: [{"سایز":"M","قد":"۶۰ سانتی‌متر"}]',
                        alignLabelWithHint: true,
                      ),
                      validator: (value) => _validateSizeGuide(value ?? ''),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('انصراف'),
        ),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save_outlined),
          label: const Text('ذخیرهٔ تغییرات'),
        ),
      ],
    );
  }

  void _save() {
    if (!_form.currentState!.validate()) {
      if (_sizeGuide.text.trim().isNotEmpty) {
        setState(() => _advancedExpanded = true);
      }
      return;
    }
    final decoded =
        _sizeGuide.text.trim().isEmpty
            ? <Map<String, dynamic>>[]
            : (jsonDecode(_sizeGuide.text.trim()) as List)
                .map((row) => Map<String, dynamic>.from(row as Map))
                .toList();
    Navigator.pop(context, <String, dynamic>{
      'name': _name.text.trim(),
      'slug': _slug.text.trim(),
      if (_categoryId != (_originalCategoryId ?? _noCategoryValue))
        'categoryId': _categoryId == _noCategoryValue ? null : _categoryId,
      'shortDescription': _shortDescription.text.trim(),
      'description': _description.text.trim(),
      'material': _material.text.trim(),
      'careInstructions': _care.text.trim(),
      'seoTitle': _seoTitle.text.trim(),
      'seoDescription': _seoDescription.text.trim(),
      'sizeGuide': decoded,
      'status': _published ? 'published' : 'draft',
    });
  }

  String? _validateSizeGuide(String value) {
    if (value.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(value.trim());
      if (decoded is! List || decoded.length > 40) {
        return 'راهنما باید آرایه‌ای با حداکثر ۴۰ ردیف باشد';
      }
      for (final row in decoded) {
        if (row is! Map ||
            row.isEmpty ||
            row.values.any((cell) => cell is! String && cell is! num)) {
          return 'هر ردیف باید کلید و مقدار متنی یا عددی داشته باشد';
        }
      }
      return null;
    } catch (_) {
      return 'ساختار JSON معتبر نیست';
    }
  }
}

String _formatSizeGuide(Object? value) {
  if (value == null) return '';
  try {
    final rows = value is Map && value['rows'] is List ? value['rows'] : value;
    return const JsonEncoder.withIndent('  ').convert(rows);
  } catch (_) {
    return '';
  }
}

class _EditVariantDialog extends StatefulWidget {
  const _EditVariantDialog({required this.variant});
  final JsonMap variant;

  @override
  State<_EditVariantDialog> createState() => _EditVariantDialogState();
}

class _EditVariantDialogState extends State<_EditVariantDialog> {
  final _form = GlobalKey<FormState>();
  late final _price = TextEditingController(
    text: _formatMoney(widget.variant['priceToman']),
  );
  late final _compare = TextEditingController(
    text:
        widget.variant['compareAtPriceToman'] == null
            ? ''
            : _formatMoney(widget.variant['compareAtPriceToman']),
  );
  late final _threshold = TextEditingController(
    text: '${widget.variant['lowStockThreshold'] ?? 3}',
  );
  late ProductColorOption? _selectedColor = _initialVariantColor(
    widget.variant,
  );
  late String _size = '${widget.variant['sizeLabel'] ?? 'Free Size'}';
  late bool _numericRange = _sizeRangePattern.hasMatch(_asciiDigits(_size));
  late final _rangeStart = TextEditingController(
    text: _sizeRangePattern.firstMatch(_asciiDigits(_size))?.group(1) ?? '',
  );
  late final _rangeEnd = TextEditingController(
    text: _sizeRangePattern.firstMatch(_asciiDigits(_size))?.group(2) ?? '',
  );
  late final _stockQuantity = TextEditingController(
    text: '${widget.variant['stockQuantity'] ?? 0}',
  );
  late bool _active = widget.variant['isActive'] == true;

  static const _sizes = <(String, String)>[
    ('XS', 'XS'),
    ('S', 'S'),
    ('M', 'M'),
    ('L', 'L'),
    ('XL', 'XL'),
    ('XXL', 'XXL'),
    ('XXXL', 'XXXL'),
    ('34', '۳۴'),
    ('36', '۳۶'),
    ('38', '۳۸'),
    ('40', '۴۰'),
    ('42', '۴۲'),
    ('44', '۴۴'),
    ('46', '۴۶'),
    ('48', '۴۸'),
    ('50', '۵۰'),
    ('52', '۵۲'),
    ('Free Size', 'فری‌سایز'),
    ('__numeric_range__', 'محدودهٔ عددی'),
  ];

  @override
  void dispose() {
    _price.dispose();
    _compare.dispose();
    _threshold.dispose();
    _rangeStart.dispose();
    _rangeEnd.dispose();
    _stockQuantity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sizeOptions = List<(String, String)>.from(_sizes);
    if (!_numericRange && !sizeOptions.any((option) => option.$1 == _size)) {
      sizeOptions.add((_size, _size));
    }
    final selectedSize = _numericRange ? '__numeric_range__' : _size;
    return AlertDialog(
      title: const Text('ویرایش تنوع محصول'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    'کد تنوع: ${widget.variant['sku'] ?? '—'}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ProductColorField(
                        initialValue: '${widget.variant['colorName'] ?? ''}',
                        selectedColor: _selectedColor,
                        onSelected:
                            (color) => setState(() => _selectedColor = color),
                        onQueryChanged: (query) {
                          if (_selectedColor != null &&
                              normalizeProductColorText(query) !=
                                  normalizeProductColorText(
                                    _selectedColor!.name,
                                  )) {
                            setState(() => _selectedColor = null);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedSize,
                        decoration: const InputDecoration(labelText: 'سایز'),
                        items:
                            sizeOptions
                                .map(
                                  (option) => DropdownMenuItem(
                                    value: option.$1,
                                    child: Text(option.$2),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) {
                          if (value != null)
                            setState(() {
                              _numericRange = value == '__numeric_range__';
                              if (!_numericRange) _size = value;
                            });
                        },
                      ),
                    ),
                  ],
                ),
                if (_numericRange) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _rangeField(_rangeStart, 'از سایز')),
                      const SizedBox(width: 8),
                      Expanded(child: _rangeField(_rangeEnd, 'تا سایز')),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                _field(
                  _price,
                  'قیمت فروش (تومان)',
                  required: true,
                  currency: true,
                  validator: (value) {
                    final amount = int.tryParse(
                      _asciiDigits(value ?? '').replaceAll(',', ''),
                    );
                    return amount == null || amount < 1
                        ? 'قیمت معتبر و بیشتر از صفر وارد کن'
                        : null;
                  },
                ),
                const SizedBox(height: 10),
                _field(
                  _compare,
                  'قیمت قبل از تخفیف (اختیاری)',
                  currency: true,
                  validator: (value) {
                    final raw =
                        _asciiDigits(value ?? '').replaceAll(',', '').trim();
                    if (raw.isEmpty) return null;
                    final compare = int.tryParse(raw);
                    final price = int.tryParse(
                      _asciiDigits(_price.text).replaceAll(',', ''),
                    );
                    if (compare == null || price == null)
                      return 'قیمت را بررسی کن';
                    if (compare <= price) return 'باید از قیمت فروش بیشتر باشد';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                _field(
                  _threshold,
                  'هشدار کمبود موجودی',
                  numeric: true,
                  validator: (value) {
                    final amount = int.tryParse(_asciiDigits(value ?? ''));
                    return amount == null || amount < 0 || amount > 1000000
                        ? 'عدد بین صفر تا یک میلیون وارد کن'
                        : null;
                  },
                ),
                const SizedBox(height: 8),
                _field(
                  _stockQuantity,
                  'موجودی کل این رنگ و سایز',
                  numeric: true,
                  validator: (value) {
                    final amount = int.tryParse(_asciiDigits(value ?? ''));
                    final reserved =
                        int.tryParse(
                          '${widget.variant['reservedQuantity'] ?? 0}',
                        ) ??
                        0;
                    return amount == null ||
                            amount < reserved ||
                            amount > 1000000
                        ? 'عدد باید بین موجودی رزروشده و یک میلیون باشد'
                        : null;
                  },
                ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    'رزرو شده: ${persianNumber(widget.variant['reservedQuantity'] ?? 0)} عدد',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                _ActiveStateSwitch(
                  title: 'فعال و قابل خرید',
                  value: _active,
                  onChanged: (value) => setState(() => _active = value),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('انصراف'),
        ),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save_outlined),
          label: const Text('ذخیرهٔ تنوع'),
        ),
      ],
    );
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final color = _selectedColor;
    if (color == null) return;
    final size =
        _numericRange
            ? '${_asciiDigits(_rangeStart.text.trim())} تا ${_asciiDigits(_rangeEnd.text.trim())}'
            : _size;
    final price = _asciiDigits(_price.text).replaceAll(',', '');
    final compare = _asciiDigits(_compare.text).replaceAll(',', '').trim();
    Navigator.pop(context, <String, dynamic>{
      'colorName': color.name,
      'colorHex': color.hex,
      'sizeLabel': size,
      'priceToman': price,
      'compareAtPriceToman': compare.isEmpty ? null : compare,
      'lowStockThreshold': int.parse(_asciiDigits(_threshold.text)),
      'stockQuantity': int.parse(_asciiDigits(_stockQuantity.text)),
      'isActive': _active,
    });
  }

  Widget _rangeField(TextEditingController controller, String label) =>
      TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        decoration: InputDecoration(labelText: label),
        validator: (value) {
          final current = int.tryParse(_asciiDigits(value ?? '').trim());
          if (current == null || current < 20 || current > 80) {
            return 'عدد بین ۲۰ و ۸۰';
          }
          final start = int.tryParse(_asciiDigits(_rangeStart.text.trim()));
          final end = int.tryParse(_asciiDigits(_rangeEnd.text.trim()));
          if (start != null && end != null && start > end) {
            return 'عدد آغاز باید کوچک‌تر باشد';
          }
          return null;
        },
      );
}

ProductColorOption _initialVariantColor(JsonMap variant) {
  final name = '${variant['colorName'] ?? 'خاکستری'}';
  final rawHex = '${variant['colorHex'] ?? '#89898D'}';
  final hex =
      RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(rawHex)
          ? rawHex.toUpperCase()
          : '#89898D';
  for (final option in productColorPalette) {
    if (normalizeProductColorText(option.name) ==
            normalizeProductColorText(name) ||
        option.aliases.any(
          (alias) =>
              normalizeProductColorText(alias) ==
              normalizeProductColorText(name),
        )) {
      return ProductColorOption(name, hex);
    }
  }
  return ProductColorOption(name, hex);
}

String _formatMoney(Object? value) {
  final raw = _asciiDigits('$value').replaceAll(RegExp(r'[^0-9]'), '');
  return raw.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
}

final _sizeRangePattern = RegExp(r'^\s*(\d{2,3})\s*(?:-|تا)\s*(\d{2,3})\s*$');

class _AdjustVariantInventoryDialog extends StatefulWidget {
  const _AdjustVariantInventoryDialog({
    required this.productName,
    required this.variant,
  });
  final String productName;
  final JsonMap variant;

  @override
  State<_AdjustVariantInventoryDialog> createState() =>
      _AdjustVariantInventoryDialogState();
}

class _AdjustVariantInventoryDialogState
    extends State<_AdjustVariantInventoryDialog> {
  final _form = GlobalKey<FormState>();
  final _quantity = TextEditingController(text: '1');
  final _note = TextEditingController();
  bool _increase = true;

  int get _available =>
      int.tryParse('${widget.variant['availableQuantity'] ?? 0}') ?? 0;
  int get _reserved =>
      int.tryParse('${widget.variant['reservedQuantity'] ?? 0}') ?? 0;

  @override
  void dispose() {
    _quantity.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('مدیریت موجودی تنوع'),
    content: SizedBox(
      width: 420,
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${widget.productName}\n${widget.variant['colorName'] ?? ''} · ${widget.variant['sizeLabel'] ?? ''} · ${widget.variant['sku'] ?? ''}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'کل موجودی: ${persianNumber(widget.variant['stockQuantity'] ?? 0)}  ·  رزرو: ${persianNumber(_reserved)}  ·  قابل‌فروش: ${persianNumber(_available)}',
                  style: const TextStyle(fontSize: 12, height: 1.5),
                ),
              ),
              const SizedBox(height: 14),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: true,
                    label: Text('افزایش'),
                    icon: Icon(Icons.add_rounded),
                  ),
                  ButtonSegment(
                    value: false,
                    label: Text('کاهش'),
                    icon: Icon(Icons.remove_rounded),
                  ),
                ],
                selected: {_increase},
                onSelectionChanged:
                    (selected) => setState(() => _increase = selected.first),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _quantity,
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'تعداد تغییر'),
                validator: (value) {
                  final amount = int.tryParse(_asciiDigits(value ?? ''));
                  if (amount == null || amount < 1)
                    return 'تعداد بیشتر از صفر وارد کن';
                  if (!_increase && amount > _available) {
                    return 'حداکثر کاهش قابل‌فروش ${persianNumber(_available)} عدد است';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _note,
                maxLength: 500,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'دلیل تغییر موجودی',
                ),
                validator:
                    (value) =>
                        (value?.trim().isNotEmpty ?? false)
                            ? null
                            : 'دلیل را وارد کن',
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _available == 0 ? null : _markOutOfStock,
                icon: const Icon(Icons.remove_shopping_cart_outlined),
                label: Text(
                  _available == 0
                      ? 'موجودی قابل‌فروش صفر است'
                      : 'اتمام موجودی قابل‌فروش',
                ),
              ),
              if (_reserved > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'تعداد رزروشده (${persianNumber(_reserved)}) حفظ می‌شود و قابل حذف نیست.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('انصراف'),
      ),
      FilledButton.icon(
        onPressed: _save,
        icon: const Icon(Icons.save_outlined),
        label: const Text('ثبت تغییر'),
      ),
    ],
  );

  void _save() {
    if (!_form.currentState!.validate()) return;
    final quantity = int.parse(_asciiDigits(_quantity.text));
    Navigator.pop(context, <String, dynamic>{
      'delta': _increase ? quantity : -quantity,
      'note': _note.text.trim(),
    });
  }

  void _markOutOfStock() {
    if (!_form.currentState!.validate()) return;
    if (_available == 0) return;
    Navigator.pop(context, <String, dynamic>{
      'delta': -_available,
      'note': _note.text.trim(),
    });
  }
}

class _AddVariantDialog extends StatefulWidget {
  const _AddVariantDialog({required this.productName});
  final String productName;
  @override
  State<_AddVariantDialog> createState() => _AddVariantDialogState();
}

class _AddVariantDialogState extends State<_AddVariantDialog> {
  final _form = GlobalKey<FormState>();
  final _price = TextEditingController();
  final _stock = TextEditingController(text: '0');
  ProductColorOption? _selectedColor;
  String _size = 'M';
  bool _numericRange = false;
  final _rangeStart = TextEditingController();
  final _rangeEnd = TextEditingController();
  static const _sizes = <(String, String)>[
    ('XS', 'XS'),
    ('S', 'S'),
    ('M', 'M'),
    ('L', 'L'),
    ('XL', 'XL'),
    ('XXL', 'XXL'),
    ('XXXL', 'XXXL'),
    ('34', '۳۴'),
    ('36', '۳۶'),
    ('38', '۳۸'),
    ('40', '۴۰'),
    ('42', '۴۲'),
    ('44', '۴۴'),
    ('46', '۴۶'),
    ('48', '۴۸'),
    ('50', '۵۰'),
    ('52', '۵۲'),
    ('Free Size', 'فری‌سایز'),
    ('__numeric_range__', 'محدودهٔ عددی'),
  ];

  @override
  void dispose() {
    _price.dispose();
    _stock.dispose();
    _rangeStart.dispose();
    _rangeEnd.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('افزودن تنوع محصول'),
    content: Form(
      key: _form,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.productName,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ProductColorField(
                    initialValue: '',
                    selectedColor: _selectedColor,
                    onSelected:
                        (color) => setState(() => _selectedColor = color),
                    onQueryChanged: (query) {
                      if (_selectedColor != null &&
                          normalizeProductColorText(query) !=
                              normalizeProductColorText(_selectedColor!.name)) {
                        setState(() => _selectedColor = null);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _numericRange ? '__numeric_range__' : _size,
                    decoration: const InputDecoration(labelText: 'سایز'),
                    items:
                        _sizes
                            .map(
                              (size) => DropdownMenuItem(
                                value: size.$1,
                                child: Text(size.$2),
                              ),
                            )
                            .toList(),
                    onChanged: (value) {
                      if (value != null)
                        setState(() {
                          _numericRange = value == '__numeric_range__';
                          if (!_numericRange) _size = value;
                        });
                    },
                  ),
                ),
              ],
            ),
            if (_numericRange) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _addVariantRangeField(_rangeStart, 'از سایز'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: _addVariantRangeField(_rangeEnd, 'تا سایز')),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _field(
                    _price,
                    'قیمت به تومان',
                    required: true,
                    currency: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _field(
                    _stock,
                    'موجودی اولیه',
                    required: true,
                    numeric: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'کد کالا برای این تنوع هم خودکار ساخته می‌شود.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('انصراف'),
      ),
      FilledButton(
        onPressed: () {
          if (!_form.currentState!.validate()) return;
          final price = _asciiDigits(_price.text.trim()).replaceAll(',', '');
          final stock = int.tryParse(_asciiDigits(_stock.text.trim()));
          if (int.tryParse(price) == null || stock == null) return;
          Navigator.pop(context, {
            'colorName': _selectedColor!.name,
            'colorHex': _selectedColor!.hex,
            'sizeLabel':
                _numericRange
                    ? '${_asciiDigits(_rangeStart.text.trim())} تا ${_asciiDigits(_rangeEnd.text.trim())}'
                    : _size,
            'priceToman': price,
            'stockQuantity': stock,
          });
        },
        child: const Text('افزودن تنوع'),
      ),
    ],
  );

  Widget _addVariantRangeField(
    TextEditingController controller,
    String label,
  ) => TextFormField(
    controller: controller,
    keyboardType: TextInputType.number,
    textAlign: TextAlign.center,
    decoration: InputDecoration(labelText: label),
    validator: (value) {
      final number = int.tryParse(_asciiDigits(value ?? '').trim());
      if (number == null || number < 20 || number > 80)
        return 'عدد بین ۲۰ و ۸۰';
      final start = int.tryParse(_asciiDigits(_rangeStart.text.trim()));
      final end = int.tryParse(_asciiDigits(_rangeEnd.text.trim()));
      if (start != null && end != null && start > end)
        return 'عدد آغاز باید کوچک‌تر باشد';
      return null;
    },
  );
}

class _AddProductImageDialog extends StatefulWidget {
  const _AddProductImageDialog({
    required this.productName,
    required this.colorNames,
  });
  final String productName;
  final List<String> colorNames;
  @override
  State<_AddProductImageDialog> createState() => _AddProductImageDialogState();
}

class _EditProductImageDialog extends StatefulWidget {
  const _EditProductImageDialog({
    required this.productName,
    required this.image,
    required this.colorNames,
  });
  final String productName;
  final JsonMap image;
  final List<String> colorNames;

  @override
  State<_EditProductImageDialog> createState() =>
      _EditProductImageDialogState();
}

class _EditProductImageDialogState extends State<_EditProductImageDialog> {
  final _form = GlobalKey<FormState>();
  bool _imageError = false;
  late final _alt = TextEditingController(
    text: '${widget.image['altText'] ?? ''}',
  );
  late final _sortOrder = TextEditingController(
    text: '${widget.image['sortOrder'] ?? 0}',
  );
  late String? _imagePath = '${widget.image['imagePath'] ?? ''}';
  late int _fileSizeBytes =
      int.tryParse('${widget.image['fileSizeBytes'] ?? 0}') ?? 0;
  late bool _primary = widget.image['isPrimary'] == true;
  late String? _colorName =
      '${widget.image['colorName'] ?? ''}'.trim().isEmpty
          ? null
          : '${widget.image['colorName']}'.trim();

  @override
  void dispose() {
    _alt.dispose();
    _sortOrder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('ویرایش تصویر کالا'),
    content: SizedBox(
      width: 440,
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  widget.productName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 12),
              AdminImagePickerField(
                label: 'تصویر کالا',
                imagePath: _imagePath,
                aspectRatio: 4 / 5,
                errorText:
                    _imageError
                        ? 'برای کالا باید دست‌کم یک تصویر انتخاب شده باشد.'
                        : null,
                onChanged:
                    (value) => setState(() {
                      _imagePath = value;
                      if (value == null) _fileSizeBytes = 0;
                      if (value?.trim().isNotEmpty == true) _imageError = false;
                    }),
                onFileSizeChanged:
                    (value) => setState(() => _fileSizeBytes = value ?? 0),
              ),
              if (_fileSizeBytes > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      'حجم فایل: ${persianNumber((_fileSizeBytes / 1024).ceil())} کیلوبایت',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _alt,
                maxLength: 240,
                decoration: const InputDecoration(
                  labelText: 'توضیح تصویر برای دسترس‌پذیری',
                ),
              ),
              const SizedBox(height: 6),
              _imageColorDropdown(
                colorNames: [
                  ...widget.colorNames,
                  if (_colorName != null &&
                      !widget.colorNames.contains(_colorName!))
                    _colorName!,
                ],
                value: _colorName,
                onChanged: (value) => setState(() => _colorName = value),
              ),
              const SizedBox(height: 6),
              _field(
                _sortOrder,
                'ترتیب نمایش',
                numeric: true,
                validator: (value) {
                  final order = int.tryParse(_asciiDigits(value ?? ''));
                  return order == null || order < 0 || order > 1000
                      ? 'عدد بین صفر تا ۱۰۰۰ وارد کن'
                      : null;
                },
              ),
              _ActiveStateSwitch(
                title: 'تصویر اصلی و اولین عکس',
                value: _primary,
                onChanged: (value) => setState(() => _primary = value),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('انصراف'),
      ),
      FilledButton.icon(
        onPressed: () {
          if (!_form.currentState!.validate()) return;
          final path = _imagePath?.trim() ?? '';
          if (path.isEmpty) {
            setState(() => _imageError = true);
            return;
          }
          Navigator.pop(context, <String, dynamic>{
            'imagePath': path,
            'altText': _alt.text.trim(),
            'colorName': _colorName,
            'sortOrder': int.parse(_asciiDigits(_sortOrder.text)),
            'isPrimary': _primary,
            'fileSizeBytes': _fileSizeBytes,
          });
        },
        icon: const Icon(Icons.save_outlined),
        label: const Text('ذخیرهٔ تصویر'),
      ),
    ],
  );
}

class _AddProductImageDialogState extends State<_AddProductImageDialog> {
  final _form = GlobalKey<FormState>();
  final _alt = TextEditingController();
  String? _imagePath;
  int? _fileSizeBytes;
  bool _imageError = false;
  bool _primary = false;
  String? _colorName;
  @override
  void dispose() {
    _alt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('افزودن تصویر به گالری'),
    content: Form(
      key: _form,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.productName,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            AdminImagePickerField(
              label: 'تصویر گالری محصول',
              imagePath: _imagePath,
              aspectRatio: 4 / 5,
              errorText:
                  _imageError ? 'برای افزودن تصویر، یک فایل انتخاب کن.' : null,
              onChanged:
                  (value) => setState(() {
                    _imagePath = value;
                    if (value == null) _fileSizeBytes = null;
                    _imageError = false;
                  }),
              onFileSizeChanged:
                  (value) => setState(() => _fileSizeBytes = value),
            ),
            if (_fileSizeBytes != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    'حجم فایل: ${persianNumber((_fileSizeBytes! / 1024).ceil())} کیلوبایت',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _alt,
              decoration: const InputDecoration(
                labelText: 'توضیح تصویر برای دسترس‌پذیری',
              ),
            ),
            const SizedBox(height: 6),
            _imageColorDropdown(
              colorNames: widget.colorNames,
              value: _colorName,
              onChanged: (value) => setState(() => _colorName = value),
            ),
            const SizedBox(height: 6),
            _ActiveStateSwitch(
              title: 'تصویر اصلی و اولین عکس',
              value: _primary,
              onChanged: (value) => setState(() => _primary = value),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('انصراف'),
      ),
      FilledButton(
        onPressed: () {
          if (_imagePath == null) {
            setState(() => _imageError = true);
            return;
          }
          if (!_form.currentState!.validate()) return;
          Navigator.pop(context, {
            'imagePath': _imagePath,
            'altText': _alt.text.trim(),
            'colorName': _colorName,
            'isPrimary': _primary,
            'fileSizeBytes': _fileSizeBytes ?? 0,
          });
        },
        child: const Text('افزودن تصویر'),
      ),
    ],
  );
}

class _ProductsEmpty extends StatelessWidget {
  const _ProductsEmpty();
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: EdgeInsets.all(26),
      child: Column(
        children: [
          Icon(
            Icons.checkroom_outlined,
            size: 34,
            color: Theme.of(context).colorScheme.primary,
          ),
          SizedBox(height: 10),
          Text('محصولی ثبت نشده'),
          SizedBox(height: 8),
          Text(
            'برای شروع روی «محصول جدید» بزن.',
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ],
      ),
    ),
  );
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('تلاش دوباره'),
          ),
        ],
      ),
    ),
  );
}

Widget _field(
  TextEditingController controller,
  String label, {
  bool required = false,
  bool numeric = false,
  bool currency = false,
  TextDirection? direction,
  String? Function(String?)? validator,
}) => TextFormField(
  controller: controller,
  textDirection: direction ?? (numeric || currency ? TextDirection.ltr : null),
  keyboardType: numeric || currency ? TextInputType.number : TextInputType.text,
  inputFormatters: currency ? [_ThousandsSeparatorInputFormatter()] : null,
  style:
      currency
          ? const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: .2,
          )
          : null,
  decoration: InputDecoration(
    labelText: label,
    isDense: !currency,
    contentPadding:
        currency
            ? const EdgeInsets.symmetric(horizontal: 16, vertical: 19)
            : null,
  ),
  validator:
      validator ??
      (required
          ? (value) =>
              (value?.trim().isNotEmpty ?? false) ? null : 'این فیلد را کامل کن'
          : null),
);

class _ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = _asciiDigits(
      newValue.text,
    ).replaceAll(RegExp(r'[^0-9]'), '');
    final limited = digits.length > 15 ? digits.substring(0, 15) : digits;
    final formatted = limited.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    final cursorSource = newValue.selection.extentOffset.clamp(
      0,
      newValue.text.length,
    );
    final digitsBeforeCursor = _asciiDigits(
      newValue.text.substring(0, cursorSource),
    ).replaceAll(RegExp(r'[^0-9]'), '').length.clamp(0, limited.length);
    var cursor = 0;
    var counted = 0;
    while (cursor < formatted.length && counted < digitsBeforeCursor) {
      if (formatted.codeUnitAt(cursor) != 44) counted++;
      cursor++;
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: cursor),
      composing: TextRange.empty,
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

Color _productColorFromHex(Object? value, Color fallback) {
  if (value is! String || !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value)) {
    return fallback;
  }
  final rgb = int.tryParse(value.substring(1), radix: 16);
  return rgb == null ? fallback : Color(0xFF000000 | rgb);
}
