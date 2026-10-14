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
    extends ConsumerState<NotificationSettingsScreen> {
  JsonMap _preferences = {};
  List<JsonMap> _devices = [];
  bool _loading = true;
  final Set<String> _saving = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = ref.read(adminApiProvider);
      final results = await Future.wait([
        api.notificationPreferences(),
        api.notificationDevices(),
      ]);
      if (!mounted) return;
      setState(() {
        _preferences = results[0] as JsonMap;
        _devices = results[1] as List<JsonMap>;
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
                              'اعلان‌های پانیذ',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'بدون سرویس Firebase',
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
                          ? 'مانیتورینگ روشن است؛ اعلان دائمی اتصال در گوشی نمایش داده می‌شود.'
                          : 'با روشن‌کردن، اتصال امن سرور در پس‌زمینه فعال می‌شود.',
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
                    'برای حفظ اتصال، اندروید یک اعلان دائمی نشان می‌دهد. قطع اینترنت، Force Stop، محدودیت باتری سازندهٔ گوشی یا منقضی‌شدن نشست می‌تواند دریافت فوری را متوقف کند؛ اعلان‌ها در سرور می‌مانند و پس از اتصال دوباره همگام می‌شوند.',
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
