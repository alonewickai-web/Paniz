import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/admin_api.dart';
import '../../core/providers.dart';
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

  static const _titles = ['خانه', 'سفارش‌ها', 'محصولات', 'آمار', 'بیشتر'];
  static const _icons = [Icons.home_rounded, Icons.receipt_long_rounded, Icons.checkroom_rounded, Icons.bar_chart_rounded, Icons.grid_view_rounded];

  Future<void> _logout() async {
    try {
      await ref.read(authProvider.notifier).logout();
    } catch (error) {
      if (mounted) showAppMessage(context, AdminApi.friendlyError(error), error: true);
    }
  }

  void _pushTool(String title, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => Scaffold(
      appBar: AppBar(title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800))),
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
    return Scaffold(
      drawer: _buildDrawer(newOrders),
      appBar: AppBar(
        leading: Builder(builder: (context) => IconButton(
          tooltip: 'منوی مدیریت',
          onPressed: () => Scaffold.of(context).openDrawer(),
          icon: const Icon(Icons.menu_rounded),
        )),
        titleSpacing: 2,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Text('PANIZ Admin', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: .3, fontSize: 15)),
            const SizedBox(width: 7),
            Text(_titles[_index], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: panizMuted)),
          ]),
          const Text('مدیریت فروشگاه پانیز', style: TextStyle(fontSize: 10, color: panizMuted)),
        ]),
        actions: [
          IconButton(
            tooltip: 'سفارش‌های نیازمند رسیدگی',
            onPressed: () => setState(() => _index = 1),
            icon: Badge(
              isLabelVisible: newOrders > 0,
              label: Text(persianNumber(newOrders)),
              backgroundColor: const Color(0xFFDC2626),
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
                PopupMenuItem<String>(enabled: false, child: Text('@${widget.admin.username}', style: const TextStyle(color: panizMuted, fontSize: 12))),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(value: 'security', child: Row(children: [Icon(Icons.shield_outlined), SizedBox(width: 10), Text('امنیت و ورود')])),
                const PopupMenuItem<String>(value: 'logout', child: Row(children: [Icon(Icons.logout_rounded), SizedBox(width: 10), Text('خروج از حساب')])),
              ],
              child: CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFFE6FFFA),
                child: Text(widget.admin.fullName.isEmpty ? 'م' : widget.admin.fullName.substring(0, 1), style: const TextStyle(color: panizPrimary, fontWeight: FontWeight.w900)),
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: [
        const DashboardScreen(),
        const OrdersScreen(),
        const ProductsScreen(),
        const StatisticsScreen(),
        MoreToolsScreen(
          admin: widget.admin,
          onInventory: () => _pushTool('مدیریت انبار', const InventoryScreen()),
          onStore: () => _pushTool('تنظیمات فروشگاه', const StoreManagementScreen()),
          onSecurity: () => _pushTool('امنیت و ورود', SecuritySettingsScreen(admin: widget.admin)),
          onLogout: _logout,
        ),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: List.generate(_titles.length, (index) => NavigationDestination(
          icon: Icon(_icons[index]),
          selectedIcon: Icon(_icons[index], color: panizPrimary),
          label: _titles[index],
        )),
      ),
    );
  }

  Widget _buildDrawer(int newOrders) => Drawer(
    width: 320,
    backgroundColor: Colors.white,
    child: SafeArea(child: Column(children: [
      Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(17, 14, 14, 14),
        child: Row(children: [
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('منوی مدیریت', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: panizInk)),
            SizedBox(height: 3),
            Text('ابزارهای فروشگاه PanizStyle', style: TextStyle(fontSize: 11, color: panizMuted)),
          ])),
          IconButton(tooltip: 'بستن منو', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
        ]),
      ),
      Card(color: const Color(0xFFE6FFFA), margin: const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 12), child: ListTile(
        leading: const CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.person_outline_rounded, color: panizPrimary)),
        title: Text(widget.admin.fullName, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('@${widget.admin.username}', style: const TextStyle(color: panizMuted, fontSize: 12)),
        trailing: const Icon(Icons.chevron_left_rounded),
        onTap: () => _pushToolFromDrawer('امنیت و ورود', SecuritySettingsScreen(admin: widget.admin)),
      )),
      const Divider(height: 1),
      Expanded(child: ListView(padding: const EdgeInsets.symmetric(vertical: 8), children: [
        _drawerHeading('کارهای روزانه'),
        _drawerTile('خانه', Icons.home_outlined, selected: _index == 0, onTap: () => _selectTab(0)),
        _drawerTile('سفارش‌ها', Icons.receipt_long_outlined, selected: _index == 1, onTap: () => _selectTab(1), trailing: _orderBadge(newOrders)),
        _drawerTile('محصولات', Icons.checkroom_outlined, selected: _index == 2, onTap: () => _selectTab(2)),
        _drawerTile('آمار فروش', Icons.bar_chart_rounded, selected: _index == 3, onTap: () => _selectTab(3)),
        _drawerHeading('مدیریت فروشگاه'),
        _drawerTile('انبار و موجودی', Icons.inventory_2_outlined, onTap: () => _pushToolFromDrawer('مدیریت انبار', const InventoryScreen())),
        _drawerTile('ظاهر و چیدمان سایت', Icons.palette_outlined, onTap: () => _pushToolFromDrawer('تنظیمات فروشگاه', const StoreManagementScreen())),
        _drawerTile('مشتریان', Icons.people_outline_rounded, onTap: () => _showPlanned('مشتریان')),
        _drawerTile('تخفیف‌ها', Icons.sell_outlined, onTap: () => _showPlanned('تخفیف‌ها')),
        _drawerTile('تبلیغات و روبیکا', Icons.campaign_outlined, onTap: () => _showPlanned('تبلیغات و روبیکا')),
        _drawerHeading('حساب و تنظیمات'),
        _drawerTile('امنیت و ورود', Icons.shield_outlined, onTap: () => _pushToolFromDrawer('امنیت و ورود', SecuritySettingsScreen(admin: widget.admin))),
        _drawerTile('سرور و پایگاه داده', Icons.dns_outlined, onTap: () => _showPlanned('سرور و پایگاه داده')),
      ])),
      const Divider(height: 1),
      ListTile(
        leading: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626)),
        title: const Text('خروج از حساب', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w800)),
        onTap: () { Navigator.pop(context); _logout(); },
      ),
    ])),
  );

  Widget? _orderBadge(int count) => count == 0
      ? null
      : Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: panizCoral.withValues(alpha: .24), borderRadius: BorderRadius.circular(20)), child: Text(persianNumber(count), style: const TextStyle(color: Color(0xFF9F1239), fontWeight: FontWeight.w800, fontSize: 11)));

  Widget _drawerHeading(String title) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(17, 14, 17, 5),
    child: Align(alignment: AlignmentDirectional.centerStart, child: Text(title, style: const TextStyle(fontSize: 11, color: panizMuted, fontWeight: FontWeight.w800))),
  );

  Widget _drawerTile(String title, IconData icon, {required VoidCallback onTap, bool selected = false, Widget? trailing}) => ListTile(
    minLeadingWidth: 27,
    minVerticalPadding: 2,
    selected: selected,
    selectedTileColor: const Color(0xFFE6FFFA),
    leading: Icon(icon, color: selected ? panizPrimary : panizMuted, size: 21),
    title: Text(title, style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.w800 : FontWeight.w600, color: panizInk)),
    trailing: trailing ?? const Icon(Icons.chevron_left_rounded, size: 19, color: panizMuted),
    onTap: onTap,
  );
}

class MoreToolsScreen extends StatelessWidget {
  const MoreToolsScreen({super.key, required this.admin, required this.onInventory, required this.onStore, required this.onSecurity, required this.onLogout});
  final AdminIdentity admin;
  final VoidCallback onInventory;
  final VoidCallback onStore;
  final VoidCallback onSecurity;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
    Card(color: const Color(0xFFE6FFFA), child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      leading: const CircleAvatar(radius: 24, backgroundColor: Colors.white, child: Icon(Icons.admin_panel_settings_outlined, color: panizPrimary)),
      title: Text(admin.fullName, style: const TextStyle(fontWeight: FontWeight.w900, color: panizInk)),
      subtitle: Text('@${admin.username} · مدیر فروشگاه', style: const TextStyle(color: panizMuted, fontSize: 12)),
      trailing: const Icon(Icons.chevron_left_rounded),
      onTap: onSecurity,
    )),
    const SizedBox(height: 18),
    const Text('ابزارهای مدیریتی', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: panizInk)),
    const SizedBox(height: 10),
    _ToolTile(icon: Icons.inventory_2_outlined, tint: panizPeach, title: 'انبار و موجودی', detail: 'موجودی سایز و رنگ کالاها', onTap: onInventory),
    _ToolTile(icon: Icons.palette_outlined, tint: panizLilac, title: 'ظاهر سایت', detail: 'رنگ‌بندی، دسته‌ها، بنر و چیدمان', onTap: onStore),
    _ToolTile(icon: Icons.shield_outlined, tint: panizMint, title: 'امنیت و ورود', detail: 'تغییر نام کاربری و گذرواژه', onTap: onSecurity),
    const SizedBox(height: 18),
    const Text('در صف اتصال به سرور', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: panizInk)),
    const SizedBox(height: 8),
    const _UpcomingTile(icon: Icons.people_outline_rounded, title: 'مدیریت مشتریان'),
    const _UpcomingTile(icon: Icons.sell_outlined, title: 'کدهای تخفیف'),
    const _UpcomingTile(icon: Icons.campaign_outlined, title: 'تبلیغات و روبیکا'),
    const _UpcomingTile(icon: Icons.dns_outlined, title: 'وضعیت سرور و پشتیبان‌گیری'),
    const SizedBox(height: 14),
    OutlinedButton.icon(onPressed: onLogout, icon: const Icon(Icons.logout_rounded), label: const Text('خروج از حساب'), style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFDC2626), minimumSize: const Size.fromHeight(48))),
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
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Card(child: ListTile(
    minVerticalPadding: 8,
    leading: CircleAvatar(backgroundColor: tint.withValues(alpha: .4), child: Icon(icon, color: panizPrimary)),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
    subtitle: Text(detail, style: const TextStyle(color: panizMuted, fontSize: 11)),
    trailing: const Icon(Icons.chevron_left_rounded),
    onTap: onTap,
  )));
}

class _UpcomingTile extends StatelessWidget {
  const _UpcomingTile({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Card(child: ListTile(
    dense: true,
    leading: Icon(icon, color: panizMuted),
    title: Text(title, style: const TextStyle(color: panizMuted, fontSize: 12)),
    trailing: const Text('به‌زودی', style: TextStyle(color: panizMuted, fontSize: 10)),
  ));
}
