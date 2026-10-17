import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/admin_api.dart';
import '../../core/paniz_theme.dart';
import '../../core/providers.dart';
import '../../core/ui_helpers.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen>
    with WidgetsBindingObserver {
  JsonMap _preferences = {};
  List<JsonMap> _devices = [];
  bool _loading = true;
  bool _batteryOptimizationExempt = false;
  final Set<String> _saving = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshBatteryOptimization();
  }

  Future<void> _refreshBatteryOptimization() async {
    final exempt =
        await ref.read(adminApiProvider).hasBatteryOptimizationExemption();
    if (!mounted || exempt == _batteryOptimizationExempt) return;
    setState(() => _batteryOptimizationExempt = exempt);
  }

  Future<void> _load() async {
    try {
      final api = ref.read(adminApiProvider);
      final results = await Future.wait([
        api.notificationPreferences(),
        api.notificationDevices(),
      ]);
      final batteryOptimizationExempt =
          await api.hasBatteryOptimizationExemption();
      if (!mounted) return;
      setState(() {
        _preferences = results[0] as JsonMap;
        _devices = results[1] as List<JsonMap>;
        _batteryOptimizationExempt = batteryOptimizationExempt;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      showAppMessage(context, AdminApi.friendlyError(error), error: true);
    }
  }

  Future<void> _update(String key, bool value) async {
    if (_saving.contains(key)) return;
    setState(() => _saving.add(key));
    String? newlyRegisteredDevice;
    try {
      final api = ref.read(adminApiProvider);
      if (key == 'backgroundMonitoringEnabled' && value) {
        final allowed = await api.requestNotificationPermission();
        if (!allowed)
          throw const AdminApiException(
            'برای دریافت اعلان، اجازهٔ نمایش اعلان را در گوشی فعال کنید.',
          );
        final deviceId = await api.notificationDeviceId();
        newlyRegisteredDevice = deviceId;
        await api.registerNotificationDevice(deviceId);
        final updated = await api.updateNotificationPreferences({key: true});
        _preferences = updated;
        await api.startNotificationMonitoring(
          deviceId: deviceId,
          soundEnabled: _preferences['soundEnabled'] == true,
          vibrationEnabled: _preferences['vibrationEnabled'] != false,
        );
      } else if (key == 'backgroundMonitoringEnabled' && !value) {
        await api.updateNotificationPreferences({key: false});
        await api.stopNotificationMonitoring();
        final deviceId = await api.notificationDeviceId();
        await api.revokeNotificationDevice(deviceId);
        _preferences[key] = false;
      } else {
        _preferences = await api.updateNotificationPreferences({key: value});
        if (_preferences['backgroundMonitoringEnabled'] == true) {
          await api.startNotificationMonitoring(
            deviceId: await api.notificationDeviceId(),
            soundEnabled: _preferences['soundEnabled'] == true,
            vibrationEnabled: _preferences['vibrationEnabled'] != false,
          );
        }
      }
      await _load();
      if (mounted) showAppMessage(context, 'تنظیم اعلان‌ها ذخیره شد.');
      if (key == 'backgroundMonitoringEnabled' && value && mounted) {
        await _offerBatteryOptimizationExemption();
      }
    } catch (error) {
      if (key == 'backgroundMonitoringEnabled' && value) {
        final api = ref.read(adminApiProvider);
        await api.stopNotificationMonitoring();
        try {
          await api.updateNotificationPreferences({
            'backgroundMonitoringEnabled': false,
          });
          if (newlyRegisteredDevice != null)
            await api.revokeNotificationDevice(newlyRegisteredDevice);
          _preferences['backgroundMonitoringEnabled'] = false;
        } catch (_) {}
      }
      if (mounted)
        showAppMessage(context, AdminApi.friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _saving.remove(key));
    }
  }

  Future<void> _offerBatteryOptimizationExemption() async {
    final api = ref.read(adminApiProvider);
    if (await api.hasBatteryOptimizationExemption()) {
      if (mounted) setState(() => _batteryOptimizationExempt = true);
      return;
    }
    if (!mounted) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('اجازهٔ اجرای بدون محدودیت باتری'),
            content: const Text(
              'این اجازه کمک می‌کند اتصال اعلان‌های سفارش و پیام در پس‌زمینه فعال بماند. ممکن است مصرف باتری بیشتر شود. اندروید درخواست نهایی را نمایش می‌دهد و می‌توانید آن را نپذیرید.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('فعلاً نه'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('ادامه'),
              ),
            ],
          ),
    );
    if (accepted != true || !mounted) return;
    try {
      await api.requestBatteryOptimizationExemption();
    } catch (error) {
      if (mounted) {
        showAppMessage(context, AdminApi.friendlyError(error), error: true);
      }
    }
  }

  Future<void> _revokeDevice(JsonMap device) async {
    final id = '${device['deviceId'] ?? ''}';
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('لغو دسترسی دستگاه؟'),
            content: Text(
              'اتصال اعلان‌های «${device['deviceName'] ?? 'دستگاه'}» قطع می‌شود.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('لغو'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('تأیید'),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final api = ref.read(adminApiProvider);
      if (id == await api.notificationDeviceId()) {
        await api.stopNotificationMonitoring();
        await api.updateNotificationPreferences({
          'backgroundMonitoringEnabled': false,
        });
      }
      await api.revokeNotificationDevice(id);
      await _load();
      if (mounted) showAppMessage(context, 'دسترسی دستگاه لغو شد.');
    } catch (error) {
      if (mounted)
        showAppMessage(context, AdminApi.friendlyError(error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final monitoring = _preferences['backgroundMonitoringEnabled'] == true;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: context.paniz.primarySoft,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(
                          Icons.notifications_active_outlined,
                          color: context.paniz.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'اتصال مستقیم اعلان‌های پانیذ',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'WebSocket امن با سرور پانیذ؛ بدون Firebase/FCM',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'دریافت اعلان در پس‌زمینه',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      monitoring
                          ? 'اتصال مستقیم سرور فعال است؛ اعلان دائمی اتصال در گوشی نمایش داده می‌شود.'
                          : 'با روشن‌کردن، اتصال امن WebSocket به سرور پانیذ فعال می‌شود.',
                    ),
                    value: monitoring,
                    onChanged:
                        _saving.contains('backgroundMonitoringEnabled')
                            ? null
                            : (value) =>
                                _update('backgroundMonitoringEnabled', value),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'پیام‌ها از اتصال مستقیم WebSocket به سرور پانیذ می‌رسند و در صورت قطع موقت، دوباره از API همگام می‌شوند. اندروید یک اعلان دائمی نشان می‌دهد؛ محدودیت باتری گوشی ممکن است دریافت پس‌زمینه را به تأخیر بیندازد.',
                    style: TextStyle(
                      color: context.paniz.muted,
                      fontSize: 12,
                      height: 1.7,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _batteryOptimizationExempt
                            ? Icons.battery_charging_full_rounded
                            : Icons.battery_saver_outlined,
                        color: context.paniz.primary,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          _batteryOptimizationExempt
                              ? 'محدودیت باتری برداشته شده است'
                              : 'اجازهٔ فعالیت بدون محدودیت باتری',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _batteryOptimizationExempt
                        ? 'اندروید برنامه را از بهینه‌سازی باتری مستثنا کرده است.'
                        : 'برای فعال‌ماندن اتصال اعلان‌ها در پس‌زمینه، از اندروید اجازه بگیرید. این کار ممکن است مصرف باتری را افزایش دهد.',
                    style: TextStyle(
                      color: context.paniz.muted,
                      fontSize: 12,
                      height: 1.7,
                    ),
                  ),
                  if (!_batteryOptimizationExempt) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: OutlinedButton.icon(
                        onPressed: _offerBatteryOptimizationExemption,
                        icon: const Icon(Icons.battery_saver_outlined),
                        label: const Text('درخواست اجازه از اندروید'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _section('چه اعلان‌هایی دریافت شود'),
          _switch(
            'سفارش جدید',
            'newOrdersEnabled',
            Icons.shopping_bag_outlined,
          ),
          _switch('پرداخت‌ها', 'paymentsEnabled', Icons.payments_outlined),
          _switch(
            'پیام‌های مشتریان و روبیکا',
            'customerMessagesEnabled',
            Icons.forum_outlined,
          ),
          _switch(
            'پیام مدیران',
            'adminMessagesEnabled',
            Icons.chat_bubble_outline_rounded,
          ),
          _switch('موجودی کم', 'lowStockEnabled', Icons.inventory_2_outlined),
          _switch(
            'هشدارهای امنیتی',
            'securityAlertsEnabled',
            Icons.shield_outlined,
          ),
          _switch('هشدارهای سرویس', 'serverAlertsEnabled', Icons.dns_outlined),
          _switch(
            'بروزرسانی برنامه',
            'appUpdatesEnabled',
            Icons.system_update_outlined,
          ),
          const SizedBox(height: 14),
          _section('صدا و لرزش'),
          _switch('صدای اعلان', 'soundEnabled', Icons.volume_up_outlined),
          _switch('لرزش', 'vibrationEnabled', Icons.vibration_rounded),
          const SizedBox(height: 14),
          _section('دستگاه‌های ثبت‌شده'),
          if (_devices.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'هنوز دستگاهی ثبت نشده است.',
                  style: TextStyle(color: context.paniz.muted),
                ),
              ),
            )
          else
            for (final device in _devices.where(
              (item) => item['revokedAt'] == null,
            ))
              Card(
                child: ListTile(
                  leading: Icon(
                    Icons.phone_android_rounded,
                    color: context.paniz.primary,
                  ),
                  title: Text(
                    '${device['deviceName'] ?? 'دستگاه اندروید'}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    device['lastSeenAt'] == null
                        ? 'هنوز متصل نشده'
                        : 'آخرین اتصال: ${_formatTime('${device['lastSeenAt']}')}',
                  ),
                  trailing: IconButton(
                    tooltip: 'لغو دسترسی',
                    icon: Icon(
                      Icons.link_off_rounded,
                      color: context.paniz.error,
                    ),
                    onPressed: () => _revokeDevice(device),
                  ),
                ),
              ),
          const SizedBox(height: 12),
          Card(
            color: context.paniz.primarySoft.withValues(alpha: .45),
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'اطلاعات مشتری در متن اعلان صفحهٔ قفل نمایش داده نمی‌شود. برای دیدن جزئیات، صفحهٔ اعلان‌ها را داخل برنامه باز کنید.',
                style: TextStyle(fontSize: 12, height: 1.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(4, 8, 4, 7),
    child: Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
    ),
  );

  Widget _switch(String title, String key, IconData icon) => Card(
    child: SwitchListTile.adaptive(
      secondary: Icon(icon, color: context.paniz.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      value: _preferences[key] != false,
      onChanged: _saving.contains(key) ? null : (value) => _update(key, value),
    ),
  );

  String _formatTime(String value) {
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return '—';
    return '${persianNumber(date.year)}/${persianNumber(date.month.toString().padLeft(2, '0'))}/${persianNumber(date.day.toString().padLeft(2, '0'))} · ${persianNumber(date.hour.toString().padLeft(2, '0'))}:${persianNumber(date.minute.toString().padLeft(2, '0'))}';
  }
}
