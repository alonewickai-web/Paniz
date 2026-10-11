import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/admin_api.dart';
import '../../core/paniz_theme.dart';
import '../../core/providers.dart';
import '../../core/theme_toggle.dart';
import '../../core/ui_helpers.dart';
import '../auth/security_settings_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../dashboard/statistics_screen.dart';
import '../inventory/inventory_screen.dart';
import '../orders/orders_screen.dart';
import '../products/products_screen.dart';
import '../store/store_management_screen.dart';

class AdminHome extends ConsumerStatefulWidget {
  const AdminHome({super.key, required this.admin});
  final AdminIdentity admin;

  @override
  ConsumerState<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends ConsumerState<AdminHome> {
  int _index = 0;

  static const _titles = ['خانه', 'محصولات', 'سفارش‌ها', 'گزارش‌ها', 'بیشتر'];
  static const _icons = [Icons.home_rounded, Icons.checkroom_rounded, Icons.receipt_long_rounded, Icons.bar_chart_rounded, Icons.grid_view_rounded];

  Future<void> _logout() async {
    try {
      await ref.read(authProvider.notifier).logout();
    } catch (error) {
      if (mounted) showAppMessage(context, AdminApi.friendlyError(error), error: true);
    }
  }

  void _pushTool(String title, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: const [PanizThemeToggle(), SizedBox(width: 4)],
      ),
      body: SafeArea(child: screen),
    )));
  }

  void _pushToolFromDrawer(String title, Widget screen) {
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _pushTool(title, screen);
    });
  }

  void _selectTab(int index) {
    Navigator.of(context).maybePop();
    setState(() => _index = index);
  }

  void _showPlanned(String section) {
    Navigator.of(context).pop();
    showAppMessage(context, 'بخش «$section» هنوز به API فروشگاه متصل نشده است.');
  }

  int _newOrderCount(JsonMap data) {
    final counts = data['orderCounts'];
    if (counts is! Map) return 0;
    final paid = counts['paid'] is num ? (counts['paid'] as num).toInt() : 0;
    final confirmed = counts['confirmed'] is num ? (counts['confirmed'] as num).toInt() : 0;
    return paid + confirmed;
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = ref.watch(dashboardProvider);
    final newOrders = dashboard.maybeWhen(data: _newOrderCount, orElse: () => 0);
    final connectionLabel = dashboard.when(data: (_) => 'اتصال برقرار است', loading: () => 'در حال بررسی اتصال', error: (_, __) => 'اتصال برقرار نیست');
    final connectionColor = dashboard.when(data: (_) => context.paniz.success, loading: () => context.paniz.warning, error: (_, __) => context.paniz.error);

    return Scaffold(
      drawer: _buildDrawer(connectionLabel, connectionColor),
      appBar: AppBar(
        leading: Builder(builder: (context) => IconButton(
          tooltip: 'بازکردن منوی مدیریت',
          onPressed: () => Scaffold.of(context).openDrawer(),
          icon: const Icon(Icons.menu_rounded),
        )),
        titleSpacing: 0,
        title: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: context.paniz.primarySoft, borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.checkroom_rounded, color: context.paniz.primary, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            const Text('PANIZ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: .8)),
            Text(_titles[_index], style: Theme.of(context).textTheme.labelSmall?.copyWith(color: context.paniz.muted)),
          ])),
        ]),
        actions: [
          const PanizThemeToggle(),
          IconButton(
            tooltip: 'سفارش‌های نیازمند رسیدگی',
            onPressed: () => setState(() => _index = 2),
            icon: Badge(
              isLabelVisible: newOrders > 0,
              label: Text(persianNumber(newOrders)),
              backgroundColor: context.paniz.error,
              child: const Icon(Icons.notifications_none_rounded),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 2, end: 12),
            child: PopupMenuButton<String>(
              tooltip: 'حساب مدیر',
              onSelected: (value) {
                if (value == 'security') _pushTool('امنیت و ورود', SecuritySettingsScreen(admin: widget.admin));
                if (value == 'logout') _logout();
              },
              itemBuilder: (context) => [
                PopupMenuItem<String>(enabled: false, child: Text(widget.admin.fullName)),
                PopupMenuItem<String>(enabled: false, child: Text('@${widget.admin.username}', style: TextStyle(color: context.paniz.muted, fontSize: 12))),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(value: 'security', child: Row(children: [Icon(Icons.shield_outlined), SizedBox(width: 10), Text('امنیت و ورود')])),
                const PopupMenuItem<String>(value: 'logout', child: Row(children: [Icon(Icons.logout_rounded), SizedBox(width: 10), Text('خروج از حساب')])),
              ],
              child: CircleAvatar(
                radius: 18,
                backgroundColor: context.paniz.primarySoft,
                child: Text(widget.admin.fullName.isEmpty ? 'م' : widget.admin.fullName.substring(0, 1), style: TextStyle(color: context.paniz.primary, fontWeight: FontWeight.w900)),
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: [
        DashboardScreen(onProducts: () => _selectTab(1), onOrders: () => _selectTab(2), onInventory: () => _pushTool('انبار و موجودی', const InventoryScreen())),
        const ProductsScreen(),
        const OrdersScreen(),
        const StatisticsScreen(),
        MoreToolsScreen(
          admin: widget.admin,
          onInventory: () => _pushTool('مدیریت انبار', const InventoryScreen()),
          onStore: () => _pushTool('تنظیمات فروشگاه', const StoreManagementScreen()),
          onSecurity: () => _pushTool('امنیت و ورود', SecuritySettingsScreen(admin: widget.admin)),
          onLogout: _logout,
          onPlanned: (section) => showAppMessage(context, 'بخش «$section» هنوز به API فروشگاه متصل نشده است.'),
        ),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        animationDuration: const Duration(milliseconds: 240),
        destinations: List.generate(_titles.length, (index) => NavigationDestination(
          icon: index == 2 && newOrders > 0
              ? Badge(smallSize: 7, backgroundColor: context.paniz.error, child: Icon(_icons[index]))
              : Icon(_icons[index]),
          selectedIcon: Icon(_icons[index]),
          label: _titles[index],
          tooltip: _titles[index],
        )),
      ),
    );
  }

  Widget _buildDrawer(String connectionLabel, Color connectionColor) => Drawer(
    width: math.min(360.0, MediaQuery.sizeOf(context).width * .9),
    child: SafeArea(child: Column(children: [
      Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(18, 12, 14, 10),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('مرکز مدیریت', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text('ابزارهای فروشگاه PANIZ', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.paniz.muted)),
          ])),
          IconButton(tooltip: 'بستن منو', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
        ]),
      ),
      Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 4, 14, 12),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(color: context.paniz.primarySoft, borderRadius: BorderRadius.circular(20)),
          child: Row(children: [
            CircleAvatar(backgroundColor: context.paniz.surface, child: Icon(Icons.person_outline_rounded, color: context.paniz.primary)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.admin.fullName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
              Text('@${widget.admin.username}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.paniz.muted)),
              const SizedBox(height: 5),
              Row(children: [
                Container(width: 7, height: 7, decoration: BoxDecoration(color: connectionColor, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Flexible(child: Text(connectionLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: context.paniz.ink))),
              ]),
            ])),
            IconButton(tooltip: 'امنیت حساب', onPressed: () => _pushToolFromDrawer('امنیت و ورود', SecuritySettingsScreen(admin: widget.admin)), icon: const Icon(Icons.settings_outlined)),
          ]),
        ),
      ),
      const Divider(height: 1),
      Expanded(child: ListView(padding: const EdgeInsets.symmetric(vertical: 8), children: [
        _drawerHeading('مدیریت فروشگاه'),
        _drawerTile('انبار و موجودی', Icons.inventory_2_outlined, detail: 'اصلاح و بررسی تنوع‌ها', onTap: () => _pushToolFromDrawer('مدیریت انبار', const InventoryScreen())),
        _drawerTile('ظاهر و چیدمان سایت', Icons.palette_outlined, detail: 'رنگ، دسته‌بندی و بنرها', onTap: () => _pushToolFromDrawer('تنظیمات فروشگاه', const StoreManagementScreen())),
        _drawerTile('مشتریان', Icons.people_outline_rounded, onTap: () => _showPlanned('مشتریان')),
        _drawerTile('تخفیف‌ها', Icons.sell_outlined, onTap: () => _showPlanned('تخفیف‌ها')),
        _drawerTile('تبلیغات و روبیکا', Icons.campaign_outlined, onTap: () => _showPlanned('تبلیغات و روبیکا')),
        _drawerHeading('حساب و ظاهر برنامه'),
        _drawerTile('امنیت و ورود', Icons.shield_outlined, detail: 'اطلاعات ورود مدیر', onTap: () => _pushToolFromDrawer('امنیت و ورود', SecuritySettingsScreen(admin: widget.admin))),
        _drawerTile('سرور و پایگاه داده', Icons.dns_outlined, onTap: () => _showPlanned('سرور و پایگاه داده')),
      ])),
      const Divider(height: 1),
      ListTile(
        minVerticalPadding: 8,
        leading: Icon(Icons.logout_rounded, color: context.paniz.error),
        title: Text('خروج از حساب', style: TextStyle(color: context.paniz.error, fontWeight: FontWeight.w800)),
        onTap: () { Navigator.pop(context); _logout(); },
      ),
    ])),
  );

  Widget _drawerHeading(String title) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(18, 12, 18, 4),
    child: Align(alignment: AlignmentDirectional.centerStart, child: Text(title, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: context.paniz.muted, fontWeight: FontWeight.w900))),
  );

  Widget _drawerTile(String title, IconData icon, {required VoidCallback onTap, String? detail}) => ListTile(
    minLeadingWidth: 28,
    leading: Icon(icon, color: context.paniz.primary, size: 21),
    title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
    subtitle: detail == null ? null : Text(detail, style: TextStyle(color: context.paniz.muted, fontSize: 11)),
    trailing: const Icon(Icons.chevron_left_rounded, size: 19),
    onTap: onTap,
  );
}

class MoreToolsScreen extends StatelessWidget {
  const MoreToolsScreen({super.key, required this.admin, required this.onInventory, required this.onStore, required this.onSecurity, required this.onLogout, required this.onPlanned});
  final AdminIdentity admin;
  final VoidCallback onInventory;
  final VoidCallback onStore;
  final VoidCallback onSecurity;
  final VoidCallback onLogout;
  final ValueChanged<String> onPlanned;

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 26), children: [
    ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PanizPageHeader(title: 'بیشتر', subtitle: 'تنظیمات و ابزارهای مدیریت فروشگاه'),
        Card(child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(radius: 24, backgroundColor: context.paniz.primarySoft, child: Icon(Icons.admin_panel_settings_outlined, color: context.paniz.primary)),
          title: Text(admin.fullName, style: const TextStyle(fontWeight: FontWeight.w900)),
          subtitle: Text('@${admin.username} · مدیر فروشگاه', style: TextStyle(color: context.paniz.muted, fontSize: 12)),
          trailing: const Icon(Icons.chevron_left_rounded),
          onTap: onSecurity,
        )),
        const SizedBox(height: 22),
        sectionTitle('ابزارهای مدیریتی'),
        const SizedBox(height: 10),
        _ToolTile(icon: Icons.inventory_2_outlined, tint: context.paniz.peach, title: 'انبار و موجودی', detail: 'بررسی سایزها و اصلاح تعداد کالا', onTap: onInventory),
        _ToolTile(icon: Icons.palette_outlined, tint: context.paniz.lilac, title: 'ظاهر سایت', detail: 'رنگ‌بندی، دسته‌ها، بنر و چیدمان', onTap: onStore),
        _ToolTile(icon: Icons.shield_outlined, tint: context.paniz.mint, title: 'امنیت و ورود', detail: 'تغییر نام کاربری و گذرواژه', onTap: onSecurity),
        const SizedBox(height: 20),
        sectionTitle('امکانات در حال آماده‌سازی'),
        const SizedBox(height: 10),
        _UpcomingTile(icon: Icons.people_outline_rounded, title: 'مدیریت مشتریان', onTap: () => onPlanned('مشتریان')),
        _UpcomingTile(icon: Icons.sell_outlined, title: 'کدهای تخفیف', onTap: () => onPlanned('کد تخفیف')),
        _UpcomingTile(icon: Icons.campaign_outlined, title: 'تبلیغات و روبیکا', onTap: () => onPlanned('تبلیغات و روبیکا')),
        _UpcomingTile(icon: Icons.dns_outlined, title: 'وضعیت سرور و پشتیبان‌گیری', onTap: () => onPlanned('سرور و پایگاه داده')),
        const SizedBox(height: 14),
        OutlinedButton.icon(onPressed: onLogout, icon: const Icon(Icons.logout_rounded), label: const Text('خروج از حساب'), style: OutlinedButton.styleFrom(foregroundColor: context.paniz.error, side: BorderSide(color: context.paniz.error.withValues(alpha: .45)))),
      ]),
    ),
  ]);
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({required this.icon, required this.tint, required this.title, required this.detail, required this.onTap});
  final IconData icon;
  final Color tint;
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 9), child: Card(child: ListTile(
    minVerticalPadding: 9,
    leading: Container(width: 42, height: 42, decoration: BoxDecoration(color: tint.withValues(alpha: .45), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: context.paniz.primary, size: 21)),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
    subtitle: Text(detail, style: TextStyle(color: context.paniz.muted, fontSize: 12)),
    trailing: const Icon(Icons.chevron_left_rounded),
    onTap: onTap,
  )));
}

class _UpcomingTile extends StatelessWidget {
  const _UpcomingTile({required this.icon, required this.title, required this.onTap});
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 7), child: Card(child: ListTile(
    dense: true,
    leading: Icon(icon, color: context.paniz.muted),
    title: Text(title, style: TextStyle(color: context.paniz.muted, fontSize: 12)),
    trailing: Text('به‌زودی', style: TextStyle(color: context.paniz.muted, fontSize: 10, fontWeight: FontWeight.w700)),
    onTap: onTap,
  )));
}
