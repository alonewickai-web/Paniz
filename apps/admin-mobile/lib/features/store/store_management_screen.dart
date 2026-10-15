import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/admin_image_picker_field.dart';
import '../../core/admin_api.dart';
import '../../core/providers.dart';
import '../../core/ui_helpers.dart';

class StoreManagementScreen extends ConsumerStatefulWidget {
  const StoreManagementScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  ConsumerState<StoreManagementScreen> createState() =>
      _StoreManagementScreenState();
}

class _StoreManagementScreenState extends ConsumerState<StoreManagementScreen> {
  int _tab = 0;
  bool _saving = false;
  List<String>? _sectionOrderOverride;

  final _shippingCost = TextEditingController();
  final _freeShippingThreshold = TextEditingController();
  bool _shippingInitialized = false;
  bool _alwaysFree = false;
  bool _freeThresholdEnabled = false;

  final _aboutAddress = TextEditingController();
  final _aboutIntroTitle = TextEditingController();
  final _aboutIntroDescription = TextEditingController();
  final _aboutPhone = TextEditingController();
  final _aboutRubikaUrl = TextEditingController();
  final _aboutInstagramUrl = TextEditingController();
  final _aboutMapUrl = TextEditingController();
  double? _mapLatitude;
  double? _mapLongitude;
  bool _aboutInitialized = false;

  final _popupLinkUrl = TextEditingController();
  String? _popupImagePath;
  bool _popupEnabled = false;
  bool _popupInitialized = false;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
  }

  @override
  void dispose() {
    _shippingCost.dispose();
    _freeShippingThreshold.dispose();
    _aboutIntroTitle.dispose();
    _aboutIntroDescription.dispose();
    _aboutAddress.dispose();
    _aboutPhone.dispose();
    _aboutRubikaUrl.dispose();
    _aboutInstagramUrl.dispose();
    _aboutMapUrl.dispose();
    _popupLinkUrl.dispose();
    super.dispose();
  }

  static const _tabs = ['قالب سایت', 'دسته‌ها', 'بنرها', 'چیدمان', 'درباره ما'];
  static const _tabIndexes = [0, 1, 2, 3, 4, 6];

  Future<void> _refresh() async {
    _sectionOrderOverride = null;
    _shippingInitialized = false;
    _aboutInitialized = false;
    _popupInitialized = false;
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
      if (mounted)
        showAppMessage(context, AdminApi.friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(storeConfigurationProvider);
    return Column(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 8),
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(
              _tabIndexes.length,
              (index) => Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: ChoiceChip(
                  label: Text(index < _tabs.length ? _tabs[index] : 'پاپ‌آپ'),
                  selected: _tab == _tabIndexes[index],
                  onSelected: (_) => setState(() => _tab = _tabIndexes[index]),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: config.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error:
                (error, _) => _ErrorState(
                  message: AdminApi.friendlyError(error),
                  onRetry: () => ref.invalidate(storeConfigurationProvider),
                ),
            data:
                (data) => RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      16,
                      8,
                      16,
                      24,
                    ),
                    children: [
                      if (_saving) const LinearProgressIndicator(minHeight: 2),
                      if (_tab == 0) _themePanel(data),
                      if (_tab == 1) _categoriesPanel(data),
                      if (_tab == 2) _bannersPanel(data),
                      if (_tab == 3) _sectionsPanel(data),
                      if (_tab == 4) _aboutPanel(data),
                      if (_tab == 5) _shippingPanel(data),
                      if (_tab == 6) _popupPanel(data),
                    ],
                  ),
                ),
          ),
        ),
      ],
    );
  }

  Widget _themePanel(JsonMap data) {
    const themes = <
      ({
        String key,
        String title,
        String description,
        Color first,
        Color second,
        Color canvas,
        bool dark,
      })
    >[
      (
        key: 'rose',
        title: 'رز پانیذ',
        description: 'گرم و لطیف',
        first: Color(0xFFC72E52),
        second: Color(0xFFEE536B),
        canvas: Color(0xFFFFFAF7),
        dark: false,
      ),
      (
        key: 'mint',
        title: 'سبز نعنایی',
        description: 'طبیعی و آرام',
        first: Color(0xFF397D61),
        second: Color(0xFF82B99B),
        canvas: Color(0xFFF8FCF8),
        dark: false,
      ),
      (
        key: 'peach',
        title: 'هلویی',
        description: 'نرم و صمیمی',
        first: Color(0xFFC66E4B),
        second: Color(0xFFF1A27B),
        canvas: Color(0xFFFFFAF6),
        dark: false,
      ),
      (
        key: 'lilac',
        title: 'یاسی',
        description: 'آرام و ظریف',
        first: Color(0xFF7868AE),
        second: Color(0xFFB49AD8),
        canvas: Color(0xFFFCFBFF),
        dark: false,
      ),
      (
        key: 'coral',
        title: 'مرجانی',
        description: 'شاد و پرانرژی',
        first: Color(0xFFDC5E5C),
        second: Color(0xFFFF9B73),
        canvas: Color(0xFFFFFAFA),
        dark: false,
      ),
      (
        key: 'dark',
        title: 'تیره و رز',
        description: 'تیره و چشم‌نواز',
        first: Color(0xFF332D35),
        second: Color(0xFF9A5367),
        canvas: Color(0xFF19171B),
        dark: true,
      ),
      (
        key: 'berry',
        title: 'تمشکی',
        description: 'پررنگ و مدرن',
        first: Color(0xFFA21D55),
        second: Color(0xFFE75888),
        canvas: Color(0xFFFFF9FC),
        dark: false,
      ),
      (
        key: 'ocean',
        title: 'اقیانوسی',
        description: 'خنک و امروزی',
        first: Color(0xFF207C9A),
        second: Color(0xFF45C3C0),
        canvas: Color(0xFFF7FCFD),
        dark: false,
      ),
      (
        key: 'sunset',
        title: 'غروب آفتاب',
        description: 'گرم و درخشان',
        first: Color(0xFFD75245),
        second: Color(0xFFF4AA4D),
        canvas: Color(0xFFFFFBF7),
        dark: false,
      ),
      (
        key: 'forest',
        title: 'جنگلی',
        description: 'سبز و الهام‌گرفته از طبیعت',
        first: Color(0xFF2F7049),
        second: Color(0xFFA8B94A),
        canvas: Color(0xFFFAFCF7),
        dark: false,
      ),
      (
        key: 'royal',
        title: 'سلطنتی',
        description: 'خاص و شیک',
        first: Color(0xFF51459A),
        second: Color(0xFFBE68A7),
        canvas: Color(0xFFFBFAFF),
        dark: false,
      ),
      (
        key: 'citrus',
        title: 'مرکباتی',
        description: 'روشن و پرنشاط',
        first: Color(0xFF8C9B29),
        second: Color(0xFFE8C843),
        canvas: Color(0xFFFCFCF5),
        dark: false,
      ),
      (
        key: 'lagoon',
        title: 'تالابی',
        description: 'فیروزه‌ای و تازه',
        first: Color(0xFF087E83),
        second: Color(0xFF64D5B1),
        canvas: Color(0xFFF7FCFA),
        dark: false,
      ),
      (
        key: 'mocha',
        title: 'موکا',
        description: 'خاکی و دلنشین',
        first: Color(0xFF7D5140),
        second: Color(0xFFD9A37E),
        canvas: Color(0xFFFDFAF7),
        dark: false,
      ),
      (
        key: 'orchid',
        title: 'ارکیده‌ای',
        description: 'لطیف و متفاوت',
        first: Color(0xFFA64690),
        second: Color(0xFFD68CC4),
        canvas: Color(0xFFFDF9FC),
        dark: false,
      ),
      (
        key: 'slate',
        title: 'خاکستری آبی',
        description: 'مینیمال و رسمی',
        first: Color(0xFF42546E),
        second: Color(0xFF8299AF),
        canvas: Color(0xFFFAFBFD),
        dark: false,
      ),
    ];
    final current = '${data['theme'] ?? 'rose'}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionTitle('نشان فروشگاه'),
        const Padding(
          padding: EdgeInsets.only(top: 4, bottom: 10),
          child: Text(
            'نشان اصلی پانیذ در سایت و برنامهٔ مدیریت نمایش داده می‌شود.',
            style: TextStyle(color: Color(0xFF74686C), fontSize: 12),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap:
                          () => showDialog<void>(
                            context: context,
                            builder:
                                (context) => Dialog(
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: InteractiveViewer(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
                                        child: _storeLogo(
                                          data,
                                          width: 280,
                                          height: 280,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                          ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _storeLogo(data, width: 76, height: 76),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'برای دیدن تصویر در اندازهٔ بزرگ روی آن بزن.',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                AdminImagePickerField(
                  imagePath: _optionalPath(data['logoPath']),
                  label: 'انتخاب و ویرایش لوگو',
                  aspectRatio: 1,
                  lockAspectRatio: true,
                  onChanged:
                      (path) => _run(() async {
                        await ref.read(adminApiProvider).updateStoreLogo(path);
                      }, 'لوگوی سایت ذخیره شد'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        sectionTitle('قالب‌های آمادهٔ سایت'),
        const Padding(
          padding: EdgeInsets.only(top: 4, bottom: 14),
          child: Text(
            'یکی از ۱۶ ترکیب رنگ را انتخاب کن. انتخابت ذخیره می‌شود؛ سایت باز هم با برگشتن به آن قالب تازه را می‌گیرد.',
            style: TextStyle(color: Color(0xFF74686C), fontSize: 12),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - 8) / 2;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  themes.map((theme) {
                    final selected = current == theme.key;
                    return SizedBox(
                      width: width,
                      child: Card(
                        margin: EdgeInsets.zero,
                        clipBehavior: Clip.antiAlias,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color:
                                selected
                                    ? theme.first
                                    : const Color(0xFFE9E4E5),
                            width: selected ? 1.6 : 1,
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap:
                              selected
                                  ? null
                                  : () => _run(() async {
                                    await ref
                                        .read(adminApiProvider)
                                        .updateStoreTheme(theme.key);
                                  }, 'قالب سایت ذخیره و فعال شد'),
                          child: Padding(
                            padding: const EdgeInsets.all(9),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  height: 54,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.canvas,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color:
                                          theme.dark
                                              ? const Color(0xFF403942)
                                              : const Color(0xFFECE7E5),
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 19,
                                            height: 19,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              gradient: LinearGradient(
                                                colors: [
                                                  theme.first,
                                                  theme.second,
                                                ],
                                              ),
                                            ),
                                            child: const Text(
                                              'پ',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            'پانیذ',
                                            style: TextStyle(
                                              color:
                                                  theme.dark
                                                      ? Colors.white
                                                      : const Color(0xFF29262A),
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const Spacer(),
                                          Container(
                                            width: 32,
                                            height: 11,
                                            decoration: BoxDecoration(
                                              color: theme.first,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Container(
                                              height: 7,
                                              decoration: BoxDecoration(
                                                color: theme.first.withValues(
                                                  alpha: .20,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(5),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 5),
                                          Container(
                                            width: 25,
                                            height: 7,
                                            decoration: BoxDecoration(
                                              color: theme.second,
                                              borderRadius:
                                                  BorderRadius.circular(5),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            theme.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            theme.description,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Color(0xFF74686C),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (selected)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: theme.first.withValues(
                                            alpha: .10,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.check_rounded,
                                              size: 12,
                                              color: theme.first,
                                            ),
                                            const SizedBox(width: 2),
                                            Text(
                                              'فعال',
                                              style: TextStyle(
                                                color: theme.first,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    else
                                      Icon(
                                        Icons.radio_button_unchecked_rounded,
                                        size: 18,
                                        color: theme.first,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _storeLogo(
    JsonMap data, {
    required double width,
    required double height,
  }) {
    final path = _optionalPath(data['logoPath']);
    if (path == null)
      return Image.asset(
        'assets/branding/paniz-logo.jpg',
        width: width,
        height: height,
        fit: BoxFit.cover,
      );
    return Image.network(
      AdminApi.imageUrl(path),
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder:
          (_, __, ___) => Image.asset(
            'assets/branding/paniz-logo.jpg',
            width: width,
            height: height,
            fit: BoxFit.cover,
          ),
    );
  }

  Widget _popupPanel(JsonMap data) {
    final popup =
        data['popup'] is Map
            ? Map<String, dynamic>.from(data['popup'] as Map)
            : <String, dynamic>{};
    if (!_popupInitialized) {
      _popupEnabled = popup['enabled'] == true;
      _popupImagePath = _optionalPath(popup['imagePath']);
      _popupLinkUrl.text = '${popup['linkUrl'] ?? ''}';
      _popupInitialized = true;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionTitle('پاپ‌آپ تبلیغاتی سایت'),
        const Padding(
          padding: EdgeInsets.only(top: 3, bottom: 12),
          child: Text(
            'تصویر را بارگذاری کن، لینک مقصد را بنویس و نمایش پاپ‌آپ را روشن یا خاموش کن. با بستن آن، مشتری تا پایان همین بازدید دوباره آن را نمی‌بیند.',
            style: TextStyle(
              color: Color(0xFF74686C),
              fontSize: 12,
              height: 1.7,
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('پاپ‌آپ در سایت نمایش داده شود'),
                  subtitle: Text(_popupEnabled ? 'فعال' : 'غیرفعال'),
                  value: _popupEnabled,
                  onChanged: (value) => setState(() => _popupEnabled = value),
                ),
                const SizedBox(height: 12),
                AdminImagePickerField(
                  imagePath: _popupImagePath,
                  label: 'تصویر تبلیغ (کادر عمودی ۴:۵)',
                  aspectRatio: 0.8,
                  lockAspectRatio: true,
                  onChanged: (path) => setState(() => _popupImagePath = path),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _popupLinkUrl,
                  keyboardType: TextInputType.url,
                  textDirection: TextDirection.ltr,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                    labelText: 'لینک مقصد با لمس تصویر',
                    hintText: 'https://... یا /products',
                    helperText:
                        'می‌توانی لینک یک محصول یا صفحهٔ سایت را وارد کنی.',
                  ),
                ),
                if (_popupImagePath != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 250),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: AspectRatio(
                          aspectRatio: 0.8,
                          child: Image.network(
                            AdminApi.imageUrl(_popupImagePath!),
                            fit: BoxFit.cover,
                            errorBuilder:
                                (_, __, ___) => const Center(
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    size: 36,
                                  ),
                                ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed:
                      _saving
                          ? null
                          : () {
                            if (_popupEnabled && _popupImagePath == null) {
                              showAppMessage(
                                context,
                                'برای فعال‌کردن پاپ‌آپ، اول تصویرش را انتخاب کن.',
                                error: true,
                              );
                              return;
                            }
                            _run(() async {
                              await ref
                                  .read(adminApiProvider)
                                  .updateStorePopup({
                                    'enabled': _popupEnabled,
                                    'imagePath': _popupImagePath,
                                    'linkUrl': _popupLinkUrl.text.trim(),
                                  });
                              _popupInitialized = false;
                            }, 'تنظیمات پاپ‌آپ ذخیره شد');
                          },
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('ذخیرهٔ پاپ‌آپ'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _shippingPanel(JsonMap data) {
    final shipping =
        data['shipping'] is Map
            ? Map<String, dynamic>.from(data['shipping'] as Map)
            : <String, dynamic>{};
    if (!_shippingInitialized) {
      _shippingCost.text = _digits('${shipping['baseCostToman'] ?? 0}');
      _freeShippingThreshold.text = _digits(
        '${shipping['freeOverToman'] ?? ''}',
      );
      _alwaysFree = shipping['baseCostToman'] == 0 && shipping['id'] != null;
      _freeThresholdEnabled = shipping['freeOverToman'] != null;
      _shippingInitialized = true;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionTitle('هزینهٔ ارسال و پست'),
        const Padding(
          padding: EdgeInsets.only(top: 4, bottom: 12),
          child: Text(
            'مبلغ ارسال در فاکتور مشتری نشان داده می‌شود. اگر ارسال رایگان باشد نیز این موضوع در فاکتور به‌روشنی نوشته می‌شود.',
            style: TextStyle(
              color: Color(0xFF74686C),
              fontSize: 12,
              height: 1.6,
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _shippingCost,
                  enabled: !_alwaysFree,
                  keyboardType: TextInputType.number,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'هزینهٔ پست',
                    suffixText: 'تومان',
                    helperText: 'مبلغ با جداکنندهٔ سه‌رقمی نمایش داده می‌شود.',
                  ),
                  onChanged: (value) {
                    final formatted = _groupDigits(value);
                    if (formatted != value) {
                      _shippingCost.value = TextEditingValue(
                        text: formatted,
                        selection: TextSelection.collapsed(
                          offset: formatted.length,
                        ),
                      );
                    }
                  },
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('ارسال همهٔ سفارش‌ها رایگان باشد'),
                  value: _alwaysFree,
                  onChanged: (value) => setState(() => _alwaysFree = value),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('ارسال بالای یک مبلغ رایگان شود'),
                  value: _freeThresholdEnabled,
                  onChanged:
                      (value) => setState(() => _freeThresholdEnabled = value),
                ),
                if (_freeThresholdEnabled && !_alwaysFree) ...[
                  const SizedBox(height: 6),
                  TextField(
                    controller: _freeShippingThreshold,
                    keyboardType: TextInputType.number,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                      labelText: 'حداقل مبلغ سبد برای ارسال رایگان',
                      suffixText: 'تومان',
                    ),
                    onChanged: (value) {
                      final formatted = _groupDigits(value);
                      if (formatted != value)
                        _freeShippingThreshold.value = TextEditingValue(
                          text: formatted,
                          selection: TextSelection.collapsed(
                            offset: formatted.length,
                          ),
                        );
                    },
                  ),
                ],
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed:
                      _saving
                          ? null
                          : () => _run(() async {
                            final cost = _digits(_shippingCost.text);
                            final threshold = _digits(
                              _freeShippingThreshold.text,
                            );
                            if (!_alwaysFree && cost.isEmpty)
                              throw const AdminApiException(
                                'هزینهٔ پست را وارد کن.',
                              );
                            if (_freeThresholdEnabled &&
                                !_alwaysFree &&
                                threshold.isEmpty)
                              throw const AdminApiException(
                                'حد خرید برای ارسال رایگان را وارد کن.',
                              );
                            await ref
                                .read(adminApiProvider)
                                .updateShippingSettings({
                                  'name': 'ارسال پستی',
                                  'baseCostToman': cost.isEmpty ? '0' : cost,
                                  'alwaysFree': _alwaysFree,
                                  'freeShippingEnabled':
                                      _freeThresholdEnabled && !_alwaysFree,
                                  if (_freeThresholdEnabled && !_alwaysFree)
                                    'freeOverToman': threshold,
                                });
                            _shippingInitialized = false;
                          }, 'تنظیمات ارسال ذخیره شد'),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('ذخیرهٔ هزینهٔ ارسال'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _aboutPanel(JsonMap data) {
    final about =
        data['about'] is Map
            ? Map<String, dynamic>.from(data['about'] as Map)
            : <String, dynamic>{};
    if (!_aboutInitialized) {
      _aboutIntroTitle.text = '${about['introTitle'] ?? ''}';
      _aboutIntroDescription.text = '${about['introDescription'] ?? ''}';
      _aboutAddress.text = '${about['address'] ?? ''}';
      _aboutPhone.text = '${about['phone'] ?? ''}';
      _aboutRubikaUrl.text = '${about['rubikaUrl'] ?? ''}';
      _aboutInstagramUrl.text = '${about['instagramUrl'] ?? ''}';
      _aboutMapUrl.text = '${about['mapUrl'] ?? ''}';
      _mapLatitude =
          about['latitude'] is num
              ? (about['latitude'] as num).toDouble()
              : null;
      _mapLongitude =
          about['longitude'] is num
              ? (about['longitude'] as num).toDouble()
              : null;
      _aboutInitialized = true;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionTitle('دربارهٔ ما و راه‌های تماس'),
        const Padding(
          padding: EdgeInsets.only(top: 3, bottom: 12),
          child: Text(
            'عنوان، متن معرفی و اطلاعات تماس اینجا ذخیره می‌شوند و در صفحهٔ «دربارهٔ ما»ی سایت نمایش داده می‌شوند. برای حذف هر مورد، کادرش را خالی بگذار.',
            style: TextStyle(
              color: Color(0xFF74686C),
              fontSize: 12,
              height: 1.7,
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _aboutIntroTitle,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: 'عنوان معرفی فروشگاه',
                    hintText: 'مثلاً دربارهٔ پانیذ',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _aboutIntroDescription,
                  minLines: 3,
                  maxLines: 7,
                  maxLength: 2000,
                  decoration: const InputDecoration(
                    labelText: 'متن معرفی فروشگاه',
                    hintText: 'متن واقعی معرفی فروشگاه را وارد کن',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _aboutAddress,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'نشانی فروشگاه',
                    hintText: 'نشانی پستی یا آدرس دفتر',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _aboutPhone,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  maxLength: 40,
                  decoration: const InputDecoration(
                    labelText: 'شمارهٔ تماس',
                    hintText: 'مثلاً ۰۲۱۱۲۳۴۵۶۷۸',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _aboutRubikaUrl,
                  keyboardType: TextInputType.url,
                  textDirection: TextDirection.ltr,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'لینک کانال روبیکا',
                    hintText: 'https://rubika.ir/...',
                    helperText:
                        'در سایت کنار این لینک، نشان روبیکا نمایش داده می‌شود.',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _aboutInstagramUrl,
                  keyboardType: TextInputType.url,
                  textDirection: TextDirection.ltr,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'لینک یا نام کاربری اینستاگرام',
                    hintText: 'https://instagram.com/... یا @username',
                  ),
                ),
                const SizedBox(height: 10),
                const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    'انتخاب نشانی روی نقشه',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 8),
                AspectRatio(
                  aspectRatio: 1,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: LatLng(
                          _mapLatitude ?? 35.6892,
                          _mapLongitude ?? 51.3890,
                        ),
                        initialZoom: 13,
                        onTap:
                            (_, point) => setState(() {
                              _mapLatitude = point.latitude;
                              _mapLongitude = point.longitude;
                            }),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'ir.panizstyle.admin',
                        ),
                        if (_mapLatitude != null && _mapLongitude != null)
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(_mapLatitude!, _mapLongitude!),
                                width: 46,
                                height: 54,
                                child: const Icon(
                                  Icons.location_pin,
                                  color: Color(0xFFC72E52),
                                  size: 48,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _mapLatitude == null || _mapLongitude == null
                      ? 'برای ثبت لوکیشن، نقطهٔ خرید حضوری را روی نقشه لمس کن.'
                      : 'موقعیت انتخاب‌شده: ${_mapLatitude!.toStringAsFixed(5)}, ${_mapLongitude!.toStringAsFixed(5)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF74686C),
                  ),
                ),
                if (_mapLatitude != null)
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton.icon(
                      onPressed:
                          () => setState(() {
                            _mapLatitude = null;
                            _mapLongitude = null;
                          }),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('پاک‌کردن موقعیت'),
                    ),
                  ),
                const SizedBox(height: 12),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed:
                      _saving
                          ? null
                          : () => _run(() async {
                            await ref.read(adminApiProvider).updateStoreAbout({
                              'introTitle': _aboutIntroTitle.text.trim(),
                              'introDescription':
                                  _aboutIntroDescription.text.trim(),
                              'address': _aboutAddress.text.trim(),
                              'phone': _aboutPhone.text.trim(),
                              'rubikaUrl': _aboutRubikaUrl.text.trim(),
                              'instagramUrl': _aboutInstagramUrl.text.trim(),
                              'physicalAddress': '',
                              'mapUrl':
                                  _mapLatitude != null && _mapLongitude != null
                                      ? 'https://www.openstreetmap.org/?mlat=${_mapLatitude!.toStringAsFixed(6)}&mlon=${_mapLongitude!.toStringAsFixed(6)}#map=15/${_mapLatitude!.toStringAsFixed(6)}/${_mapLongitude!.toStringAsFixed(6)}'
                                      : '',
                              'latitude': _mapLatitude,
                              'longitude': _mapLongitude,
                            });
                            _aboutInitialized = false;
                          }, 'اطلاعات دربارهٔ ما ذخیره شد'),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('ذخیرهٔ اطلاعات دربارهٔ ما'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _categoriesPanel(JsonMap data) {
    final categories = _maps(data['categories']);
    final roots = categories.where((item) => item['parentId'] == null).toList();
    final children =
        categories.where((item) => item['parentId'] != null).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionTitle(
          'دسته‌بندی‌ها',
          trailing: IconButton.filledTonal(
            tooltip: 'دستهٔ جدید',
            icon: const Icon(Icons.add),
            onPressed: () => _editCategory(data, null),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 3, bottom: 10),
          child: Text(
            'ساختار فروشگاه تا دو سطح اصلی و زیردسته پشتیبانی می‌کند.',
            style: TextStyle(color: Color(0xFF74686C), fontSize: 12),
          ),
        ),
        if (categories.isEmpty)
          const _EmptyState(label: 'هنوز دسته‌ای ثبت نشده است.'),
        ...roots.map((item) => _categoryTile(data, item)),
        ...children.map((item) => _categoryTile(data, item, child: true)),
      ],
    );
  }

  Widget _categoryTile(
    JsonMap data,
    JsonMap item, {
    bool child = false,
  }) => Card(
    child: ListTile(
      contentPadding: EdgeInsetsDirectional.fromSTEB(child ? 30 : 12, 2, 12, 2),
      leading: Icon(
        child ? Icons.subdirectory_arrow_left_rounded : Icons.category_rounded,
        color: const Color(0xFF806C9C),
      ),
      title: Text(
        '${item['name'] ?? ''}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${item['slug'] ?? ''}  ·  ${item['isActive'] == true ? 'فعال' : 'بایگانی'}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textDirection: TextDirection.ltr,
      ),
      trailing: IconButton(
        tooltip: 'ویرایش',
        icon: const Icon(Icons.edit_outlined),
        onPressed: () => _editCategory(data, item),
      ),
    ),
  );

  Future<void> _editCategory(JsonMap data, JsonMap? existing) async {
    final roots =
        _maps(data['categories'])
            .where(
              (item) =>
                  item['parentId'] == null &&
                  '${item['id']}' != '${existing?['id']}',
            )
            .toList();
    final result = await showDialog<JsonMap>(
      context: context,
      builder: (_) => _CategoryDialog(existing: existing, roots: roots),
    );
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
    final activeBanners =
        banners.where((banner) => banner['isArchived'] != true).toList();
    final archivedBanners =
        banners.where((banner) => banner['isArchived'] == true).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionTitle(
          'بنرهای صفحهٔ اصلی',
          trailing: IconButton.filledTonal(
            tooltip: 'بنر جدید',
            icon: const Icon(Icons.add_photo_alternate_outlined),
            onPressed: () => _editBanner(null),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 3, bottom: 10),
          child: Text(
            'تصویر هر بنر را از گالری انتخاب و همان‌جا بارگذاری کن.',
            style: TextStyle(color: Color(0xFF74686C), fontSize: 12),
          ),
        ),
        if (activeBanners.isEmpty)
          const _EmptyState(
            label: 'بنر فعالی نداریم. برای افزودن، دکمهٔ بنر جدید را بزن.',
          ),
        ...activeBanners.map((banner) => _bannerCard(banner)),
        const SizedBox(height: 20),
        sectionTitle('آرشیو بنرها (${archivedBanners.length})'),
        const Padding(
          padding: EdgeInsets.only(top: 3, bottom: 10),
          child: Text(
            'بنرهای این بخش در سایت نمایش داده نمی‌شوند و هر زمان بخواهی می‌توانی آن‌ها را بازگردانی کنی.',
            style: TextStyle(color: Color(0xFF74686C), fontSize: 12),
          ),
        ),
        if (archivedBanners.isEmpty)
          const _EmptyState(
            label:
                'آرشیو خالی است. بنرهایی که از سایت حذف کنی اینجا نگه‌داری می‌شوند.',
          ),
        ...archivedBanners.map((banner) => _bannerCard(banner, archived: true)),
      ],
    );
  }

  Widget _bannerCard(JsonMap banner, {bool archived = false}) => Card(
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if ('${banner['imagePath'] ?? ''}'.isNotEmpty)
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ColoredBox(
              color: _bannerColorValue(
                '${banner['backgroundColor'] ?? '#FCE4DB'}',
              ),
              child: Image.network(
                AdminApi.imageUrl('${banner['imagePath']}'),
                fit: BoxFit.cover,
                errorBuilder:
                    (_, __, ___) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          '${banner['altText'] ?? banner['title'] ?? ''}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
              ),
            ),
          ),
        ListTile(
          title: Text('${banner['altText'] ?? banner['title'] ?? ''}'),
          subtitle: Text(
            archived
                ? 'در آرشیو'
                : (banner['isActive'] == true ? 'فعال' : 'غیرفعال'),
          ),
          trailing:
              archived
                  ? IconButton.filledTonal(
                    tooltip: 'بازگردانی به سایت',
                    icon: const Icon(Icons.unarchive_outlined),
                    onPressed: _saving ? null : () => _restoreBanner(banner),
                  )
                  : PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') _editBanner(banner);
                      if (value == 'toggle')
                        _run(() async {
                          await ref.read(adminApiProvider).updateBanner(
                            '${banner['id']}',
                            {'isActive': banner['isActive'] != true},
                          );
                        }, 'وضعیت بنر تغییر کرد');
                      if (value == 'archive') _archiveBanner(banner);
                    },
                    itemBuilder:
                        (_) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('ویرایش'),
                          ),
                          PopupMenuItem(
                            value: 'toggle',
                            child: Text(
                              banner['isActive'] == true
                                  ? 'غیرفعال‌کردن'
                                  : 'فعال‌کردن',
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'archive',
                            child: Text('حذف از سایت و بایگانی'),
                          ),
                        ],
                  ),
        ),
      ],
    ),
  );

  Future<void> _editBanner(JsonMap? existing) async {
    final result = await showDialog<JsonMap>(
      context: context,
      builder: (_) => _BannerDialog(existing: existing),
    );
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

  Future<void> _archiveBanner(JsonMap banner) async {
    final confirmed = await _confirm(
      'بنر «${banner['altText'] ?? banner['title'] ?? ''}» از سایت برداشته و در آرشیو همین صفحه نگه‌داری شود؟',
    );
    if (!confirmed || !mounted) return;
    await _run(
      () async => ref.read(adminApiProvider).archiveBanner('${banner['id']}'),
      'بنر به آرشیو منتقل شد',
    );
  }

  Future<void> _restoreBanner(JsonMap banner) async {
    await _run(
      () async => ref.read(adminApiProvider).restoreBanner('${banner['id']}'),
      'بنر به سایت بازگردانده شد',
    );
  }

  Widget _sectionsPanel(JsonMap data) {
    final sections = _maps(data['sections'])..sort(
      (a, b) => _integer(a['sortOrder']).compareTo(_integer(b['sortOrder'])),
    );
    final order = _sectionOrderOverride;
    if (order != null) {
      final byKey = {
        for (final section in sections) '${section['sectionKey']}': section,
      };
      if (order.length == sections.length && order.every(byKey.containsKey)) {
        sections
          ..clear()
          ..addAll(order.map((key) => byKey[key]!));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionTitle('چیدمان صفحهٔ اصلی'),
        const Padding(
          padding: EdgeInsets.only(top: 3, bottom: 10),
          child: Text(
            'برای تغییر ترتیب، دستگیرهٔ کنار هر بخش را نگه دار و آن را بکش. بخش‌های خاموش‌شده در ویترین نمایش داده نمی‌شوند.',
            style: TextStyle(color: Color(0xFF74686C), fontSize: 12),
          ),
        ),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: sections.length,
          onReorderItem: (oldIndex, newIndex) {
            if (_saving || oldIndex == newIndex) return;
            final reordered = List<JsonMap>.of(sections);
            final moved = reordered.removeAt(oldIndex);
            reordered.insert(newIndex, moved);
            _saveSectionOrder(
              reordered
                  .map((section) => '${section['sectionKey']}')
                  .toList(growable: false),
            );
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
                    child: Icon(
                      Icons.drag_handle_rounded,
                      color: Color(0xFF806C9C),
                    ),
                  ),
                ),
                title: Text('${section['title'] ?? key}'),
                subtitle: Text(
                  section['isActive'] == true
                      ? 'نمایش داده می‌شود'
                      : 'پنهان است',
                ),
                trailing: Switch.adaptive(
                  value: section['isActive'] == true,
                  onChanged:
                      (value) => _run(() async {
                        await ref.read(adminApiProvider).updateHomepageSection(
                          key,
                          {'isActive': value},
                        );
                      }, value ? 'بخش فعال شد' : 'بخش پنهان شد'),
                ),
              ),
            );
          },
        ),
      ],
    );
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

  Future<bool> _confirm(String message) async =>
      await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              content: Text(message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('انصراف'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('تأیید'),
                ),
              ],
            ),
      ) ??
      false;
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
  late final _name = TextEditingController(
    text: '${widget.existing?['name'] ?? ''}',
  );
  late final _slug = TextEditingController(
    text: '${widget.existing?['slug'] ?? ''}',
  );
  late final _description = TextEditingController(
    text: '${widget.existing?['description'] ?? ''}',
  );
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
  void dispose() {
    _name.dispose();
    _slug.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.existing == null ? 'دستهٔ جدید' : 'ویرایش دسته'),
    content: SizedBox(
      width: 440,
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _textField(_name, 'نام دسته', required: true),
              _textField(
                _slug,
                'نشانی انگلیسی، مثل sportswear',
                required: true,
                ltr: true,
              ),
              DropdownButtonFormField<String?>(
                initialValue: _parentId,
                decoration: const InputDecoration(labelText: 'دستهٔ مادر'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('دستهٔ اصلی'),
                  ),
                  ...widget.roots.map(
                    (item) => DropdownMenuItem<String?>(
                      value: '${item['id']}',
                      child: Text('${item['name']}'),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _parentId = value),
              ),
              _textField(_description, 'توضیح کوتاه'),
              AdminImagePickerField(
                label: 'تصویر دسته‌بندی',
                imagePath: _imagePath,
                aspectRatio: 1,
                onChanged: (value) => setState(() => _imagePath = value),
              ),
              if (widget.existing != null)
                SwitchListTile(
                  value: _active,
                  onChanged: (value) => setState(() => _active = value),
                  title: const Text('دسته فعال باشد'),
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
      FilledButton(
        onPressed: () {
          if (!_form.currentState!.validate()) return;
          Navigator.pop(context, <String, dynamic>{
            'name': _name.text.trim(),
            'slug': _slug.text.trim().toLowerCase(),
            'parentId': _parentId,
            'description':
                _description.text.trim().isEmpty
                    ? null
                    : _description.text.trim(),
            'imagePath': _imagePath,
            'isActive': _active,
          });
        },
        child: const Text('ذخیره'),
      ),
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
  late final _altText = TextEditingController(
    text:
        (widget.existing?['altText'] ?? widget.existing?['title'] ?? '')
            .toString(),
  );
  late final _colorSearch = TextEditingController();
  String? _imagePath;
  late String _backgroundColor;
  bool _imageError = false;

  @override
  void initState() {
    super.initState();
    _imagePath = _optionalPath(widget.existing?['imagePath']);
    final savedColor = '${widget.existing?['backgroundColor'] ?? ''}';
    _backgroundColor =
        _isBannerHex(savedColor) ? savedColor.toUpperCase() : '#FCE4DB';
    _altText.addListener(_refreshPreview);
  }

  void _refreshPreview() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _altText.dispose();
    _colorSearch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.existing == null ? 'بنر تصویری جدید' : 'ویرایش بنر تصویری',
    ),
    content: SizedBox(
      width: 450,
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _livePreview(),
              const SizedBox(height: 16),
              AdminImagePickerField(
                label: 'تصویر بنر افقی (۱۶:۹)',
                imagePath: _imagePath,
                aspectRatio: 16 / 9,
                lockAspectRatio: true,
                errorText:
                    _imageError ? 'برای ثبت بنر یک تصویر انتخاب کن.' : null,
                onChanged:
                    (value) => setState(() {
                      _imagePath = value;
                      _imageError = false;
                    }),
              ),
              const SizedBox(height: 12),
              _textField(
                _altText,
                'متن جایگزین تصویر (Alt)',
                required: true,
                maxLines: 2,
              ),
              const SizedBox(height: 4),
              sectionTitle('رنگ پس‌زمینه'),
              _colorPicker(),
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
      FilledButton(
        onPressed: () {
          if (_imagePath == null) {
            setState(() => _imageError = true);
            return;
          }
          if (!_form.currentState!.validate()) return;
          Navigator.pop(context, <String, dynamic>{
            'altText': _altText.text.trim(),
            'imagePath': _imagePath,
            'backgroundColor': _backgroundColor,
          });
        },
        child: const Text('ذخیره'),
      ),
    ],
  );

  Widget _livePreview() {
    final imagePath = _imagePath;
    final altText = _altText.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionTitle('پیش‌نمایش بنر سایت'),
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: ColoredBox(
              color: _bannerColorValue(_backgroundColor),
              child:
                  imagePath == null
                      ? _bannerPreviewFallback(altText)
                      : Image.network(
                        AdminApi.imageUrl(imagePath),
                        fit: BoxFit.cover,
                        errorBuilder:
                            (_, __, ___) => _bannerPreviewFallback(altText),
                      ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _bannerPreviewFallback(String text) => Center(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Text(
        text.isEmpty ? 'متن جایگزین تصویر اینجا نمایش داده می‌شود' : text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
  );

  Widget _colorPicker() {
    final query = _normalizeBannerColorSearch(_colorSearch.text);
    final palettes =
        _bannerColorPalettes
            .where(
              (palette) =>
                  query.isNotEmpty &&
                  _normalizeBannerColorSearch(
                    '${palette.name} ${palette.aliases.join(' ')}',
                  ).contains(query),
            )
            .toList();
    final typedHex = _isBannerHex(
      _colorSearch.text.trim().startsWith('#')
          ? _colorSearch.text.trim()
          : '#${_colorSearch.text.trim()}',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _colorSearch,
          textDirection: TextDirection.rtl,
          decoration: const InputDecoration(
            labelText: 'جست‌وجوی رنگ یا کد HEX',
            hintText: 'مثلاً آبی یا #1976D2',
            prefixIcon: Icon(Icons.search_rounded),
            isDense: true,
          ),
          onChanged: (value) {
            final candidate =
                value.trim().startsWith('#')
                    ? value.trim()
                    : '#${value.trim()}';
            if (_isBannerHex(candidate))
              _backgroundColor = candidate.toUpperCase();
            setState(() {});
          },
        ),
        if (query.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'نام رنگ را بنویس تا همهٔ طیف‌هایش نمایش داده شود؛ مثل «آبی».',
              style: TextStyle(fontSize: 11, color: Color(0xFF74686C)),
            ),
          ),
        if (typedHex)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton.icon(
              onPressed:
                  () => setState(
                    () =>
                        _backgroundColor =
                            (_colorSearch.text.trim().startsWith('#')
                                    ? _colorSearch.text.trim()
                                    : '#${_colorSearch.text.trim()}')
                                .toUpperCase(),
                  ),
              icon: Icon(
                Icons.circle,
                color: _bannerColorValue(
                  _colorSearch.text.trim().startsWith('#')
                      ? _colorSearch.text.trim()
                      : '#${_colorSearch.text.trim()}',
                ),
              ),
              label: Text('انتخاب رنگ ${_colorSearch.text.toUpperCase()}'),
            ),
          ),
        if (query.isNotEmpty && palettes.isEmpty && !typedHex)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'رنگی پیدا نشد؛ نام فارسی یا کد HEX را وارد کن.',
              style: TextStyle(fontSize: 11, color: Color(0xFF74686C)),
            ),
          ),
        ...palettes.map(
          (palette) => Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  palette.name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 9,
                  children:
                      _bannerPaletteShades(palette).map((shade) {
                        final hex = _bannerColorHex(shade.color);
                        final selected = hex == _backgroundColor.toUpperCase();
                        return SizedBox(
                          width: 44,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => setState(() => _backgroundColor = hex),
                            child: Column(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: shade.color,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color:
                                          selected
                                              ? Theme.of(
                                                context,
                                              ).colorScheme.primary
                                              : Theme.of(
                                                context,
                                              ).colorScheme.outlineVariant,
                                      width: selected ? 2.5 : 1,
                                    ),
                                  ),
                                  child:
                                      selected
                                          ? Icon(
                                            Icons.check_rounded,
                                            size: 18,
                                            color:
                                                shade.color.computeLuminance() >
                                                        .48
                                                    ? Colors.black87
                                                    : Colors.white,
                                          )
                                          : null,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${shade.shade}',
                                  style: const TextStyle(fontSize: 9),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: _bannerColorValue(_backgroundColor),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'رنگ انتخاب‌شده: $_backgroundColor',
              textDirection: TextDirection.ltr,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ],
    );
  }
}

typedef _BannerShade = ({int shade, Color color});
typedef _BannerColorPalette =
    ({String name, ColorSwatch<int> colors, bool accent, List<String> aliases});

const _bannerColorPalettes = <_BannerColorPalette>[
  (name: 'قرمز', colors: Colors.red, accent: false, aliases: ['red']),
  (name: 'صورتی', colors: Colors.pink, accent: false, aliases: ['pink']),
  (name: 'بنفش', colors: Colors.purple, accent: false, aliases: ['purple']),
  (
    name: 'بنفش تیره',
    colors: Colors.deepPurple,
    accent: false,
    aliases: ['deep purple'],
  ),
  (
    name: 'نیلی',
    colors: Colors.indigo,
    accent: false,
    aliases: ['indigo', 'آبی تیره'],
  ),
  (name: 'آبی', colors: Colors.blue, accent: false, aliases: ['blue']),
  (
    name: 'آبی روشن',
    colors: Colors.lightBlue,
    accent: false,
    aliases: ['light blue'],
  ),
  (
    name: 'فیروزه‌ای',
    colors: Colors.cyan,
    accent: false,
    aliases: ['cyan', 'آبی فیروزه ای'],
  ),
  (
    name: 'سبزآبی',
    colors: Colors.teal,
    accent: false,
    aliases: ['teal', 'فیروزه‌ای تیره'],
  ),
  (name: 'سبز', colors: Colors.green, accent: false, aliases: ['green']),
  (
    name: 'سبز روشن',
    colors: Colors.lightGreen,
    accent: false,
    aliases: ['light green'],
  ),
  (name: 'لیمویی', colors: Colors.lime, accent: false, aliases: ['lime']),
  (name: 'زرد', colors: Colors.yellow, accent: false, aliases: ['yellow']),
  (name: 'کهربایی', colors: Colors.amber, accent: false, aliases: ['amber']),
  (name: 'نارنجی', colors: Colors.orange, accent: false, aliases: ['orange']),
  (
    name: 'نارنجی تیره',
    colors: Colors.deepOrange,
    accent: false,
    aliases: ['deep orange'],
  ),
  (name: 'قهوه‌ای', colors: Colors.brown, accent: false, aliases: ['brown']),
  (
    name: 'خاکستری',
    colors: Colors.grey,
    accent: false,
    aliases: ['grey', 'gray'],
  ),
  (
    name: 'خاکستری آبی',
    colors: Colors.blueGrey,
    accent: false,
    aliases: ['blue grey', 'blue gray'],
  ),
  (
    name: 'آبی درخشان',
    colors: Colors.blueAccent,
    accent: true,
    aliases: ['blue accent'],
  ),
  (
    name: 'آبی روشن درخشان',
    colors: Colors.lightBlueAccent,
    accent: true,
    aliases: ['light blue accent'],
  ),
  (
    name: 'فیروزه‌ای درخشان',
    colors: Colors.cyanAccent,
    accent: true,
    aliases: ['cyan accent', 'آبی فیروزه‌ای'],
  ),
  (
    name: 'سبزآبی درخشان',
    colors: Colors.tealAccent,
    accent: true,
    aliases: ['teal accent'],
  ),
  (
    name: 'سبز درخشان',
    colors: Colors.greenAccent,
    accent: true,
    aliases: ['green accent'],
  ),
  (
    name: 'سبز روشن درخشان',
    colors: Colors.lightGreenAccent,
    accent: true,
    aliases: ['light green accent'],
  ),
  (
    name: 'لیمویی درخشان',
    colors: Colors.limeAccent,
    accent: true,
    aliases: ['lime accent'],
  ),
  (
    name: 'زرد درخشان',
    colors: Colors.yellowAccent,
    accent: true,
    aliases: ['yellow accent'],
  ),
  (
    name: 'کهربایی درخشان',
    colors: Colors.amberAccent,
    accent: true,
    aliases: ['amber accent'],
  ),
  (
    name: 'نارنجی درخشان',
    colors: Colors.orangeAccent,
    accent: true,
    aliases: ['orange accent'],
  ),
  (
    name: 'نارنجی تیره درخشان',
    colors: Colors.deepOrangeAccent,
    accent: true,
    aliases: ['deep orange accent'],
  ),
  (
    name: 'قرمز درخشان',
    colors: Colors.redAccent,
    accent: true,
    aliases: ['red accent'],
  ),
  (
    name: 'صورتی درخشان',
    colors: Colors.pinkAccent,
    accent: true,
    aliases: ['pink accent'],
  ),
  (
    name: 'بنفش درخشان',
    colors: Colors.purpleAccent,
    accent: true,
    aliases: ['purple accent'],
  ),
  (
    name: 'بنفش تیره درخشان',
    colors: Colors.deepPurpleAccent,
    accent: true,
    aliases: ['deep purple accent'],
  ),
  (
    name: 'نیلی درخشان',
    colors: Colors.indigoAccent,
    accent: true,
    aliases: ['indigo accent', 'آبی تیره درخشان'],
  ),
];

List<_BannerShade> _bannerPaletteShades(_BannerColorPalette palette) {
  final shades =
      palette.accent
          ? const [100, 200, 400, 700]
          : const [50, 100, 200, 300, 400, 500, 600, 700, 800, 900];
  final colors = shades
      .map((shade) => palette.colors[shade]!)
      .toList(growable: false);
  return List.generate(
    colors.length,
    (index) => (shade: shades[index], color: colors[index]),
  );
}

bool _isBannerHex(String value) => RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value);

Color _bannerColorValue(String value) {
  if (!_isBannerHex(value)) return const Color(0xFFFCE4DB);
  return Color(0xFF000000 | int.parse(value.substring(1), radix: 16));
}

String _bannerColorHex(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

String _normalizeBannerColorSearch(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll('ي', 'ی')
    .replaceAll('ك', 'ک')
    .replaceAll('آ', 'ا')
    .replaceAll('‌', ' ')
    .replaceAll(RegExp(r'\s+'), ' ');

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 26),
    child: Center(
      child: Text(label, style: const TextStyle(color: Color(0xFF74686C))),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
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
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onRetry, child: const Text('تلاش دوباره')),
        ],
      ),
    ),
  );
}

Widget _textField(
  TextEditingController controller,
  String label, {
  bool required = false,
  bool ltr = false,
  int maxLines = 1,
}) => Padding(
  padding: const EdgeInsets.only(bottom: 10),
  child: TextFormField(
    controller: controller,
    textDirection: ltr ? TextDirection.ltr : null,
    textAlign: ltr ? TextAlign.left : TextAlign.start,
    maxLines: maxLines,
    decoration: InputDecoration(labelText: label),
    validator:
        required
            ? (value) =>
                value == null || value.trim().isEmpty
                    ? 'این فیلد الزامی است'
                    : null
            : null,
  ),
);

List<JsonMap> _maps(Object? value) =>
    value is List
        ? value
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : const [];
int _integer(Object? value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;
String? _optionalPath(Object? value) {
  final path = '$value'.trim();
  return path.isEmpty || path == 'null' ? null : path;
}

String _digits(String value) {
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  return value
      .replaceAllMapped(RegExp('[۰-۹٠-٩]'), (match) {
        final digit = match[0]!;
        final index = persian.indexOf(digit);
        return '${index >= 0 ? index : arabic.indexOf(digit)}';
      })
      .replaceAll(RegExp(r'[^0-9]'), '');
}

String _groupDigits(String value) {
  final digits = _digits(value);
  if (digits.isEmpty) return '';
  final grouped = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) grouped.write(',');
    grouped.write(digits[index]);
  }
  return grouped.toString();
}
