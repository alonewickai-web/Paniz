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
  final _username = TextEditingController(text: 'erfan');
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      await ref.read(authProvider.notifier).login(_username.text, _password.text);
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
                      const Center(child: Text('ورود به پنل مدیریت فروشگاه', style: TextStyle(color: panizMuted))),
                      const SizedBox(height: 28),
                      TextFormField(
                        controller: _username,
                        textDirection: TextDirection.ltr,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.username],
                        decoration: InputDecoration(
                          labelText: 'نام کاربری',
                          hintText: 'erfan',
                          prefixIcon: const Icon(Icons.person_outline_rounded),
                        ),
                        validator: (value) => RegExp(r'^[a-zA-Z0-9._-]{3,40}$').hasMatch(value?.trim() ?? '')
                            ? null
                            : 'نام کاربری را وارد کن',
                      ),
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
                        label: Text(_busy ? 'در حال بررسی…' : 'ورود به مدیریت'),
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                      ),
                      const SizedBox(height: 13),
                      Text(
                        'ورود با نام کاربری و گذرواژهٔ مدیر فروشگاه',
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
