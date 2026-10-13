import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/admin_api.dart';
import '../../core/providers.dart';
import '../../core/ui_helpers.dart';

class SecuritySettingsScreen extends ConsumerStatefulWidget {
  const SecuritySettingsScreen({super.key, required this.admin});
  final AdminIdentity admin;

  @override
  ConsumerState<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends ConsumerState<SecuritySettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPassword = TextEditingController();
  final _username = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false;
  bool _hideCurrent = true;
  bool _hideNew = true;
  String? _error;

  @override
  void dispose() {
    _currentPassword.dispose();
    _username.dispose();
    _newPassword.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final username = _username.text.trim();
    final newPassword = _newPassword.text;
    if (username.isEmpty && newPassword.isEmpty) {
      setState(() => _error = 'نام کاربری یا گذرواژهٔ جدید را وارد کن.');
      return;
    }

    setState(() { _busy = true; _error = null; });
    try {
      await ref.read(adminApiProvider).updateCredentials(
        currentPassword: _currentPassword.text,
        username: username.isEmpty ? null : username,
        newPassword: newPassword.isEmpty ? null : newPassword,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          icon: Icon(Icons.verified_user_rounded, color: Theme.of(context).colorScheme.primary, size: 34),
          title: const Text('اطلاعات ورود تغییر کرد'),
          content: const Text('اطلاعات جدید ذخیره شد و نشست دستگاه‌های دیگر بسته شد.'),
          actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('ادامه'))],
        ),
      );
      final authController = ref.read(authProvider.notifier);
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      await authController.refreshIdentity();
    } catch (error) {
      if (mounted) setState(() => _error = AdminApi.friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Card(color: Theme.of(context).colorScheme.primaryContainer, child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.shield_outlined, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('حساب مدیر فروشگاه', style: TextStyle(fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 5),
            Text('نام کاربری فعلی: ${widget.admin.username}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
            const SizedBox(height: 4),
            Text(widget.admin.mustChangePassword ? 'برای فعال‌شدن حساب، گذرواژهٔ موقت را با یک گذرواژهٔ شخصی جایگزین کنید.' : 'برای هر تغییر، گذرواژهٔ فعلی لازم است. پس از ذخیره، نشست دستگاه‌های دیگر بسته می‌شود.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12, height: 1.5)),
          ])),
        ]),
      )),
      const SizedBox(height: 14),
      Card(child: Padding(
        padding: const EdgeInsets.all(18),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('تغییر اطلاعات ورود', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 15),
            TextFormField(
              controller: _currentPassword,
              obscureText: _hideCurrent,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: 'گذرواژهٔ فعلی',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(onPressed: () => setState(() => _hideCurrent = !_hideCurrent), icon: Icon(_hideCurrent ? Icons.visibility_outlined : Icons.visibility_off_outlined)),
              ),
              validator: (value) => (value?.isNotEmpty ?? false) ? null : 'گذرواژهٔ فعلی را وارد کن',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _username,
              textDirection: TextDirection.ltr,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'نام کاربری جدید', helperText: 'برای نگه‌داشتن نام فعلی، این قسمت را خالی بگذار.', prefixIcon: Icon(Icons.person_outline_rounded)),
              validator: (value) {
                final next = value?.trim() ?? '';
                if (next.isEmpty) return null;
                return RegExp(r'^[a-zA-Z0-9._-]{3,40}$').hasMatch(next) ? null : 'نام کاربری باید ۳ تا ۴۰ نویسهٔ مجاز داشته باشد';
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _newPassword,
              obscureText: _hideNew,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: 'گذرواژهٔ جدید',
                helperText: 'حداقل ۱۲ نویسه؛ برای حفظ گذرواژه فعلی خالی بگذار.',
                prefixIcon: const Icon(Icons.password_rounded),
                suffixIcon: IconButton(onPressed: () => setState(() => _hideNew = !_hideNew), icon: Icon(_hideNew ? Icons.visibility_outlined : Icons.visibility_off_outlined)),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return widget.admin.mustChangePassword ? 'گذرواژهٔ جدید را وارد کنید.' : null;
                return value.length >= 12 ? null : 'گذرواژهٔ جدید باید دست‌کم ۱۲ نویسه باشد';
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmation,
              obscureText: true,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: 'تکرار گذرواژهٔ جدید', prefixIcon: Icon(Icons.check_circle_outline_rounded)),
              validator: (value) {
                if (_newPassword.text.isEmpty && (value?.isEmpty ?? true)) return null;
                return value == _newPassword.text ? null : 'تکرار گذرواژه یکسان نیست';
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error), textAlign: TextAlign.center),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : _save,
              icon: _busy ? const SizedBox.square(dimension: 17, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_outlined),
              label: Text(_busy ? 'در حال ذخیره…' : 'ذخیرهٔ اطلاعات ورود'),
            ),
          ]),
        ),
      )),
      const SizedBox(height: 12),
      Card(child: ListTile(
        leading: Icon(Icons.phonelink_lock_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant),
        title: Text('تأیید دومرحله‌ای'),
        subtitle: Text('فعالسازی TOTP هنوز به API و اپ متصل نشده است.'),
      )),
      Card(child: ref.watch(biometricEnabledProvider).when(
        loading: () => const ListTile(leading: Icon(Icons.fingerprint_rounded), title: Text('ورود با اثر انگشت'), trailing: SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))),
        error: (_, __) => const ListTile(leading: Icon(Icons.fingerprint_rounded), title: Text('ورود با اثر انگشت')),
        data: (enabled) => SwitchListTile.adaptive(
          secondary: Icon(Icons.fingerprint_rounded, color: Theme.of(context).colorScheme.primary),
          title: const Text('ورود با اثر انگشت'),
          subtitle: const Text('هنگام بازشدن برنامه از هویت دستگاه استفاده می‌شود.'),
          value: enabled,
          onChanged: _busy ? null : (value) async {
            setState(() { _busy = true; _error = null; });
            try {
              final active = await ref.read(authProvider.notifier).setBiometricsEnabled(value);
              ref.invalidate(biometricEnabledProvider);
              if (!value || active) {
                if (mounted) showAppMessage(context, value ? 'ورود با اثر انگشت فعال شد.' : 'ورود با اثر انگشت غیرفعال شد.');
              } else if (mounted) {
                setState(() => _error = 'تأیید اثر انگشت کامل نشد.');
              }
            } catch (error) {
              if (mounted) setState(() => _error = AdminApi.friendlyError(error));
            } finally {
              if (mounted) setState(() => _busy = false);
            }
          },
        ),
      )),
      if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
    ],
  );
}
