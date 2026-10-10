import 'package:flutter/material.dart';

import '../app.dart';

String persianNumber(Object? value) {
  final ascii = '$value';
  const digits = '۰۱۲۳۴۵۶۷۸۹';
  return ascii.replaceAllMapped(RegExp(r'\d'), (match) => digits[int.parse(match[0]!)])
      .replaceAll(',', '٬');
}

String groupedNumber(Object? value) {
  final raw = '$value';
  final number = int.tryParse(raw);
  if (number == null) return persianNumber(value);
  final grouped = number.abs().toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (_) => ',',
      );
  return persianNumber('${number.isNegative ? '-' : ''}$grouped');
}

String toman(Object? value) => '${groupedNumber(value)} تومان';

String statusLabel(String? status) => switch (status) {
      'pending_payment' => 'در انتظار پرداخت',
      'paid' => 'پرداخت‌شده',
      'confirmed' => 'تأییدشده',
      'preparing' => 'در حال آماده‌سازی',
      'shipped' => 'ارسال‌شده',
      'delivered' => 'تحویل‌شده',
      'cancelled' => 'لغوشده',
      'expired' => 'منقضی‌شده',
      'returned' => 'مرجوع‌شده',
      'published' => 'منتشرشده',
      'draft' => 'پیش‌نویس',
      'archived' => 'بایگانی',
      _ => status ?? 'نامشخص',
    };

Color statusColor(String? status) => switch (status) {
      'paid' || 'delivered' || 'published' => const Color(0xFF138A65),
      'pending_payment' || 'preparing' || 'draft' => const Color(0xFFAF6A1B),
      'cancelled' || 'expired' || 'returned' || 'archived' => panizError,
      _ => const Color(0xFF6E5A9D),
    };

void showAppMessage(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? const Color(0xFF9E344B) : const Color(0xFF276E58),
    ));
}

Widget sectionTitle(String title, {Widget? trailing}) => Row(
      children: [
        Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: panizInk))),
        if (trailing != null) trailing,
      ],
    );
