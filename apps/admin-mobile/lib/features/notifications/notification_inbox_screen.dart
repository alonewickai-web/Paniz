import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/admin_api.dart';
import '../../core/paniz_theme.dart';
import '../../core/providers.dart';
import '../../core/ui_helpers.dart';

class NotificationInboxScreen extends ConsumerStatefulWidget {
  const NotificationInboxScreen({
    super.key,
    this.initialNotificationId,
    this.onNavigate,
  });
  final String? initialNotificationId;
  final void Function(JsonMap item)? onNavigate;

  @override
  ConsumerState<NotificationInboxScreen> createState() =>
      _NotificationInboxScreenState();
}

class _NotificationInboxScreenState
    extends ConsumerState<NotificationInboxScreen> {
  bool _initialNotificationOpened = false;

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(adminNotificationsProvider);
    return notifications.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:
          (error, _) => _LoadError(
            message: AdminApi.friendlyError(error),
            onRetry: () => ref.invalidate(adminNotificationsProvider),
          ),
      data: (result) {
        final rows =
            (result['data'] as List? ?? const [])
                .whereType<Map>()
                .map((row) => Map<String, dynamic>.from(row))
                .toList();
        JsonMap? target;
        final initial = widget.initialNotificationId;
        if (initial != null && !_initialNotificationOpened) {
          for (final row in rows) {
            if ('${row['id']}' == initial) {
              target = row;
              break;
            }
          }
        }
        final notificationToOpen = target;
        if (notificationToOpen != null && !_initialNotificationOpened) {
          _initialNotificationOpened = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              _openNotification(
                context,
                ref,
                notificationToOpen,
                widget.onNavigate,
              );
            }
          });
        }
        final unread =
            result['unreadCount'] is num
                ? (result['unreadCount'] as num).toInt()
                : 0;
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(adminNotificationsProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'اعلان‌های فروشگاه',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${persianNumber(unread)} اعلان خوانده‌نشده',
                              style: TextStyle(
                                color: context.paniz.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (unread > 0)
                        TextButton(
                          onPressed: () async {
                            try {
                              await ref
                                  .read(adminApiProvider)
                                  .markAllAdminNotificationsRead();
                              ref.invalidate(adminNotificationsProvider);
                            } catch (error) {
                              if (context.mounted)
                                showAppMessage(
                                  context,
                                  AdminApi.friendlyError(error),
                                  error: true,
                                );
                            }
                          },
                          child: const Text('خواندن همه'),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (rows.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 52,
                      horizontal: 24,
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.notifications_none_rounded,
                          size: 42,
                          color: context.paniz.muted,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'هنوز اعلانی دریافت نشده است.',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'سفارش‌ها و پیام‌های تازه در همین بخش نمایش داده می‌شوند.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: context.paniz.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                for (final item in rows)
                  _NotificationTile(
                    item: item,
                    onTap:
                        () => _openNotification(
                          context,
                          ref,
                          item,
                          widget.onNavigate,
                        ),
                  ),
            ],
          ),
        );
      },
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.item, required this.onTap});
  final JsonMap item;
  final VoidCallback onTap;

  IconData get _icon => switch ('${item['type']}') {
    'new_order' => Icons.receipt_long_outlined,
    'rubika_message' => Icons.forum_outlined,
    'customer_message' => Icons.mark_unread_chat_alt_outlined,
    'app_update' => Icons.system_update_alt_rounded,
    _ => Icons.notifications_none_rounded,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = item['readAt'] == null;
    final createdAt = DateTime.tryParse('${item['createdAt']}')?.toLocal();
    final time =
        createdAt == null
            ? ''
            : '${persianNumber(createdAt.year)}/${persianNumber(createdAt.month.toString().padLeft(2, '0'))}/${persianNumber(createdAt.day.toString().padLeft(2, '0'))} · ${persianNumber(createdAt.hour.toString().padLeft(2, '0'))}:${persianNumber(createdAt.minute.toString().padLeft(2, '0'))}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Card(
        color: unread ? context.paniz.primarySoft.withValues(alpha: .38) : null,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 8,
          ),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.paniz.primarySoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(_icon, color: context.paniz.primary),
          ),
          title: Text(
            '${item['title'] ?? 'اعلان تازه'}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: unread ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              '${item['body'] ?? ''}\n$time',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.paniz.muted,
                fontSize: 11,
                height: 1.65,
              ),
            ),
          ),
          isThreeLine: true,
          trailing:
              unread
                  ? Icon(Icons.circle, color: context.paniz.primary, size: 10)
                  : const Icon(Icons.chevron_left_rounded),
          onTap: onTap,
        ),
      ),
    );
  }
}

Future<void> _openNotification(
  BuildContext context,
  WidgetRef ref,
  JsonMap item,
  void Function(JsonMap item)? onNavigate,
) async {
  final id = '${item['id'] ?? ''}';
  if (item['readAt'] == null && id.isNotEmpty) {
    try {
      await ref.read(adminApiProvider).markAdminNotificationRead(id);
      ref.invalidate(adminNotificationsProvider);
    } catch (error) {
      if (context.mounted) {
        showAppMessage(context, AdminApi.friendlyError(error), error: true);
      }
    }
  }
  if (!context.mounted) return;
  final entityType = '${item['entityType'] ?? ''}';
  if (onNavigate != null &&
      (entityType.isNotEmpty ||
          '${item['type']}' == 'new_order' ||
          '${item['type']}' == 'admin_message')) {
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) => onNavigate(item));
    return;
  }
  final createdAt = DateTime.tryParse('${item['createdAt']}')?.toLocal();
  final time =
      createdAt == null
          ? ''
          : '${persianNumber(createdAt.year)}/${persianNumber(createdAt.month.toString().padLeft(2, '0'))}/${persianNumber(createdAt.day.toString().padLeft(2, '0'))} · ${persianNumber(createdAt.hour.toString().padLeft(2, '0'))}:${persianNumber(createdAt.minute.toString().padLeft(2, '0'))}';
  await showDialog<void>(
    context: context,
    builder:
        (dialogContext) => AlertDialog(
          title: Text('${item['title'] ?? 'اعلان تازه'}'),
          content: SingleChildScrollView(
            child: SelectableText(
              '${item['body'] ?? ''}\n\n$time',
              textDirection: TextDirection.rtl,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('بستن'),
            ),
          ],
        ),
  );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, color: context.paniz.error, size: 36),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 14),
          FilledButton(onPressed: onRetry, child: const Text('تلاش دوباره')),
        ],
      ),
    ),
  );
}
