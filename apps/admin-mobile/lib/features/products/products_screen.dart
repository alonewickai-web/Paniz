import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/admin_image_picker_field.dart';
import '../../core/admin_api.dart';
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

  Future<void> _createProduct() async {
    final values = await showDialog<JsonMap>(
      context: context,
      builder: (_) => const _CreateProductDialog(),
    );
    if (values == null || !mounted) return;
    setState(() => _saving = true);
    try {
      final api = ref.read(adminApiProvider);
      final imageBytes = values.remove('_imageBytes') as Uint8List;
      final imageName = values.remove('_imageFilename') as String;
      final image = await api.uploadProductImage(imageBytes, imageName);
      values['images'] = [
        {
          'imagePath': image['imagePath'],
          'altText': values['name'],
          'isPrimary': true,
        },
      ];
      final created = await api.createProduct(values);
      ref.invalidate(productsProvider);
      if (mounted)
        showAppMessage(context, 'کد محصول: ' + created['sku'].toString());
    } catch (error) {
      if (mounted)
        showAppMessage(context, AdminApi.friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleStatus(JsonMap product) async {
    final next = product['status'] == 'published' ? 'draft' : 'published';
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
      await ref
          .read(adminApiProvider)
          .updateVariant('${variant['id']}', result);
      ref.invalidate(productsProvider);
      ref.invalidate(dashboardProvider);
      if (mounted) showAppMessage(context, 'مشخصات تنوع ذخیره شد.');
    } catch (error) {
      if (mounted)
        showAppMessage(context, AdminApi.friendlyError(error), error: true);
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
          (_) =>
              _AddProductImageDialog(productName: '${product['name'] ?? ''}'),
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
                            onStatus: () => _toggleStatus(product),
                            onEditProduct: () => _editProduct(product),
                            onArchive: () => _archive(product),
                            onEditVariant: _editVariant,
                            onAdjustVariant:
                                (variant) =>
                                    _adjustVariantInventory(product, variant),
                            onAddVariant: () => _addVariant(product),
                            onAddImage: () => _addImage(product),
                            onEditImage: (image) => _editImage(product, image),
                            onDeleteImage:
                                (image) => _deleteImage(product, image),
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

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.onStatus,
    required this.onEditProduct,
    required this.onArchive,
    required this.onEditVariant,
    required this.onAdjustVariant,
    required this.onAddVariant,
    required this.onAddImage,
    required this.onEditImage,
    required this.onDeleteImage,
  });
  final JsonMap product;
  final VoidCallback onStatus;
  final VoidCallback onEditProduct;
  final VoidCallback onArchive;
  final ValueChanged<JsonMap> onEditVariant;
  final ValueChanged<JsonMap> onAdjustVariant;
  final VoidCallback onAddVariant;
  final VoidCallback onAddImage;
  final ValueChanged<JsonMap> onEditImage;
  final ValueChanged<JsonMap> onDeleteImage;

  @override
  Widget build(BuildContext context) {
    final images =
        product['images'] is List
            ? (product['images'] as List).whereType<Map>().toList()
            : const [];
    final variants =
        product['variants'] is List
            ? (product['variants'] as List)
                .whereType<Map>()
                .map((entry) => Map<String, dynamic>.from(entry))
                .toList()
            : const <JsonMap>[];
    final status = '${product['status'] ?? ''}';
    final imagePath =
        images.isNotEmpty ? '${images.first['imagePath'] ?? ''}' : '';
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
                  : Image.network(
                    AdminApi.imageUrl(imagePath),
                    width: 52,
                    height: 58,
                    cacheWidth: 180,
                    fit: BoxFit.contain,
                    errorBuilder:
                        (_, __, ___) => Container(
                          width: 52,
                          height: 58,
                          color:
                              Theme.of(context).colorScheme.secondaryContainer,
                          child: Icon(
                            Icons.image_not_supported_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                  ),
        ),
        title: Text(
          '${product['name'] ?? ''}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${product['category']?['name'] ?? 'بدون دسته'} · ${persianNumber(variants.length)} تنوع',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: _StatusPill(status: status),
        childrenPadding: const EdgeInsetsDirectional.fromSTEB(14, 0, 14, 14),
        children: [
          const Divider(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEditProduct,
                  icon: const Icon(Icons.edit_outlined, size: 17),
                  label: const Text('ویرایش کالا'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onStatus,
                  icon: Icon(
                    status == 'published'
                        ? Icons.visibility_off_outlined
                        : Icons.publish_rounded,
                    size: 17,
                  ),
                  label: Text(status == 'published' ? 'پیش‌نویس' : 'انتشار'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            alignment: WrapAlignment.start,
            children: [
              IconButton(
                tooltip: 'افزودن رنگ یا سایز',
                onPressed: onAddVariant,
                color: Theme.of(context).colorScheme.primary,
                icon: const Icon(Icons.add_box_outlined),
              ),
              IconButton(
                tooltip: 'افزودن تصویر',
                onPressed: onAddImage,
                color: Theme.of(context).colorScheme.primary,
                icon: const Icon(Icons.add_photo_alternate_outlined),
              ),
              IconButton(
                tooltip: 'بایگانی',
                onPressed: onArchive,
                color: Theme.of(context).colorScheme.primary,
                icon: Icon(Icons.archive_outlined),
              ),
            ],
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              'تصاویر محصول',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          ...images.map(
            (image) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  AdminApi.imageUrl('${image['imagePath'] ?? ''}'),
                  width: 42,
                  height: 52,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (_, __, ___) => Icon(
                        Icons.image_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ),
              title: Text(
                '${image['altText'] ?? image['imagePath'] ?? ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11),
              ),
              subtitle:
                  image['isPrimary'] == true
                      ? Text(
                        'تصویر اصلی',
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      )
                      : null,
              trailing: Wrap(
                spacing: 2,
                children: [
                  IconButton(
                    tooltip: 'ویرایش یا تعویض تصویر',
                    onPressed:
                        () => onEditImage(Map<String, dynamic>.from(image)),
                    icon: Icon(
                      Icons.edit_outlined,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  IconButton(
                    tooltip: 'حذف تصویر',
                    onPressed:
                        () => onDeleteImage(Map<String, dynamic>.from(image)),
                    icon: Icon(
                      Icons.delete_outline,
                      color: Theme.of(context).colorScheme.error,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
          ...variants.map(
            (variant) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: _productColorFromHex(
                    variant['colorHex'],
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
              title: Text(
                '${variant['colorName'] ?? ''} · ${variant['sizeLabel'] ?? ''}  (${variant['sku'] ?? ''})',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
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
                    onPressed: () => onEditVariant(variant),
                    icon: Icon(
                      Icons.edit_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  IconButton(
                    tooltip: 'اصلاح موجودی این تنوع',
                    onPressed: () => onAdjustVariant(variant),
                    icon: Icon(
                      Icons.inventory_2_outlined,
                      color: Theme.of(context).colorScheme.tertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: statusColor(context, status).withValues(alpha: .1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      statusLabel(status),
      style: TextStyle(
        color: statusColor(context, status),
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
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
  final _stock = TextEditingController(text: '0');
  final _imagePicker = ImagePicker();
  ProductColorOption? _selectedColor = productColorPalette.first;
  String? _categoryId;
  String _size = 'M';
  Uint8List? _imageBytes;
  String? _imageFilename;

  static const _sizes = <(String, String)>[
    ('XS', 'XS'),
    ('S', 'S'),
    ('M', 'M'),
    ('L', 'L'),
    ('XL', 'XL'),
    ('XXL', 'XXL'),
    ('XXXL', 'XXXL'),
    ('Free Size', 'فری‌سایز'),
  ];

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _stock.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final selected = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1800,
        imageQuality: 84,
      );
      if (selected == null || !mounted) return;
      final bytes = await selected.readAsBytes();
      if (bytes.length > 8 * 1024 * 1024) {
        showAppMessage(
          context,
          'حجم تصویر باید کمتر از ۸ مگابایت باشد.',
          error: true,
        );
        return;
      }
      setState(() {
        _imageBytes = bytes;
        _imageFilename = selected.name;
      });
    } catch (error) {
      if (mounted)
        showAppMessage(context, AdminApi.friendlyError(error), error: true);
    }
  }

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
    return AlertDialog(
      title: const Text('ثبت محصول جدید'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                                () =>
                                    ref.invalidate(storeConfigurationProvider),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('بارگذاری دوباره دسته‌بندی‌ها'),
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
                                          item['id'].toString() == _categoryId,
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
                                        child: Text(item['name'].toString()),
                                      ),
                                    )
                                    .toList(),
                            onChanged:
                                (value) => setState(() => _categoryId = value),
                            validator:
                                (value) =>
                                    value == null
                                        ? 'یک دسته‌بندی انتخاب یا اضافه کنید'
                                        : null,
                          ),
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: TextButton.icon(
                              onPressed: _manageCategories,
                              icon: const Icon(
                                Icons.category_outlined,
                                size: 19,
                              ),
                              label: const Text('افزودن یا حذف دسته‌بندی'),
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
                const SizedBox(height: 4),
                _imagePickerControl(context),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ProductColorField(
                        initialValue: productColorPalette.first.name,
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
                        initialValue: _size,
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
                          if (value != null) setState(() => _size = value);
                        },
                      ),
                    ),
                  ],
                ),
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
            if (_imageBytes == null || _imageFilename == null) {
              showAppMessage(
                context,
                'ابتدا تصویر محصول را اضافه کنید.',
                error: true,
              );
              return;
            }
            final price = _asciiDigits(_price.text.trim()).replaceAll(',', '');
            final stock = int.tryParse(_asciiDigits(_stock.text.trim()));
            if (int.tryParse(price) == null || stock == null) return;
            Navigator.pop(context, <String, dynamic>{
              'name': _name.text.trim(),
              'categoryId': _categoryId,
              'status': 'draft',
              'variants': [
                {
                  'colorName': _selectedColor!.name,
                  'colorHex': _selectedColor!.hex,
                  'sizeLabel': _size,
                  'priceToman': price,
                  'stockQuantity': stock,
                },
              ],
              '_imageBytes': _imageBytes,
              '_imageFilename': _imageFilename,
            });
          },
          icon: const Icon(Icons.save_outlined),
          label: const Text('ثبت پیش‌نویس'),
        ),
      ],
    );
  }

  Widget _imagePickerControl(BuildContext context) {
    final hasImage = _imageBytes != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 164,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child:
              hasImage
                  ? Image.memory(_imageBytes!, fit: BoxFit.cover)
                  : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 34,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'تصویر اصلی محصول',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      Text(
                        'JPG، PNG یا WebP · حداکثر ۸ مگابایت',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickImage,
                icon: Icon(
                  hasImage
                      ? Icons.swap_horiz_rounded
                      : Icons.add_photo_alternate_outlined,
                ),
                label: Text(hasImage ? 'تغییر تصویر' : 'افزودن تصویر از گالری'),
              ),
            ),
            if (hasImage) ...[
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'حذف تصویر انتخاب‌شده',
                onPressed:
                    () => setState(() {
                      _imageBytes = null;
                      _imageFilename = null;
                    }),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ],
        ),
      ],
    );
  }
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
                            onPressed:
                                () =>
                                    ref.invalidate(storeConfigurationProvider),
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
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _published,
                  onChanged: (value) => setState(() => _published = value),
                  title: const Text('نمایش و فروش در سایت'),
                  subtitle: Text(
                    _published ? 'کالا منتشر می‌شود' : 'کالا پیش‌نویس می‌ماند',
                  ),
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
  late bool _active = widget.variant['isActive'] == true;

  static const _sizes = <(String, String)>[
    ('XS', 'XS'),
    ('S', 'S'),
    ('M', 'M'),
    ('L', 'L'),
    ('XL', 'XL'),
    ('XXL', 'XXL'),
    ('XXXL', 'XXXL'),
    ('Free Size', 'فری‌سایز'),
  ];

  @override
  void dispose() {
    _price.dispose();
    _compare.dispose();
    _threshold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sizeOptions = List<(String, String)>.from(_sizes);
    if (!sizeOptions.any((option) => option.$1 == _size)) {
      sizeOptions.add((_size, _size));
    }
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
                        initialValue: _size,
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
                          if (value != null) setState(() => _size = value);
                        },
                      ),
                    ),
                  ],
                ),
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
                const SizedBox(height: 6),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _active,
                  onChanged: (value) => setState(() => _active = value),
                  title: const Text('این تنوع فعال و قابل خرید باشد'),
                  subtitle: Text(
                    _active
                        ? 'در انتخاب‌های خرید نمایش داده می‌شود'
                        : 'از خرید پنهان می‌شود',
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
          label: const Text('ذخیرهٔ تنوع'),
        ),
      ],
    );
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final color = _selectedColor;
    if (color == null) return;
    final price = _asciiDigits(_price.text).replaceAll(',', '');
    final compare = _asciiDigits(_compare.text).replaceAll(',', '').trim();
    Navigator.pop(context, <String, dynamic>{
      'colorName': color.name,
      'colorHex': color.hex,
      'sizeLabel': _size,
      'priceToman': price,
      'compareAtPriceToman': compare.isEmpty ? null : compare,
      'lowStockThreshold': int.parse(_asciiDigits(_threshold.text)),
      'isActive': _active,
    });
  }
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
  static const _sizes = <(String, String)>[
    ('XS', 'XS'),
    ('S', 'S'),
    ('M', 'M'),
    ('L', 'L'),
    ('XL', 'XL'),
    ('XXL', 'XXL'),
    ('XXXL', 'XXXL'),
    ('Free Size', 'فری‌سایز'),
  ];

  @override
  void dispose() {
    _price.dispose();
    _stock.dispose();
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
                    initialValue: _size,
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
                      if (value != null) setState(() => _size = value);
                    },
                  ),
                ),
              ],
            ),
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
            'sizeLabel': _size,
            'priceToman': price,
            'stockQuantity': stock,
          });
        },
        child: const Text('افزودن تنوع'),
      ),
    ],
  );
}

class _AddProductImageDialog extends StatefulWidget {
  const _AddProductImageDialog({required this.productName});
  final String productName;
  @override
  State<_AddProductImageDialog> createState() => _AddProductImageDialogState();
}

class _EditProductImageDialog extends StatefulWidget {
  const _EditProductImageDialog({
    required this.productName,
    required this.image,
  });
  final String productName;
  final JsonMap image;

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
  late bool _primary = widget.image['isPrimary'] == true;

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
                      if (value?.trim().isNotEmpty == true) _imageError = false;
                    }),
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
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _primary,
                onChanged: (value) => setState(() => _primary = value),
                title: const Text('تصویر اصلی محصول'),
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
            'sortOrder': int.parse(_asciiDigits(_sortOrder.text)),
            'isPrimary': _primary,
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
  bool _imageError = false;
  bool _primary = false;
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
                    _imageError = false;
                  }),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _alt,
              decoration: const InputDecoration(
                labelText: 'توضیح تصویر برای دسترس‌پذیری',
              ),
            ),
            const SizedBox(height: 6),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _primary,
              onChanged: (value) => setState(() => _primary = value),
              title: const Text(
                'تصویر اصلی محصول',
                style: TextStyle(fontSize: 13),
              ),
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
            'isPrimary': _primary,
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
