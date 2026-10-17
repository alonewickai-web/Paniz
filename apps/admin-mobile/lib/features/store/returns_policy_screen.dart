import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/admin_api.dart';
import '../../core/providers.dart';
import '../../core/ui_helpers.dart';

class ReturnsPolicyScreen extends ConsumerStatefulWidget {
  const ReturnsPolicyScreen({super.key});

  @override
  ConsumerState<ReturnsPolicyScreen> createState() =>
      _ReturnsPolicyScreenState();
}

class _ReturnsPolicyScreenState extends ConsumerState<ReturnsPolicyScreen> {
  final List<_PolicySectionControllers> _sections = [];
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    for (final section in _sections) {
      section.dispose();
    }
    super.dispose();
  }

  void _initialize(JsonMap config) {
    if (_initialized) return;
    final rawPolicy = config['returnsPolicy'];
    final rawSections = rawPolicy is Map ? rawPolicy['sections'] : null;
    if (rawSections is List) {
      for (final value in rawSections) {
        if (value is Map) {
          _sections.add(
            _PolicySectionControllers(
              heading: '${value['heading'] ?? ''}',
              body: '${value['body'] ?? ''}',
            ),
          );
        }
      }
    }
    if (_sections.isEmpty) _sections.add(_PolicySectionControllers());
    _initialized = true;
  }

  Future<void> _refresh() async {
    _initialized = false;
    for (final section in _sections) {
      section.dispose();
    }
    _sections.clear();
    ref.invalidate(storeConfigurationProvider);
    await ref.read(storeConfigurationProvider.future);
  }

  void _addSection() {
    if (_sections.length >= 20) {
      showAppMessage(context, 'حداکثر ۲۰ بند می‌توانی اضافه کنی.', error: true);
      return;
    }
    setState(() => _sections.add(_PolicySectionControllers()));
  }

  void _removeSection(int index) {
    if (_sections.length <= 1) {
      showAppMessage(context, 'دست‌کم یک بند باید در سیاست باقی بماند.', error: true);
      return;
    }
    setState(() {
      _sections.removeAt(index).dispose();
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final sections = _sections
        .map(
          (section) => {
            'heading': section.heading.text.trim(),
            'body': section.body.text.trim(),
          },
        )
        .toList(growable: false);
    if (sections.any(
      (section) =>
          (section['heading'] as String).isEmpty ||
          (section['body'] as String).isEmpty,
    )) {
      showAppMessage(context, 'عنوان و متن همهٔ بندها را کامل کن.', error: true);
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(adminApiProvider).updateReturnsPolicy({'sections': sections});
      ref.invalidate(storeConfigurationProvider);
      if (mounted) showAppMessage(context, 'سیاست تعویض و مرجوعی ذخیره شد');
    } catch (error) {
      if (mounted) {
        showAppMessage(context, AdminApi.friendlyError(error), error: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(storeConfigurationProvider);
    return config.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          Text(AdminApi.friendlyError(error), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Center(
            child: OutlinedButton(
              onPressed: () => ref.invalidate(storeConfigurationProvider),
              child: const Text('تلاش دوباره'),
            ),
          ),
        ],
      ),
      data: (data) {
        _initialize(data);
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsetsDirectional.fromSTEB(16, 18, 16, 28),
            children: [
              PanizPageHeader(
                title: 'شرایط تعویض و مرجوعی',
                subtitle: 'بندهایی را بنویس که مشتری در صفحهٔ قوانین سایت می‌بیند.',
                trailing: Icon(
                  Icons.assignment_return_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.public_outlined, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'پس از ذخیره، همین بندها در صفحهٔ «تعویض و مرجوعی» سایت نمایش داده می‌شوند.',
                          style: TextStyle(height: 1.65),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              sectionTitle(
                'بندهای سیاست',
                trailing: TextButton.icon(
                  onPressed: _saving ? null : _addSection,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('افزودن بند'),
                ),
              ),
              const SizedBox(height: 10),
              for (var index = 0; index < _sections.length; index++) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'بند ${persianNumber(index + 1)}',
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                            IconButton(
                              tooltip: 'حذف بند',
                              onPressed: _saving ? null : () => _removeSection(index),
                              icon: const Icon(Icons.delete_outline_rounded),
                            ),
                          ],
                        ),
                        TextField(
                          controller: _sections[index].heading,
                          maxLength: 120,
                          decoration: const InputDecoration(
                            labelText: 'عنوان بند',
                            hintText: 'مثلاً مهلت درخواست تعویض',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _sections[index].body,
                          minLines: 3,
                          maxLines: 8,
                          maxLength: 3000,
                          decoration: const InputDecoration(
                            labelText: 'متن شرایط',
                            hintText: 'شرایط را روشن و کامل برای مشتری توضیح بده.',
                            alignLabelWithHint: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? 'در حال ذخیره…' : 'ذخیرهٔ سیاست تعویض و مرجوعی'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PolicySectionControllers {
  _PolicySectionControllers({String heading = '', String body = ''})
    : heading = TextEditingController(text: heading),
      body = TextEditingController(text: body);

  final TextEditingController heading;
  final TextEditingController body;

  void dispose() {
    heading.dispose();
    body.dispose();
  }
}
