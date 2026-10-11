import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/admin_api.dart';
import '../../core/providers.dart';
import '../../core/ui_helpers.dart';

class CustomerManagementScreen extends ConsumerStatefulWidget {
  const CustomerManagementScreen({super.key});
  @override
  ConsumerState<CustomerManagementScreen> createState() => _CustomerManagementScreenState();
}

class _CustomerManagementScreenState extends ConsumerState<CustomerManagementScreen> {
  final _query = TextEditingController();
  final _city = TextEditingController();
  String _registration = 'any';
  String _purchaseSort = 'none';
  String? _productId;
  int _page = 1;
  bool _loading = false;
  List<JsonMap> _customers = const [];
  List<JsonMap> _products = const [];
  int _total = 0;
  String? _error;

  @override
  void initState() { super.initState(); _loadProducts(); _load(); }
  @override
  void dispose() { _query.dispose(); _city.dispose(); super.dispose(); }

  Future<void> _loadProducts() async {
    try { final list = await ref.read(adminApiProvider).productOptions(); if (mounted) setState(() => _products = list); } catch (_) { }
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await ref.read(adminApiProvider).customers(
        page: _page, query: _query.text, city: _city.text,
        registration: _registration, purchaseSort: _purchaseSort, productId: _productId,
      );
      if (!mounted) return;
      final meta = result['meta'] is Map ? Map<String, dynamic>.from(result['meta'] as Map) : <String, dynamic>{};
      setState(() {
        _customers = result['items'] is List ? (result['items'] as List).whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList() : const [];
        _total = (meta['total'] as num?)?.toInt() ?? _customers.length;
      });
    } catch (error) { if (mounted) setState(() => _error = AdminApi.friendlyError(error)); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _load,
    child: ListView(padding: const EdgeInsets.all(16), children: [
      const _PageIntro(icon: Icons.people_alt_outlined, title: 'مدیریت مشتریان', subtitle: 'جست‌وجو، خریدهای قبلی و رضایت دریافت پیامک'),
      const SizedBox(height: 12),
      TextField(controller: _query, textInputAction: TextInputAction.search, onSubmitted: (_) { _page = 1; _load(); }, decoration: const InputDecoration(labelText: 'نام، شماره یا ایمیل', prefixIcon: Icon(Icons.search))),
      const SizedBox(height: 9),
      TextField(controller: _city, textInputAction: TextInputAction.search, onSubmitted: (_) { _page = 1; _load(); }, decoration: const InputDecoration(labelText: 'شهر', prefixIcon: Icon(Icons.location_city_outlined))),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(initialValue: _registration, decoration: const InputDecoration(labelText: 'زمان ثبت‌نام'), items: const [
        DropdownMenuItem(value: 'any', child: Text('همه زمان‌ها')),
        DropdownMenuItem(value: 'under_year', child: Text('کمتر از یک سال')),
        DropdownMenuItem(value: 'over_year', child: Text('بیشتر از یک سال')),
      ], onChanged: (value) => setState(() => _registration = value ?? 'any')),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(initialValue: _purchaseSort, decoration: const InputDecoration(labelText: 'مرتب‌سازی بر اساس خرید'), items: const [
        DropdownMenuItem(value: 'none', child: Text('بدون مرتب‌سازی')),
        DropdownMenuItem(value: 'recent', child: Text('خرید جدیدتر')),
        DropdownMenuItem(value: 'oldest', child: Text('خرید قدیمی‌تر')),
      ], onChanged: (value) => setState(() => _purchaseSort = value ?? 'none')),
      if (_products.isNotEmpty) ...[
        const SizedBox(height: 8),
        DropdownButtonFormField<String?>(initialValue: _productId, decoration: const InputDecoration(labelText: 'خرید محصول خاص'), items: [
          const DropdownMenuItem<String?>(value: null, child: Text('همهٔ محصولات')),
          ..._products.map((item) => DropdownMenuItem<String?>(value: '${item['id']}', child: Text('${item['name']}', maxLines: 1, overflow: TextOverflow.ellipsis))),
        ], onChanged: (value) => setState(() => _productId = value)),
      ],
      const SizedBox(height: 10),
      FilledButton.icon(onPressed: _loading ? null : () { _page = 1; _load(); }, icon: const Icon(Icons.filter_alt_outlined), label: const Text('اعمال فیلترها')),
      const SizedBox(height: 9),
      _StatStrip(label: 'مشتری‌های منطبق', value: persianNumber(_total), icon: Icons.groups_outlined),
      if (_error != null) _ErrorCard(message: _error!, onRetry: _load),
      if (_loading) const Padding(padding: EdgeInsets.all(26), child: Center(child: CircularProgressIndicator())),
      if (!_loading && _error == null && _customers.isEmpty) const _EmptyCard(text: 'مشتری‌ای با این فیلتر پیدا نشد.'),
      ..._customers.map((customer) => Card(
        child: Padding(padding: const EdgeInsets.all(13), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            CircleAvatar(child: Text(_initial(customer['fullName']))),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${customer['fullName'] ?? 'بدون نام'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text('${customer['phone'] ?? ''}', textDirection: TextDirection.ltr, textAlign: TextAlign.right, style: Theme.of(context).textTheme.bodySmall),
            ])),
          ]),
          const SizedBox(height: 7),
          Text('شهر: ${customer['city'] ?? 'ثبت نشده'}  ·  عضویت: ${_date(customer['createdAt'])}', style: Theme.of(context).textTheme.bodySmall),
          Text('آخرین خرید: ${_date(customer['lastPurchaseAt'])}', style: Theme.of(context).textTheme.bodySmall),
          ListTile(
            dense: true, contentPadding: EdgeInsets.zero,
            leading: Icon(customer['marketingOptIn'] == true ? Icons.mark_email_read_outlined : Icons.unsubscribe_outlined, size: 19),
            title: Text(customer['marketingOptIn'] == true ? 'با رضایت دریافت پیامک' : 'بدون رضایت پیامکی', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ])),
      )),
      if (_total > 50) Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(onPressed: _page > 1 ? () { setState(() => _page--); _load(); } : null, icon: const Icon(Icons.chevron_right)),
        Text('صفحهٔ ${persianNumber(_page)}', style: Theme.of(context).textTheme.labelLarge),
        IconButton(onPressed: _page * 50 < _total ? () { setState(() => _page++); _load(); } : null, icon: const Icon(Icons.chevron_left)),
      ]),
    ]),
  );
}

class CouponManagementScreen extends ConsumerStatefulWidget {
  const CouponManagementScreen({super.key});
  @override
  ConsumerState<CouponManagementScreen> createState() => _CouponManagementScreenState();
}

class _CouponManagementScreenState extends ConsumerState<CouponManagementScreen> {
  bool _loading = true;
  List<JsonMap> _coupons = const [];
  String? _error;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try { final data = await ref.read(adminApiProvider).coupons(); if (mounted) setState(() => _coupons = data); }
    catch (error) { if (mounted) setState(() => _error = AdminApi.friendlyError(error)); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _edit([JsonMap? coupon]) async {
    final code = TextEditingController(text: '${coupon?['code'] ?? ''}');
    final value = TextEditingController(text: '${coupon?['discountValue'] ?? ''}');
    final minimum = TextEditingController(text: '${coupon?['minOrderToman'] ?? '0'}');
    final max = TextEditingController(text: '${coupon?['maxDiscountToman'] ?? ''}');
    final usageLimit = TextEditingController(text: '${coupon?['usageLimit'] ?? ''}');
    final customerLimit = TextEditingController(text: '${coupon?['perCustomerLimit'] ?? ''}');
    final type = ValueNotifier<String>(coupon?['discountType'] == 'fixed' ? 'fixed' : 'percent');
    final usage = ValueNotifier<bool>(coupon?['isActive'] != false);
    final firstOrderOnly = ValueNotifier<bool>(coupon?['firstOrderOnly'] == true);
    final form = await showDialog<JsonMap>(context: context, builder: (dialogContext) => AlertDialog(
      title: Text(coupon == null ? 'کد تخفیف جدید' : 'ویرایش کد تخفیف'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: code, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'کد')),
        const SizedBox(height: 8),
        ValueListenableBuilder(valueListenable: type, builder: (_, selected, __) => DropdownButtonFormField<String>(initialValue: selected, decoration: const InputDecoration(labelText: 'نوع تخفیف'), items: const [DropdownMenuItem(value: 'percent', child: Text('درصدی')),
          DropdownMenuItem(value: 'fixed', child: Text('مبلغ ثابت (تومان)'))], onChanged: (next) { if (next != null) type.value = next; })),
        const SizedBox(height: 8),
        TextField(controller: value, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'مقدار تخفیف')),
        const SizedBox(height: 8),
        TextField(controller: minimum, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'حداقل مبلغ سفارش (تومان)')),
        const SizedBox(height: 8),
        TextField(controller: max, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'سقف تخفیف (اختیاری)')),
        const SizedBox(height: 8),
        TextField(controller: usageLimit, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'سقف کل استفاده (اختیاری)')),
        const SizedBox(height: 8),
        TextField(controller: customerLimit, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'سقف استفاده برای هر مشتری (اختیاری)')),
        ValueListenableBuilder(valueListenable: firstOrderOnly, builder: (_, enabled, __) => SwitchListTile(value: enabled, title: const Text('فقط سفارش اول'), onChanged: (next) => firstOrderOnly.value = next)),
        ValueListenableBuilder(valueListenable: usage, builder: (_, active, __) => SwitchListTile(value: active, title: const Text('فعال'), onChanged: (next) => usage.value = next)),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('انصراف')),
        FilledButton(onPressed: () {
          final parsedValue = num.tryParse(_digits(value.text));
          final parsedMinimum = int.tryParse(_digits(minimum.text));
          final parsedMax = max.text.trim().isEmpty ? null : int.tryParse(_digits(max.text));
          final parsedUsageLimit = usageLimit.text.trim().isEmpty ? null : int.tryParse(_digits(usageLimit.text));
          final parsedCustomerLimit = customerLimit.text.trim().isEmpty ? null : int.tryParse(_digits(customerLimit.text));
          if (code.text.trim().isEmpty || parsedValue == null || parsedMinimum == null ||
              (max.text.trim().isNotEmpty && parsedMax == null) ||
              (usageLimit.text.trim().isNotEmpty && parsedUsageLimit == null) ||
              (customerLimit.text.trim().isNotEmpty && parsedCustomerLimit == null)) return;
          Navigator.pop(dialogContext, {
            'code': code.text.trim().toUpperCase(), 'discountType': type.value,
            'discountValue': parsedValue, 'minOrderToman': parsedMinimum,
            'maxDiscountToman': parsedMax, 'usageLimit': parsedUsageLimit,
            'perCustomerLimit': parsedCustomerLimit, 'firstOrderOnly': firstOrderOnly.value,
            'isActive': usage.value,
          });
        }, child: const Text('ذخیره'))],
    ));
    code.dispose(); value.dispose(); minimum.dispose(); max.dispose(); usageLimit.dispose(); customerLimit.dispose(); type.dispose(); usage.dispose(); firstOrderOnly.dispose();
    if (form == null || !mounted) return;
    try {
      await ref.read(adminApiProvider).saveCoupon(form, id: coupon == null ? null : '${coupon['id']}');
      await _load();
      if (mounted) showAppMessage(context, 'کد تخفیف ذخیره شد.');
    } catch (error) { if (mounted) showAppMessage(context, AdminApi.friendlyError(error), error: true); }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.all(16), children: [
    const _PageIntro(icon: Icons.sell_outlined, title: 'کدهای تخفیف', subtitle: 'ساخت و فعال/غیرفعال‌کردن کدهای قابل استفاده در خرید'),
    const SizedBox(height: 12),
    FilledButton.icon(onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('کد تخفیف جدید')),
    if (_error != null) _ErrorCard(message: _error!, onRetry: _load),
    if (_loading) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
    if (!_loading && _coupons.isEmpty) const _EmptyCard(text: 'هنوز کد تخفیفی نساخته‌ای.'),
    ..._coupons.map((coupon) => Card(child: ListTile(
      leading: CircleAvatar(child: Icon(coupon['isActive'] == true ? Icons.local_offer_outlined : Icons.do_not_disturb_on_outlined)),
      title: Text('${coupon['code']}', style: const TextStyle(fontWeight: FontWeight.w900)),
      subtitle: Text('${coupon['discountType'] == 'percent' ? '${coupon['discountValue']}٪' : '${persianNumber(coupon['discountValue'] ?? 0)} تومان'} · حداقل ${persianNumber(coupon['minOrderToman'] ?? 0)} تومان\n${coupon['isActive'] == true ? 'فعال' : 'غیرفعال'}'),
      isThreeLine: true, trailing: IconButton(tooltip: 'ویرایش', onPressed: () => _edit(coupon), icon: const Icon(Icons.edit_outlined)),
      onTap: () => _edit(coupon),
    ))),
  ]));
}

class SmsCampaignScreen extends ConsumerStatefulWidget {
  const SmsCampaignScreen({super.key});
  @override
  ConsumerState<SmsCampaignScreen> createState() => _SmsCampaignScreenState();
}

class _SmsCampaignScreenState extends ConsumerState<SmsCampaignScreen> {
  final _title = TextEditingController();
  final _message = TextEditingController();
  final _city = TextEditingController();
  final _query = TextEditingController();
  String _registration = 'any';
  String _purchaseSort = 'none';
  String? _productId;
  List<JsonMap> _products = const [];
  List<JsonMap> _history = const [];
  int? _audienceCount;
  bool _loading = false;
  String? _error;

  @override
  void initState() { super.initState(); _refreshHistory(); _loadProducts(); }
  @override
  void dispose() { _title.dispose(); _message.dispose(); _city.dispose(); _query.dispose(); super.dispose(); }

  JsonMap get _filters => {
    'q': _query.text.trim(), 'city': _city.text.trim(), 'registration': _registration,
    'purchaseSort': _purchaseSort, if (_productId != null) 'productId': _productId,
  };

  Future<void> _loadProducts() async { try { final list = await ref.read(adminApiProvider).productOptions(); if (mounted) setState(() => _products = list); } catch (_) { } }
  Future<void> _refreshHistory() async { try { final list = await ref.read(adminApiProvider).smsCampaigns(); if (mounted) setState(() => _history = list); } catch (_) { } }

  Future<void> _preview() async {
    setState(() { _loading = true; _error = null; });
    try { final result = await ref.read(adminApiProvider).previewSmsAudience(_filters); if (mounted) setState(() => _audienceCount = (result['count'] as num?)?.toInt() ?? 0); }
    catch (error) { if (mounted) setState(() => _error = AdminApi.friendlyError(error)); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _send() async {
    if (_title.text.trim().isEmpty || _message.text.trim().isEmpty) { showAppMessage(context, 'عنوان و متن پیام را وارد کن.', error: true); return; }
    if (_audienceCount == null) { await _preview(); if (!mounted || _audienceCount == null) return; }
    if (_audienceCount == 0) { showAppMessage(context, 'مشتری دارای رضایت پیامکی با این فیلتر پیدا نشد.', error: true); return; }
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('ارسال پیامک'),
      content: Text('این پیام برای ${persianNumber(_audienceCount!)} مشتری رضایت‌داده ارسال می‌شود و هزینهٔ سرویس پیامک دارد. ادامه می‌دهی؟'),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('بازبینی')),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('ساخت و ارسال'))],
    ));
    if (confirmed != true || !mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final created = await ref.read(adminApiProvider).createSmsCampaign(_title.text.trim(), _message.text.trim(), _filters);
      await ref.read(adminApiProvider).sendSmsCampaign('${created['id']}');
      _title.clear(); _message.clear();
      await _refreshHistory();
      if (mounted) showAppMessage(context, 'درخواست ارسال ثبت شد. نتیجه در سابقهٔ کمپین نمایش داده می‌شود.');
    } catch (error) { if (mounted) setState(() => _error = AdminApi.friendlyError(error)); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(onRefresh: () async { await _preview(); await _refreshHistory(); }, child: ListView(padding: const EdgeInsets.all(16), children: [
    const _PageIntro(icon: Icons.sms_outlined, title: 'پیامک به مشتریان', subtitle: 'فیلتر مخاطب، پیش‌نمایش تعداد و مشاهدهٔ سوابق ارسال'),
    const SizedBox(height: 12),
    TextField(controller: _title, maxLength: 160, decoration: const InputDecoration(labelText: 'عنوان کمپین')),
    const SizedBox(height: 8),
    TextField(controller: _message, maxLength: 1000, minLines: 5, maxLines: 8, keyboardType: TextInputType.multiline, textAlignVertical: TextAlignVertical.top, decoration: const InputDecoration(labelText: 'متن پیامک', alignLabelWithHint: true, hintText: 'متن پیام را بنویس…')),
    const SizedBox(height: 12),
    Text('فیلتر مخاطبان', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
    const SizedBox(height: 8),
    TextField(controller: _query, onChanged: (_) => setState(() => _audienceCount = null), decoration: const InputDecoration(labelText: 'جست‌وجوی نام یا شماره')),
    const SizedBox(height: 8),
    TextField(controller: _city, onChanged: (_) => setState(() => _audienceCount = null), decoration: const InputDecoration(labelText: 'شهر')),
    const SizedBox(height: 8),
    DropdownButtonFormField<String>(initialValue: _registration, decoration: const InputDecoration(labelText: 'زمان ثبت‌نام'), items: const [
      DropdownMenuItem(value: 'any', child: Text('هر زمانی')),
      DropdownMenuItem(value: 'under_year', child: Text('کمتر از یک سال')),
      DropdownMenuItem(value: 'over_year', child: Text('بیشتر از یک سال')),
    ], onChanged: (value) => setState(() { _registration = value ?? 'any'; _audienceCount = null; })),
    const SizedBox(height: 8),
    DropdownButtonFormField<String>(initialValue: _purchaseSort, decoration: const InputDecoration(labelText: 'ترتیب آخرین خرید'), items: const [
      DropdownMenuItem(value: 'none', child: Text('بدون ترتیب')),
      DropdownMenuItem(value: 'recent', child: Text('خرید جدیدتر')),
      DropdownMenuItem(value: 'oldest', child: Text('خرید قدیمی‌تر')),
    ], onChanged: (value) => setState(() { _purchaseSort = value ?? 'none'; _audienceCount = null; })),
    if (_products.isNotEmpty) ...[
      const SizedBox(height: 8),
      DropdownButtonFormField<String?>(initialValue: _productId, decoration: const InputDecoration(labelText: 'خریداران یک محصول'), items: [
        const DropdownMenuItem<String?>(value: null, child: Text('همهٔ محصولات')),
        ..._products.map((product) => DropdownMenuItem<String?>(value: '${product['id']}', child: Text('${product['name']}', maxLines: 1, overflow: TextOverflow.ellipsis))),
      ], onChanged: (value) => setState(() { _productId = value; _audienceCount = null; })),
    ],
    const SizedBox(height: 8),
    Card(child: SwitchListTile.adaptive(value: true, onChanged: null, title: const Text('فقط مشتریان دارای رضایت پیامکی'), subtitle: const Text('این محدودیت هنگام ارسال نیز دوباره بررسی می‌شود.'))),
    FilledButton.tonalIcon(onPressed: _loading ? null : _preview, icon: const Icon(Icons.groups_outlined), label: Text(_audienceCount == null ? 'شمارش مخاطبان' : 'مخاطبان منطبق: ${persianNumber(_audienceCount!)}')),
    const SizedBox(height: 8),
    FilledButton.icon(onPressed: _loading ? null : _send, icon: const Icon(Icons.send_outlined), label: Text(_loading ? 'در حال پردازش…' : 'ارسال کمپین')),
    if (_error != null) _ErrorCard(message: _error!, onRetry: _preview),
    const SizedBox(height: 22),
    Text('سابقهٔ کمپین‌ها', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
    const SizedBox(height: 8),
    if (_history.isEmpty) const _EmptyCard(text: 'هنوز کمپینی ثبت نشده است.'),
    ..._history.map((item) => Card(child: ListTile(
      leading: const Icon(Icons.mark_email_read_outlined), title: Text('${item['title']}', maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${_statusLabel(item['status'])} · ${persianNumber(item['sentCount'] ?? 0)} ارسال از ${persianNumber(item['recipientCount'] ?? 0)}'),
      isThreeLine: false, trailing: Text(_date(item['createdAt']), style: Theme.of(context).textTheme.labelSmall),
    ))),
  ]));
}

class SocialPublishingScreen extends ConsumerStatefulWidget {
  const SocialPublishingScreen({super.key});
  @override
  ConsumerState<SocialPublishingScreen> createState() => _SocialPublishingScreenState();
}

class _SocialPublishingScreenState extends ConsumerState<SocialPublishingScreen> {
  final _caption = TextEditingController();
  final _image = TextEditingController();
  bool _rubika = true;
  bool _instagram = false;
  bool _schedule = false;
  DateTime? _publishAt;
  bool _loading = false;
  JsonMap _status = {};
  List<JsonMap> _posts = const [];
  String? _error;

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _caption.dispose(); _image.dispose(); super.dispose(); }
  Future<void> _load() async {
    try {
      final status = await ref.read(adminApiProvider).socialStatus();
      final posts = await ref.read(adminApiProvider).socialPosts();
      if (mounted) setState(() { _status = status; _posts = posts; });
    } catch (error) { if (mounted) setState(() => _error = AdminApi.friendlyError(error)); }
  }

  Future<void> _chooseTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(context: context, initialDate: _publishAt ?? now, firstDate: now, lastDate: now.add(const Duration(days: 365)));
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_publishAt ?? now));
    if (time == null) return;
    setState(() => _publishAt = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _publish() async {
    if (_caption.text.trim().isEmpty || (!_rubika && !_instagram)) { showAppMessage(context, 'متن و دست‌کم یک کانال را انتخاب کن.', error: true); return; }
    if (_schedule && _publishAt == null) { showAppMessage(context, 'برای انتشار زمان‌بندی‌شده تاریخ و ساعت را انتخاب کن.', error: true); return; }
    setState(() { _loading = true; _error = null; });
    try {
      final channels = [if (_rubika) 'rubika', if (_instagram) 'instagram'];
      await ref.read(adminApiProvider).createSocialPost({
        'caption': _caption.text.trim(), 'imageUrl': _image.text.trim(), 'channels': channels,
        if (_schedule && _publishAt != null) 'publishAt': _publishAt!.toUtc().toIso8601String(),
      });
      _caption.clear(); _image.clear();
      await _load();
      if (mounted) showAppMessage(context, _schedule ? 'انتشار زمان‌بندی شد.' : 'درخواست انتشار ثبت شد؛ نتیجه در فهرست نمایش داده می‌شود.');
    } catch (error) { if (mounted) setState(() => _error = AdminApi.friendlyError(error)); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final rubika = _status['rubika'] is Map ? Map<String, dynamic>.from(_status['rubika'] as Map) : <String, dynamic>{};
    final instagram = _status['instagram'] is Map ? Map<String, dynamic>.from(_status['instagram'] as Map) : <String, dynamic>{};
    return RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.all(16), children: [
      const _PageIntro(icon: Icons.campaign_outlined, title: 'انتشار تبلیغات', subtitle: 'ارسال به روبیکا یا انتشار زمان‌بندی‌شده در اینستاگرام'),
      const SizedBox(height: 10),
      _IntegrationTile(title: 'ربات روبیکا', configured: rubika['configured'] == true, hint: 'RUBIKA_BOT_TOKEN و RUBIKA_CHANNEL_ID'),
      _IntegrationTile(title: 'Instagram Graph API', configured: instagram['configured'] == true, hint: 'INSTAGRAM_USER_ID، token و Graph API version مجاز'),
      const SizedBox(height: 8),
      TextField(controller: _caption, maxLength: 2200, minLines: 4, maxLines: 7, textAlignVertical: TextAlignVertical.top, decoration: const InputDecoration(labelText: 'متن تبلیغ', alignLabelWithHint: true)),
      const SizedBox(height: 8),
      TextField(controller: _image, keyboardType: TextInputType.url, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'لینک عمومی HTTPS تصویر', hintText: 'https://…')),
      CheckboxListTile(value: _rubika, onChanged: (value) => setState(() => _rubika = value ?? false), contentPadding: EdgeInsets.zero, title: const Text('ارسال به کانال روبیکا')),
      CheckboxListTile(value: _instagram, onChanged: (value) => setState(() => _instagram = value ?? false), contentPadding: EdgeInsets.zero, title: const Text('انتشار در Instagram')),
      SwitchListTile.adaptive(value: _schedule, onChanged: (value) => setState(() => _schedule = value), contentPadding: EdgeInsets.zero, title: const Text('زمان‌بندی انتشار')),
      if (_schedule) OutlinedButton.icon(onPressed: _chooseTime, icon: const Icon(Icons.schedule), label: Text(_publishAt == null ? 'انتخاب تاریخ و ساعت' : _publishAt!.toLocal().toString().substring(0, 16))),
      FilledButton.icon(onPressed: _loading ? null : _publish, icon: const Icon(Icons.send_outlined), label: Text(_loading ? 'در حال ثبت…' : 'ثبت انتشار')),
      if (_error != null) _ErrorCard(message: _error!, onRetry: _load),
      const SizedBox(height: 20), Text('انتشارهای اخیر', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
      if (_posts.isEmpty) const _EmptyCard(text: 'انتشاری ثبت نشده است.'),
      ..._posts.map((post) => Card(child: ListTile(
        leading: const Icon(Icons.post_add_outlined), title: Text('${post['caption']}', maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text('${_statusLabel(post['status'])} · ${_date(post['publishAt'])}'),
        trailing: const Icon(Icons.chevron_left), onTap: () => showDialog<void>(context: context, builder: (context) => AlertDialog(title: const Text('نتیجهٔ انتشار'), content: SingleChildScrollView(child: Text('${post['lastError'] ?? post['channelResults'] ?? 'در صف انتشار'}')), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('بستن'))])),
      ))),
    ]));
  }
}

class OperationsScreen extends ConsumerStatefulWidget {
  const OperationsScreen({super.key});
  @override
  ConsumerState<OperationsScreen> createState() => _OperationsScreenState();
}

class _OperationsScreenState extends ConsumerState<OperationsScreen> {
  JsonMap _status = {};
  List<JsonMap> _backups = const [];
  bool _loading = true;
  String? _error;
  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final status = await ref.read(adminApiProvider).operationsStatus();
      final backups = await ref.read(adminApiProvider).backups();
      if (mounted) setState(() { _status = status; _backups = backups; });
    } catch (error) { if (mounted) setState(() => _error = AdminApi.friendlyError(error)); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _backup() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await ref.read(adminApiProvider).createBackup();
      await _load();
      if (mounted) showAppMessage(context, 'نسخهٔ پشتیبان ${result['filename']} ساخته شد.');
    } catch (error) { if (mounted) setState(() => _error = AdminApi.friendlyError(error)); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final volume = _status['backupVolume'] is Map ? Map<String, dynamic>.from(_status['backupVolume'] as Map) : <String, dynamic>{};
    final integrations = _status['integrations'] is Map ? Map<String, dynamic>.from(_status['integrations'] as Map) : <String, dynamic>{};
    return RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.all(16), children: [
      const _PageIntro(icon: Icons.dns_outlined, title: 'سرور و پشتیبان‌گیری', subtitle: 'سلامت API، دیتابیس، اتصال‌ها و نسخه‌های SQL'),
      if (_loading) const LinearProgressIndicator(),
      if (_error != null) _ErrorCard(message: _error!, onRetry: _load),
      _StatStrip(label: 'API', value: '${_status['api'] ?? '—'}', icon: Icons.cloud_done_outlined),
      _StatStrip(label: 'دیتابیس', value: '${_status['database'] ?? '—'}', icon: Icons.storage_outlined),
      _StatStrip(label: 'فضای پشتیبان', value: volume['available'] != true ? 'در دسترس نیست' : volume['persistentConfigured'] == true ? 'پایدار · ${persianNumber(volume['backupCount'] ?? 0)} فایل' : 'قابل‌نوشتن اما بدون volume پایدار', icon: Icons.sd_storage_outlined),
      Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('اتصال سرویس‌ها', style: TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 9),
        _statusLine('SMS.ir', integrations['smsIr'] == true),
        _statusLine('Rubika', integrations['rubika'] == true),
        _statusLine('Instagram', integrations['instagram'] == true),
      ]))),
      Card(child: Padding(padding: const EdgeInsets.all(14), child: Text('مسیر پشتیبان: ${volume['path'] ?? 'BACKUP_DIR'}\nبرای نگهداری پس از restart در Railway یک Volume با mount path برابر /data بساز و BACKUP_DIR را روی /data/backups قرار بده. ابزار mysqldump باید داخل image نصب باشد.', style: Theme.of(context).textTheme.bodySmall))),
      FilledButton.icon(onPressed: _loading ? null : _backup, icon: const Icon(Icons.backup_outlined), label: const Text('ساخت پشتیبان همین حالا')),
      const SizedBox(height: 18), Text('نسخه‌های ذخیره‌شده', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
      if (_backups.isEmpty) const _EmptyCard(text: 'هنوز فایل پشتیبانی در volume ثبت نشده است.'),
      ..._backups.map((backup) => Card(child: ListTile(
        leading: const Icon(Icons.description_outlined), title: Text('${backup['filename']}', maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('${_date(backup['createdAt'])} · ${_size(backup['sizeBytes'])}'),
      ))),
    ]));
  }
}

class _PageIntro extends StatelessWidget {
  const _PageIntro({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(15), child: Row(children: [
    CircleAvatar(radius: 24, child: Icon(icon)), const SizedBox(width: 12),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
      const SizedBox(height: 4), Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
    ])),
  ])));
}

class _StatStrip extends StatelessWidget {
  const _StatStrip({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Card(child: ListTile(leading: Icon(icon, color: Theme.of(context).colorScheme.primary), title: Text(label), trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.w900))));
}

class _IntegrationTile extends StatelessWidget {
  const _IntegrationTile({required this.title, required this.configured, required this.hint});
  final String title;
  final bool configured;
  final String hint;
  @override
  Widget build(BuildContext context) => Card(child: ListTile(
    leading: Icon(configured ? Icons.check_circle_outline : Icons.error_outline, color: configured ? Colors.green : Theme.of(context).colorScheme.tertiary),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
    subtitle: Text(configured ? 'تنظیمات اتصال ثبت شده' : 'تنظیم در متغیرهای API: $hint', style: Theme.of(context).textTheme.bodySmall),
  ));
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(18), child: Center(child: Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall))));
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Card(color: Theme.of(context).colorScheme.errorContainer, child: ListTile(
    title: Text(message, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
    trailing: IconButton(onPressed: onRetry, icon: const Icon(Icons.refresh)),
  ));
}

Widget _statusLine(String name, bool ready) => Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [Icon(ready ? Icons.check_circle : Icons.remove_circle_outline, size: 17, color: ready ? Colors.green : Colors.grey), const SizedBox(width: 8), Expanded(child: Text(name)), Text(ready ? 'آماده' : 'تنظیم نشده')]));

String _date(Object? raw) {
  if (raw is! String) return 'ندارد';
  final date = DateTime.tryParse(raw);
  return date == null ? '—' : '${date.toLocal().year}/${date.toLocal().month.toString().padLeft(2, '0')}/${date.toLocal().day.toString().padLeft(2, '0')}';
}

String _initial(Object? raw) {
  final value = raw is String ? raw.trim() : '';
  return value.isEmpty ? 'م' : value.substring(0, 1);
}

String _statusLabel(Object? raw) => switch (raw) {
  'draft' => 'پیش‌نویس', 'queued' => 'در صف', 'sending' || 'publishing' => 'در حال انجام',
  'sent' || 'published' => 'موفق', 'partial' => 'نیمه‌کاره', 'failed' => 'ناموفق', _ => '$raw',
};

String _size(Object? raw) {
  final bytes = raw is num ? raw.toDouble() : 0.0;
  if (bytes < 1024) return '${bytes.toInt()} B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String _digits(String value) {
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  return value.replaceAllMapped(RegExp('[۰-۹٠-٩]'), (match) {
    final digit = match[0]!;
    final index = persian.indexOf(digit);
    return '${index >= 0 ? index : arabic.indexOf(digit)}';
  });
}
