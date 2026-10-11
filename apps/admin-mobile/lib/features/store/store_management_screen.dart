import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/admin_image_picker_field.dart';
import '../../core/admin_api.dart';
import '../../core/providers.dart';
import '../../core/ui_helpers.dart';

class StoreManagementScreen extends ConsumerStatefulWidget {
  const StoreManagementScreen({super.key});

  @override
  ConsumerState<StoreManagementScreen> createState() => _StoreManagementScreenState();
}

class _StoreManagementScreenState extends ConsumerState<StoreManagementScreen> {
  int _tab = 0;
  bool _saving = false;
  List<String>? _sectionOrderOverride;

  static const _tabs = ['تم', 'دسته‌ها', 'بنرها', 'چیدمان'];

  Future<void> _refresh() async {
    _sectionOrderOverride = null;
    ref.invalidate(storeConfigurationProvider);
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await action();
      ref.invalidate(storeConfigurationProvider);
      if (mounted) showAppMessage(context, success);
    } catch (error) {
      if (mounted) showAppMessage(context, AdminApi.friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(storeConfigurationProvider);
    return Column(children: [
      SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 8),
        scrollDirection: Axis.horizontal,
        child: Row(children: List.generate(_tabs.length, (index) => Padding(
          padding: const EdgeInsetsDirectional.only(end: 8),
          child: ChoiceChip(label: Text(_tabs[index]), selected: _tab == index, onSelected: (_) => setState(() => _tab = index)),
        ))),
      ),
      Expanded(child: config.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(message: AdminApi.friendlyError(error), onRetry: () => ref.invalidate(storeConfigurationProvider)),
        data: (data) => RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 24), children: [
            if (_saving) const LinearProgressIndicator(minHeight: 2),
            if (_tab == 0) _themePanel(data),
            if (_tab == 1) _categoriesPanel(data),
            if (_tab == 2) _bannersPanel(data),
            if (_tab == 3) _sectionsPanel(data),
          ]),
        ),
      )),
    ]);
  }

  Widget _themePanel(JsonMap data) {
    const themes = <(String, String, Color)>[
      ('rose', 'رز پانیز', Color(0xFFC72E52)),
      ('mint', 'سبز نعنایی', Color(0xFF54866E)),
      ('peach', 'هلویی', Color(0xFFCE805C)),
      ('lilac', 'یاسی', Color(0xFF8170B3)),
      ('coral', 'مرجانی', Color(0xFFE46262)),
      ('dark', 'تیره', Color(0xFF332D35)),
    ];
    final current = '${data['theme'] ?? 'rose'}';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      sectionTitle('رنگ‌بندی سایت'),
      const Padding(padding: EdgeInsets.only(top: 4, bottom: 14), child: Text('رنگ انتخاب‌شده بعد از بارگذاری دوبارهٔ سایت اعمال می‌شود.', style: TextStyle(color: Color(0xFF74686C), fontSize: 12))),
      ...themes.map((theme) => Card(
        child: ListTile(
          leading: CircleAvatar(backgroundColor: theme.$3, child: current == theme.$1 ? const Icon(Icons.check, color: Colors.white) : null),
          title: Text(theme.$2),
          trailing: current == theme.$1 ? const Icon(Icons.radio_button_checked, color: Color(0xFFB52F50)) : const Icon(Icons.radio_button_off),
          onTap: current == theme.$1 ? null : () => _run(() async {
            await ref.read(adminApiProvider).updateStoreTheme(theme.$1);
          }, 'رنگ‌بندی سایت ذخیره شد'),
        ),
      )),
    ]);
  }

  Widget _categoriesPanel(JsonMap data) {
    final categories = _maps(data['categories']);
    final roots = categories.where((item) => item['parentId'] == null).toList();
    final children = categories.where((item) => item['parentId'] != null).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      sectionTitle('دسته‌بندی‌ها', trailing: IconButton.filledTonal(
        tooltip: 'دستهٔ جدید', icon: const Icon(Icons.add), onPressed: () => _editCategory(data, null),
      )),
      const Padding(padding: EdgeInsets.only(top: 3, bottom: 10), child: Text('ساختار فروشگاه تا دو سطح اصلی و زیردسته پشتیبانی می‌کند.', style: TextStyle(color: Color(0xFF74686C), fontSize: 12))),
      if (categories.isEmpty) const _EmptyState(label: 'هنوز دسته‌ای ثبت نشده است.'),
      ...roots.map((item) => _categoryTile(data, item)),
      ...children.map((item) => _categoryTile(data, item, child: true)),
    ]);
  }

  Widget _categoryTile(JsonMap data, JsonMap item, {bool child = false}) => Card(
    child: ListTile(
      contentPadding: EdgeInsetsDirectional.fromSTEB(child ? 30 : 12, 2, 12, 2),
      leading: Icon(child ? Icons.subdirectory_arrow_left_rounded : Icons.category_rounded, color: const Color(0xFF806C9C)),
      title: Text('${item['name'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${item['slug'] ?? ''}  ·  ${item['isActive'] == true ? 'فعال' : 'بایگانی'}', maxLines: 1, overflow: TextOverflow.ellipsis, textDirection: TextDirection.ltr),
      trailing: IconButton(tooltip: 'ویرایش', icon: const Icon(Icons.edit_outlined), onPressed: () => _editCategory(data, item)),
    ),
  );

  Future<void> _editCategory(JsonMap data, JsonMap? existing) async {
    final roots = _maps(data['categories']).where((item) => item['parentId'] == null && '${item['id']}' != '${existing?['id']}').toList();
    final result = await showDialog<JsonMap>(context: context, builder: (_) => _CategoryDialog(existing: existing, roots: roots));
    if (result == null || !mounted) return;
    await _run(() async {
      final api = ref.read(adminApiProvider);
      if (existing == null) {
        await api.createCategory(result);
      } else {
        await api.updateCategory('${existing['id']}', result);
      }
    }, existing == null ? 'دسته‌بندی ثبت شد' : 'دسته‌بندی ویرایش شد');
  }

  Widget _bannersPanel(JsonMap data) {
    final banners = _maps(data['banners']);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      sectionTitle('بنرهای صفحهٔ اصلی', trailing: IconButton.filledTonal(
        tooltip: 'بنر جدید', icon: const Icon(Icons.add_photo_alternate_outlined), onPressed: () => _editBanner(null),
      )),
      const Padding(padding: EdgeInsets.only(top: 3, bottom: 10), child: Text('تصویر هر بنر را از گالری انتخاب و همان‌جا بارگذاری کن.', style: TextStyle(color: Color(0xFF74686C), fontSize: 12))),
      if (banners.isEmpty) const _EmptyState(label: 'هنوز بنری ثبت نشده است.'),
      ...banners.map((banner) => Card(
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if ('${banner['imagePath'] ?? ''}'.isNotEmpty)
            SizedBox(height: 130, width: double.infinity, child: Image.network(
              AdminApi.imageUrl('${banner['imagePath']}'), fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFFF4E8E9), child: Center(child: Icon(Icons.image_not_supported_outlined))),
            )),
          ListTile(
            title: Text('${banner['title'] ?? ''}'),
            subtitle: Text(banner['isActive'] == true ? 'فعال' : 'غیرفعال'),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') _editBanner(banner);
                if (value == 'toggle') _run(() async {
                  await ref.read(adminApiProvider).updateBanner('${banner['id']}', {'isActive': banner['isActive'] != true});
                }, 'وضعیت بنر تغییر کرد');
                if (value == 'delete') _deleteBanner(banner);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('ویرایش')),
                PopupMenuItem(value: 'toggle', child: Text(banner['isActive'] == true ? 'غیرفعال‌کردن' : 'فعال‌کردن')),
                const PopupMenuItem(value: 'delete', child: Text('حذف بنر')),
              ],
            ),
          ),
        ]),
      )),
    ]);
  }

  Future<void> _editBanner(JsonMap? existing) async {
    final result = await showDialog<JsonMap>(context: context, builder: (_) => _BannerDialog(existing: existing));
    if (result == null || !mounted) return;
    await _run(() async {
      final api = ref.read(adminApiProvider);
      if (existing == null) {
        await api.createBanner(result);
      } else {
        await api.updateBanner('${existing['id']}', result);
      }
    }, existing == null ? 'بنر ثبت شد' : 'بنر ویرایش شد');
  }

  Future<void> _deleteBanner(JsonMap banner) async {
    final confirmed = await _confirm('بنر «${banner['title']}» حذف شود؟');
    if (!confirmed || !mounted) return;
    await _run(() async => ref.read(adminApiProvider).deleteBanner('${banner['id']}'), 'بنر حذف شد');
  }

  Widget _sectionsPanel(JsonMap data) {
    final sections = _maps(data['sections'])..sort((a, b) => _integer(a['sortOrder']).compareTo(_integer(b['sortOrder'])));
    final order = _sectionOrderOverride;
    if (order != null) {
      final byKey = {for (final section in sections) '${section['sectionKey']}': section};
      if (order.length == sections.length && order.every(byKey.containsKey)) {
        sections
          ..clear()
          ..addAll(order.map((key) => byKey[key]!));
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      sectionTitle('چیدمان صفحهٔ اصلی'),
      const Padding(padding: EdgeInsets.only(top: 3, bottom: 10), child: Text('برای تغییر ترتیب، دستگیرهٔ کنار هر بخش را نگه دار و آن را بکش. بخش‌های خاموش‌شده در ویترین نمایش داده نمی‌شوند.', style: TextStyle(color: Color(0xFF74686C), fontSize: 12))),
      ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        itemCount: sections.length,
        onReorder: (oldIndex, newIndex) {
          if (_saving || oldIndex == newIndex) return;
          final reordered = List<JsonMap>.of(sections);
          if (newIndex > oldIndex) newIndex -= 1;
          final moved = reordered.removeAt(oldIndex);
          reordered.insert(newIndex, moved);
          _saveSectionOrder(reordered.map((section) => '${section['sectionKey']}').toList(growable: false));
        },
        itemBuilder: (context, index) {
          final section = sections[index];
          final key = '${section['sectionKey']}';
          return Card(
            key: ValueKey('homepage-section-$key'),
            child: ListTile(
              leading: ReorderableDragStartListener(
                index: index,
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.drag_handle_rounded, color: Color(0xFF806C9C)),
                ),
              ),
              title: Text('${section['title'] ?? key}'),
              subtitle: Text(section['isActive'] == true ? 'نمایش داده می‌شود' : 'پنهان است'),
              trailing: Switch.adaptive(value: section['isActive'] == true, onChanged: (value) => _run(() async {
                await ref.read(adminApiProvider).updateHomepageSection(key, {'isActive': value});
              }, value ? 'بخش فعال شد' : 'بخش پنهان شد')),
            ),
          );
        },
      ),
    ]);
  }

  Future<void> _saveSectionOrder(List<String> sectionKeys) async {
    setState(() {
      _sectionOrderOverride = sectionKeys;
      _saving = true;
    });
    try {
      await ref.read(adminApiProvider).reorderHomepageSections(sectionKeys);
      ref.invalidate(storeConfigurationProvider);
      if (mounted) showAppMessage(context, 'ترتیب بخش‌ها به‌روز شد');
    } catch (error) {
      if (mounted) {
        setState(() => _sectionOrderOverride = null);
        showAppMessage(context, AdminApi.friendlyError(error), error: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _confirm(String message) async => await showDialog<bool>(context: context, builder: (context) => AlertDialog(
    content: Text(message),
    actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('تأیید'))],
  )) ?? false;
}

class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog({required this.existing, required this.roots});
  final JsonMap? existing;
  final List<JsonMap> roots;
  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: '${widget.existing?['name'] ?? ''}');
  late final _slug = TextEditingController(text: '${widget.existing?['slug'] ?? ''}');
  late final _description = TextEditingController(text: '${widget.existing?['description'] ?? ''}');
  String? _imagePath;
  String? _parentId;
  bool _active = true;

  @override
  void initState() {
    super.initState();
    _parentId = widget.existing?['parentId']?.toString();
    _imagePath = _optionalPath(widget.existing?['imagePath']);
    _active = widget.existing?['isActive'] != false;
  }

  @override
  void dispose() { _name.dispose(); _slug.dispose(); _description.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.existing == null ? 'دستهٔ جدید' : 'ویرایش دسته'),
    content: SizedBox(width: 440, child: Form(key: _form, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      _textField(_name, 'نام دسته', required: true),
      _textField(_slug, 'نشانی انگلیسی، مثل sportswear', required: true, ltr: true),
      DropdownButtonFormField<String?>(
        initialValue: _parentId,
        decoration: const InputDecoration(labelText: 'دستهٔ مادر'),
        items: [const DropdownMenuItem<String?>(value: null, child: Text('دستهٔ اصلی')), ...widget.roots.map((item) => DropdownMenuItem<String?>(value: '${item['id']}', child: Text('${item['name']}')))],
        onChanged: (value) => setState(() => _parentId = value),
      ),
      _textField(_description, 'توضیح کوتاه'),
      AdminImagePickerField(
        label: 'تصویر دسته‌بندی',
        imagePath: _imagePath,
        aspectRatio: 1,
        onChanged: (value) => setState(() => _imagePath = value),
      ),
      if (widget.existing != null) SwitchListTile(value: _active, onChanged: (value) => setState(() => _active = value), title: const Text('دسته فعال باشد')),
    ])))),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
      FilledButton(onPressed: () {
        if (!_form.currentState!.validate()) return;
        Navigator.pop(context, <String, dynamic>{
          'name': _name.text.trim(), 'slug': _slug.text.trim().toLowerCase(),
          'parentId': _parentId, 'description': _description.text.trim().isEmpty ? null : _description.text.trim(),
          'imagePath': _imagePath, 'isActive': _active,
        });
      }, child: const Text('ذخیره')),
    ],
  );
}

class _BannerDialog extends StatefulWidget {
  const _BannerDialog({required this.existing});
  final JsonMap? existing;
  @override
  State<_BannerDialog> createState() => _BannerDialogState();
}

class _BannerDialogState extends State<_BannerDialog> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: '${widget.existing?['title'] ?? ''}');
  late final _description = TextEditingController(text: '${widget.existing?['description'] ?? ''}');
  late final _target = TextEditingController(text: '${widget.existing?['targetUrl'] ?? ''}');
  late final _starts = TextEditingController(text: '${widget.existing?['startsAt'] ?? ''}');
  late final _ends = TextEditingController(text: '${widget.existing?['endsAt'] ?? ''}');
  String? _imagePath;
  bool _imageError = false;
  bool _active = true;

  @override
  void initState() { super.initState(); _imagePath = _optionalPath(widget.existing?['imagePath']); _active = widget.existing?['isActive'] != false; }
  @override
  void dispose() { for (final item in [_title, _description, _target, _starts, _ends]) { item.dispose(); } super.dispose(); }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.existing == null ? 'بنر جدید' : 'ویرایش بنر'),
    content: SizedBox(width: 450, child: Form(key: _form, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      _textField(_title, 'عنوان بنر', required: true),
      _textField(_description, 'توضیح'),
      AdminImagePickerField(
        label: 'تصویر بنر',
        imagePath: _imagePath,
        errorText: _imageError ? 'برای ثبت بنر یک تصویر انتخاب کن.' : null,
        onChanged: (value) => setState(() {
          _imagePath = value;
          _imageError = false;
        }),
      ),
      _textField(_target, 'پیوند مقصد (مثلاً /products)', ltr: true),
      _textField(_starts, 'شروع زمان‌بندی (اختیاری، ISO-8601)', ltr: true),
      _textField(_ends, 'پایان زمان‌بندی (اختیاری، ISO-8601)', ltr: true),
      SwitchListTile(value: _active, onChanged: (value) => setState(() => _active = value), title: const Text('بنر فعال باشد')),
    ])))),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
      FilledButton(onPressed: () {
        if (_imagePath == null) {
          setState(() => _imageError = true);
          return;
        }
        if (!_form.currentState!.validate()) return;
        Navigator.pop(context, <String, dynamic>{
          'title': _title.text.trim(), 'description': _description.text.trim().isEmpty ? null : _description.text.trim(),
          'imagePath': _imagePath, 'targetUrl': _target.text.trim().isEmpty ? null : _target.text.trim(),
          'startsAt': _starts.text.trim().isEmpty ? null : _starts.text.trim(), 'endsAt': _ends.text.trim().isEmpty ? null : _ends.text.trim(),
          'isActive': _active,
        });
      }, child: const Text('ذخیره')),
    ],
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 26), child: Center(child: Text(label, style: const TextStyle(color: Color(0xFF74686C)))));
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(message, textAlign: TextAlign.center), const SizedBox(height: 8), OutlinedButton(onPressed: onRetry, child: const Text('تلاش دوباره'))])));
}

Widget _textField(TextEditingController controller, String label, {bool required = false, bool ltr = false}) => Padding(
  padding: const EdgeInsets.only(bottom: 10),
  child: TextFormField(
    controller: controller,
    textDirection: ltr ? TextDirection.ltr : null,
    textAlign: ltr ? TextAlign.left : TextAlign.start,
    decoration: InputDecoration(labelText: label),
    validator: required ? (value) => value == null || value.trim().isEmpty ? 'این فیلد الزامی است' : null : null,
  ),
);

List<JsonMap> _maps(Object? value) => value is List ? value.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList() : const [];
int _integer(Object? value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;
String? _optionalPath(Object? value) { final path = '$value'.trim(); return path.isEmpty || path == 'null' ? null : path; }
