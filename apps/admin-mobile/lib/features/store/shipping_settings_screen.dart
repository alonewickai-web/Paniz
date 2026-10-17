import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/admin_api.dart';
import '../../core/providers.dart';
import '../../core/ui_helpers.dart';

class ShippingSettingsScreen extends ConsumerStatefulWidget {
  const ShippingSettingsScreen({super.key});

  @override
  ConsumerState<ShippingSettingsScreen> createState() =>
      _ShippingSettingsScreenState();
}

class _ShippingSettingsScreenState
    extends ConsumerState<ShippingSettingsScreen> {
  final _methodName = TextEditingController();
  final _description = TextEditingController();
  final _daysMin = TextEditingController();
  final _daysMax = TextEditingController();
  final _cost = TextEditingController();
  final _freeThreshold = TextEditingController();
  bool _initialized = false;
  bool _saving = false;
  bool _alwaysFree = false;
  bool _freeThresholdEnabled = false;

  @override
  void dispose() {
    _methodName.dispose();
    _description.dispose();
    _daysMin.dispose();
    _daysMax.dispose();
    _cost.dispose();
    _freeThreshold.dispose();
    super.dispose();
  }

  void _initialize(JsonMap data) {
    if (_initialized) return;
    final shipping =
        data['shipping'] is Map
            ? Map<String, dynamic>.from(data['shipping'] as Map)
            : <String, dynamic>{};
    _methodName.text = '${shipping['name'] ?? ''}';
    final description = '${shipping['description'] ?? ''}';
    _description.text =
        description == 'هزینهٔ ارسال سفارش بر اساس تنظیم فروشگاه'
            ? ''
            : description;
    _daysMin.text = '${shipping['estimatedDaysMin'] ?? ''}';
    _daysMax.text = '${shipping['estimatedDaysMax'] ?? ''}';
    _cost.text = _digits('${shipping['baseCostToman'] ?? 0}');
    _freeThreshold.text = _digits('${shipping['freeOverToman'] ?? ''}');
    _alwaysFree = shipping['baseCostToman'] == 0 && shipping['id'] != null;
    _freeThresholdEnabled = shipping['freeOverToman'] != null;
    _initialized = true;
  }

  Future<void> _refresh() async {
    _initialized = false;
    ref.invalidate(storeConfigurationProvider);
    await ref.read(storeConfigurationProvider.future);
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _methodName.text.trim();
    final cost = _digits(_cost.text);
    final threshold = _digits(_freeThreshold.text);
    final minDays = _digits(_daysMin.text);
    final maxDays = _digits(_daysMax.text);

    if (name.isEmpty) {
      showAppMessage(context, 'نام روش ارسال را وارد کن.', error: true);
      return;
    }
    if (!_alwaysFree && cost.isEmpty) {
      showAppMessage(context, 'هزینهٔ ارسال را وارد کن.', error: true);
      return;
    }
    if (minDays.isNotEmpty != maxDays.isNotEmpty) {
      showAppMessage(
        context,
        'حداقل و حداکثر زمان ارسال را با هم وارد کن.',
        error: true,
      );
      return;
    }
    if (minDays.isNotEmpty && int.parse(maxDays) < int.parse(minDays)) {
      showAppMessage(
        context,
        'حداکثر زمان ارسال نباید از حداقل آن کمتر باشد.',
        error: true,
      );
      return;
    }
    if (_freeThresholdEnabled && !_alwaysFree && threshold.isEmpty) {
      showAppMessage(
        context,
        'حد خرید برای ارسال رایگان را وارد کن.',
        error: true,
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(adminApiProvider).updateShippingSettings({
        'name': name,
        'description': _description.text.trim(),
        'estimatedDaysMin': minDays.isEmpty ? null : int.parse(minDays),
        'estimatedDaysMax': maxDays.isEmpty ? null : int.parse(maxDays),
        'baseCostToman': _alwaysFree ? '0' : cost,
        'alwaysFree': _alwaysFree,
        'freeShippingEnabled': _freeThresholdEnabled && !_alwaysFree,
        if (_freeThresholdEnabled && !_alwaysFree) 'freeOverToman': threshold,
      });
      _initialized = false;
      ref.invalidate(storeConfigurationProvider);
      if (mounted) showAppMessage(context, 'روش و هزینهٔ ارسال ذخیره شد');
    } catch (error) {
      if (mounted) {
        showAppMessage(context, AdminApi.friendlyError(error), error: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(storeConfigurationProvider);
    return config.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:
          (error, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 80),
              Text(AdminApi.friendlyError(error), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Center(
                child: OutlinedButton(
                  onPressed: () => ref.invalidate(storeConfigurationProvider),
                  child: const Text('تلاش دوباره'),
                ),
              ),
            ],
          ),
      data: (data) {
        _initialize(data);
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsetsDirectional.fromSTEB(16, 18, 16, 28),
            children: [
              PanizPageHeader(
                title: 'هزینه و روش ارسال',
                subtitle:
                    'اطلاعاتی که مشتری در سایت می‌بیند و در مبلغ سفارش اعمال می‌شود.',
                trailing: Icon(
                  Icons.local_shipping_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'روش فعال فروشگاه را اینجا مشخص کن. نام، توضیحات، هزینه و زمان تحویل در راهنمای ارسال سایت نمایش داده می‌شوند؛ هزینهٔ همین روش هم در سبد و تسویه‌حساب محاسبه می‌شود.',
                          style: TextStyle(height: 1.65),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              sectionTitle('روش ارسال'),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _methodName,
                        maxLength: 120,
                        decoration: const InputDecoration(
                          labelText: 'عنوان روش ارسال',
                          hintText: 'مثلاً ارسال پستی یا پیک',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _description,
                        minLines: 2,
                        maxLines: 4,
                        maxLength: 500,
                        decoration: const InputDecoration(
                          labelText: 'توضیحات روش ارسال برای سایت',
                          hintText: 'شرایط و جزئیات واقعی ارسال را بنویس',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _daysMin,
                              keyboardType: TextInputType.number,
                              textDirection: TextDirection.ltr,
                              decoration: const InputDecoration(
                                labelText: 'حداقل زمان (روز)',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _daysMax,
                              keyboardType: TextInputType.number,
                              textDirection: TextDirection.ltr,
                              decoration: const InputDecoration(
                                labelText: 'حداکثر زمان (روز)',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              sectionTitle('هزینهٔ ارسال'),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _cost,
                        enabled: !_alwaysFree,
                        keyboardType: TextInputType.number,
                        textDirection: TextDirection.ltr,
                        decoration: const InputDecoration(
                          labelText: 'هزینهٔ ارسال',
                          suffixText: 'تومان',
                          helperText: 'مبلغ با جداکنندهٔ سه‌رقمی وارد می‌شود.',
                        ),
                        onChanged: (value) => _formatController(_cost, value),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('ارسال همهٔ سفارش‌ها رایگان باشد'),
                        value: _alwaysFree,
                        onChanged:
                            (value) => setState(() => _alwaysFree = value),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('ارسال بالای یک مبلغ رایگان شود'),
                        value: _freeThresholdEnabled,
                        onChanged:
                            (value) =>
                                setState(() => _freeThresholdEnabled = value),
                      ),
                      if (_freeThresholdEnabled && !_alwaysFree) ...[
                        const SizedBox(height: 6),
                        TextField(
                          controller: _freeThreshold,
                          keyboardType: TextInputType.number,
                          textDirection: TextDirection.ltr,
                          decoration: const InputDecoration(
                            labelText: 'حداقل مبلغ سبد برای ارسال رایگان',
                            suffixText: 'تومان',
                          ),
                          onChanged:
                              (value) =>
                                  _formatController(_freeThreshold, value),
                        ),
                      ],
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon:
                            _saving
                                ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Icon(Icons.save_outlined),
                        label: Text(
                          _saving
                              ? 'در حال ذخیره…'
                              : 'ذخیرهٔ روش و هزینهٔ ارسال',
                        ),
                      ),
                    ],
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

void _formatController(TextEditingController controller, String value) {
  final formatted = _groupDigits(value);
  if (formatted == value) return;
  controller.value = TextEditingValue(
    text: formatted,
    selection: TextSelection.collapsed(offset: formatted.length),
  );
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
