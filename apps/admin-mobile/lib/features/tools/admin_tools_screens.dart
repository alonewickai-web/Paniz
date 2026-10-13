import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/admin_image_picker_field.dart';
import '../../core/admin_api.dart';
import '../../core/providers.dart';
import '../../core/ui_helpers.dart';

class CustomerManagementScreen extends ConsumerStatefulWidget {
  const CustomerManagementScreen({super.key});
  @override
  ConsumerState<CustomerManagementScreen> createState() =>
      _CustomerManagementScreenState();
}

class _CustomerManagementScreenState
    extends ConsumerState<CustomerManagementScreen> {
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
  void initState() {
    super.initState();
    _loadProducts();
    _load();
  }

  @override
  void dispose() {
    _query.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    try {
      final list = await ref.read(adminApiProvider).productOptions();
      if (mounted) setState(() => _products = list);
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(adminApiProvider)
          .customers(
            page: _page,
            query: _query.text,
            city: _city.text,
            registration: _registration,
            purchaseSort: _purchaseSort,
            productId: _productId,
          );
      if (!mounted) return;
      final meta =
          result['meta'] is Map
              ? Map<String, dynamic>.from(result['meta'] as Map)
              : <String, dynamic>{};
      setState(() {
        _customers =
            result['items'] is List
                ? (result['items'] as List)
                    .whereType<Map>()
                    .map((row) => Map<String, dynamic>.from(row))
                    .toList()
                : const [];
        _total = (meta['total'] as num?)?.toInt() ?? _customers.length;
      });
    } catch (error) {
      if (mounted) setState(() => _error = AdminApi.friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _load,
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _PageIntro(
          icon: Icons.people_alt_outlined,
          title: 'مدیریت مشتریان',
          subtitle: 'جست‌وجو، خریدهای قبلی و رضایت پیامک و روبیکا',
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _query,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) {
            _page = 1;
            _load();
          },
          decoration: const InputDecoration(
            labelText: 'نام، شماره یا ایمیل',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 9),
        TextField(
          controller: _city,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) {
            _page = 1;
            _load();
          },
          decoration: const InputDecoration(
            labelText: 'شهر',
            prefixIcon: Icon(Icons.location_city_outlined),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _registration,
          decoration: const InputDecoration(labelText: 'زمان ثبت‌نام'),
          items: const [
            DropdownMenuItem(value: 'any', child: Text('همه زمان‌ها')),
            DropdownMenuItem(
              value: 'under_year',
              child: Text('کمتر از یک سال'),
            ),
            DropdownMenuItem(
              value: 'over_year',
              child: Text('بیشتر از یک سال'),
            ),
          ],
          onChanged: (value) => setState(() => _registration = value ?? 'any'),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _purchaseSort,
          decoration: const InputDecoration(
            labelText: 'مرتب‌سازی بر اساس خرید',
          ),
          items: const [
            DropdownMenuItem(value: 'none', child: Text('بدون مرتب‌سازی')),
            DropdownMenuItem(value: 'recent', child: Text('خرید جدیدتر')),
            DropdownMenuItem(value: 'oldest', child: Text('خرید قدیمی‌تر')),
          ],
          onChanged: (value) => setState(() => _purchaseSort = value ?? 'none'),
        ),
        if (_products.isNotEmpty) ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            initialValue: _productId,
            decoration: const InputDecoration(labelText: 'خرید محصول خاص'),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('همهٔ محصولات'),
              ),
              ..._products.map(
                (item) => DropdownMenuItem<String?>(
                  value: '${item['id']}',
                  child: Text(
                    '${item['name']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            onChanged: (value) => setState(() => _productId = value),
          ),
        ],
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed:
              _loading
                  ? null
                  : () {
                    _page = 1;
                    _load();
                  },
          icon: const Icon(Icons.filter_alt_outlined),
          label: const Text('اعمال فیلترها'),
        ),
        const SizedBox(height: 9),
        _StatStrip(
          label: 'مشتری‌های منطبق',
          value: persianNumber(_total),
          icon: Icons.groups_outlined,
        ),
        if (_error != null) _ErrorCard(message: _error!, onRetry: _load),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(26),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (!_loading && _error == null && _customers.isEmpty)
          const _EmptyCard(text: 'مشتری‌ای با این فیلتر پیدا نشد.'),
        ..._customers.map(
          (customer) => Card(
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      CircleAvatar(child: Text(_initial(customer['fullName']))),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${customer['fullName'] ?? 'بدون نام'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${customer['phone'] ?? ''}',
                              textDirection: TextDirection.ltr,
                              textAlign: TextAlign.right,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'شهر: ${customer['city'] ?? 'ثبت نشده'}  ·  عضویت: ${_date(customer['createdAt'])}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    'آخرین خرید: ${_date(customer['lastPurchaseAt'])}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      customer['marketingOptIn'] == true
                          ? Icons.mark_email_read_outlined
                          : Icons.unsubscribe_outlined,
                      size: 19,
                    ),
                    title: Text(
                      customer['marketingOptIn'] == true
                          ? 'با رضایت دریافت پیامک'
                          : 'بدون رضایت پیامکی',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      customer['rubikaLinked'] == true
                          ? Icons.link_outlined
                          : Icons.link_off_outlined,
                      size: 19,
                    ),
                    title: Text(
                      customer['rubikaLinked'] == true &&
                              customer['rubikaMarketingOptIn'] == true
                          ? 'روبیکا متصل · رضایت فعال'
                          : customer['rubikaLinked'] == true
                          ? 'روبیکا متصل · بدون رضایت'
                          : 'روبیکا متصل نیست',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_total > 50)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed:
                    _page > 1
                        ? () {
                          setState(() => _page--);
                          _load();
                        }
                        : null,
                icon: const Icon(Icons.chevron_right),
              ),
              Text(
                'صفحهٔ ${persianNumber(_page)}',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              IconButton(
                onPressed:
                    _page * 50 < _total
                        ? () {
                          setState(() => _page++);
                          _load();
                        }
                        : null,
                icon: const Icon(Icons.chevron_left),
              ),
            ],
          ),
      ],
    ),
  );
}

class CouponManagementScreen extends ConsumerStatefulWidget {
  const CouponManagementScreen({super.key});
  @override
  ConsumerState<CouponManagementScreen> createState() =>
      _CouponManagementScreenState();
}

class _CouponManagementScreenState
    extends ConsumerState<CouponManagementScreen> {
  bool _loading = true;
  List<JsonMap> _coupons = const [];
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ref.read(adminApiProvider).coupons();
      if (mounted) setState(() => _coupons = data);
    } catch (error) {
      if (mounted) setState(() => _error = AdminApi.friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit([JsonMap? coupon]) async {
    final code = TextEditingController(text: '${coupon?['code'] ?? ''}');
    final value = TextEditingController(
      text: '${coupon?['discountValue'] ?? ''}',
    );
    final minimum = TextEditingController(
      text: '${coupon?['minOrderToman'] ?? '0'}',
    );
    final max = TextEditingController(
      text: '${coupon?['maxDiscountToman'] ?? ''}',
    );
    final usageLimit = TextEditingController(
      text: '${coupon?['usageLimit'] ?? ''}',
    );
    final customerLimit = TextEditingController(
      text: '${coupon?['perCustomerLimit'] ?? ''}',
    );
    final type = ValueNotifier<String>(
      coupon?['discountType'] == 'fixed' ? 'fixed' : 'percent',
    );
    final usage = ValueNotifier<bool>(coupon?['isActive'] != false);
    final firstOrderOnly = ValueNotifier<bool>(
      coupon?['firstOrderOnly'] == true,
    );
    final form = await showDialog<JsonMap>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(coupon == null ? 'کد تخفیف جدید' : 'ویرایش کد تخفیف'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: code,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'کد'),
                  ),
                  const SizedBox(height: 8),
                  ValueListenableBuilder(
                    valueListenable: type,
                    builder:
                        (_, selected, __) => DropdownButtonFormField<String>(
                          initialValue: selected,
                          decoration: const InputDecoration(
                            labelText: 'نوع تخفیف',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'percent',
                              child: Text('درصدی'),
                            ),
                            DropdownMenuItem(
                              value: 'fixed',
                              child: Text('مبلغ ثابت (تومان)'),
                            ),
                          ],
                          onChanged: (next) {
                            if (next != null) type.value = next;
                          },
                        ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: value,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'مقدار تخفیف'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: minimum,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'حداقل مبلغ سفارش (تومان)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: max,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'سقف تخفیف (اختیاری)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: usageLimit,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'سقف کل استفاده (اختیاری)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: customerLimit,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'سقف استفاده برای هر مشتری (اختیاری)',
                    ),
                  ),
                  ValueListenableBuilder(
                    valueListenable: firstOrderOnly,
                    builder:
                        (_, enabled, __) => SwitchListTile(
                          value: enabled,
                          title: const Text('فقط سفارش اول'),
                          onChanged: (next) => firstOrderOnly.value = next,
                        ),
                  ),
                  ValueListenableBuilder(
                    valueListenable: usage,
                    builder:
                        (_, active, __) => SwitchListTile(
                          value: active,
                          title: const Text('فعال'),
                          onChanged: (next) => usage.value = next,
                        ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('انصراف'),
              ),
              FilledButton(
                onPressed: () {
                  final parsedValue = num.tryParse(_digits(value.text));
                  final parsedMinimum = int.tryParse(_digits(minimum.text));
                  final parsedMax =
                      max.text.trim().isEmpty
                          ? null
                          : int.tryParse(_digits(max.text));
                  final parsedUsageLimit =
                      usageLimit.text.trim().isEmpty
                          ? null
                          : int.tryParse(_digits(usageLimit.text));
                  final parsedCustomerLimit =
                      customerLimit.text.trim().isEmpty
                          ? null
                          : int.tryParse(_digits(customerLimit.text));
                  if (code.text.trim().isEmpty ||
                      parsedValue == null ||
                      parsedMinimum == null ||
                      (max.text.trim().isNotEmpty && parsedMax == null) ||
                      (usageLimit.text.trim().isNotEmpty &&
                          parsedUsageLimit == null) ||
                      (customerLimit.text.trim().isNotEmpty &&
                          parsedCustomerLimit == null))
                    return;
                  Navigator.pop(dialogContext, {
                    'code': code.text.trim().toUpperCase(),
                    'discountType': type.value,
                    'discountValue': parsedValue,
                    'minOrderToman': parsedMinimum,
                    'maxDiscountToman': parsedMax,
                    'usageLimit': parsedUsageLimit,
                    'perCustomerLimit': parsedCustomerLimit,
                    'firstOrderOnly': firstOrderOnly.value,
                    'isActive': usage.value,
                  });
                },
                child: const Text('ذخیره'),
              ),
            ],
          ),
    );
    code.dispose();
    value.dispose();
    minimum.dispose();
    max.dispose();
    usageLimit.dispose();
    customerLimit.dispose();
    type.dispose();
    usage.dispose();
    firstOrderOnly.dispose();
    if (form == null || !mounted) return;
    try {
      await ref
          .read(adminApiProvider)
          .saveCoupon(form, id: coupon == null ? null : '${coupon['id']}');
      await _load();
      if (mounted) showAppMessage(context, 'کد تخفیف ذخیره شد.');
    } catch (error) {
      if (mounted)
        showAppMessage(context, AdminApi.friendlyError(error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _load,
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _PageIntro(
          icon: Icons.sell_outlined,
          title: 'کدهای تخفیف',
          subtitle: 'ساخت و فعال/غیرفعال‌کردن کدهای قابل استفاده در خرید',
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => _edit(),
          icon: const Icon(Icons.add),
          label: const Text('کد تخفیف جدید'),
        ),
        if (_error != null) _ErrorCard(message: _error!, onRetry: _load),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (!_loading && _coupons.isEmpty)
          const _EmptyCard(text: 'هنوز کد تخفیفی نساخته‌ای.'),
        ..._coupons.map(
          (coupon) => Card(
            child: ListTile(
              leading: CircleAvatar(
                child: Icon(
                  coupon['isActive'] == true
                      ? Icons.local_offer_outlined
                      : Icons.do_not_disturb_on_outlined,
                ),
              ),
              title: Text(
                '${coupon['code']}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text(
                '${coupon['discountType'] == 'percent' ? '${coupon['discountValue']}٪' : '${persianNumber(coupon['discountValue'] ?? 0)} تومان'} · حداقل ${persianNumber(coupon['minOrderToman'] ?? 0)} تومان\n${coupon['isActive'] == true ? 'فعال' : 'غیرفعال'}',
              ),
              isThreeLine: true,
              trailing: IconButton(
                tooltip: 'ویرایش',
                onPressed: () => _edit(coupon),
                icon: const Icon(Icons.edit_outlined),
              ),
              onTap: () => _edit(coupon),
            ),
          ),
        ),
      ],
    ),
  );
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
  String _channel = 'sms';
  String? _productId;
  List<JsonMap> _products = const [];
  List<JsonMap> _history = const [];
  int? _audienceCount;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refreshHistory();
    _loadProducts();
  }

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    _city.dispose();
    _query.dispose();
    super.dispose();
  }

  JsonMap get _filters => {
    'q': _query.text.trim(),
    'city': _city.text.trim(),
    'registration': _registration,
    'purchaseSort': _purchaseSort,
    if (_productId != null) 'productId': _productId,
  };

  Future<void> _loadProducts() async {
    try {
      final list = await ref.read(adminApiProvider).productOptions();
      if (mounted) setState(() => _products = list);
    } catch (_) {}
  }

  Future<void> _refreshHistory() async {
    try {
      final list = await ref
          .read(adminApiProvider)
          .marketingCampaigns(_channel);
      if (mounted) setState(() => _history = list);
    } catch (_) {}
  }

  Future<void> _preview() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(adminApiProvider)
          .previewCampaignAudience(_channel, _filters);
      if (mounted)
        setState(
          () => _audienceCount = (result['count'] as num?)?.toInt() ?? 0,
        );
    } catch (error) {
      if (mounted) setState(() => _error = AdminApi.friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    if (_title.text.trim().isEmpty || _message.text.trim().isEmpty) {
      showAppMessage(context, 'عنوان و متن پیام را وارد کن.', error: true);
      return;
    }
    if (_audienceCount == null) {
      await _preview();
      if (!mounted || _audienceCount == null) return;
    }
    if (_audienceCount == 0) {
      showAppMessage(
        context,
        _channel == 'rubika'
            ? 'مشتری متصل و دارای رضایت روبیکا با این فیلتر پیدا نشد.'
            : 'مشتری دارای رضایت پیامکی با این فیلتر پیدا نشد.',
        error: true,
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(
              _channel == 'rubika' ? 'ارسال پیام روبیکا' : 'ارسال پیامک',
            ),
            content: Text(
              _channel == 'rubika'
                  ? 'این پیام برای ' +
                      persianNumber(_audienceCount!) +
                      ' مشتری متصل و دارای رضایت روبیکا ارسال می‌شود. ادامه می‌دهی؟'
                  : 'این پیام برای ' +
                      persianNumber(_audienceCount!) +
                      ' مشتری دارای رضایت پیامکی ارسال می‌شود و هزینهٔ سرویس پیامک دارد. ادامه می‌دهی؟',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('بازبینی'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('ساخت و ارسال'),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final created = await ref
          .read(adminApiProvider)
          .createMarketingCampaign(
            _channel,
            _title.text.trim(),
            _message.text.trim(),
            _filters,
          );
      await ref
          .read(adminApiProvider)
          .sendMarketingCampaign(_channel, created['id'].toString());
      _title.clear();
      _message.clear();
      await _refreshHistory();
      if (mounted)
        showAppMessage(
          context,
          'درخواست ارسال ثبت شد. نتیجه در سابقهٔ کمپین نمایش داده می‌شود.',
        );
    } catch (error) {
      if (mounted) setState(() => _error = AdminApi.friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () async {
      await _preview();
      await _refreshHistory();
    },
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _PageIntro(
          icon: Icons.campaign_outlined,
          title: 'پیام‌رسانی به مشتریان',
          subtitle:
              'ارسال از پیامک یا ربات روبیکا با فیلتر و پیش‌نمایش مخاطبان',
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey(_channel),
          initialValue: _channel,
          decoration: const InputDecoration(labelText: 'روش ارسال'),
          items: const [
            DropdownMenuItem(value: 'sms', child: Text('پیامک از SMS.ir')),
            DropdownMenuItem(
              value: 'rubika',
              child: Text('پیام خصوصی ربات روبیکا'),
            ),
          ],
          onChanged: (value) {
            if (value == null || value == _channel) return;
            setState(() {
              _channel = value;
              _audienceCount = null;
              _error = null;
            });
            _refreshHistory();
          },
        ),
        TextField(
          controller: _title,
          maxLength: 160,
          decoration: const InputDecoration(labelText: 'عنوان کمپین'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _message,
          maxLength: 1000,
          minLines: 5,
          maxLines: 8,
          keyboardType: TextInputType.multiline,
          textAlignVertical: TextAlignVertical.top,
          decoration: InputDecoration(
            labelText: _channel == 'rubika' ? 'متن پیام روبیکا' : 'متن پیامک',
            alignLabelWithHint: true,
            hintText: 'متن پیام را بنویس…',
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'فیلتر مخاطبان',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _query,
          onChanged: (_) => setState(() => _audienceCount = null),
          decoration: const InputDecoration(labelText: 'جست‌وجوی نام یا شماره'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _city,
          onChanged: (_) => setState(() => _audienceCount = null),
          decoration: const InputDecoration(labelText: 'شهر'),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _registration,
          decoration: const InputDecoration(labelText: 'زمان ثبت‌نام'),
          items: const [
            DropdownMenuItem(value: 'any', child: Text('هر زمانی')),
            DropdownMenuItem(
              value: 'under_year',
              child: Text('کمتر از یک سال'),
            ),
            DropdownMenuItem(
              value: 'over_year',
              child: Text('بیشتر از یک سال'),
            ),
          ],
          onChanged:
              (value) => setState(() {
                _registration = value ?? 'any';
                _audienceCount = null;
              }),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _purchaseSort,
          decoration: const InputDecoration(labelText: 'ترتیب آخرین خرید'),
          items: const [
            DropdownMenuItem(value: 'none', child: Text('بدون ترتیب')),
            DropdownMenuItem(value: 'recent', child: Text('خرید جدیدتر')),
            DropdownMenuItem(value: 'oldest', child: Text('خرید قدیمی‌تر')),
          ],
          onChanged:
              (value) => setState(() {
                _purchaseSort = value ?? 'none';
                _audienceCount = null;
              }),
        ),
        if (_products.isNotEmpty) ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            initialValue: _productId,
            decoration: const InputDecoration(labelText: 'خریداران یک محصول'),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('همهٔ محصولات'),
              ),
              ..._products.map(
                (product) => DropdownMenuItem<String?>(
                  value: '${product['id']}',
                  child: Text(
                    '${product['name']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            onChanged:
                (value) => setState(() {
                  _productId = value;
                  _audienceCount = null;
                }),
          ),
        ],
        const SizedBox(height: 8),
        Card(
          child: SwitchListTile.adaptive(
            value: true,
            onChanged: null,
            title: Text(
              _channel == 'rubika'
                  ? 'فقط مشتریان متصل و دارای رضایت روبیکا'
                  : 'فقط مشتریان دارای رضایت پیامکی',
            ),
            subtitle: Text(
              _channel == 'rubika'
                  ? 'مشتری باید از حساب کاربری، ربات را به حسابش وصل کرده باشد.'
                  : 'این محدودیت هنگام ارسال نیز دوباره بررسی می‌شود.',
            ),
          ),
        ),
        FilledButton.tonalIcon(
          onPressed: _loading ? null : _preview,
          icon: const Icon(Icons.groups_outlined),
          label: Text(
            _audienceCount == null
                ? 'شمارش مخاطبان'
                : 'مخاطبان منطبق: ${persianNumber(_audienceCount!)}',
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _loading ? null : _send,
          icon: const Icon(Icons.send_outlined),
          label: Text(_loading ? 'در حال پردازش…' : 'ارسال کمپین'),
        ),
        if (_error != null) _ErrorCard(message: _error!, onRetry: _preview),
        const SizedBox(height: 22),
        Text(
          'سابقهٔ کمپین‌ها',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        if (_history.isEmpty)
          const _EmptyCard(text: 'هنوز کمپینی ثبت نشده است.'),
        ..._history.map(
          (item) => Card(
            child: ListTile(
              leading: Icon(
                _channel == 'rubika'
                    ? Icons.send_outlined
                    : Icons.mark_email_read_outlined,
              ),
              title: Text(
                '${item['title']}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${_statusLabel(item['status'])} · ${persianNumber(item['sentCount'] ?? 0)} ارسال از ${persianNumber(item['recipientCount'] ?? 0)}',
              ),
              isThreeLine: false,
              trailing: Text(
                _date(item['createdAt']),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class SocialPublishingScreen extends ConsumerStatefulWidget {
  const SocialPublishingScreen({super.key});
  @override
  ConsumerState<SocialPublishingScreen> createState() =>
      _SocialPublishingScreenState();
}

class _SocialPublishingScreenState
    extends ConsumerState<SocialPublishingScreen> {
  final _caption = TextEditingController();
  final _productTitle = TextEditingController();
  List<JsonMap> _products = const [];
  String? _productId;
  String? _imagePath;
  bool _rubika = true;
  bool _instagram = false;
  bool _schedule = false;
  DateTime? _publishAt;
  bool _loading = false;
  JsonMap _status = {};
  List<JsonMap> _posts = const [];
  final Set<String> _actingPostIds = {};
  String _postFilter = 'queue';
  String _channelFilter = 'rubika';
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _caption.dispose();
    _productTitle.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final status = await ref.read(adminApiProvider).socialStatus();
      final posts = await ref.read(adminApiProvider).socialPosts();
      final products = await ref.read(adminApiProvider).socialProducts();
      if (mounted)
        setState(() {
          _status = status;
          _posts = posts;
          _products = products;
          _error = null;
        });
    } catch (error) {
      if (mounted) setState(() => _error = AdminApi.friendlyError(error));
    }
  }

  List<JsonMap> get _visiblePosts {
    final channelPosts = _posts.where((post) {
      final channels = post['channels'];
      return _channelFilter == 'all' ||
          (channels is List && channels.contains(_channelFilter));
    });
    bool isQueue(JsonMap post) => const {
      'awaiting_approval',
      'queued',
      'publishing',
    }.contains(post['status']);
    if (_postFilter == 'queue') return channelPosts.where(isQueue).toList();
    if (_postFilter == 'history')
      return channelPosts.where((post) => !isQueue(post)).toList();
    return channelPosts.toList();
  }

  JsonMap? get _selectedProduct {
    if (_productId == null) return null;
    for (final product in _products) {
      if ('${product['id']}' == _productId) return product;
    }
    return null;
  }

  void _selectProduct(String? id) {
    JsonMap? selected;
    for (final product in _products) {
      if ('${product['id']}' == id) {
        selected = product;
        break;
      }
    }
    setState(() {
      _productId = id;
      _productTitle.text =
          selected == null
              ? ''
              : '${selected['title'] ?? selected['name'] ?? ''}';
    });
  }

  String _buildCaption(JsonMap? product, {required bool includeProduct}) {
    final message = _caption.text.trim();
    if (!includeProduct || product == null) return message;
    String joinValues(Object? value) {
      if (value is! List) return '—';
      final values =
          value
              .map((item) => '$item'.trim())
              .where((item) => item.isNotEmpty)
              .toList();
      return values.isEmpty ? '—' : values.join('، ');
    }

    final title =
        _productTitle.text.trim().isEmpty
            ? '${product['title'] ?? product['name'] ?? '—'}'
            : _productTitle.text.trim();
    return [
      if (message.isNotEmpty) message,
      if (message.isNotEmpty) '',
      'نام محصول: ${product['name'] ?? '—'}',
      'عنوان محصول: $title',
      'کد محصول: ${product['productCode'] ?? '—'}',
      'تنوع رنگی محصول: ${joinValues(product['colors'])}',
      'تنوع سایزی محصول: ${joinValues(product['sizes'])}',
      'لینک خرید محصول: ${product['purchaseUrl'] ?? '—'}',
    ].join('\n');
  }

  Future<void> _chooseTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _publishAt ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_publishAt ?? now),
    );
    if (time == null) return;
    setState(
      () =>
          _publishAt = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          ),
    );
  }

  Future<void> _publish() async {
    final product = _selectedProduct;
    final includeProduct = _rubika && product != null;
    final finalCaption = _buildCaption(product, includeProduct: includeProduct);
    if (finalCaption.isEmpty || (!_rubika && !_instagram)) {
      showAppMessage(
        context,
        'متن بنویس یا برای روبیکا یک محصول انتخاب کن و دست‌کم یک کانال را بزن.',
        error: true,
      );
      return;
    }
    if (finalCaption.length > 2200) {
      showAppMessage(
        context,
        'کپشن نهایی بیشتر از ۲۲۰۰ نویسه است؛ متن را کوتاه‌تر کن.',
        error: true,
      );
      return;
    }
    if (_instagram && (_imagePath == null || _imagePath!.isEmpty)) {
      showAppMessage(
        context,
        'برای انتشار در اینستاگرام تصویر انتخاب کن.',
        error: true,
      );
      return;
    }
    if (_schedule && _publishAt == null) {
      showAppMessage(
        context,
        'برای انتشار زمان‌بندی‌شده تاریخ و ساعت را انتخاب کن.',
        error: true,
      );
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final channels = [if (_rubika) 'rubika', if (_instagram) 'instagram'];
      await ref.read(adminApiProvider).createSocialPost({
        'caption': _caption.text.trim(),
        if (includeProduct) 'productId': _productId,
        if (includeProduct) 'productTitle': _productTitle.text.trim(),
        'imageUrl': _imagePath == null ? null : AdminApi.imageUrl(_imagePath!),
        'channels': channels,
        if (_schedule && _publishAt != null)
          'publishAt': _publishAt!.toUtc().toIso8601String(),
      });
      _caption.clear();
      setState(() {
        _imagePath = null;
        _productId = null;
        _productTitle.clear();
      });
      await _load();
      if (mounted)
        showAppMessage(
          context,
          _schedule
              ? 'پیام برای انتشار زمان‌بندی‌شده ثبت شد.'
              : 'پیام مستقیم در صف انتشار قرار گرفت.',
        );
    } catch (error) {
      if (mounted) setState(() => _error = AdminApi.friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _channelNames(Object? raw) {
    if (raw is! List) return 'کانال انتخاب‌شده';
    final names =
        raw
            .map(
              (channel) => switch ('$channel') {
                'rubika' => 'روبیکا',
                'instagram' => 'اینستاگرام',
                _ => '$channel',
              },
            )
            .toList();
    return names.isEmpty ? 'کانال انتخاب‌شده' : names.join(' و ');
  }

  String _socialDate(Object? raw) {
    if (raw is! String) return '—';
    final date = DateTime.tryParse(raw)?.toLocal();
    if (date == null) return '—';
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}  ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _actOnPost(JsonMap post, String action) async {
    final id = '${post['id'] ?? ''}';
    if (id.isEmpty) return;
    final scheduledAt =
        DateTime.tryParse('${post['publishAt'] ?? ''}')?.toLocal();
    final scheduled =
        scheduledAt != null && scheduledAt.isAfter(DateTime.now());
    final title = switch (action) {
      'approve' => 'تأیید انتشار',
      'send_now' => 'ارسال فوری',
      _ => 'لغو ارسال',
    };
    final message = switch (action) {
      'approve' =>
        scheduled
            ? 'پس از تأیید، پیام در زمان ${_socialDate(post['publishAt'])} به ${_channelNames(post['channels'])} ارسال می‌شود.'
            : 'با تأیید، پیام بلافاصله به ${_channelNames(post['channels'])} ارسال می‌شود.',
      'send_now' =>
        'این پیام تأییدشده اکنون به ${_channelNames(post['channels'])} ارسال می‌شود. ادامه می‌دهی؟',
      _ =>
        'پیام از صف خارج می‌شود و دیگر به کانال ارسال نخواهد شد. ادامه می‌دهی؟',
    };
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('بازگشت'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(action == 'cancel' ? 'لغو ارسال' : 'تأیید'),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _actingPostIds.add(id);
      _error = null;
    });
    try {
      final api = ref.read(adminApiProvider);
      if (action == 'approve') await api.approveSocialPost(id);
      if (action == 'send_now') await api.sendSocialPostNow(id);
      if (action == 'cancel') await api.cancelSocialPost(id);
      await _load();
      if (mounted)
        showAppMessage(context, switch (action) {
          'approve' =>
            scheduled
                ? 'پیام تأیید شد و در زمان تعیین‌شده ارسال می‌شود.'
                : 'پیام تأیید شد و به صف ارسال رفت.',
          'send_now' => 'درخواست ارسال فوری ثبت شد.',
          _ => 'ارسال پیام لغو شد.',
        });
    } catch (error) {
      if (mounted)
        showAppMessage(context, AdminApi.friendlyError(error), error: true);
      if (mounted) await _load();
    } finally {
      if (mounted) setState(() => _actingPostIds.remove(id));
    }
  }

  Widget _postCard(JsonMap post) {
    final id = '${post['id'] ?? ''}';
    final status = '${post['status'] ?? ''}';
    final busy = _actingPostIds.contains(id);
    final canApprove = status == 'awaiting_approval';
    final canSendNow = status == 'queued';
    final canCancel = canApprove || canSendNow;
    final publishAt = DateTime.tryParse('${post['publishAt'] ?? ''}');
    final scheduled = publishAt != null && publishAt.isAfter(DateTime.now());
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                child: Icon(
                  status == 'awaiting_approval'
                      ? Icons.mark_email_unread_outlined
                      : status == 'published'
                      ? Icons.check_circle_outline
                      : Icons.post_add_outlined,
                ),
              ),
              title: Text(
                '${post['caption'] ?? 'پیام بدون متن'}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                '#$id · ${_statusLabel(status)} · ${_channelNames(post['channels'])}\n${status == 'published' ? 'ارسال' : 'زمان انتشار'}: ${_socialDate(status == 'published' ? post['publishedAt'] : post['publishAt'])}',
              ),
              isThreeLine: true,
              trailing: const Icon(Icons.chevron_left),
              onTap:
                  () => showDialog<void>(
                    context: context,
                    builder:
                        (dialogContext) => AlertDialog(
                          title: Text('جزئیات پیام #$id'),
                          content: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('وضعیت: ${_statusLabel(status)}'),
                                Text(
                                  'کانال: ${_channelNames(post['channels'])}',
                                ),
                                Text(
                                  'زمان انتشار: ${_socialDate(post['publishAt'])}',
                                ),
                                if (post['publishedAt'] is String)
                                  Text(
                                    'ارسال‌شده در: ${_socialDate(post['publishedAt'])}',
                                  ),
                                const SizedBox(height: 10),
                                const Text(
                                  'متن پیام',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text('${post['caption'] ?? ''}'),
                                if (post['lastError'] is String &&
                                    '${post['lastError']}'.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Text(
                                    'خطا: ${post['lastError']}',
                                    style: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.error,
                                    ),
                                  ),
                                ],
                                if (post['channelResults'] != null) ...[
                                  const SizedBox(height: 10),
                                  const Text(
                                    'نتیجهٔ کانال‌ها',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text('${post['channelResults']}'),
                                ],
                              ],
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              child: const Text('بستن'),
                            ),
                          ],
                        ),
                  ),
            ),
            if (canApprove || canSendNow || canCancel) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  if (canApprove)
                    FilledButton.icon(
                      onPressed:
                          busy ? null : () => _actOnPost(post, 'approve'),
                      icon: const Icon(Icons.check_circle_outline),
                      label: Text(
                        scheduled ? 'تأیید زمان‌بندی' : 'تأیید و ارسال',
                      ),
                    ),
                  if (canSendNow)
                    FilledButton.tonalIcon(
                      onPressed:
                          busy ? null : () => _actOnPost(post, 'send_now'),
                      icon: const Icon(Icons.send_outlined),
                      label: const Text('ارسال اکنون'),
                    ),
                  if (canCancel)
                    OutlinedButton.icon(
                      onPressed: busy ? null : () => _actOnPost(post, 'cancel'),
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('لغو ارسال'),
                    ),
                  if (busy)
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rubika =
        _status['rubika'] is Map
            ? Map<String, dynamic>.from(_status['rubika'] as Map)
            : <String, dynamic>{};
    final instagram =
        _status['instagram'] is Map
            ? Map<String, dynamic>.from(_status['instagram'] as Map)
            : <String, dynamic>{};
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _PageIntro(
            icon: Icons.campaign_outlined,
            title: 'انتشار تبلیغات',
            subtitle: 'ارسال مستقیم پیام و مشاهدهٔ سوابق روبیکا و اینستاگرام',
          ),
          const SizedBox(height: 10),
          _IntegrationTile(
            title: 'ربات روبیکا',
            configured: rubika['configured'] == true,
            hint: 'توکن، شناسه و لینک عمومی کانال',
          ),
          _IntegrationTile(
            title: 'Instagram Graph API',
            configured: instagram['configured'] == true,
            hint: 'INSTAGRAM_USER_ID، token و Graph API version مجاز',
          ),
          const SizedBox(height: 8),
          Card(
            child: ExpansionTile(
              leading: const Icon(Icons.edit_note_outlined),
              title: const Text(
                'نوشتن پیام جدید',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text(
                'با ثبت، پیام مستقیم وارد صف انتشار می‌شود.',
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                DropdownButtonFormField<String?>(
                  initialValue: _productId,
                  decoration: const InputDecoration(
                    labelText: 'افزودن اطلاعات محصول به کپشن روبیکا (اختیاری)',
                    helperText:
                        'فقط محصولات منتشرشده؛ اطلاعات به ترتیب در پیش‌نمایش اضافه می‌شود.',
                  ),
                  items: <DropdownMenuItem<String?>>[
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('بدون انتخاب محصول'),
                    ),
                    ..._products.map(
                      (product) => DropdownMenuItem<String?>(
                        value: '${product['id']}',
                        child: Text(
                          '${product['name'] ?? 'محصول'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: _selectProduct,
                ),
                if (_productId != null) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _productTitle,
                    maxLength: 220,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'عنوان محصول در کپشن',
                      helperText:
                          'پیش‌فرض از عنوان سئو، توضیح کوتاه یا نام محصول پر شده است.',
                    ),
                  ),
                ],
                TextField(
                  controller: _caption,
                  maxLength: 2200,
                  minLines: 4,
                  maxLines: 7,
                  onChanged: (_) => setState(() {}),
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    labelText: 'متن اصلی کپشن (قبل از اطلاعات محصول)',
                    alignLabelWithHint: true,
                  ),
                ),
                if (_rubika && _selectedProduct != null) ...[
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'پیش‌نمایش کپشن روبیکا',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _buildCaption(
                              _selectedProduct,
                              includeProduct: true,
                            ),
                            textDirection: TextDirection.rtl,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                AdminImagePickerField(
                  label: 'تصویر تبلیغ',
                  imagePath: _imagePath,
                  aspectRatio: 4 / 5,
                  onChanged: (value) => setState(() => _imagePath = value),
                ),
                const SizedBox(height: 4),
                Text(
                  'برای اینستاگرام تصویر الزامی است؛ برای روبیکا اختیاری است و در صورت انتخاب، خود فایل تصویر ارسال می‌شود.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                CheckboxListTile(
                  value: _rubika,
                  onChanged:
                      (value) => setState(() => _rubika = value ?? false),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('ارسال به کانال روبیکا'),
                ),
                CheckboxListTile(
                  value: _instagram,
                  onChanged:
                      (value) => setState(() => _instagram = value ?? false),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('انتشار در Instagram'),
                ),
                SwitchListTile.adaptive(
                  value: _schedule,
                  onChanged: (value) => setState(() => _schedule = value),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('زمان‌بندی انتشار'),
                ),
                if (_schedule)
                  OutlinedButton.icon(
                    onPressed: _chooseTime,
                    icon: const Icon(Icons.schedule),
                    label: Text(
                      _publishAt == null
                          ? 'انتخاب تاریخ و ساعت'
                          : _publishAt!.toLocal().toString().substring(0, 16),
                    ),
                  ),
                FilledButton.icon(
                  onPressed: _loading ? null : _publish,
                  icon: const Icon(Icons.send_outlined),
                  label: Text(_loading ? 'در حال ثبت…' : 'ارسال مستقیم'),
                ),
                if (_error != null)
                  _ErrorCard(message: _error!, onRetry: _load),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  _channelFilter == 'rubika' ? 'صف انتشار روبیکا' : 'صف انتشار',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${persianNumber(_posts.where((post) => post['status'] == 'queued' && (_channelFilter == 'all' || (post['channels'] is List && (post['channels'] as List).contains(_channelFilter)))).length)} در صف انتشار',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _channelFilter,
            decoration: const InputDecoration(labelText: 'کانال انتشار'),
            items: const [
              DropdownMenuItem(value: 'rubika', child: Text('روبیکا')),
              DropdownMenuItem(value: 'instagram', child: Text('اینستاگرام')),
              DropdownMenuItem(value: 'all', child: Text('همهٔ کانال‌ها')),
            ],
            onChanged:
                (value) => setState(() => _channelFilter = value ?? 'rubika'),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'queue',
                label: Text('صف'),
                icon: Icon(Icons.pending_actions_outlined),
              ),
              ButtonSegment(
                value: 'history',
                label: Text('سوابق'),
                icon: Icon(Icons.history),
              ),
              ButtonSegment(
                value: 'all',
                label: Text('همه'),
                icon: Icon(Icons.list_alt),
              ),
            ],
            selected: {_postFilter},
            onSelectionChanged:
                (value) => setState(() => _postFilter = value.first),
          ),
          const SizedBox(height: 8),
          if (_posts.isEmpty)
            const _EmptyCard(text: 'هنوز پیامی برای انتشار ثبت نشده است.'),
          if (_posts.isNotEmpty && _visiblePosts.isEmpty)
            _EmptyCard(
              text:
                  _postFilter == 'queue'
                      ? 'صف انتشار خالی است.'
                      : 'در این بخش پیامی وجود ندارد.',
            ),
          ..._visiblePosts.map(_postCard),
        ],
      ),
    );
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
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final status = await ref.read(adminApiProvider).operationsStatus();
      final backups = await ref.read(adminApiProvider).backups();
      if (mounted)
        setState(() {
          _status = status;
          _backups = backups;
        });
    } catch (error) {
      if (mounted) setState(() => _error = AdminApi.friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _backup() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref.read(adminApiProvider).createBackup();
      await _load();
      if (mounted)
        showAppMessage(
          context,
          'نسخهٔ پشتیبان ${result['filename']} ساخته شد.',
        );
    } catch (error) {
      if (mounted) setState(() => _error = AdminApi.friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final volume =
        _status['backupVolume'] is Map
            ? Map<String, dynamic>.from(_status['backupVolume'] as Map)
            : <String, dynamic>{};
    final integrations =
        _status['integrations'] is Map
            ? Map<String, dynamic>.from(_status['integrations'] as Map)
            : <String, dynamic>{};
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _PageIntro(
            icon: Icons.dns_outlined,
            title: 'سرور و پشتیبان‌گیری',
            subtitle: 'سلامت API، دیتابیس، اتصال‌ها و نسخه‌های SQL',
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) _ErrorCard(message: _error!, onRetry: _load),
          _StatStrip(
            label: 'API',
            value: '${_status['api'] ?? '—'}',
            icon: Icons.cloud_done_outlined,
          ),
          _StatStrip(
            label: 'دیتابیس',
            value: '${_status['database'] ?? '—'}',
            icon: Icons.storage_outlined,
          ),
          _StatStrip(
            label: 'فضای پشتیبان',
            value:
                volume['available'] != true
                    ? 'در دسترس نیست'
                    : volume['persistentConfigured'] == true
                    ? 'پایدار · ${persianNumber(volume['backupCount'] ?? 0)} فایل'
                    : 'قابل‌نوشتن اما بدون volume پایدار',
            icon: Icons.sd_storage_outlined,
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'اتصال سرویس‌ها',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 9),
                  _statusLine('SMS.ir', integrations['smsIr'] == true),
                  _statusLine(
                    'پیام خصوصی بات روبیکا',
                    integrations['rubikaBotMessaging'] == true,
                  ),
                  _statusLine(
                    'وب‌هوک اتصال حساب روبیکا',
                    integrations['rubikaWebhook'] == true,
                  ),
                  _statusLine(
                    'انتشار در کانال روبیکا',
                    integrations['rubika'] == true,
                  ),
                  _statusLine('Instagram', integrations['instagram'] == true),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                'مسیر پشتیبان: ${volume['path'] ?? 'BACKUP_DIR'}\nبرای نگهداری پس از راه‌اندازی مجدد، volume پایدار /data باید به API متصل باشد و BACKUP_DIR روی /data/backups تنظیم شود. ابزار mysqldump باید داخل image نصب باشد.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          FilledButton.icon(
            onPressed: _loading ? null : _backup,
            icon: const Icon(Icons.backup_outlined),
            label: const Text('ساخت پشتیبان همین حالا'),
          ),
          const SizedBox(height: 18),
          Text(
            'نسخه‌های ذخیره‌شده',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          if (_backups.isEmpty)
            const _EmptyCard(
              text: 'هنوز فایل پشتیبانی در volume ثبت نشده است.',
            ),
          ..._backups.map(
            (backup) => Card(
              child: ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(
                  '${backup['filename']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${_date(backup['createdAt'])} · ${_size(backup['sizeBytes'])}',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageIntro extends StatelessWidget {
  const _PageIntro({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          CircleAvatar(radius: 24, child: Icon(icon)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _StatStrip extends StatelessWidget {
  const _StatStrip({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(label),
      trailing: Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
    ),
  );
}

class _IntegrationTile extends StatelessWidget {
  const _IntegrationTile({
    required this.title,
    required this.configured,
    required this.hint,
  });
  final String title;
  final bool configured;
  final String hint;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(
        configured ? Icons.check_circle_outline : Icons.error_outline,
        color:
            configured ? Colors.green : Theme.of(context).colorScheme.tertiary,
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(
        configured ? 'تنظیمات اتصال ثبت شده' : 'تنظیم در متغیرهای API: $hint',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ),
  );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    ),
  );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    child: ListTile(
      title: Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
      ),
      trailing: IconButton(onPressed: onRetry, icon: const Icon(Icons.refresh)),
    ),
  );
}

Widget _statusLine(String name, bool ready) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 3),
  child: Row(
    children: [
      Icon(
        ready ? Icons.check_circle : Icons.remove_circle_outline,
        size: 17,
        color: ready ? Colors.green : Colors.grey,
      ),
      const SizedBox(width: 8),
      Expanded(child: Text(name)),
      Text(ready ? 'آماده' : 'تنظیم نشده'),
    ],
  ),
);

String _date(Object? raw) {
  if (raw is! String) return 'ندارد';
  final date = DateTime.tryParse(raw);
  return date == null
      ? '—'
      : '${date.toLocal().year}/${date.toLocal().month.toString().padLeft(2, '0')}/${date.toLocal().day.toString().padLeft(2, '0')}';
}

String _initial(Object? raw) {
  final value = raw is String ? raw.trim() : '';
  return value.isEmpty ? 'م' : value.substring(0, 1);
}

String _statusLabel(Object? raw) => switch (raw) {
  'draft' => 'پیش‌نویس',
  'awaiting_approval' => 'در انتظار تأیید',
  'queued' => 'تأیید شده · در صف',
  'sending' || 'publishing' => 'در حال ارسال',
  'sent' || 'published' => 'ارسال‌شده',
  'partial' => 'ارسال ناقص',
  'failed' => 'ناموفق',
  'cancelled' => 'لغو شده',
  _ => '$raw',
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
