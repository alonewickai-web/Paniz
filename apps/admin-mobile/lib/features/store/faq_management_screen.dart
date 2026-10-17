import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/admin_api.dart';
import '../../core/providers.dart';
import '../../core/ui_helpers.dart';

class FaqManagementScreen extends ConsumerStatefulWidget {
  const FaqManagementScreen({super.key});

  @override
  ConsumerState<FaqManagementScreen> createState() =>
      _FaqManagementScreenState();
}

class _FaqManagementScreenState extends ConsumerState<FaqManagementScreen> {
  final List<_FaqControllers> _faqs = [];
  bool _initialized = false;
  bool _saving = false;

  static const _defaultFaqs = [
    (
      'چطور سایز مناسب را انتخاب کنم؟',
      'در صفحهٔ هر محصول، سایزهای موجود مشخص هستند. جدول اندازه‌گیری پس از ثبت اندازه‌های واقعی هر مدل نمایش داده می‌شود؛ اگر برای محصولی جدول نمی‌بینی، اطلاعات تکمیلی هنوز ثبت نشده است.',
    ),
    (
      'آیا محصولات موجود هستند؟',
      'موجودی رنگ و سایز از دیتابیس بررسی می‌شود. هنگام ثبت درخواست خرید نیز موجودی دوباره کنترل و برای مدت کوتاهی رزرو می‌شود.',
    ),
    (
      'چطور هزینه و وضعیت سفارش را ببینم؟',
      'هزینهٔ ارسال بر اساس روش فعال فروشگاه و مبلغ سفارش در تسویه‌حساب محاسبه می‌شود. برای دیدن وضعیت سفارش ثبت‌شده، شمارهٔ سفارش و تلفن گیرنده را در صفحهٔ حساب کاربری وارد کن.',
    ),
    (
      'پرداخت آنلاین چطور انجام می‌شود؟',
      'درگاه پرداخت هنوز به پروژه متصل نشده است. ثبت درخواست خرید در نسخهٔ فعلی تراکنش بانکی انجام نمی‌دهد و پرداخت‌شده تلقی نمی‌شود.',
    ),
  ];

  @override
  void dispose() {
    for (final faq in _faqs) {
      faq.dispose();
    }
    super.dispose();
  }

  void _initialize(JsonMap config) {
    if (_initialized) return;
    final rawSettings = config['faqs'];
    final rawFaqs = rawSettings is Map ? rawSettings['faqs'] : null;
    if (rawFaqs is List) {
      for (final item in rawFaqs) {
        if (item is Map) {
          _faqs.add(
            _FaqControllers(
              question: '${item['question'] ?? ''}',
              answer: '${item['answer'] ?? ''}',
            ),
          );
        }
      }
    }
    if (_faqs.isEmpty) {
      _faqs.addAll(
        _defaultFaqs.map((item) => _FaqControllers(question: item.$1, answer: item.$2)),
      );
    }
    _initialized = true;
  }

  Future<void> _refresh() async {
    _initialized = false;
    for (final faq in _faqs) {
      faq.dispose();
    }
    _faqs.clear();
    ref.invalidate(storeConfigurationProvider);
    await ref.read(storeConfigurationProvider.future);
  }

  void _addFaq() {
    if (_faqs.length >= 50) {
      showAppMessage(context, 'حداکثر ۵۰ پرسش می‌توانی ثبت کنی.', error: true);
      return;
    }
    setState(() => _faqs.add(_FaqControllers()));
  }

  void _removeFaq(int index) {
    if (_faqs.length <= 1) {
      showAppMessage(context, 'دست‌کم یک پرسش باید باقی بماند.', error: true);
      return;
    }
    setState(() => _faqs.removeAt(index).dispose());
  }

  Future<void> _save() async {
    if (_saving) return;
    final faqs = _faqs
        .map(
          (faq) => {
            'question': faq.question.text.trim(),
            'answer': faq.answer.text.trim(),
          },
        )
        .toList(growable: false);
    if (faqs.any(
      (faq) =>
          (faq['question'] as String).isEmpty ||
          (faq['answer'] as String).isEmpty,
    )) {
      showAppMessage(context, 'پرسش و پاسخ همهٔ موارد را کامل کن.', error: true);
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(adminApiProvider).updateStoreFaqs({'faqs': faqs});
      ref.invalidate(storeConfigurationProvider);
      if (mounted) showAppMessage(context, 'پرسش‌های پرتکرار ذخیره شد');
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
                title: 'پرسش‌های پرتکرار',
                subtitle: 'سؤال و پاسخ‌هایی را مدیریت کن که در راهنمای خرید سایت نمایش داده می‌شوند.',
                trailing: Icon(
                  Icons.quiz_outlined,
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
                          'پرسش‌های ذخیره‌شده در صفحهٔ «پرسش‌های پرتکرار» سایت قرار می‌گیرند. اگر هنوز موردی ذخیره نشده باشد، پرسش‌های فعلی سایت برای ویرایش نمایش داده می‌شوند.',
                          style: TextStyle(height: 1.65),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              sectionTitle(
                'پرسش‌ها و پاسخ‌ها',
                trailing: TextButton.icon(
                  onPressed: _saving ? null : _addFaq,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('افزودن پرسش'),
                ),
              ),
              const SizedBox(height: 10),
              for (var index = 0; index < _faqs.length; index++) ...[
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
                                'پرسش ${persianNumber(index + 1)}',
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                            IconButton(
                              tooltip: 'حذف پرسش',
                              onPressed: _saving ? null : () => _removeFaq(index),
                              icon: const Icon(Icons.delete_outline_rounded),
                            ),
                          ],
                        ),
                        TextField(
                          controller: _faqs[index].question,
                          maxLength: 240,
                          decoration: const InputDecoration(
                            labelText: 'پرسش',
                            hintText: 'سؤال مشتری را کوتاه و روشن بنویس',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _faqs[index].answer,
                          minLines: 3,
                          maxLines: 8,
                          maxLength: 5000,
                          decoration: const InputDecoration(
                            labelText: 'پاسخ',
                            hintText: 'پاسخ کامل و قابل فهم برای مشتری بنویس',
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
                label: Text(_saving ? 'در حال ذخیره…' : 'ذخیرهٔ پرسش‌های پرتکرار'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FaqControllers {
  _FaqControllers({String question = '', String answer = ''})
    : question = TextEditingController(text: question),
      answer = TextEditingController(text: answer);

  final TextEditingController question;
  final TextEditingController answer;

  void dispose() {
    question.dispose();
    answer.dispose();
  }
}
