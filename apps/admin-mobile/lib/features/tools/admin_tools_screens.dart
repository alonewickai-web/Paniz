import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'package:excel/excel.dart' as excel_lib show Excel;
import 'dart:convert';

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
  String? _city;
  List<String> _cities = const [];
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
    _loadCities();
    _load();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _loadCities() async {
    try {
      final cities = await ref.read(adminApiProvider).customerCities();
      if (mounted) setState(() => _cities = cities);
    } catch (_) {}
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
            city: _city,
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

  Future<void> _openCustomer(JsonMap customer) async {
    try {
      final details = await ref
          .read(adminApiProvider)
          .customerDetails('${customer['id']}');
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text('${details['fullName'] ?? 'مشتری'}'),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('شماره: ${details['phone'] ?? '—'}'),
                      if ('${details['email'] ?? ''}'.isNotEmpty)
                        Text('ایمیل: ${details['email']}'),
                      Text('عضویت: ${_date(details['createdAt'])}'),
                      Text(
                        'تعداد خرید: ${persianNumber(details['purchaseCount'] ?? 0)}',
                      ),
                      Text(
                        'جمع خریدها: ${toman(details['totalPurchaseToman'])}',
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed:
                                () => _showCustomerPurchases(context, details),
                            icon: const Icon(Icons.receipt_long_outlined),
                            label: Text(
                              'خریدها (${persianNumber(details['purchaseCount'] ?? 0)})',
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed:
                                () => _showCustomerTickets(context, details),
                            icon: const Icon(Icons.support_agent_outlined),
                            label: Text(
                              'تیکت‌ها (${persianNumber((details['tickets'] as List?)?.length ?? 0)})',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if ((details['addresses'] as List?)?.isNotEmpty ==
                          true) ...[
                        const Text(
                          'نشانی‌های ثبت‌شده',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        ...((details['addresses'] as List).whereType<Map>().map(
                          (address) => Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Text(
                              '${address['province'] ?? ''}، ${address['city'] ?? ''}، ${address['street'] ?? ''}، پلاک ${address['plaqueNumber'] ?? '—'}، واحد ${address['unit'] ?? '—'}',
                            ),
                          ),
                        )),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('بستن'),
                ),
              ],
            ),
      );
    } catch (error) {
      if (mounted)
        showAppMessage(context, AdminApi.friendlyError(error), error: true);
    }
  }

  Future<void> _showCustomerPurchases(
    BuildContext parent,
    JsonMap details,
  ) async {
    final purchases =
        (details['purchases'] as List? ?? const []).whereType<Map>().toList();
    await showDialog<void>(
      context: parent,
      builder:
          (context) => AlertDialog(
            title: const Text('خریدهای مشتری'),
            content: SizedBox(
              width: 460,
              child: ListView(
                shrinkWrap: true,
                children:
                    purchases.isEmpty
                        ? const [Text('خریدی ثبت نشده است.')]
                        : purchases
                            .map(
                              (order) => Card(
                                child: ListTile(
                                  title: Text(
                                    'سفارش ${order['orderNumber'] ?? ''}',
                                  ),
                                  subtitle: Text(
                                    '${_date(order['placedAt'])} · ${_statusLabel(order['status'])}\\n${(order['items'] as List? ?? const []).whereType<Map>().map((item) => '${item['productNameSnapshot']} × ${item['quantity']}').join('، ')}',
                                  ),
                                  isThreeLine: true,
                                  trailing: Text(toman(order['totalToman'])),
                                ),
                              ),
                            )
                            .toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('بستن'),
              ),
            ],
          ),
    );
  }

  Future<void> _showCustomerTickets(
    BuildContext parent,
    JsonMap details,
  ) async {
    final tickets =
        (details['tickets'] as List? ?? const []).whereType<Map>().toList();
    await showDialog<void>(
      context: parent,
      builder:
          (context) => AlertDialog(
            title: const Text('تیکت‌های مشتری'),
            content: SizedBox(
              width: 460,
              child: ListView(
                shrinkWrap: true,
                children:
                    tickets.isEmpty
                        ? const [Text('تیکتی ثبت نشده است.')]
                        : tickets
                            .map(
                              (ticket) => Card(
                                child: ListTile(
                                  title: Text(
                                    '${ticket['subject'] ?? 'بدون عنوان'}',
                                  ),
                                  subtitle: Text(
                                    '${_date(ticket['lastMessageAt'])} · ${ticket['status'] == 'closed' ? 'بسته‌شده' : 'باز'}',
                                  ),
                                  leading: const Icon(
                                    Icons.support_agent_outlined,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('بستن'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _load,
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String?>(
                initialValue: _city,
                isExpanded: true,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'شهر',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('همهٔ شهرها'),
                  ),
                  ..._cities.map(
                    (city) => DropdownMenuItem<String?>(
                      value: city,
                      child: Text(city, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _city = value),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _registration,
                isExpanded: true,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'زمان ثبت‌نام',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'any', child: Text('همه')),
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
                    (value) => setState(() => _registration = value ?? 'any'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _purchaseSort,
                isExpanded: true,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'میزان خرید',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'none',
                    child: Text('بدون مرتب‌سازی'),
                  ),
                  DropdownMenuItem(
                    value: 'highest',
                    child: Text('بیشترین خرید'),
                  ),
                  DropdownMenuItem(value: 'lowest', child: Text('کمترین خرید')),
                  DropdownMenuItem(value: 'never', child: Text('بدون خرید')),
                  DropdownMenuItem(value: 'recent', child: Text('خرید جدیدتر')),
                  DropdownMenuItem(
                    value: 'oldest',
                    child: Text('خرید قدیمی‌تر'),
                  ),
                ],
                onChanged:
                    (value) => setState(() => _purchaseSort = value ?? 'none'),
              ),
            ),
            if (_products.isNotEmpty) ...[
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String?>(
                  initialValue: _productId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'خرید محصول خاص',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                  ),
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
              ),
            ],
          ],
        ),
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
            margin: const EdgeInsets.only(bottom: 12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _openCustomer(customer),
              child: Padding(
                padding: const EdgeInsets.all(13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
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
                    const SizedBox(height: 4),
                    Text(
                      'تعداد خرید: ${persianNumber(customer['purchaseCount'] ?? 0)}  ·  جمع خرید: ${toman(customer['totalPurchaseToman'])}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
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
    final initialType =
        coupon?['discountType'] == 'fixed' ? 'fixed' : 'percent';
    final value = TextEditingController(
      text:
          initialType == 'fixed'
              ? groupedNumber(coupon?['discountValue'] ?? '')
              : '${coupon?['discountValue'] ?? ''}',
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
    final type = ValueNotifier<String>(initialType);
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
                            if (next != null) {
                              value.text =
                                  next == 'fixed'
                                      ? _formatGroupedValue(value.text)
                                      : _ungroupedDigits(value.text);
                              type.value = next;
                            }
                          },
                        ),
                  ),
                  const SizedBox(height: 8),
                  ValueListenableBuilder(
                    valueListenable: type,
                    builder:
                        (_, selected, __) => TextField(
                          controller: value,
                          keyboardType: TextInputType.number,
                          inputFormatters:
                              selected == 'fixed'
                                  ? const [_ThousandsSeparatorInputFormatter()]
                                  : const [],
                          decoration: InputDecoration(
                            labelText:
                                selected == 'fixed'
                                    ? 'مبلغ تخفیف (تومان)'
                                    : 'درصد تخفیف',
                          ),
                        ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: minimum,
                    keyboardType: TextInputType.number,
                    inputFormatters: const [
                      _ThousandsSeparatorInputFormatter(),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'حداقل مبلغ سفارش (تومان)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: max,
                    keyboardType: TextInputType.number,
                    inputFormatters: const [
                      _ThousandsSeparatorInputFormatter(),
                    ],
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
                  final parsedValue = num.tryParse(
                    _ungroupedDigits(value.text),
                  );
                  final parsedMinimum = int.tryParse(
                    _ungroupedDigits(minimum.text),
                  );
                  final parsedMax =
                      max.text.trim().isEmpty
                          ? null
                          : int.tryParse(_ungroupedDigits(max.text));
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
                '${coupon['discountType'] == 'percent' ? '${coupon['discountValue']}٪' : '${groupedNumber(coupon['discountValue'] ?? 0)} تومان'} · حداقل ${groupedNumber(coupon['minOrderToman'] ?? 0)} تومان\n${coupon['isActive'] == true ? 'فعال' : 'غیرفعال'}',
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

class ProductDiscountCampaignScreen extends ConsumerStatefulWidget {
  const ProductDiscountCampaignScreen({super.key});

  @override
  ConsumerState<ProductDiscountCampaignScreen> createState() =>
      _ProductDiscountCampaignScreenState();
}

class _ProductDiscountCampaignScreenState
    extends ConsumerState<ProductDiscountCampaignScreen> {
  final _amount = TextEditingController();
  final _search = TextEditingController();
  String _type = 'percent';
  bool _loading = true;
  bool _saving = false;
  List<JsonMap> _products = const [];
  final Set<String> _selectedIds = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amount.dispose();
    _search.dispose();
    super.dispose();
  }

  List<JsonMap> _variants(JsonMap product) =>
      (product['variants'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

  List<JsonMap> _discountedVariants(JsonMap product) =>
      _variants(product).where((variant) {
        final compare = int.tryParse('${variant['compareAtPriceToman'] ?? ''}');
        final price = int.tryParse('${variant['priceToman'] ?? ''}');
        return variant['isActive'] == true &&
            compare != null &&
            price != null &&
            compare > price;
      }).toList();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final products = await ref.read(adminApiProvider).products();
      if (!mounted) return;
      setState(() {
        _products = products;
        _selectedIds.removeWhere(
          (id) => !products.any((product) => '${product['id']}' == id),
        );
      });
    } catch (error) {
      if (mounted) setState(() => _error = AdminApi.friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<JsonMap> get _visibleProducts {
    final query = _search.text.trim().toLowerCase();
    return _products.where((product) {
      final hasVariants = _variants(
        product,
      ).any((variant) => variant['isActive'] == true);
      final matches =
          query.isEmpty ||
          '${product['name'] ?? ''}'.toLowerCase().contains(query) ||
          '${product['slug'] ?? ''}'.toLowerCase().contains(query);
      return hasVariants && matches && product['status'] == 'published';
    }).toList();
  }

  Future<void> _applyCampaign() async {
    final value = int.tryParse(_ungroupedDigits(_amount.text));
    if (_selectedIds.isEmpty) {
      showAppMessage(
        context,
        'ابتدا حداقل یک محصول را انتخاب کن.',
        error: true,
      );
      return;
    }
    if (value == null || value < 1 || (_type == 'percent' && value >= 100)) {
      showAppMessage(
        context,
        _type == 'percent'
            ? 'درصد تخفیف باید بین ۱ تا ۹۹ باشد.'
            : 'مبلغ تخفیف را به تومان وارد کن.',
        error: true,
      );
      return;
    }

    setState(() => _saving = true);
    var updated = 0;
    var failed = 0;
    final api = ref.read(adminApiProvider);
    for (final product in _products.where(
      (item) => _selectedIds.contains('${item['id']}'),
    )) {
      for (final variant in _variants(
        product,
      ).where((item) => item['isActive'] == true)) {
        final price = int.tryParse('${variant['priceToman'] ?? ''}');
        final compare = int.tryParse('${variant['compareAtPriceToman'] ?? ''}');
        final base =
            compare != null && compare > (price ?? 0) ? compare : price;
        if (base == null || base < 2) {
          failed++;
          continue;
        }
        final discount =
            _type == 'percent'
                ? (base * value) ~/ 100
                : (value < base - 1 ? value : base - 1);
        final salePrice = base - discount;
        if (salePrice < 1 || salePrice >= base) {
          failed++;
          continue;
        }
        try {
          await api.updateVariant('${variant['id']}', {
            'priceToman': '$salePrice',
            'compareAtPriceToman': '$base',
          });
          updated++;
        } catch (_) {
          failed++;
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      _selectedIds.clear();
    });
    await _load();
    if (!mounted) return;
    showAppMessage(
      context,
      failed == 0
          ? 'تخفیف روی ${persianNumber(updated)} تنوع اعمال شد.'
          : 'روی ${persianNumber(updated)} تنوع اعمال شد؛ ${persianNumber(failed)} مورد ذخیره نشد.',
      error: failed > 0,
    );
  }

  Future<void> _removeCampaign(JsonMap product) async {
    final variants = _discountedVariants(product);
    if (variants.isEmpty) return;
    setState(() => _saving = true);
    var updated = 0;
    var failed = 0;
    final api = ref.read(adminApiProvider);
    for (final variant in variants) {
      try {
        await api.updateVariant('${variant['id']}', {
          'priceToman': '${variant['compareAtPriceToman']}',
          'compareAtPriceToman': null,
        });
        updated++;
      } catch (_) {
        failed++;
      }
    }
    if (!mounted) return;
    setState(() => _saving = false);
    await _load();
    if (!mounted) return;
    showAppMessage(
      context,
      failed == 0
          ? 'تخفیف ${product['name']} برداشته شد.'
          : 'تخفیف ${persianNumber(updated)} تنوع برداشته شد؛ ${persianNumber(failed)} مورد باقی ماند.',
      error: failed > 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleProducts;
    final discounted =
        _products
            .where(
              (product) =>
                  product['status'] == 'published' &&
                  _discountedVariants(product).isNotEmpty,
            )
            .toList();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _PageIntro(
            icon: Icons.sell_outlined,
            title: 'کمپین تخفیف محصولات',
            subtitle:
                'تخفیف درصدی یا مبلغ ثابت را روی رنگ و سایزهای یک یا چند محصول اعمال کن؛ محصولات منتشرشده با قیمت جدید در سایت دیده می‌شوند.',
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'تنظیم تخفیف کمپین',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'percent',
                        label: Text('درصدی'),
                        icon: Icon(Icons.percent),
                      ),
                      ButtonSegment(
                        value: 'fixed',
                        label: Text('مبلغ ثابت'),
                        icon: Icon(Icons.payments_outlined),
                      ),
                    ],
                    selected: {_type},
                    onSelectionChanged:
                        _saving
                            ? null
                            : (selected) => setState(() {
                              _type = selected.first;
                              _amount.text =
                                  _type == 'fixed'
                                      ? _formatGroupedValue(_amount.text)
                                      : _ungroupedDigits(_amount.text);
                            }),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _amount,
                    keyboardType: TextInputType.number,
                    inputFormatters:
                        _type == 'fixed'
                            ? const [_ThousandsSeparatorInputFormatter()]
                            : const [],
                    decoration: InputDecoration(
                      labelText:
                          _type == 'percent'
                              ? 'درصد تخفیف'
                              : 'مبلغ تخفیف (تومان)',
                      suffixText: _type == 'percent' ? '٪' : 'تومان',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'جست‌وجو و انتخاب محصولات',
                    ),
                  ),
                  if (visible.isNotEmpty)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        onPressed:
                            _saving
                                ? null
                                : () => setState(() {
                                  final allSelected = visible.every(
                                    (item) =>
                                        _selectedIds.contains('${item['id']}'),
                                  );
                                  if (allSelected) {
                                    _selectedIds.removeAll(
                                      visible.map((item) => '${item['id']}'),
                                    );
                                  } else {
                                    _selectedIds.addAll(
                                      visible.map((item) => '${item['id']}'),
                                    );
                                  }
                                }),
                        icon: const Icon(Icons.select_all),
                        label: Text(
                          visible.every(
                                (item) =>
                                    _selectedIds.contains('${item['id']}'),
                              )
                              ? 'لغو انتخاب همه'
                              : 'انتخاب همهٔ نتایج',
                        ),
                      ),
                    ),
                  if (_error != null)
                    _ErrorCard(message: _error!, onRetry: _load),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (visible.isEmpty)
                    const _EmptyCard(text: 'محصولی برای انتخاب پیدا نشد.'),
                  ...visible.map((product) {
                    final id = '${product['id']}';
                    final active = _discountedVariants(product);
                    return CheckboxListTile(
                      value: _selectedIds.contains(id),
                      onChanged:
                          _saving
                              ? null
                              : (checked) => setState(() {
                                if (checked == true)
                                  _selectedIds.add(id);
                                else
                                  _selectedIds.remove(id);
                              }),
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${product['name'] ?? 'محصول'}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        active.isEmpty
                            ? '${persianNumber(_variants(product).where((item) => item['isActive'] == true).length)} رنگ و سایز فعال'
                            : '${persianNumber(active.length)} تنوع تخفیف‌دار · قیمت پایه ${groupedNumber(active.first['compareAtPriceToman'])} تومان',
                      ),
                      secondary: Icon(
                        active.isNotEmpty
                            ? Icons.local_offer_rounded
                            : Icons.checkroom_outlined,
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _saving || _loading ? null : _applyCampaign,
                    icon:
                        _saving
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.campaign_outlined),
                    label: Text(
                      _saving
                          ? 'در حال ثبت تغییرات…'
                          : 'اعمال روی ${persianNumber(_selectedIds.length)} محصول',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'تخفیف‌های فعال در سایت · ${persianNumber(discounted.length)} محصول',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          if (discounted.isEmpty && !_loading)
            const _EmptyCard(
              text: 'در حال حاضر محصول تخفیف‌داری در سایت نمایش داده نمی‌شود.',
            ),
          ...discounted.map((product) {
            final variants = _discountedVariants(product);
            return Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.sell_outlined)),
                title: Text(
                  '${product['name'] ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  '${persianNumber(variants.length)} رنگ و سایز · ${groupedNumber(variants.first['priceToman'])} تومان',
                ),
                trailing: TextButton(
                  onPressed: _saving ? null : () => _removeCampaign(product),
                  child: const Text('برداشتن تخفیف'),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
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
  int _purchaseThreshold = 10;
  List<String> _phoneNumbers = const [];
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
    'purchaseThreshold': _purchaseThreshold,
    if (_phoneNumbers.isNotEmpty) 'phoneNumbers': _phoneNumbers,
    if (_productId != null) 'productId': _productId,
  };

  Future<void> _loadProducts() async {
    try {
      final list = await ref.read(adminApiProvider).productOptions();
      if (mounted) setState(() => _products = list);
    } catch (_) {}
  }

  Future<void> _importContacts() async {
    try {
      const fileChannel = MethodChannel('paniz/admin-reports');
      final selected = await fileChannel.invokeMapMethod<String, Object?>(
        'selectContactFile',
      );
      if (selected == null) return;
      final fileName = '${selected['name'] ?? ''}';
      final bytes = selected['bytes'];
      if (bytes is! Uint8List) {
        throw const AdminApiException('خواندن فایل ممکن نشد.');
      }
      final rawValues = <String>[];
      if (fileName.toLowerCase().endsWith('.xlsx')) {
        final workbook = excel_lib.Excel.decodeBytes(bytes);
        for (final sheet in workbook.tables.values) {
          for (final row in sheet.rows) {
            for (final cell in row) {
              if (cell?.value != null) rawValues.add(cell!.value.toString());
            }
          }
        }
      } else {
        rawValues.add(utf8.decode(bytes, allowMalformed: true));
      }
      final found = <String>{};
      for (final value in rawValues) {
        for (final match in RegExp(
          r'(?:\+?98|0098|0)?[\s-]*9(?:[0-9۰-۹٠-٩][\s-]*){9}',
        ).allMatches(value)) {
          final digits = match
              .group(0)!
              .replaceAll(RegExp(r'[^0-9۰-۹٠-٩]'), '');
          final ascii = digits.replaceAllMapped(RegExp(r'[۰-۹٠-٩]'), (m) {
            final persian = '۰۱۲۳۴۵۶۷۸۹'.indexOf(m.group(0)!);
            final arabic = '٠١٢٣٤٥٦٧٨٩'.indexOf(m.group(0)!);
            return '${persian >= 0 ? persian : arabic}';
          });
          final local =
              ascii.startsWith('0098')
                  ? '0${ascii.substring(4)}'
                  : ascii.startsWith('98')
                  ? '0${ascii.substring(2)}'
                  : ascii.startsWith('9')
                  ? '0$ascii'
                  : ascii;
          if (RegExp(r'^09\d{9}$').hasMatch(local)) found.add(local);
        }
      }
      if (found.isEmpty)
        throw const AdminApiException(
          'در فایل شماره موبایل معتبر ایرانی پیدا نشد.',
        );
      if (!mounted) return;
      setState(() {
        _phoneNumbers = found.take(20000).toList();
        _audienceCount = null;
      });
      showAppMessage(
        context,
        '${persianNumber(_phoneNumbers.length)} شماره از فایل خوانده شد. هنگام ارسال فقط مخاطبانی استفاده می‌شوند که رضایت این کانال را ثبت کرده باشند.',
      );
    } catch (error) {
      if (mounted)
        showAppMessage(context, AdminApi.friendlyError(error), error: true);
    }
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
          decoration: const InputDecoration(labelText: 'عنوان'),
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
        OutlinedButton.icon(
          onPressed: _loading ? null : _importContacts,
          icon: const Icon(Icons.upload_file_outlined),
          label: Text(
            _phoneNumbers.isEmpty
                ? 'افزودن شماره از CSV یا Excel'
                : 'تغییر فایل شماره‌ها (${persianNumber(_phoneNumbers.length)})',
          ),
        ),
        if (_phoneNumbers.isNotEmpty)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed:
                  () => setState(() {
                    _phoneNumbers = const [];
                    _audienceCount = null;
                  }),
              icon: const Icon(Icons.close),
              label: const Text('پاک‌کردن شماره‌های فایل'),
            ),
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
            DropdownMenuItem(
              value: 'over_threshold',
              child: Text('میزان خرید بالاتر از تعداد'),
            ),
            DropdownMenuItem(
              value: 'under_threshold',
              child: Text('میزان خرید کمتر از تعداد'),
            ),
          ],
          onChanged:
              (value) => setState(() {
                _purchaseSort = value ?? 'none';
                _audienceCount = null;
              }),
        ),
        if (_purchaseSort == 'over_threshold' ||
            _purchaseSort == 'under_threshold') ...[
          const SizedBox(height: 8),
          TextFormField(
            key: ValueKey(_purchaseSort),
            initialValue: '$_purchaseThreshold',
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'تعداد سفارش برای مقایسه',
            ),
            onChanged: (value) {
              final parsed = int.tryParse(value);
              if (parsed != null && parsed > 0 && parsed <= 100000) {
                _purchaseThreshold = parsed;
                _audienceCount = null;
              }
            },
          ),
        ],
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
    final images =
        selected?['images'] is List
            ? (selected!['images'] as List).whereType<Map>().toList()
            : const <Map>[];
    setState(() {
      _productId = id;
      _imagePath = images.isEmpty ? null : '${images.first['imagePath']}';
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
    final today = Jalali.now();
    final date = await showPersianDatePicker(
      context: context,
      initialDate: Jalali.fromDateTime(_publishAt ?? now),
      firstDate: today,
      lastDate: today.add(years: 1),
      currentDate: today,
      locale: const Locale('fa', 'IR'),
      textDirection: TextDirection.rtl,
      helpText: 'تاریخ انتشار',
      cancelText: 'انصراف',
      confirmText: 'انتخاب',
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
            date.toDateTime().year,
            date.toDateTime().month,
            date.toDateTime().day,
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
    return '${shamsiDate(date)} · ${persianNumber(date.hour.toString().padLeft(2, '0'))}:${persianNumber(date.minute.toString().padLeft(2, '0'))}';
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
          _IntegrationTile(
            title: 'روبیکا',
            configured: rubika['configured'] == true,
            hint: _integrationReason(rubika),
            icon: Icons.send_rounded,
          ),
          const SizedBox(height: 8),
          _IntegrationTile(
            title: 'اینستاگرام',
            configured: instagram['configured'] == true,
            hint: _integrationReason(instagram),
            icon: Icons.camera_alt_outlined,
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
                  if (_selectedProduct?['images'] is List &&
                      (_selectedProduct!['images'] as List).isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        'عکس‌های همین محصول',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    const SizedBox(height: 7),
                    SizedBox(
                      height: 92,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children:
                            (_selectedProduct!['images'] as List)
                                .whereType<Map>()
                                .map((image) {
                                  final path = '${image['imagePath'] ?? ''}';
                                  final selected = path == _imagePath;
                                  return Padding(
                                    padding: const EdgeInsetsDirectional.only(
                                      end: 8,
                                    ),
                                    child: InkWell(
                                      onTap:
                                          () =>
                                              setState(() => _imagePath = path),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        width: 76,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color:
                                                selected
                                                    ? Theme.of(
                                                      context,
                                                    ).colorScheme.primary
                                                    : Theme.of(context)
                                                        .colorScheme
                                                        .outlineVariant,
                                            width: selected ? 2 : 1,
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            11,
                                          ),
                                          child: Image.network(
                                            AdminApi.imageUrl(path),
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (_, __, ___) => const Icon(
                                                  Icons.broken_image_outlined,
                                                ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                })
                                .toList(),
                      ),
                    ),
                  ],
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
                  if (_selectedProduct?['images'] is List &&
                      (_selectedProduct!['images'] as List).isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        'عکس‌های همین محصول',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    const SizedBox(height: 7),
                    SizedBox(
                      height: 92,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children:
                            (_selectedProduct!['images'] as List)
                                .whereType<Map>()
                                .map((image) {
                                  final path = '${image['imagePath'] ?? ''}';
                                  final selectedImage = path == _imagePath;
                                  return Padding(
                                    padding: const EdgeInsetsDirectional.only(
                                      end: 8,
                                    ),
                                    child: InkWell(
                                      onTap:
                                          () =>
                                              setState(() => _imagePath = path),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        width: 76,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color:
                                                selectedImage
                                                    ? Theme.of(
                                                      context,
                                                    ).colorScheme.primary
                                                    : Theme.of(context)
                                                        .colorScheme
                                                        .outlineVariant,
                                            width: selectedImage ? 2 : 1,
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            11,
                                          ),
                                          child: Image.network(
                                            AdminApi.imageUrl(path),
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (_, __, ___) => const Icon(
                                                  Icons.broken_image_outlined,
                                                ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                })
                                .toList(),
                      ),
                    ),
                  ],
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
                          : _socialDate(_publishAt!.toUtc().toIso8601String()),
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
    required this.icon,
  });
  final String title;
  final bool configured;
  final String hint;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor:
            configured
                ? Colors.green.withValues(alpha: .12)
                : Theme.of(context).colorScheme.errorContainer,
        child: Icon(
          icon,
          color:
              configured ? Colors.green : Theme.of(context).colorScheme.error,
        ),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(
        configured ? 'متصل' : 'قطع شده: $hint',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ),
  );
}

String _integrationReason(JsonMap status) {
  final missing = status['missing'];
  if (missing is! List || missing.isEmpty) return 'اتصال برقرار است';
  return 'تنظیمات ناقص است: ${missing.join('، ')}';
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
  return date == null ? '—' : shamsiDate(date.toLocal());
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

String _ungroupedDigits(String value) =>
    _digits(value).replaceAll(RegExp(r'[,٬\s]'), '');

String _formatGroupedValue(String value) {
  final parsed = int.tryParse(_ungroupedDigits(value));
  return parsed == null ? '' : groupedNumber(parsed);
}

class _ThousandsSeparatorInputFormatter extends TextInputFormatter {
  const _ThousandsSeparatorInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = _digits(newValue.text).replaceAll(RegExp(r'\D'), '');
    if (raw.isEmpty) {
      return newValue.copyWith(
        text: '',
        selection: const TextSelection.collapsed(offset: 0),
      );
    }
    final grouped = raw.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    final formatted = persianNumber(grouped);
    final oldOffset =
        newValue.selection.extentOffset.clamp(0, newValue.text.length).toInt();
    final digitCountBeforeCursor =
        _digits(
          newValue.text.substring(0, oldOffset),
        ).replaceAll(RegExp(r'\D'), '').length;
    var offset = 0;
    var digitsSeen = 0;
    while (offset < formatted.length && digitsSeen < digitCountBeforeCursor) {
      if (RegExp(r'[۰-۹]').hasMatch(formatted[offset])) digitsSeen++;
      offset++;
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}
