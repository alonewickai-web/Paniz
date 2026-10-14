import 'dart:math' as math;
import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/admin_api.dart';
import '../../core/admin_avatar.dart';
import '../auth/profile_screen.dart';
import '../staff/staff_management_screen.dart';
import '../activity/audit_log_screen.dart';
import '../../core/paniz_theme.dart';
import '../../core/providers.dart';
import '../notifications/notification_inbox_screen.dart';
import '../notifications/notification_settings_screen.dart';
import '../chat/admin_chat_screen.dart';
import '../support/admin_support_screen.dart';
import '../updates/app_update_screen.dart';
import '../../core/theme_toggle.dart';
import '../../core/ui_helpers.dart';
import '../auth/security_settings_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../dashboard/statistics_screen.dart';
import '../dashboard/financial_report_screen.dart';
import '../dashboard/seo_analytics_screen.dart';
import '../inventory/inventory_screen.dart';
import '../orders/orders_screen.dart';
import '../products/products_screen.dart';
import '../store/store_management_screen.dart';
import '../tools/admin_tools_screens.dart';

class AdminHome extends ConsumerStatefulWidget {
  const AdminHome({super.key, required this.admin});
  final AdminIdentity admin;

  @override
  ConsumerState<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends ConsumerState<AdminHome> {
  static const _notificationChannel = MethodChannel(
    'paniz/admin-notifications',
  );
  int _index = 0;
  final List<int> _tabHistory = <int>[];
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _notificationChannel.setMethodCallHandler((call) async {
      if (call.method == 'notificationOpened') {
        _openNotification('${call.arguments ?? ''}');
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final id = await _notificationChannel.invokeMethod<String>(
          'takePendingNotification',
        );
        if (id != null && id.isNotEmpty) _openNotification(id);
      } on PlatformException {
        // The app can still show the full notification inbox from its menu.
      } on MissingPluginException {
        // The app can still show the full notification inbox from its menu.
      }
    });
  }

  @override
  void dispose() {
    _notificationChannel.setMethodCallHandler(null);
    super.dispose();
  }

  void _openNotification(String id) {
    if (!mounted) return;
    _pushTool(
      'اعلان‌ها',
      NotificationInboxScreen(
        initialNotificationId: id.isEmpty ? null : id,
        onNavigate: _navigateFromNotification,
      ),
    );
  }

  void _navigateFromNotification(JsonMap item) {
    if (!mounted) return;
    final type = '${item['type'] ?? ''}';
    final entity = '${item['entityType'] ?? ''}';
    if (type == 'new_order' || entity == 'order') {
      _selectTab(2);
    } else if (type == 'admin_message' || entity == 'admin_chat') {
      _pushTool('گفت‌وگوی مدیران', const AdminChatScreen());
    } else if (entity == 'product') {
      _selectTab(1);
    } else if (entity == 'support_ticket' || entity == 'ticket') {
      _pushTool('پشتیبانی', const AdminSupportScreen());
    } else if (entity == 'social_post' || entity == 'sms_campaign') {
      _pushTool('انتشار و پیام‌رسانی', const SocialPublishingScreen());
    } else {
      _pushTool('اعلان‌ها', const NotificationInboxScreen());
    }
  }

  static const _titles = ['خانه', 'محصولات', 'سفارش‌ها', 'گزارش‌ها'];
  static const _icons = [
    Icons.home_rounded,
    Icons.checkroom_rounded,
    Icons.receipt_long_rounded,
    Icons.bar_chart_rounded,
  ];

  Future<void> _logout() async {
    try {
      await ref.read(authProvider.notifier).logout();
    } catch (error) {
      if (mounted)
        showAppMessage(context, AdminApi.friendlyError(error), error: true);
    }
  }

  void _pushTool(String title, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) => Scaffold(
              appBar: AppBar(
                title: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                actions: const [PanizThemeToggle(), SizedBox(width: 4)],
              ),
              body: SafeArea(child: screen),
            ),
      ),
    );
  }

  void _pushToolFromDrawer(String title, Widget screen) {
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _pushTool(title, screen);
    });
  }

  void _selectTab(int index) {
    if (index == _index) return;
    setState(() {
      _tabHistory.add(_index);
      _index = index;
    });
  }

  Future<void> _handleBack() async {
    if (!mounted) return;
    final scaffold = _scaffoldKey.currentState;
    if (scaffold?.isDrawerOpen == true) {
      scaffold!.closeDrawer();
      return;
    }
    if (_tabHistory.isNotEmpty) {
      setState(() => _index = _tabHistory.removeLast());
      return;
    }
    if (_index != 0) {
      setState(() => _index = 0);
      return;
    }
    final shouldExit = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('خروج از برنامه'),
            content: const Text('می‌خواهید از برنامه خارج شوید؟'),
            actions: [
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: context.paniz.error,
                ),
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('لغو'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: context.paniz.success,
                ),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('تأیید'),
              ),
            ],
          ),
    );
    if (shouldExit == true) await SystemNavigator.pop();
  }

  int _newOrderCount(JsonMap data) {
    final counts = data['orderCounts'];
    if (counts is! Map) return 0;
    final paid = counts['paid'] is num ? (counts['paid'] as num).toInt() : 0;
    final confirmed =
        counts['confirmed'] is num ? (counts['confirmed'] as num).toInt() : 0;
    return paid + confirmed;
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = ref.watch(dashboardProvider);
    final newOrders = dashboard.maybeWhen(
      data: _newOrderCount,
      orElse: () => 0,
    );
    final notifications = ref.watch(adminNotificationsProvider);
    final unreadNotifications = notifications.maybeWhen(
      data:
          (value) =>
              value['unreadCount'] is num
                  ? (value['unreadCount'] as num).toInt()
                  : 0,
      orElse: () => 0,
    );
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        key: _scaffoldKey,
        drawer: _buildDrawer(),
        appBar: AppBar(
          leading: Builder(
            builder:
                (context) => IconButton(
                  tooltip: 'بازکردن منوی مدیریت',
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  icon: const Icon(Icons.menu_rounded),
                ),
          ),
          titleSpacing: 0,
          title: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/branding/paniz-logo.jpg',
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'PANIZ',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .8,
                      ),
                    ),
                    Text(
                      _titles[_index],
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: context.paniz.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            const PanizThemeToggle(),
            IconButton(
              tooltip: 'سفارش‌های نیازمند رسیدگی',
              onPressed:
                  () => _pushTool(
                    'اعلان‌ها',
                    NotificationInboxScreen(
                      onNavigate: _navigateFromNotification,
                    ),
                  ),
              icon: Badge(
                isLabelVisible:
                    unreadNotifications > 0 ||
                    (widget.admin.role != 'owner' && newOrders > 0),
                label: Text(
                  persianNumber(
                    unreadNotifications > 0
                        ? unreadNotifications
                        : (widget.admin.role != 'owner' ? newOrders : 0),
                  ),
                ),
                backgroundColor: context.paniz.error,
                child: const Icon(Icons.notifications_none_rounded),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 2, end: 12),
              child: PopupMenuButton<String>(
                tooltip: 'حساب مدیر',
                onSelected: (value) {
                  if (value == 'profile')
                    _pushTool('پروفایل من', ProfileScreen(admin: widget.admin));
                  if (value == 'security')
                    _pushTool(
                      'امنیت و ورود',
                      SecuritySettingsScreen(admin: widget.admin),
                    );
                  if (value == 'logout') _logout();
                },
                itemBuilder:
                    (context) => [
                      PopupMenuItem<String>(
                        enabled: false,
                        child: Text(widget.admin.fullName),
                      ),
                      PopupMenuItem<String>(
                        enabled: false,
                        child: Text(
                          '@${widget.admin.username}',
                          style: TextStyle(
                            color: context.paniz.muted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem<String>(
                        value: 'profile',
                        child: Row(
                          children: [
                            Icon(Icons.person_outline),
                            SizedBox(width: 10),
                            Text('پروفایل من'),
                          ],
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'security',
                        child: Row(
                          children: [
                            Icon(Icons.shield_outlined),
                            SizedBox(width: 10),
                            Text('امنیت و ورود'),
                          ],
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'logout',
                        child: Row(
                          children: [
                            Icon(Icons.logout_rounded),
                            SizedBox(width: 10),
                            Text('خروج از حساب'),
                          ],
                        ),
                      ),
                    ],
                child: AdminAvatar(
                  name: widget.admin.fullName,
                  path: widget.admin.avatarPath,
                  size: 36,
                ),
              ),
            ),
          ],
        ),
        body: IndexedStack(
          index: _index,
          children: [
            DashboardScreen(
              onProducts:
                  widget.admin.can('products.view')
                      ? () => _selectTab(1)
                      : null,
              onOrders:
                  widget.admin.can('orders.view') ? () => _selectTab(2) : null,
              onInventory:
                  widget.admin.can('products.view')
                      ? () =>
                          _pushTool('انبار و موجودی', const InventoryScreen())
                      : null,
              onActivity:
                  widget.admin.can('staff.activity')
                      ? () =>
                          _pushTool('گزارش فعالیت‌ها', const AuditLogScreen())
                      : null,
              onCustomers:
                  widget.admin.can('customers.view')
                      ? () => _pushTool(
                        'مدیریت مشتریان',
                        const CustomerManagementScreen(),
                      )
                      : null,
            ),
            widget.admin.can('products.view')
                ? const ProductsScreen()
                : _restrictedTab('محصولات'),
            widget.admin.can('orders.view')
                ? const OrdersScreen()
                : _restrictedTab('سفارش‌ها'),
            widget.admin.can('reports.view')
                ? const StatisticsScreen()
                : _restrictedTab('گزارش‌ها'),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _selectTab,
          animationDuration: const Duration(milliseconds: 240),
          destinations: List.generate(
            _titles.length,
            (index) => NavigationDestination(
              icon:
                  index == 2 && newOrders > 0
                      ? Badge(
                        smallSize: 7,
                        backgroundColor: context.paniz.error,
                        child: Icon(_icons[index]),
                      )
                      : Icon(_icons[index]),
              selectedIcon: Icon(_icons[index]),
              label: _titles[index],
              tooltip: _titles[index],
            ),
          ),
        ),
      ),
    );
  }

  Widget _restrictedTab(String title) => Center(
    child: PanizEmptyState(
      icon: Icons.lock_outline,
      title: 'دسترسی به $title فعال نیست',
      description: 'برای فعال‌شدن این بخش با مدیر فروشگاه هماهنگ کنید.',
    ),
  );

  Widget _buildDrawer() => Drawer(
    width: math.min(360.0, MediaQuery.sizeOf(context).width * .9),
    child: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(18, 12, 14, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'مرکز مدیریت',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'ابزارهای فروشگاه PANIZ',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.paniz.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'بستن منو',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(14, 4, 14, 12),
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: context.paniz.primarySoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  AdminAvatar(
                    name: widget.admin.fullName,
                    path: widget.admin.avatarPath,
                    size: 44,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.admin.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          '@${widget.admin.username}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: context.paniz.muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'امنیت حساب',
                    onPressed:
                        () => _pushToolFromDrawer(
                          'امنیت و ورود',
                          SecuritySettingsScreen(admin: widget.admin),
                        ),
                    icon: const Icon(Icons.settings_outlined),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _drawerHeading('مدیریت فروشگاه'),
                _drawerTile(
                  'انبار و موجودی',
                  Icons.inventory_2_outlined,
                  permission: 'products.view',
                  detail: 'اصلاح و بررسی تنوع‌ها',
                  onTap:
                      () => _pushToolFromDrawer(
                        'مدیریت انبار',
                        const InventoryScreen(),
                      ),
                ),
                _drawerTile(
                  'ظاهر و چیدمان سایت',
                  Icons.palette_outlined,
                  permission: 'store.content',
                  detail: 'رنگ، دسته‌بندی و بنرها',
                  onTap:
                      () => _pushToolFromDrawer(
                        'تنظیمات فروشگاه',
                        const StoreManagementScreen(),
                      ),
                ),
                _drawerTile(
                  'هزینه و روش ارسال',
                  Icons.local_shipping_outlined,
                  permission: 'store.content',
                  detail: 'هزینهٔ پست و حد ارسال رایگان',
                  onTap:
                      () => _pushToolFromDrawer(
                        'هزینه و روش ارسال',
                        const StoreManagementScreen(initialTab: 5),
                      ),
                ),
                _drawerTile(
                  'مشتریان',
                  Icons.people_outline_rounded,
                  permission: 'customers.view',
                  onTap:
                      () => _pushToolFromDrawer(
                        'مدیریت مشتریان',
                        const CustomerManagementScreen(),
                      ),
                ),
                _drawerTile(
                  'کدهای تخفیف',
                  Icons.sell_outlined,
                  permission: 'store.content',
                  onTap:
                      () => _pushToolFromDrawer(
                        'کدهای تخفیف',
                        const CouponManagementScreen(),
                      ),
                ),
                _drawerHeading('بازاریابی و تبلیغات'),
                _drawerTile(
                  'کمپین تخفیف محصولات',
                  Icons.local_offer_outlined,
                  permission: 'products.change_price',
                  detail: 'تخفیف درصدی یا مبلغی برای چند محصول',
                  onTap:
                      () => _pushToolFromDrawer(
                        'کمپین تخفیف محصولات',
                        const ProductDiscountCampaignScreen(),
                      ),
                ),
                _drawerTile(
                  'تبلیغات و روبیکا',
                  Icons.campaign_outlined,
                  permission: 'marketing.rubika.view',
                  onTap:
                      () => _pushToolFromDrawer(
                        'انتشار تبلیغات',
                        const SocialPublishingScreen(),
                      ),
                ),
                _drawerTile(
                  'پیام‌رسانی به مشتریان',
                  Icons.campaign_outlined,
                  permission: 'marketing.sms.send',
                  onTap:
                      () => _pushToolFromDrawer(
                        'پیام‌رسانی به مشتریان',
                        const SmsCampaignScreen(),
                      ),
                ),
                _drawerHeading('مدیریت و کارکنان'),
                _drawerTile(
                  'کارکنان و دسترسی‌ها',
                  Icons.manage_accounts_outlined,
                  permission: 'staff.manage',
                  onTap:
                      () => _pushToolFromDrawer(
                        'کارکنان و دسترسی‌ها',
                        const StaffManagementScreen(),
                      ),
                ),
                _drawerTile(
                  'گزارش فعالیت‌ها',
                  Icons.history_outlined,
                  permission: 'staff.activity',
                  onTap:
                      () => _pushToolFromDrawer(
                        'گزارش فعالیت‌ها',
                        const AuditLogScreen(),
                      ),
                ),
                _drawerTile(
                  'گزارش مالی',
                  Icons.account_balance_wallet_outlined,
                  permission: 'reports.financial',
                  detail: 'فروش، بهای خرید و سود به ریال',
                  onTap:
                      () => _pushToolFromDrawer(
                        'گزارش مالی',
                        const FinancialReportScreen(),
                      ),
                ),
                _drawerTile(
                  'سئو و تحلیل بازدید',
                  Icons.query_stats_rounded,
                  permission: 'reports.view',
                  detail: 'عملکرد گوگل، بازدید و محصولات',
                  onTap:
                      () => _pushToolFromDrawer(
                        'سئو و تحلیل بازدید',
                        SeoAnalyticsScreen(admin: widget.admin),
                      ),
                ),
                _drawerTile(
                  'گفت‌وگوی مدیران',
                  Icons.forum_outlined,
                  detail: 'پیام مستقیم و اعلان گروهی',
                  onTap:
                      () => _pushToolFromDrawer(
                        'گفت‌وگوی مدیران',
                        const AdminChatScreen(),
                      ),
                ),
                _drawerTile(
                  'پشتیبانی و مرجوعی',
                  Icons.support_agent_rounded,
                  permission: 'customers.view',
                  detail: 'پاسخ به مشتری و رسید بازپرداخت',
                  onTap:
                      () => _pushToolFromDrawer(
                        'پشتیبانی مشتریان',
                        const AdminSupportScreen(),
                      ),
                ),
                _drawerHeading('حساب و ظاهر برنامه'),
                _drawerTile(
                  'اعلان‌ها و دستگاه‌ها',
                  Icons.notifications_active_outlined,
                  detail: 'مدیریت اعلان و اتصال پس‌زمینه',
                  onTap:
                      () => _pushToolFromDrawer(
                        'اعلان‌ها و دستگاه‌ها',
                        const NotificationSettingsScreen(),
                      ),
                ),
                _drawerTile(
                  'پروفایل من',
                  Icons.person_outline,
                  onTap:
                      () => _pushToolFromDrawer(
                        'پروفایل من',
                        ProfileScreen(admin: widget.admin),
                      ),
                ),
                _drawerTile(
                  'امنیت و ورود',
                  Icons.shield_outlined,
                  detail: 'اطلاعات ورود مدیر',
                  onTap:
                      () => _pushToolFromDrawer(
                        'امنیت و ورود',
                        SecuritySettingsScreen(admin: widget.admin),
                      ),
                ),
                _drawerTile(
                  'سرور و پایگاه داده',
                  Icons.dns_outlined,
                  permission: 'system.monitor',
                  onTap:
                      () => _pushToolFromDrawer(
                        'سرور و پشتیبان‌گیری',
                        const OperationsScreen(),
                      ),
                ),

                _drawerTile(
                  'بروزرسانی',
                  Icons.system_update_outlined,
                  detail: 'بررسی و انتشار نسخهٔ برنامه',
                  onTap:
                      () => _pushToolFromDrawer(
                        'بروزرسانی',
                        const AppUpdateScreen(),
                      ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            minVerticalPadding: 8,
            leading: Icon(Icons.logout_rounded, color: context.paniz.error),
            title: Text(
              'خروج از حساب',
              style: TextStyle(
                color: context.paniz.error,
                fontWeight: FontWeight.w800,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              _logout();
            },
          ),
        ],
      ),
    ),
  );

  Widget _drawerHeading(String title) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(18, 12, 18, 4),
    child: Align(
      alignment: AlignmentDirectional.centerStart,
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: context.paniz.muted,
          fontWeight: FontWeight.w900,
        ),
      ),
    ),
  );

  Widget _drawerTile(
    String title,
    IconData icon, {
    required VoidCallback onTap,
    String? detail,
    String? permission,
  }) =>
      permission != null && !widget.admin.can(permission)
          ? const SizedBox.shrink()
          : ListTile(
            minLeadingWidth: 28,
            leading: Icon(icon, color: context.paniz.primary, size: 21),
            title: Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            subtitle:
                detail == null
                    ? null
                    : Text(
                      detail,
                      style: TextStyle(
                        color: context.paniz.muted,
                        fontSize: 11,
                      ),
                    ),
            trailing: const Icon(Icons.chevron_left_rounded, size: 19),
            onTap: onTap,
          );
}

class MoreToolsScreen extends StatelessWidget {
  const MoreToolsScreen({
    super.key,
    required this.admin,
    required this.onProfile,
    required this.onStaff,
    required this.onActivity,
    required this.onUpdate,
    required this.onInventory,
    required this.onStore,
    required this.onSecurity,
    required this.onCustomers,
    required this.onCoupons,
    required this.onSocial,
    required this.onSms,
    required this.onOperations,
    required this.onLogout,
  });
  final AdminIdentity admin;
  final VoidCallback onProfile;
  final VoidCallback onStaff;
  final VoidCallback onActivity;
  final VoidCallback onUpdate;
  final VoidCallback onInventory;
  final VoidCallback onStore;
  final VoidCallback onSecurity;
  final VoidCallback onCustomers;
  final VoidCallback onCoupons;
  final VoidCallback onSocial;
  final VoidCallback onSms;
  final VoidCallback onOperations;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 26),
    children: [
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PanizPageHeader(
              title: 'بیشتر',
              subtitle: 'تنظیمات و ابزارهای مدیریت فروشگاه',
            ),
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: AdminAvatar(
                  name: admin.fullName,
                  path: admin.avatarPath,
                  size: 48,
                ),
                title: Text(
                  admin.fullName,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(
                  '@${admin.username} · مدیر فروشگاه',
                  style: TextStyle(color: context.paniz.muted, fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_left_rounded),
                onTap: onProfile,
              ),
            ),
            const SizedBox(height: 22),
            sectionTitle('ابزارهای مدیریتی'),
            const SizedBox(height: 10),
            if (admin.can('products.view'))
              _ToolTile(
                icon: Icons.inventory_2_outlined,
                tint: context.paniz.peach,
                title: 'انبار و موجودی',
                detail: 'بررسی سایزها و اصلاح تعداد کالا',
                onTap: onInventory,
              ),
            if (admin.can('store.content'))
              _ToolTile(
                icon: Icons.palette_outlined,
                tint: context.paniz.lilac,
                title: 'ظاهر سایت',
                detail: 'رنگ‌بندی، دسته‌ها، بنر و چیدمان',
                onTap: onStore,
              ),
            _ToolTile(
              icon: Icons.shield_outlined,
              tint: context.paniz.mint,
              title: 'امنیت و ورود',
              detail: 'تغییر نام کاربری و گذرواژه',
              onTap: onSecurity,
            ),
            const SizedBox(height: 20),
            sectionTitle('بازاریابی و ارتباط با مشتریان'),
            const SizedBox(height: 10),
            if (admin.can('customers.view'))
              _ToolTile(
                icon: Icons.people_outline_rounded,
                tint: context.paniz.mint,
                title: 'مدیریت مشتریان',
                detail: 'جست‌وجو، فیلتر خرید و رضایت پیامک',
                onTap: onCustomers,
              ),
            if (admin.can('store.content'))
              _ToolTile(
                icon: Icons.sell_outlined,
                tint: context.paniz.peach,
                title: 'کدهای تخفیف',
                detail: 'ساخت و کنترل کدهای خرید',
                onTap: onCoupons,
              ),
            if (admin.can('marketing.rubika.view'))
              _ToolTile(
                icon: Icons.campaign_outlined,
                tint: context.paniz.lilac,
                title: 'انتشار تبلیغات',
                detail: 'روبیکا و Instagram',
                onTap: onSocial,
              ),
            if (admin.can('marketing.sms.send'))
              _ToolTile(
                icon: Icons.campaign_outlined,
                tint: context.paniz.coral,
                title: 'پیام‌رسانی به مشتریان',
                detail: 'پیامک یا ربات روبیکا با فیلتر مخاطب',
                onTap: onSms,
              ),
            if (admin.can('system.monitor'))
              _ToolTile(
                icon: Icons.dns_outlined,
                tint: context.paniz.mint,
                title: 'سرور و پشتیبان‌گیری',
                detail: 'وضعیت سرویس و فایل‌های SQL',
                onTap: onOperations,
              ),
            const SizedBox(height: 20),
            sectionTitle('حساب و مدیریت'),
            const SizedBox(height: 10),
            if (admin.can('staff.manage'))
              _ToolTile(
                icon: Icons.manage_accounts_outlined,
                tint: context.paniz.mint,
                title: 'کارکنان و دسترسی‌ها',
                detail: 'افزودن کارمند و تعیین مجوزها',
                onTap: onStaff,
              ),
            if (admin.can('staff.activity'))
              _ToolTile(
                icon: Icons.history_outlined,
                tint: context.paniz.lilac,
                title: 'گزارش فعالیت‌ها',
                detail: 'رویدادهای فارسی و جزئیات تغییرات',
                onTap: onActivity,
              ),
            _ToolTile(
              icon: Icons.system_update_outlined,
              tint: context.paniz.mint,
              title: 'بروزرسانی',
              detail: 'دریافت آخرین نسخه از سرور فروشگاه',
              onTap: onUpdate,
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onLogout,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('خروج از حساب'),
              style: OutlinedButton.styleFrom(
                foregroundColor: context.paniz.error,
                side: BorderSide(
                  color: context.paniz.error.withValues(alpha: .45),
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({
    required this.icon,
    required this.tint,
    required this.title,
    required this.detail,
    required this.onTap,
  });
  final IconData icon;
  final Color tint;
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Card(
      child: ListTile(
        minVerticalPadding: 9,
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: tint.withValues(alpha: .45),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: context.paniz.primary, size: 21),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
        subtitle: Text(
          detail,
          style: TextStyle(color: context.paniz.muted, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_left_rounded),
        onTap: onTap,
      ),
    ),
  );
}
