import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/admin_api.dart';
import '../../core/providers.dart';
import '../../core/ui_helpers.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  bool _saving = false;

  Future<void> _createProduct() async {
    final values = await showDialog<JsonMap>(context: context, builder: (_) => const _CreateProductDialog());
    if (values == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await ref.read(adminApiProvider).createProduct(values);
      ref.invalidate(productsProvider);
      if (mounted) showAppMessage(context, 'محصول به‌صورت پیش‌نویس ثبت شد.');
    } catch (error) {
      if (mounted) showAppMessage(context, AdminApi.friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleStatus(JsonMap product) async {
    final next = product['status'] == 'published' ? 'draft' : 'published';
    try {
      await ref.read(adminApiProvider).updateProduct('${product['id']}', {'status': next});
      ref.invalidate(productsProvider);
      if (mounted) showAppMessage(context, next == 'published' ? 'محصول در سایت منتشر شد.' : 'محصول به پیش‌نویس برگشت.');
    } catch (error) {
      if (mounted) showAppMessage(context, AdminApi.friendlyError(error), error: true);
    }
  }

  Future<void> _editVariant(JsonMap variant) async {
    final result = await showDialog<JsonMap>(context: context, builder: (_) => _EditVariantDialog(variant: variant));
    if (result == null || !mounted) return;
    try {
      await ref.read(adminApiProvider).updateVariant('${variant['id']}', result);
      ref.invalidate(productsProvider);
      ref.invalidate(dashboardProvider);
      if (mounted) showAppMessage(context, 'قیمت و تنظیمات تنوع ذخیره شد.');
    } catch (error) {
      if (mounted) showAppMessage(context, AdminApi.friendlyError(error), error: true);
    }
  }

  Future<void> _addVariant(JsonMap product) async {
    final input = await showDialog<JsonMap>(context: context, builder: (_) => _AddVariantDialog(productName: '${product['name'] ?? ''}'));
    if (input == null || !mounted) return;
    try {
      await ref.read(adminApiProvider).addProductVariant('${product['id']}', input);
      ref.invalidate(productsProvider);
      ref.invalidate(dashboardProvider);
      if (mounted) showAppMessage(context, 'تنوع جدید به محصول اضافه شد.');
    } catch (error) {
      if (mounted) showAppMessage(context, AdminApi.friendlyError(error), error: true);
    }
  }

  Future<void> _addImage(JsonMap product) async {
    final input = await showDialog<JsonMap>(context: context, builder: (_) => _AddProductImageDialog(productName: '${product['name'] ?? ''}'));
    if (input == null || !mounted) return;
    try {
      await ref.read(adminApiProvider).addProductImage('${product['id']}', input);
      ref.invalidate(productsProvider);
      if (mounted) showAppMessage(context, 'تصویر به گالری محصول اضافه شد.');
    } catch (error) {
      if (mounted) showAppMessage(context, AdminApi.friendlyError(error), error: true);
    }
  }

  Future<void> _deleteImage(JsonMap product, JsonMap image) async {
    final accepted = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('حذف تصویر؟'),
      content: Text('تصویر از گالری «${product['name']}» حذف می‌شود.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('بازگشت')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف تصویر'))],
    ));
    if (accepted != true || !mounted) return;
    try {
      await ref.read(adminApiProvider).deleteProductImage('${product['id']}', '${image['id']}');
      ref.invalidate(productsProvider);
      if (mounted) showAppMessage(context, 'تصویر حذف شد.');
    } catch (error) {
      if (mounted) showAppMessage(context, AdminApi.friendlyError(error), error: true);
    }
  }

  Future<void> _archive(JsonMap product) async {
    final accepted = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('بایگانی محصول؟'),
      content: Text('«${product['name']}» از ویترین خارج می‌شود و سابقهٔ سفارش‌هایش حفظ می‌شود.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('بازگشت')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('بایگانی'))],
    ));
    if (accepted != true || !mounted) return;
    try {
      await ref.read(adminApiProvider).archiveProduct('${product['id']}');
      ref.invalidate(productsProvider);
      if (mounted) showAppMessage(context, 'محصول بایگانی شد.');
    } catch (error) {
      if (mounted) showAppMessage(context, AdminApi.friendlyError(error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider);
    return Stack(children: [
      products.when(
        loading: () => Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary)),
        error: (error, _) => _InlineError(message: AdminApi.friendlyError(error), onRetry: () => ref.invalidate(productsProvider)),
        data: (items) => RefreshIndicator(
          onRefresh: () => ref.refresh(productsProvider.future),
          color: Theme.of(context).colorScheme.primary,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
            children: [
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('کاتالوگ فروشگاه', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19, color: Theme.of(context).colorScheme.onSurface)),
                  Text('${persianNumber(items.length)} محصول', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ])),
                IconButton(tooltip: 'به‌روزرسانی', onPressed: () => ref.invalidate(productsProvider), icon: const Icon(Icons.refresh_rounded)),
              ]),
              const SizedBox(height: 13),
              if (items.isEmpty) const _ProductsEmpty()
              else ...items.map((product) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ProductCard(
                  product: product,
                  onStatus: () => _toggleStatus(product),
                  onArchive: () => _archive(product),
                  onEditVariant: _editVariant,
                  onAddVariant: () => _addVariant(product),
                  onAddImage: () => _addImage(product),
                  onDeleteImage: (image) => _deleteImage(product, image),
                ),
              )),
              if (_saving) LinearProgressIndicator(color: Theme.of(context).colorScheme.primary),
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
    ]);
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.onStatus, required this.onArchive, required this.onEditVariant, required this.onAddVariant, required this.onAddImage, required this.onDeleteImage});
  final JsonMap product;
  final VoidCallback onStatus;
  final VoidCallback onArchive;
  final ValueChanged<JsonMap> onEditVariant;
  final VoidCallback onAddVariant;
  final VoidCallback onAddImage;
  final ValueChanged<JsonMap> onDeleteImage;

  @override
  Widget build(BuildContext context) {
    final images = product['images'] is List ? (product['images'] as List).whereType<Map>().toList() : const [];
    final variants = product['variants'] is List ? (product['variants'] as List).whereType<Map>().map((entry) => Map<String, dynamic>.from(entry)).toList() : const <JsonMap>[];
    final status = '${product['status'] ?? ''}';
    final imagePath = images.isNotEmpty ? '${images.first['imagePath'] ?? ''}' : '';
    return Card(child: ExpansionTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: imagePath.isEmpty
            ? Container(width: 52, height: 58, color: Theme.of(context).colorScheme.secondaryContainer, child: Icon(Icons.checkroom_rounded, color: Theme.of(context).colorScheme.primary))
            : Image.network(AdminApi.imageUrl(imagePath), width: 52, height: 58, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 52, height: 58, color: Theme.of(context).colorScheme.secondaryContainer, child: Icon(Icons.image_not_supported_outlined, color: Theme.of(context).colorScheme.primary))),
      ),
      title: Text('${product['name'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
      subtitle: Text('${product['category']?['name'] ?? 'بدون دسته'} · ${persianNumber(variants.length)} تنوع', maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: _StatusPill(status: status),
      childrenPadding: const EdgeInsetsDirectional.fromSTEB(14, 0, 14, 14),
      children: [
        const Divider(height: 12),
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: onStatus, icon: Icon(status == 'published' ? Icons.visibility_off_outlined : Icons.publish_rounded, size: 17), label: Text(status == 'published' ? 'پیش‌نویس' : 'انتشار'))),
          const SizedBox(width: 8),
          IconButton(tooltip: 'افزودن رنگ یا سایز', onPressed: onAddVariant, color: Theme.of(context).colorScheme.primary, icon: const Icon(Icons.add_box_outlined)),
          IconButton(tooltip: 'افزودن تصویر', onPressed: onAddImage, color: Theme.of(context).colorScheme.primary, icon: const Icon(Icons.add_photo_alternate_outlined)),
          IconButton(tooltip: 'بایگانی', onPressed: onArchive, color: Theme.of(context).colorScheme.primary, icon: Icon(Icons.archive_outlined)),
        ]),
        Align(alignment: AlignmentDirectional.centerStart, child: Text('تصاویر محصول', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurfaceVariant))),
        ...images.map((image) => ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: Icon(Icons.image_outlined, color: Theme.of(context).colorScheme.primary),
          title: Text('${image['altText'] ?? image['imagePath'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
          subtitle: image['isPrimary'] == true ? Text('تصویر اصلی', style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.primary)) : null,
          trailing: IconButton(tooltip: 'حذف تصویر', onPressed: () => onDeleteImage(Map<String, dynamic>.from(image)), icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.primary, size: 20)),
        )),
        ...variants.map((variant) => ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text('${variant['colorName'] ?? ''} · ${variant['sizeLabel'] ?? ''}  (${variant['sku'] ?? ''})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          subtitle: Text('${toman(variant['priceToman'] ?? 0)} · موجود ${persianNumber(variant['availableQuantity'] ?? 0)}'),
          trailing: IconButton(tooltip: 'ویرایش قیمت', onPressed: () => onEditVariant(variant), icon: Icon(Icons.edit_outlined, color: Theme.of(context).colorScheme.primary)),
        )),
      ],
    ));
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(color: statusColor(context, status).withValues(alpha: .1), borderRadius: BorderRadius.circular(20)),
    child: Text(statusLabel(status), style: TextStyle(color: statusColor(context, status), fontSize: 10, fontWeight: FontWeight.w700)),
  );
}

class _CreateProductDialog extends ConsumerStatefulWidget {
  const _CreateProductDialog();
  @override
  ConsumerState<_CreateProductDialog> createState() => _CreateProductDialogState();
}

class _CreateProductDialogState extends ConsumerState<_CreateProductDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _slug = TextEditingController();
  final _sku = TextEditingController();
  final _price = TextEditingController();
  final _color = TextEditingController(text: 'مشکی');
  final _size = TextEditingController(text: 'M');
  final _stock = TextEditingController(text: '0');
  final _image = TextEditingController();
  String? _categoryId;

  @override
  void dispose() {
    for (final controller in [_name, _slug, _sku, _price, _color, _size, _stock, _image]) { controller.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    return AlertDialog(
      title: const Text('ثبت محصول'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _form,
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            _field(_name, 'نام محصول', required: true),
            _field(_slug, 'شناسهٔ انگلیسی (slug)', required: true, direction: TextDirection.ltr),
            const SizedBox(height: 10),
            categories.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text(AdminApi.friendlyError(error)),
              data: (items) => DropdownButtonFormField<String>(
                initialValue: _categoryId,
                decoration: const InputDecoration(labelText: 'دسته‌بندی'),
                items: items.map((item) => DropdownMenuItem(value: '${item['id']}', child: Text('${item['name']}'))).toList(),
                onChanged: (value) => setState(() => _categoryId = value),
                validator: (value) => value == null ? 'یک دسته انتخاب کن' : null,
              ),
            ),
            const SizedBox(height: 10),
            _field(_image, 'مسیر تصویر یا نشانی HTTPS', required: true, direction: TextDirection.ltr),
            const SizedBox(height: 10),
            _field(_sku, 'کد SKU', required: true, direction: TextDirection.ltr),
            const SizedBox(height: 10),
            Row(children: [Expanded(child: _field(_color, 'رنگ', required: true)), const SizedBox(width: 8), Expanded(child: _field(_size, 'سایز', required: true))]),
            const SizedBox(height: 10),
            Row(children: [Expanded(child: _field(_price, 'قیمت به تومان', required: true, numeric: true)), const SizedBox(width: 8), Expanded(child: _field(_stock, 'موجودی اولیه', required: true, numeric: true))]),
            const SizedBox(height: 8),
            const Text('محصول به‌صورت پیش‌نویس ثبت می‌شود؛ تصویر باید مسیر معتبر سایت یا نشانی HTTPS داشته باشد.', style: TextStyle(fontSize: 11, color: Color(0xFF81777A))),
          ])),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
        FilledButton(onPressed: () {
          if (!_form.currentState!.validate() || _categoryId == null) return;
          final price = _asciiDigits(_price.text.trim());
          final stock = int.tryParse(_asciiDigits(_stock.text.trim()));
          if (int.tryParse(price) == null || stock == null) return;
          Navigator.pop(context, <String, dynamic>{
            'name': _name.text.trim(),
            'slug': _slug.text.trim().toLowerCase(),
            'categoryId': _categoryId,
            'status': 'draft',
            'images': [{'imagePath': _image.text.trim(), 'altText': _name.text.trim(), 'isPrimary': true}],
            'variants': [{'sku': _sku.text.trim().toUpperCase(), 'colorName': _color.text.trim(), 'sizeLabel': _size.text.trim(), 'priceToman': price, 'stockQuantity': stock}],
          });
        }, child: const Text('ذخیرهٔ پیش‌نویس')),
      ],
    );
  }
}

class _EditVariantDialog extends StatefulWidget {
  const _EditVariantDialog({required this.variant});
  final JsonMap variant;
  @override
  State<_EditVariantDialog> createState() => _EditVariantDialogState();
}

class _EditVariantDialogState extends State<_EditVariantDialog> {
  late final _price = TextEditingController(text: '${widget.variant['priceToman'] ?? ''}');
  late final _compare = TextEditingController(text: '${widget.variant['compareAtPriceToman'] ?? ''}');
  @override
  void dispose() { _price.dispose(); _compare.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('ویرایش قیمت تنوع'),
    content: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('${widget.variant['sku'] ?? ''} · ${widget.variant['colorName'] ?? ''} / ${widget.variant['sizeLabel'] ?? ''}'),
      const SizedBox(height: 14),
      TextField(controller: _price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'قیمت فروش (تومان)')),
      const SizedBox(height: 10),
      TextField(controller: _compare, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'قیمت قبل از تخفیف (اختیاری)')),
    ]),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
      FilledButton(onPressed: () {
        final price = _asciiDigits(_price.text.trim());
        final compare = _asciiDigits(_compare.text.trim());
        if (int.tryParse(price) == null || (compare.isNotEmpty && int.tryParse(compare) == null)) return;
        Navigator.pop(context, {'priceToman': price, 'compareAtPriceToman': compare.isEmpty ? null : compare});
      }, child: const Text('ذخیره')),
    ],
  );
}

class _AddVariantDialog extends StatefulWidget {
  const _AddVariantDialog({required this.productName});
  final String productName;
  @override
  State<_AddVariantDialog> createState() => _AddVariantDialogState();
}

class _AddVariantDialogState extends State<_AddVariantDialog> {
  final _form = GlobalKey<FormState>();
  final _sku = TextEditingController();
  final _color = TextEditingController();
  final _size = TextEditingController();
  final _price = TextEditingController();
  final _stock = TextEditingController(text: '0');
  @override
  void dispose() { _sku.dispose(); _color.dispose(); _size.dispose(); _price.dispose(); _stock.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('افزودن تنوع محصول'),
    content: Form(key: _form, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(widget.productName, style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      _field(_sku, 'کد SKU', required: true, direction: TextDirection.ltr),
      const SizedBox(height: 10),
      Row(children: [Expanded(child: _field(_color, 'رنگ', required: true)), const SizedBox(width: 8), Expanded(child: _field(_size, 'سایز', required: true))]),
      const SizedBox(height: 10),
      Row(children: [Expanded(child: _field(_price, 'قیمت به تومان', required: true, numeric: true)), const SizedBox(width: 8), Expanded(child: _field(_stock, 'موجودی اولیه', required: true, numeric: true))]),
    ]))),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
      FilledButton(onPressed: () {
        if (!_form.currentState!.validate()) return;
        final price = _asciiDigits(_price.text.trim());
        final stock = int.tryParse(_asciiDigits(_stock.text.trim()));
        if (int.tryParse(price) == null || stock == null) return;
        Navigator.pop(context, {
          'sku': _sku.text.trim().toUpperCase(),
          'colorName': _color.text.trim(),
          'sizeLabel': _size.text.trim(),
          'priceToman': price,
          'stockQuantity': stock,
        });
      }, child: const Text('افزودن تنوع')),
    ],
  );
}

class _AddProductImageDialog extends StatefulWidget {
  const _AddProductImageDialog({required this.productName});
  final String productName;
  @override
  State<_AddProductImageDialog> createState() => _AddProductImageDialogState();
}

class _AddProductImageDialogState extends State<_AddProductImageDialog> {
  final _form = GlobalKey<FormState>();
  final _path = TextEditingController();
  final _alt = TextEditingController();
  bool _primary = false;
  @override
  void dispose() { _path.dispose(); _alt.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('افزودن تصویر به گالری'),
    content: Form(key: _form, child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(widget.productName, style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      TextFormField(controller: _path, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'مسیر سایت یا نشانی HTTPS'), validator: (value) {
        final path = value?.trim() ?? '';
        return path.startsWith('/') || path.startsWith('https://') ? null : 'مسیر سایت با / یا نشانی HTTPS وارد کن';
      }),
      const SizedBox(height: 10),
      TextFormField(controller: _alt, decoration: const InputDecoration(labelText: 'توضیح تصویر برای دسترس‌پذیری')),
      const SizedBox(height: 6),
      SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, value: _primary, onChanged: (value) => setState(() => _primary = value), title: const Text('تصویر اصلی محصول', style: TextStyle(fontSize: 13))),
      const Text('فایل تصویر باید از قبل در سایت یا نشانی HTTPS میزبانی شده باشد.', style: TextStyle(fontSize: 11, color: Color(0xFF81777A))),
    ])),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
      FilledButton(onPressed: () {
        if (!_form.currentState!.validate()) return;
        Navigator.pop(context, {'imagePath': _path.text.trim(), 'altText': _alt.text.trim(), 'isPrimary': _primary});
      }, child: const Text('افزودن تصویر')),
    ],
  );
}

class _ProductsEmpty extends StatelessWidget {
  const _ProductsEmpty();
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: EdgeInsets.all(26), child: Column(children: [Icon(Icons.checkroom_outlined, size: 34, color: Theme.of(context).colorScheme.primary), SizedBox(height: 10), Text('محصولی ثبت نشده'), SizedBox(height: 8), Text('برای شروع روی «محصول جدید» بزن.', style: TextStyle(color: Colors.grey.shade700))])));
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(message, textAlign: TextAlign.center), const SizedBox(height: 12), OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('تلاش دوباره'))])));
}

Widget _field(TextEditingController controller, String label, {bool required = false, bool numeric = false, TextDirection? direction}) => TextFormField(
  controller: controller,
  textDirection: direction,
  keyboardType: numeric ? TextInputType.number : TextInputType.text,
  decoration: InputDecoration(labelText: label, isDense: true),
  validator: required ? (value) => (value?.trim().isNotEmpty ?? false) ? null : 'این فیلد را کامل کن' : null,
);

String _asciiDigits(String value) {
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  return value.replaceAllMapped(RegExp(r'[۰-۹٠-٩]'), (match) {
    final character = match[0]!;
    final index = persian.indexOf(character);
    return '${index >= 0 ? index : arabic.indexOf(character)}';
  });
}
