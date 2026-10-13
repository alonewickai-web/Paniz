import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/admin_api.dart';
import '../../core/admin_avatar.dart';
import '../../core/admin_network_image.dart';
import '../../core/paniz_theme.dart';
import '../../core/providers.dart';
import '../../core/ui_helpers.dart';
import '../store/store_management_screen.dart';
import '../updates/app_update_screen.dart';

String activityTime(Object? value) {
  final date = DateTime.tryParse('$value')?.toLocal();
  if (date == null) return 'ثبت نشده';
  final difference = DateTime.now().difference(date);
  if (difference.inSeconds >= 0 && difference.inMinutes < 1) return 'همین الآن';
  if (difference.inMinutes >= 0 && difference.inMinutes < 60)
    return '${persianNumber(difference.inMinutes)} دقیقه پیش';
  if (difference.inHours >= 0 && difference.inHours < 24)
    return '${persianNumber(difference.inHours)} ساعت پیش';
  return '${shamsiDate(date)} · ${persianNumber(date.hour.toString().padLeft(2, '0'))}:${persianNumber(date.minute.toString().padLeft(2, '0'))}';
}

String activityTitle(JsonMap row) {
  final details =
      row['details'] is Map
          ? Map<String, dynamic>.from(row['details'] as Map)
          : <String, dynamic>{};
  final code = '${details['sku'] ?? row['entityId'] ?? ''}';
  return switch (row['action']) {
    'product.created' => 'محصول جدید با کد $code اضافه شد',
    'product.updated' =>
      'اطلاعات محصول ${details['productName'] ?? code} تغییر کرد',
    'product.archived' => 'محصول $code بایگانی شد',
    'product_variant.created' => 'تنوع جدید با کد $code به محصول اضافه شد',
    'product_variant.updated' => 'قیمت یا مشخصات تنوع $code تغییر کرد',
    'inventory.adjusted' => 'موجودی کالای $code اصلاح شد',
    'product_image.created' => 'تصویر جدید به محصول اضافه شد',
    'product_image.updated' => 'تصویر محصول ویرایش شد',
    'product_image.deleted' => 'تصویر محصول حذف شد',
    'order.status_changed' =>
      'سفارش ${details['orderNumber'] ?? row['entityId']} از «${statusLabel('${details['from']}')}» به «${statusLabel('${details['to']}')}» تغییر کرد',
    'admin.login_succeeded' => 'ورود به برنامه انجام شد',
    'admin.login_failed' => 'تلاش ناموفق برای ورود ثبت شد',
    'admin.logout' => 'خروج از حساب انجام شد',
    'admin.credentials_changed' => 'اطلاعات ورود حساب تغییر کرد',
    'admin.credentials_reauthentication_failed' =>
      'تأیید گذرواژهٔ فعلی ناموفق بود',
    'admin.profile_updated' => 'اطلاعات یا عکس پروفایل تغییر کرد',
    'admin.staff_created' =>
      'حساب کارمند ${details['username'] ?? ''} ایجاد شد',
    'admin.staff_updated' => 'اطلاعات کارمند ویرایش شد',
    'admin.staff_deactivated' => 'حساب کارمند غیرفعال شد',
    'admin.permissions_changed' => 'دسترسی‌های کارمند تغییر کرد',
    'admin.staff_password_reset' => 'گذرواژهٔ موقت جدید برای کارمند ایجاد شد',
    'admin.app_release_published' =>
      'نسخهٔ ${details['versionName'] ?? ''} برنامه روی سرور منتشر شد',
    'admin.test_account_seeded' => 'حساب اولیهٔ آزمایشی ایجاد شد',
    'store.theme.updated' => 'رنگ‌بندی سایت تغییر کرد',
    'store.logo.updated' => 'نشان فروشگاه تغییر کرد',
    'shipping.settings.updated' => 'هزینه و شرایط ارسال تغییر کرد',
    'homepage_section.updated' => 'تنظیمات یک بخش صفحهٔ اصلی تغییر کرد',
    'homepage_sections.reordered' => 'ترتیب بخش‌های صفحهٔ اصلی تغییر کرد',
    'category.created' => 'دسته‌بندی ${details['name'] ?? ''} اضافه شد',
    'category.updated' => 'دسته‌بندی ${details['name'] ?? ''} ویرایش شد',
    'category.archived' => 'دسته‌بندی بایگانی شد',
    'banner.created' => 'بنر ${details['title'] ?? ''} اضافه شد',
    'banner.updated' => 'بنر ${details['title'] ?? ''} ویرایش شد',
    'banner.archived' => 'بنر از سایت برداشته شد',
    'banner.restored' => 'بنر به سایت بازگردانده شد',
    'coupon.created' => 'کد تخفیف ${details['code'] ?? ''} ایجاد شد',
    'coupon.updated' => 'کد تخفیف ${details['code'] ?? ''} ویرایش شد',
    'sms_campaign.created' =>
      'کمپین پیامکی برای ${persianNumber(details['recipientCount'] ?? 0)} مخاطب ایجاد شد',
    'sms_campaign.queued' => 'ارسال کمپین پیامکی در صف قرار گرفت',
    'sms_campaign.sent' => 'ارسال کمپین پیامکی انجام شد',
    'rubika_campaign.created' => 'کمپین روبیکا ایجاد شد',
    'rubika_campaign.queued' => 'ارسال کمپین روبیکا در صف قرار گرفت',
    'social_post.awaiting_approval' => 'پست روبیکا برای تأیید آماده شد',
    'social_post.approved' => 'انتشار پست روبیکا تأیید شد',
    'social_post.send_now' => 'انتشار فوری پست درخواست شد',
    'social_post.cancelled' => 'انتشار پست لغو شد',
    'database.backup_created' => 'نسخهٔ پشتیبان پایگاه داده ساخته شد',
    _ => 'رویداد مدیریتی ثبت شد',
  };
}

class AdminActivityCard extends StatelessWidget {
  const AdminActivityCard({super.key, required this.activity});
  final JsonMap activity;
  @override
  Widget build(BuildContext context) {
    final actor =
        activity['admin'] is Map
            ? activity['admin'] as Map
            : const <String, dynamic>{};
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 8,
          ),
          leading: AdminAvatar(
            name: '${actor['fullName'] ?? 'سامانه'}',
            path: actor['avatarPath'] as String?,
            size: 40,
          ),
          title: Text(
            activityTitle(activity),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.6,
            ),
          ),
          subtitle: Text(
            '${actor['fullName'] ?? 'سامانه'} · ${activityTime(activity['createdAt'])}',
            style: TextStyle(
              color: context.paniz.muted,
              fontSize: 11,
              height: 1.6,
            ),
          ),
          trailing: Icon(
            activity['result'] == 'failed'
                ? Icons.error_outline
                : Icons.chevron_left,
            color:
                activity['result'] == 'failed'
                    ? context.paniz.error
                    : context.paniz.muted,
          ),
          onTap:
              () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => AuditLogDetailScreen(id: '${activity['id']}'),
                ),
              ),
        ),
      ),
    );
  }
}

class AuditLogScreen extends ConsumerStatefulWidget {
  const AuditLogScreen({super.key, this.adminId});
  final String? adminId;
  @override
  ConsumerState<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends ConsumerState<AuditLogScreen> {
  List<JsonMap> _rows = [];
  int _page = 1;
  int _total = 0;
  bool _loading = true;
  String? _entity;
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
      final result = await ref
          .read(adminApiProvider)
          .auditLogs(page: _page, adminId: widget.adminId, entityType: _entity);
      if (mounted)
        setState(() {
          _rows =
              (result['data'] as List)
                  .whereType<Map>()
                  .map((row) => Map<String, dynamic>.from(row))
                  .toList();
          _total = (result['meta']['total'] as num).toInt();
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
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        const PanizPageHeader(
          title: 'تاریخچهٔ فعالیت‌ها',
          subtitle: 'برای دیدن جزئیات تغییر، روی هر فعالیت بزنید.',
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final item
                  in <String?, String>{
                    null: 'همه',
                    'product': 'محصولات',
                    'product_variant': 'قیمت و تنوع',
                    'order': 'سفارش‌ها',
                    'admin_user': 'کارکنان',
                    'sms_campaign': 'کمپین‌ها',
                    'app_release': 'نسخهٔ برنامه',
                  }.entries)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: ChoiceChip(
                    label: Text(item.value),
                    selected: _entity == item.key,
                    onSelected: (_) {
                      setState(() {
                        _entity = item.key;
                        _page = 1;
                      });
                      _load();
                    },
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null)
          PanizEmptyState(
            icon: Icons.cloud_off_outlined,
            title: _error!,
            action: OutlinedButton(
              onPressed: _load,
              child: const Text('تلاش دوباره'),
            ),
          ),
        if (!_loading && _error == null && _rows.isEmpty)
          const PanizEmptyState(
            icon: Icons.history_outlined,
            title: 'فعالیتی در این بخش نیست',
          ),
        ..._rows.map((row) => AdminActivityCard(activity: row)),
        if (_total > 30)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed:
                    !_loading && _page > 1
                        ? () {
                          _page--;
                          _load();
                        }
                        : null,
                icon: const Icon(Icons.chevron_right),
              ),
              Text('صفحهٔ ${persianNumber(_page)}'),
              IconButton(
                onPressed:
                    !_loading && _page * 30 < _total
                        ? () {
                          _page++;
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

class AuditLogDetailScreen extends ConsumerStatefulWidget {
  const AuditLogDetailScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<AuditLogDetailScreen> createState() =>
      _AuditLogDetailScreenState();
}

class _AuditLogDetailScreenState extends ConsumerState<AuditLogDetailScreen> {
  late Future<JsonMap> _future;
  @override
  void initState() {
    super.initState();
    _future = ref.read(adminApiProvider).auditDetail(widget.id);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('جزئیات فعالیت')),
    body: SafeArea(
      child: FutureBuilder<JsonMap>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(AdminApi.friendlyError(snapshot.error!)),
                    OutlinedButton(
                      onPressed:
                          () => setState(
                            () =>
                                _future = ref
                                    .read(adminApiProvider)
                                    .auditDetail(widget.id),
                          ),
                      child: const Text('تلاش دوباره'),
                    ),
                  ],
                ),
              ),
            );
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final row = snapshot.data!;
          final actor =
              row['admin'] is Map
                  ? row['admin'] as Map
                  : const <String, dynamic>{};
          final details =
              row['details'] is Map
                  ? Map<String, dynamic>.from(row['details'] as Map)
                  : <String, dynamic>{};
          final admin = ref.read(authProvider).asData?.value;
          final kind = '${row['entityType']}';
          final entityId = row['entityId'];
          final productId = kind == 'product' ? entityId : details['productId'];
          Widget? target;
          if (productId != null && admin?.can('products.view') == true)
            target = AdminRecordScreen(kind: 'product', id: '$productId');
          if (kind == 'order' &&
              entityId != null &&
              admin?.can('orders.view') == true)
            target = AdminRecordScreen(kind: 'order', id: '$entityId');
          if (const {
                'category',
                'banner',
                'homepage_section',
                'store_setting',
              }.contains(kind) &&
              admin?.can('store.content') == true)
            target = const StoreManagementScreen();
          if (kind == 'app_release') target = const AppUpdateScreen();
          final destination = target;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          AdminAvatar(
                            name: '${actor['fullName'] ?? 'سامانه'}',
                            path: actor['avatarPath'] as String?,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${actor['fullName'] ?? 'سامانه'}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  activityTime(row['createdAt']),
                                  style: TextStyle(
                                    color: context.paniz.muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        activityTitle(row),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          height: 1.7,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        row['result'] == 'failed'
                            ? 'نتیجه: ناموفق'
                            : 'نتیجه: موفق',
                        style: TextStyle(
                          color:
                              row['result'] == 'failed'
                                  ? context.paniz.error
                                  : context.paniz.primary,
                        ),
                      ),
                      Text(
                        'شناسهٔ رویداد: ${persianNumber(row['id'])}',
                        style: TextStyle(
                          color: context.paniz.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (destination != null)
                FilledButton.icon(
                  onPressed:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder:
                              (_) =>
                                  destination is AdminRecordScreen
                                      ? destination
                                      : Scaffold(
                                        appBar: AppBar(
                                          title: const Text(
                                            'بخش مربوط به تغییر',
                                          ),
                                        ),
                                        body: SafeArea(child: destination),
                                      ),
                        ),
                      ),
                  icon: const Icon(Icons.open_in_new_outlined),
                  label: const Text('بازکردن صفحهٔ مربوط به تغییر'),
                ),
              const SizedBox(height: 20),
              sectionTitle('اطلاعات ثبت‌شده'),
              const SizedBox(height: 12),
              if (details.isEmpty)
                const PanizEmptyState(
                  icon: Icons.info_outline,
                  title: 'اطلاعات تکمیلی ثبت نشده',
                ),
              ...details.entries
                  .where((entry) => entry.key != 'identifierHash')
                  .map(
                    (entry) => _DetailValue(
                      label: detailLabel(entry.key),
                      value: entry.value,
                    ),
                  ),
            ],
          );
        },
      ),
    ),
  );
}

class AdminRecordScreen extends ConsumerStatefulWidget {
  const AdminRecordScreen({super.key, required this.kind, required this.id});
  final String kind;
  final String id;
  @override
  ConsumerState<AdminRecordScreen> createState() => _AdminRecordScreenState();
}

class _AdminRecordScreenState extends ConsumerState<AdminRecordScreen> {
  late Future<JsonMap> _future;
  @override
  void initState() {
    super.initState();
    _future =
        widget.kind == 'product'
            ? ref.read(adminApiProvider).productDetail(widget.id)
            : ref.read(adminApiProvider).orderDetail(widget.id);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.kind == 'product' ? 'جزئیات محصول' : 'جزئیات سفارش'),
    ),
    body: SafeArea(
      child: FutureBuilder<JsonMap>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(AdminApi.friendlyError(snapshot.error!)),
              ),
            );
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final row = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '${row['name'] ?? row['orderNumber']}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: statusPill(context, '${row['status']}'),
              ),
              const SizedBox(height: 20),
              if (row['images'] is List && (row['images'] as List).isNotEmpty)
                SizedBox(
                  height: 280,
                  child: PageView(
                    children:
                        (row['images'] as List)
                            .whereType<Map>()
                            .map(
                              (image) => Padding(
                                padding: const EdgeInsets.all(4),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(18),
                                  child: AdminNetworkImage(
                                    imagePath: '${image['imagePath']}',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                  ),
                ),
              if (row['variants'] is List) ...[
                sectionTitle('تنوع‌ها'),
                const SizedBox(height: 12),
                ...(row['variants'] as List).whereType<Map>().map(
                  (variant) => Card(
                    child: ListTile(
                      title: Text(
                        '${variant['colorName']} · ${variant['sizeLabel']}',
                      ),
                      subtitle: Text(
                        'کد: ${variant['sku']} · موجودی ${persianNumber(variant['availableQuantity'])}',
                      ),
                      trailing: Text(toman(variant['priceToman'])),
                    ),
                  ),
                ),
              ],
              if (row['items'] is List) ...[
                sectionTitle('اقلام سفارش'),
                const SizedBox(height: 12),
                ...(row['items'] as List).whereType<Map>().map(
                  (item) => Card(
                    child: ListTile(
                      title: Text('${item['name']}'),
                      subtitle: Text(
                        '${item['color']} · ${item['size']} · ${persianNumber(item['quantity'])} عدد',
                      ),
                      trailing:
                          item['lineTotalToman'] != null
                              ? Text(toman(item['lineTotalToman']))
                              : null,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              ...row.entries
                  .where(
                    (entry) =>
                        !const {
                          'images',
                          'variants',
                          'items',
                          'name',
                          'status',
                          'category',
                        }.contains(entry.key) &&
                        entry.value != null,
                  )
                  .map(
                    (entry) => _DetailValue(
                      label: detailLabel(entry.key),
                      value: entry.value,
                    ),
                  ),
            ],
          );
        },
      ),
    ),
  );
}

const _labels = <String, String>{
  'id': 'شناسه',
  'name': 'نام',
  'fullName': 'نام و نام خانوادگی',
  'phone': 'شمارهٔ تماس',
  'avatarPath': 'تصویر پروفایل',
  'username': 'نام کاربری',
  'sku': 'کد کالا',
  'slug': 'نشانی محصول',
  'productId': 'شناسهٔ محصول',
  'productName': 'نام محصول',
  'changedFields': 'بخش‌های تغییرکرده',
  'before': 'قبل از تغییر',
  'after': 'پس از تغییر',
  'categoryId': 'شناسهٔ دسته‌بندی',
  'description': 'توضیحات کامل',
  'shortDescription': 'توضیحات کوتاه',
  'seoTitle': 'عنوان جست‌وجو',
  'seoDescription': 'توضیح جست‌وجو',
  'material': 'جنس',
  'careInstructions': 'راهنمای نگهداری',
  'sizeGuide': 'راهنمای اندازه',
  'colorBefore': 'رنگ قبلی',
  'colorAfter': 'رنگ جدید',
  'sizeBefore': 'اندازهٔ قبلی',
  'sizeAfter': 'اندازهٔ جدید',
  'priceBefore': 'قیمت قبلی (تومان)',
  'priceAfter': 'قیمت جدید (تومان)',
  'compareAtPriceBefore': 'قیمت مرجع قبلی',
  'compareAtPriceAfter': 'قیمت مرجع جدید',
  'priceToman': 'قیمت (تومان)',
  'purchaseCostToman': 'قیمت خرید (تومان)',
  'compareAtPriceToman': 'قیمت قبل از تخفیف',
  'baseCostToman': 'هزینهٔ پایهٔ ارسال (تومان)',
  'freeOverToman': 'حد خرید برای ارسال رایگان (تومان)',
  'alwaysFree': 'ارسال همیشگی رایگان',
  'logoPath': 'نشان فروشگاه',
  'colorName': 'رنگ',
  'colorHex': 'کد رنگ',
  'sizeLabel': 'اندازه',
  'lowStockThreshold': 'آستانهٔ هشدار موجودی',
  'isActive': 'وضعیت فعال',
  'orderNumber': 'شمارهٔ سفارش',
  'from': 'وضعیت قبلی',
  'to': 'وضعیت جدید',
  'note': 'یادداشت',
  'trackingCode': 'کد رهگیری',
  'stockBefore': 'موجودی قبلی',
  'stockAfter': 'موجودی جدید',
  'delta': 'میزان تغییر موجودی',
  'reservedQuantity': 'موجودی رزروشده',
  'quantity': 'تعداد',
  'permissions': 'دسترسی‌های جدید',
  'previousPermissions': 'دسترسی‌های قبلی',
  'previousActive': 'وضعیت فعال قبلی',
  'sessionsRevoked': 'نشست‌های بسته‌شده',
  'versionName': 'نسخهٔ برنامه',
  'versionCode': 'شمارهٔ ساخت',
  'sha256': 'شناسهٔ صحت فایل',
  'releaseNotes': 'توضیحات نسخه',
  'imagePath': 'نشانی تصویر',
  'altText': 'توضیح تصویر',
  'sortOrder': 'ترتیب نمایش',
  'isPrimary': 'تصویر اصلی',
  'title': 'عنوان',
  'theme': 'رنگ‌بندی',
  'recipientCount': 'تعداد مخاطبان',
  'code': 'کد تخفیف',
  'channels': 'کانال‌های انتشار',
  'publishAt': 'زمان انتشار',
  'filename': 'نام فایل',
  'sizeBytes': 'حجم فایل',
  'recipientName': 'نام گیرنده',
  'recipientPhone': 'شمارهٔ گیرنده',
  'address': 'نشانی ارسال',
  'customerNote': 'یادداشت مشتری',
  'totalToman': 'مبلغ کل (تومان)',
  'subtotalToman': 'جمع کالاها (تومان)',
  'discountToman': 'تخفیف (تومان)',
  'shippingToman': 'هزینهٔ ارسال (تومان)',
  'paymentStatus': 'وضعیت پرداخت',
  'placedAt': 'زمان ثبت سفارش',
  'updatedAt': 'آخرین تغییر',
  'status': 'وضعیت',
  'shipments': 'مرسوله‌ها',
  'usernameChanged': 'تغییر نام کاربری',
  'passwordChanged': 'تغییر گذرواژه',
  'expiresAt': 'زمان انقضا',
  'sessionId': 'شناسهٔ نشست',
};
String detailLabel(String key) => _labels[key] ?? 'اطلاعات تکمیلی';

class _DetailValue extends StatelessWidget {
  const _DetailValue({required this.label, required this.value});
  final String label;
  final Object? value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              label,
              style: TextStyle(color: context.paniz.muted, fontSize: 12),
            ),
            const SizedBox(height: 6),
            if (value is Map)
              ...((value as Map).entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    '${detailLabel('${entry.key}')}: ${_text(entry.value)}',
                    style: const TextStyle(height: 1.6),
                  ),
                ),
              ))
            else
              SelectableText(
                _text(value),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  height: 1.7,
                ),
              ),
          ],
        ),
      ),
    ),
  );
  String _text(Object? input) {
    if (input == null) return 'ثبت نشده';
    if (input is bool) return input ? 'بله' : 'خیر';
    if (input is List) return input.map(_text).join('، ');
    if (input is Map)
      return input.entries
          .map(
            (entry) => '${detailLabel('${entry.key}')}: ${_text(entry.value)}',
          )
          .join('\n');
    if (input is num) return groupedNumber(input);
    final text = '$input';
    if (_labels.containsKey(text)) return detailLabel(text);
    if (const {
      'draft',
      'published',
      'archived',
      'paid',
      'pending_payment',
      'confirmed',
      'preparing',
      'shipped',
      'delivered',
      'cancelled',
      'returned',
      'expired',
    }.contains(text))
      return statusLabel(text);
    if (text == 'rubika') return 'روبیکا';
    if (text == 'sms') return 'پیامک';
    if (RegExp(r'^\d{4}-\d{2}-\d{2}T').hasMatch(text))
      return activityTime(text);
    // Permission identifiers retain their stable code beside a Persian category.
    if (text.contains('.') &&
        !text.contains('/') &&
        RegExp(r'^[a-z_]+\.[a-z_.]+$').hasMatch(text)) {
      final category =
          {
            'products': 'محصولات',
            'orders': 'سفارش‌ها',
            'customers': 'مشتریان',
            'marketing': 'بازاریابی',
            'reports': 'گزارش‌ها',
            'staff': 'کارکنان',
            'system': 'سیستم',
            'store': 'ظاهر سایت',
            'security': 'امنیت',
            'loyalty': 'باشگاه',
          }[text.split('.').first];
      if (category != null)
        return '$category: ${const {'view': 'مشاهده', 'create': 'افزودن', 'edit': 'ویرایش', 'archive': 'بایگانی', 'change_price': 'تغییر قیمت', 'change_stock': 'تغییر موجودی', 'publish': 'انتشار', 'status': 'تغییر وضعیت', 'cancel': 'لغو', 'refund': 'بازپرداخت', 'view_contact': 'مشاهدهٔ تماس', 'message': 'ارسال پیام', 'export': 'خروجی', 'send': 'ارسال', 'templates': 'قالب‌ها', 'manage': 'مدیریت', 'financial': 'اطلاعات مالی', 'activity': 'فعالیت‌ها', 'content': 'محتوا', 'monitor': 'وضعیت سرور', 'backup': 'پشتیبان‌گیری', 'release': 'انتشار نسخه'}[text.split('.').last] ?? 'دسترسی'}';
    }
    return text;
  }
}
