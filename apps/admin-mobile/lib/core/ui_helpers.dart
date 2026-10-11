import 'package:flutter/material.dart';
import 'paniz_theme.dart';

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

Color statusColor(BuildContext context, String? status) => switch (status) {
      'paid' || 'delivered' || 'published' => context.paniz.success,
      'pending_payment' || 'preparing' || 'draft' => context.paniz.warning,
      'cancelled' || 'expired' || 'returned' || 'archived' => context.paniz.error,
      _ => context.paniz.primary,
    };

Widget statusPill(BuildContext context, String? status, {bool dense = false}) {
  final color = statusColor(context, status);
  return Container(
    padding: EdgeInsets.symmetric(horizontal: dense ? 9 : 11, vertical: dense ? 5 : 7),
    decoration: BoxDecoration(color: color.withValues(alpha: .13), borderRadius: BorderRadius.circular(30)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(statusLabel(status), style: TextStyle(color: color, fontSize: dense ? 10 : 11, fontWeight: FontWeight.w800)),
    ]),
  );
}

void showAppMessage(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? context.paniz.error : context.paniz.primary,
    ));
}

Widget sectionTitle(String title, {Widget? trailing}) => Row(
      children: [
        Expanded(child: Builder(builder: (context) => Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: context.paniz.ink)))),
        if (trailing != null) trailing,
      ],
    );

class PanizPageHeader extends StatelessWidget {
  const PanizPageHeader({super.key, required this.title, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.paniz.muted, height: 1.45)),
        ],
      ])),
      if (trailing != null) ...[
        const SizedBox(width: 12),
        trailing!,
      ],
    ]),
  );
}

class PanizEmptyState extends StatelessWidget {
  const PanizEmptyState({super.key, required this.icon, required this.title, this.description, this.action});
  final IconData icon;
  final String title;
  final String? description;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(color: context.paniz.primarySoft, borderRadius: BorderRadius.circular(20)),
          child: Icon(icon, color: context.paniz.primary, size: 28),
        ),
        const SizedBox(height: 14),
        Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        if (description != null) ...[
          const SizedBox(height: 6),
          Text(description!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.paniz.muted, height: 1.5)),
        ],
        if (action != null) ...[
          const SizedBox(height: 16),
          action!,
        ],
      ]),
    ),
  );
}

class PanizSkeletonBlock extends StatelessWidget {
  const PanizSkeletonBlock({super.key, this.width, this.height = 16, this.radius = 8});
  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(color: context.paniz.line.withValues(alpha: .75), borderRadius: BorderRadius.circular(radius)),
  );
}

String shamsiDate(DateTime date) {
  const monthNames = ['فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور', 'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند'];
  const weekdays = ['دوشنبه', 'سه‌شنبه', 'چهارشنبه', 'پنجشنبه', 'جمعه', 'شنبه', 'یکشنبه'];
  final converted = _gregorianToJalali(date.year, date.month, date.day);
  return '${weekdays[date.weekday - 1]}، ${persianNumber(converted.$3)} ${monthNames[converted.$2 - 1]} ${persianNumber(converted.$1)}';
}

(int, int, int) _gregorianToJalali(int gy, int gm, int gd) {
  const gregorianMonthDays = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  var days = 355666 + 365 * gy + ((gy + 3) ~/ 4) - ((gy + 99) ~/ 100) + ((gy + 399) ~/ 400) + gd;
  for (var month = 0; month < gm - 1; month++) {
    days += gregorianMonthDays[month];
  }
  if (gm > 2 && ((gy % 4 == 0 && gy % 100 != 0) || gy % 400 == 0)) days++;
  var jy = -1595 + 33 * (days ~/ 12053);
  days %= 12053;
  jy += 4 * (days ~/ 1461);
  days %= 1461;
  if (days > 365) {
    jy += (days - 1) ~/ 365;
    days = (days - 1) % 365;
  }
  final jm = days < 186 ? 1 + days ~/ 31 : 7 + (days - 186) ~/ 30;
  final jd = days < 186 ? 1 + days % 31 : 1 + (days - 186) % 30;
  return (jy, jm, jd);
}
