import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/admin_api.dart';
import '../../core/providers.dart';
import '../../core/ui_helpers.dart';

class FinancialReportScreen extends ConsumerStatefulWidget {
  const FinancialReportScreen({super.key});
  @override
  ConsumerState<FinancialReportScreen> createState() => _FinancialReportScreenState();
}

class _FinancialReportScreenState extends ConsumerState<FinancialReportScreen> {
  String _range = '7';
  static const _options = [('7', '۷ روز'), ('10', '۱۰ روز'), ('30', '۳۰ روز'), ('month', 'این ماه')];

  @override
  Widget build(BuildContext context) {
    final report = ref.watch(financeReportProvider(_range));
    return report.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(AdminApi.friendlyError(error), textAlign: TextAlign.center), const SizedBox(height: 10), FilledButton(onPressed: () => ref.invalidate(financeReportProvider(_range)), child: const Text('تلاش دوباره'))]))),
      data: (data) {
        final daily = (data['daily'] as List? ?? const []).whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
        final totals = data['totals'] is Map ? Map<String, dynamic>.from(data['totals'] as Map) : <String, dynamic>{};
        return RefreshIndicator(onRefresh: () async => ref.invalidate(financeReportProvider(_range)), child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(16), children: [
          const Text('گزارش مالی فروشگاه', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text('فروش‌های پرداخت‌شده · نمایش مبلغ‌ها به ریال', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          Wrap(spacing: 7, runSpacing: 6, children: _options.map((item) => ChoiceChip(label: Text(item.$2), selected: _range == item.$1, onSelected: (_) => setState(() => _range = item.$1))).toList()),
          const SizedBox(height: 14),
          _SummaryCard(title: 'فروش پرداخت‌شده', amount: totals['salesRial'], icon: Icons.account_balance_wallet_outlined, color: Theme.of(context).colorScheme.primaryContainer),
          _SummaryCard(title: 'بهای خرید کالاهای فروخته‌شده', amount: totals['productCostRial'], icon: Icons.inventory_2_outlined, color: Theme.of(context).colorScheme.secondaryContainer),
          _SummaryCard(title: 'سود ناخالص تخمینی', amount: totals['grossProfitRial'], icon: Icons.trending_up_rounded, color: Theme.of(context).colorScheme.tertiaryContainer),
          Card(child: Padding(padding: const EdgeInsets.fromLTRB(12, 16, 12, 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('روند فروش روزانه', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text('${persianNumber(totals['orderCount'] ?? 0)} سفارش پرداخت‌شده · نمودار به ریال', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            SizedBox(height: 270, width: double.infinity, child: CustomPaint(painter: _FinanceChartPainter(data: daily, grid: Theme.of(context).colorScheme.outlineVariant, line: Theme.of(context).colorScheme.primary, fill: Theme.of(context).colorScheme.primary.withValues(alpha: .12), label: Theme.of(context).colorScheme.onSurfaceVariant))),
            const Center(child: Text('مبالغ به ریال', style: TextStyle(fontSize: 10))),
          ]))),
          const SizedBox(height: 8),
          Text('سود ناخالص از مبلغ پرداخت‌شده منهای بهای خرید ثبت‌شدهٔ محصول محاسبه شده و هزینه‌های عملیاتی را شامل نمی‌شود.', style: TextStyle(fontSize: 11, height: 1.6, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ]));
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.title, required this.amount, required this.icon, required this.color});
  final String title;
  final Object? amount;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [Container(width: 43, height: 43, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: Theme.of(context).colorScheme.primary)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)), const SizedBox(height: 4), Text(groupedNumber(amount ?? 0), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), const Text('ریال', style: TextStyle(fontSize: 10))]))])));
}

class _FinanceChartPainter extends CustomPainter {
  _FinanceChartPainter({required this.data, required this.grid, required this.line, required this.fill, required this.label});
  final List<JsonMap> data;
  final Color grid;
  final Color line;
  final Color fill;
  final Color label;
  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) { _text(canvas, 'داده‌ای برای این بازه نیست', Offset(size.width / 2 - 55, size.height / 2), label, 12); return; }
    const left = 70.0, right = 8.0, top = 12.0, bottom = 76.0;
    final chart = Rect.fromLTRB(left, top, size.width - right, size.height - bottom);
    final values = data.map((item) => _value(item['salesRial'])).toList();
    final maximum = math.max(1, values.fold<int>(0, math.max)).toDouble();
    final gridPaint = Paint()..color = grid.withValues(alpha: .7)..strokeWidth = .7;
    for (var tick = 0; tick <= 4; tick++) {
      final y = chart.bottom - chart.height * tick / 4;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
      _text(canvas, groupedNumber((maximum * tick / 4).round()), Offset(0, y - 7), label, 8);
    }
    final points = <Offset>[];
    for (var index = 0; index < values.length; index++) {
      final x = values.length == 1 ? chart.center.dx : chart.left + chart.width * index / (values.length - 1);
      final y = chart.bottom - chart.height * values[index] / maximum;
      points.add(Offset(x, y));
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1]; final current = points[i];
      final middle = (previous.dx + current.dx) / 2;
      path.cubicTo(middle, previous.dy, middle, current.dy, current.dx, current.dy);
    }
    final area = Path.from(path)..lineTo(points.last.dx, chart.bottom)..lineTo(points.first.dx, chart.bottom)..close();
    canvas.drawPath(area, Paint()..shader = LinearGradient(colors: [fill, fill.withValues(alpha: .02)], begin: Alignment.topCenter, end: Alignment.bottomCenter).createShader(chart));
    canvas.drawPath(path, Paint()..color = line..strokeWidth = 2.6..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
    for (final point in points) canvas.drawCircle(point, 3.2, Paint()..color = line);
    final interval = math.max(1, (data.length / 9).ceil());
    for (var index = 0; index < data.length; index += interval) {
      final x = points[index].dx;
      final date = '${data[index]['dateJalali'] ?? ''}';
      final painter = TextPainter(text: TextSpan(text: date, style: TextStyle(color: label, fontSize: 8)), textDirection: TextDirection.rtl)..layout();
      canvas.save(); canvas.translate(x + 3, chart.bottom + 68); canvas.rotate(-math.pi / 2); painter.paint(canvas, Offset.zero); canvas.restore();
    }
  }
  void _text(Canvas canvas, String value, Offset position, Color color, double size) {
    final painter = TextPainter(text: TextSpan(text: value, style: TextStyle(color: color, fontSize: size)), textDirection: TextDirection.rtl)..layout(maxWidth: 68);
    painter.paint(canvas, position);
  }
  int _value(Object? value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;
  @override
  bool shouldRepaint(covariant _FinanceChartPainter oldDelegate) => oldDelegate.data != data || oldDelegate.line != line || oldDelegate.grid != grid;
}
