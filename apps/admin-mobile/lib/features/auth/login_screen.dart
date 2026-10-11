import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/admin_api.dart';
import '../../core/providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _username = TextEditingController(text: 'erfan');
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _setupKey = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  bool _setupMode = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _phone.dispose();
    _password.dispose();
    _setupKey.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      if (_setupMode) {
        await ref.read(authProvider.notifier).bootstrap(
          setupKey: _setupKey.text.trim(),
          fullName: _name.text.trim(),
          username: _username.text.trim(),
          phone: _phone.text,
          password: _password.text,
        );
      } else {
        await ref.read(authProvider.notifier).login(_username.text, _password.text);
      }
    } catch (error) {
      if (mounted) setState(() => _error = AdminApi.friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(26),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(color: panizMint.withValues(alpha: .42), borderRadius: BorderRadius.circular(22)),
                          child: const Icon(Icons.storefront_rounded, color: panizPrimary, size: 31),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Center(child: Text('PANIZ', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900, letterSpacing: 1.6, color: panizInk))),
                      const SizedBox(height: 7),
                      Center(child: Text(_setupMode ? 'راه‌اندازی مدیر فروشگاه' : 'ورود به پنل مدیریت فروشگاه', style: const TextStyle(color: panizMuted))),
                      const SizedBox(height: 28),
                      if (_setupMode) ...[
                        TextFormField(
                          controller: _setupKey,
                          obscureText: true,
                          decoration: const InputDecoration(labelText: 'کد یک‌بارمصرف راه‌اندازی', prefixIcon: Icon(Icons.key_rounded)),
                          validator: (value) => (value?.trim().length ?? 0) >= 32 ? null : 'کد را از لاگ خصوصی سرویس API وارد کن',
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _name,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(labelText: 'نام مدیر', prefixIcon: Icon(Icons.person_outline_rounded)),
                          validator: (value) => (value?.trim().isNotEmpty ?? false) ? null : 'نام مدیر را وارد کن',
                        ),
                        const SizedBox(height: 14),
                      ],
                      TextFormField(
                        controller: _username,
                        textDirection: TextDirection.ltr,
                        textInputAction: _setupMode ? TextInputAction.next : TextInputAction.next,
                        autofillHints: const [AutofillHints.username],
                        decoration: InputDecoration(
                          labelText: 'نام کاربری یا شمارهٔ همراه',
                          hintText: 'erfan',
                          prefixIcon: const Icon(Icons.person_outline_rounded),
                          helperText: _setupMode ? 'نام کاربری اولیه را بعداً از تنظیمات امنیتی تغییر می‌دهی.' : null,
                        ),
                        validator: (value) => RegExp(r'^(?:[a-zA-Z0-9._-]{3,40}|(?:\+98|0098|0)?9[0-9۰-۹٠-٩]{9})$').hasMatch(value?.trim() ?? '')
                            ? null
                            : 'نام کاربری یا شمارهٔ همراه مدیر را وارد کن',
                      ),
                      if (_setupMode) ...[
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          textDirection: TextDirection.ltr,
                          autofillHints: const [AutofillHints.telephoneNumber],
                          decoration: const InputDecoration(labelText: 'شمارهٔ همراه بازیابی', hintText: '09121234567', prefixIcon: Icon(Icons.phone_rounded)),
                          validator: (value) {
                            final phone = _asciiDigits(value ?? '').replaceAll(' ', '');
                            return RegExp(r'^(?:\+98|0098|0)?9[0-9]{9}$').hasMatch(phone) ? null : 'شمارهٔ همراه معتبر وارد کن';
                          },
                        ),
                      ],
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _password,
                        obscureText: _obscure,
                        textDirection: TextDirection.ltr,
                        autofillHints: const [AutofillHints.password],
                        decoration: InputDecoration(
                          labelText: 'گذرواژه',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            tooltip: _obscure ? 'نمایش گذرواژه' : 'پنهان‌کردن گذرواژه',
                            onPressed: () => setState(() => _obscure = !_obscure),
                            icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          ),
                        ),
                        validator: (value) {
                          final password = value ?? '';
                          if (password.isEmpty) return 'گذرواژه را وارد کن';
                          if (_setupMode && password.length < 12) return 'گذرواژهٔ مدیر باید دست‌کم ۱۲ نویسه باشد';
                          return null;
                        },
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Text(_error!, style: const TextStyle(color: Color(0xFFDC2626)), textAlign: TextAlign.center),
                      ],
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _busy ? null : _submit,
                        icon: _busy
                            ? const SizedBox.square(dimension: 17, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.login_rounded),
                        label: Text(_busy ? 'در حال بررسی…' : _setupMode ? 'ساخت حساب مدیر' : 'ورود به مدیریت'),
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                      ),
                      const SizedBox(height: 13),
                      TextButton(
                        onPressed: _busy ? null : () => setState(() { _setupMode = !_setupMode; _error = null; }),
                        child: Text(_setupMode ? 'بازگشت به ورود مدیر' : 'راه‌اندازی اولیهٔ مدیر'),
                      ),
                      Text(
                        _setupMode
                            ? 'کد یک‌بارمصرف در لاگ خصوصی API ثبت شده است؛ پس از ساخت مدیر، کد دیگر قابل استفاده نیست.'
                            : 'ورود فقط برای حساب مدیر فروشگاه فعال است.',
                        style: const TextStyle(fontSize: 12, color: panizMuted),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

String _asciiDigits(String value) {
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  return value.replaceAllMapped(RegExp(r'[۰-۹٠-٩]'), (match) {
    final character = match[0]!;
    final index = persian.indexOf(character);
    return '${index >= 0 ? index : arabic.indexOf(character)}';
  });
}
