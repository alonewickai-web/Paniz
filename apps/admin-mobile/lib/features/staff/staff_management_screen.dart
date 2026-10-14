import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/admin_api.dart';
import '../../core/admin_avatar.dart';
import '../../core/paniz_theme.dart';
import '../../core/providers.dart';
import '../../core/ui_helpers.dart';
import '../activity/audit_log_screen.dart';

class StaffManagementScreen extends ConsumerStatefulWidget {
  const StaffManagementScreen({super.key});
  @override
  ConsumerState<StaffManagementScreen> createState() =>
      _StaffManagementScreenState();
}

class _StaffManagementScreenState extends ConsumerState<StaffManagementScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _active = '';
  List<JsonMap> _staff = [];
  int _page = 1;
  int _total = 0;
  int _request = 0;
  bool _loading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(adminApiProvider)
          .staff(query: _search.text, active: _active, page: _page);
      if (!mounted || request != _request) return;
      setState(() {
        _staff =
            (result['data'] as List)
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList();
        _total = (result['meta']['total'] as num).toInt();
      });
    } catch (error) {
      if (mounted && request == _request)
        setState(() => _error = AdminApi.friendlyError(error));
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _edit([JsonMap? staff]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => StaffEditorScreen(staff: staff)),
    );
    if (saved == true && mounted) _load();
  }

  Future<void> _action(JsonMap staff, String action) async {
    if (action == 'activity') {
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder:
              (_) => Scaffold(
                appBar: AppBar(title: Text('فعالیت‌های ${staff['fullName']}')),
                body: AuditLogScreen(adminId: '${staff['id']}'),
              ),
        ),
      );
      return;
    }
    final reset = action == 'reset';
    final active = staff['isActive'] != true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              reset
                  ? 'تغییر گذرواژهٔ کارمند'
                  : active
                  ? 'فعال‌کردن حساب'
                  : 'غیرفعال‌کردن حساب',
            ),
            content: Text(
              reset
                  ? 'گذرواژهٔ موقت جدید ایجاد و همهٔ نشست‌های این کارمند بسته می‌شود.'
                  : active
                  ? 'حساب با دسترسی‌های ذخیره‌شده فعال شود؟'
                  : 'کارمند بلافاصله از تمام دستگاه‌ها خارج می‌شود.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('انصراف'),
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
      if (reset) {
        final result = await ref
            .read(adminApiProvider)
            .resetStaffPassword('${staff['id']}');
        if (mounted)
          await showTemporaryPassword(
            context,
            '${staff['username']}',
            '${result['temporaryPassword']}',
          );
      } else {
        await ref.read(adminApiProvider).saveStaff({
          'isActive': active,
        }, id: '${staff['id']}');
        if (mounted)
          showAppMessage(
            context,
            active ? 'حساب فعال شد.' : 'حساب غیرفعال شد.',
          );
      }
      if (mounted) _load();
    } catch (error) {
      if (mounted)
        showAppMessage(context, AdminApi.friendlyError(error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _load,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        FilledButton.icon(
          onPressed: () => _edit(),
          icon: const Icon(Icons.person_add_alt_outlined),
          label: const Text('افزودن کارمند'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _search,
          decoration: const InputDecoration(
            hintText: 'جست‌وجو با نام یا نام کاربری',
            prefixIcon: Icon(Icons.search_outlined),
          ),
          onChanged: (_) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 350), () {
              _page = 1;
              _load();
            });
          },
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            for (final item
                in {'': 'همه', 'true': 'فعال', 'false': 'غیرفعال'}.entries)
              ChoiceChip(
                label: Text(item.value),
                selected: _active == item.key,
                onSelected: (_) {
                  setState(() {
                    _active = item.key;
                    _page = 1;
                  });
                  _load();
                },
              ),
          ],
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
        if (!_loading && _error == null && _staff.isEmpty)
          const PanizEmptyState(
            icon: Icons.people_outline,
            title: 'کارمندی پیدا نشد',
            description: 'حساب همکاران را با دسترسی مناسب ایجاد کنید.',
          ),
        ..._staff.map(
          (staff) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                leading: AdminAvatar(
                  name: '${staff['fullName']}',
                  path: staff['avatarPath'] as String?,
                ),
                title: Text(
                  '${staff['fullName']}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '@${staff['username']}',
                      textDirection: TextDirection.ltr,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      staff['isActive'] != true
                          ? 'غیرفعال'
                          : staff['mustChangePassword'] == true
                          ? 'در انتظار اولین ورود'
                          : 'فعال',
                      style: TextStyle(
                        color:
                            staff['isActive'] == true
                                ? context.paniz.primary
                                : context.paniz.error,
                        fontSize: 12,
                      ),
                    ),
                    if (staff['lastActivityAt'] != null)
                      Text(
                        'آخرین فعالیت: ${activityTime(staff['lastActivityAt'])}',
                        style: TextStyle(
                          color: context.paniz.muted,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
                onTap: () => _edit(staff),
                trailing:
                    '${staff['role']}' == 'staff'
                        ? PopupMenuButton<String>(
                          onSelected: (value) => _action(staff, value),
                          itemBuilder:
                              (_) => [
                                PopupMenuItem(
                                  value: 'toggle',
                                  child: Text(
                                    staff['isActive'] == true
                                        ? 'غیرفعال‌کردن'
                                        : 'فعال‌کردن',
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'reset',
                                  child: Text('گذرواژهٔ موقت جدید'),
                                ),
                                if (ref
                                        .read(authProvider)
                                        .asData
                                        ?.value
                                        ?.can('staff.activity') ==
                                    true)
                                  const PopupMenuItem(
                                    value: 'activity',
                                    child: Text('تاریخچهٔ فعالیت'),
                                  ),
                              ],
                        )
                        : const Icon(Icons.verified_user_outlined),
              ),
            ),
          ),
        ),
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

class StaffEditorScreen extends ConsumerStatefulWidget {
  const StaffEditorScreen({super.key, this.staff});
  final JsonMap? staff;
  @override
  ConsumerState<StaffEditorScreen> createState() => _StaffEditorScreenState();
}

class _StaffEditorScreenState extends ConsumerState<StaffEditorScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: '${widget.staff?['fullName'] ?? ''}',
  );
  late final _username = TextEditingController(
    text: '${widget.staff?['username'] ?? ''}',
  );
  late final _phone = TextEditingController(
    text: '${widget.staff?['phone'] ?? ''}',
  );
  late final Set<String> _permissions =
      (widget.staff?['permissions'] as List? ?? [])
          .map((value) => '$value')
          .toSet();
  List<JsonMap> _groups = [];
  int _step = 0;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final groups = await ref.read(adminApiProvider).permissionCatalog();
      if (mounted) setState(() => _groups = groups);
    } catch (error) {
      if (mounted) setState(() => _error = AdminApi.friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _template(String prefix) {
    final admin = ref.read(authProvider).asData?.value;
    final keys = _groups.expand(
      (group) => (group['permissions'] as List).whereType<Map>().map(
        (row) => '${row['key']}',
      ),
    );
    setState(() {
      _permissions.clear();
      _permissions.addAll(
        keys.where((key) => key.startsWith(prefix) && admin?.can(key) == true),
      );
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await ref.read(adminApiProvider).saveStaff({
        'fullName': _name.text.trim(),
        if (widget.staff == null) 'username': _username.text.trim(),
        'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        'permissions': _permissions.toList(),
      }, id: widget.staff == null ? null : '${widget.staff!['id']}');
      if (!mounted) return;
      if (widget.staff == null)
        await showTemporaryPassword(
          context,
          _username.text.trim(),
          '${result['temporaryPassword']}',
        );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = AdminApi.friendlyError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = ref.watch(authProvider).asData?.value;
    final editable = widget.staff == null || widget.staff!['role'] == 'staff';
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.staff == null ? 'افزودن کارمند' : 'ویرایش کارمند'),
      ),
      body: SafeArea(
        child:
            _loading
                ? const Center(child: CircularProgressIndicator())
                : Stepper(
                  currentStep: _step,
                  type: StepperType.vertical,
                  onStepContinue:
                      _saving || !editable
                          ? null
                          : () {
                            if (_step == 0 && !_form.currentState!.validate())
                              return;
                            if (_step < 2)
                              setState(() => _step++);
                            else
                              _save();
                          },
                  onStepCancel:
                      _step > 0 && !_saving
                          ? () => setState(() => _step--)
                          : null,
                  controlsBuilder:
                      (context, controls) => Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                onPressed: controls.onStepContinue,
                                child: Text(
                                  _saving
                                      ? 'در حال ذخیره…'
                                      : _step == 2
                                      ? 'ذخیرهٔ حساب و دسترسی‌ها'
                                      : 'مرحلهٔ بعد',
                                ),
                              ),
                            ),
                            if (_step > 0)
                              Padding(
                                padding: const EdgeInsetsDirectional.only(
                                  start: 8,
                                ),
                                child: TextButton(
                                  onPressed: controls.onStepCancel,
                                  child: const Text('قبلی'),
                                ),
                              ),
                          ],
                        ),
                      ),
                  steps: [
                    Step(
                      title: const Text('اطلاعات کارمند'),
                      isActive: _step >= 0,
                      content: Form(
                        key: _form,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _name,
                              enabled: editable,
                              decoration: const InputDecoration(
                                labelText: 'نام و نام خانوادگی',
                              ),
                              validator:
                                  (value) =>
                                      (value?.trim().length ?? 0) >= 2
                                          ? null
                                          : 'نام کامل را وارد کنید.',
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _username,
                              enabled: widget.staff == null,
                              textDirection: TextDirection.ltr,
                              decoration: const InputDecoration(
                                labelText: 'نام کاربری',
                              ),
                              validator:
                                  (value) =>
                                      RegExp(
                                            r'^[a-zA-Z0-9._-]{3,80}$',
                                          ).hasMatch(value?.trim() ?? '')
                                          ? null
                                          : 'نام کاربری ۳ تا ۸۰ نویسهٔ لاتین لازم است.',
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _phone,
                              enabled: editable,
                              keyboardType: TextInputType.phone,
                              textDirection: TextDirection.ltr,
                              decoration: const InputDecoration(
                                labelText: 'شماره تماس (اختیاری)',
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'ورود با گذرواژهٔ موقت است. کارمند در اولین ورود باید آن را تغییر دهد.',
                            ),
                          ],
                        ),
                      ),
                    ),
                    Step(
                      title: const Text('دسترسی‌ها'),
                      isActive: _step >= 1,
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (editable)
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                ActionChip(
                                  label: const Text('مسئول محصولات'),
                                  onPressed: () => _template('products.'),
                                ),
                                ActionChip(
                                  label: const Text('مسئول سفارش‌ها'),
                                  onPressed: () => _template('orders.'),
                                ),
                                ActionChip(
                                  label: const Text('بازاریابی'),
                                  onPressed: () => _template('marketing.'),
                                ),
                                ActionChip(
                                  label: const Text('پاک‌کردن انتخاب‌ها'),
                                  onPressed:
                                      () =>
                                          setState(() => _permissions.clear()),
                                ),
                              ],
                            ),
                          const SizedBox(height: 12),
                          ..._groups.map(
                            (group) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Card(
                                child: ExpansionTile(
                                  title: Text(
                                    '${group['title']}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  children:
                                      (group['permissions'] as List)
                                          .whereType<Map>()
                                          .map((permission) {
                                            final key = '${permission['key']}';
                                            return CheckboxListTile(
                                              title: Text(
                                                '${permission['title']}',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                ),
                                              ),
                                              value: _permissions.contains(key),
                                              onChanged:
                                                  editable &&
                                                          admin?.can(key) ==
                                                              true
                                                      ? (selected) => setState(
                                                        () {
                                                          selected == true
                                                              ? _permissions
                                                                  .add(key)
                                                              : _permissions
                                                                  .remove(key);
                                                        },
                                                      )
                                                      : null,
                                            );
                                          })
                                          .toList(),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Step(
                      title: const Text('تأیید حساب'),
                      isActive: _step >= 2,
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _name.text,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '@${_username.text}',
                            textDirection: TextDirection.ltr,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${persianNumber(_permissions.length)} دسترسی انتخاب شده است.',
                          ),
                          ..._groups
                              .expand(
                                (group) =>
                                    (group['permissions'] as List)
                                        .whereType<Map>(),
                              )
                              .where(
                                (permission) => _permissions.contains(
                                  '${permission['key']}',
                                ),
                              )
                              .map(
                                (permission) => ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(
                                    Icons.check_circle_outline,
                                    color: context.paniz.primary,
                                  ),
                                  title: Text('${permission['title']}'),
                                ),
                              ),
                          if (_permissions.isEmpty)
                            const Text(
                              'این حساب هیچ بخش مدیریتی را نمی‌بیند. دسترسی‌ها را می‌توانید بعداً تعیین کنید.',
                            ),
                          if (widget.staff != null && editable)
                            const Text(
                              'با ذخیرهٔ مجوزها، نشست‌های قبلی کارمند بسته می‌شوند تا با مجوزهای جدید وارد شود.',
                            ),
                          if (!editable)
                            const Text(
                              'دسترسی مدیر اصلی از این صفحه قابل تغییر نیست.',
                            ),
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Text(
                                _error!,
                                style: TextStyle(color: context.paniz.error),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}

Future<void> showTemporaryPassword(
  BuildContext context,
  String username,
  String password,
) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder:
      (context) => AlertDialog(
        title: const Text('اطلاعات ورود موقت'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'گذرواژه فقط یک‌بار نمایش داده می‌شود. آن را خصوصی در اختیار همین کارمند قرار دهید.',
            ),
            const SizedBox(height: 16),
            SelectableText(username, textDirection: TextDirection.ltr),
            const SizedBox(height: 8),
            SelectableText(
              password,
              textDirection: TextDirection.ltr,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: password));
                if (context.mounted) showAppMessage(context, 'گذرواژه کپی شد.');
              },
              icon: const Icon(Icons.copy_outlined),
              label: const Text('کپی گذرواژه'),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ذخیره کردم'),
          ),
        ],
      ),
);
