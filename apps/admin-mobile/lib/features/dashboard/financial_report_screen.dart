import 'dart:math' as math;
import 'dart:convert';
import 'package:excel/excel.dart'
    as excel_lib
    show Excel, TextCellValue, IntCellValue;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import '../../core/admin_api.dart';
import '../../core/providers.dart';
import '../../core/ui_helpers.dart';

class FinancialReportScreen extends ConsumerStatefulWidget {
  const FinancialReportScreen({super.key});
  @override
  ConsumerState<FinancialReportScreen> createState() =>
      _FinancialReportScreenState();
}

class _FinancialReportScreenState extends ConsumerState<FinancialReportScreen> {
  String _range = '7';
  DateTime? _from;
  DateTime? _to;
  bool _exporting = false;
  static const _options = [
    ('7', '۷ روز'),
    ('10', '۱۰ روز'),
    ('30', '۳۰ روز'),
    ('month', 'این ماه'),
  ];

  String get _reportKey =>
      _from != null && _to != null
          ? 'custom|${_dayKey(_from!)}|${_dayKey(_to!)}'
          : _range;

  Future<void> _pickDate({required bool start}) async {
    final today = Jalali.now();
    final initial = start ? _from : _to;
    final selected = await showPersianDatePicker(
      context: context,
      initialDate: initial == null ? today : Jalali.fromDateTime(initial),
      firstDate: Jalali(1390, 1, 1),
      lastDate: today,
      currentDate: today,
      locale: const Locale('fa', 'IR'),
      textDirection: TextDirection.rtl,
      helpText: start ? 'از تاریخ' : 'تا تاریخ',
      cancelText: 'انصراف',
      confirmText: 'انتخاب',
    );
    if (selected == null || !mounted) return;
    setState(() {
      final value = DateTime(
        selected.toDateTime().year,
        selected.toDateTime().month,
        selected.toDateTime().day,
      );
      if (start) {
        _from = value;
        _to ??= DateTime.now();
      } else {
        _to = value;
        _from ??= value;
      }
      _range = '7';
    });
  }

  Future<void> _export(JsonMap data, {required bool excel}) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final daily =
          (data['daily'] as List? ?? const [])
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList();
      final Uint8List bytes;
      final extension = excel ? 'xlsx' : 'csv';
      if (excel) {
        final workbook = excel_lib.Excel.createExcel();
        workbook.rename('Sheet1', 'گزارش مالی');
        final sheet = workbook['گزارش مالی'];
        sheet.appendRow([
          excel_lib.TextCellValue('تاریخ شمسی'),
          excel_lib.TextCellValue('تعداد سفارش'),
          excel_lib.TextCellValue('فروش (ریال)'),
          excel_lib.TextCellValue('بهای خرید (ریال)'),
          excel_lib.TextCellValue('سود ناخالص (ریال)'),
        ]);
        for (final row in daily) {
          sheet.appendRow([
            excel_lib.TextCellValue('${row['dateJalali'] ?? ''}'),
            excel_lib.IntCellValue(_asInt(row['orderCount'])),
            excel_lib.IntCellValue(_asInt(row['salesRial'])),
            excel_lib.IntCellValue(_asInt(row['productCostRial'])),
            excel_lib.IntCellValue(_asInt(row['grossProfitRial'])),
          ]);
        }
        final result = workbook.save();
        if (result == null) throw StateError('ساخت فایل اکسل انجام نشد.');
        bytes = Uint8List.fromList(result);
      } else {
        final rows = <List<Object?>>[
          [
            'تاریخ شمسی',
            'تعداد سفارش',
            'فروش (ریال)',
            'بهای خرید (ریال)',
            'سود ناخالص (ریال)',
          ],
          ...daily.map(
            (row) => [
              row['dateJalali'],
              row['orderCount'],
              row['salesRial'],
              row['productCostRial'],
              row['grossProfitRial'],
            ],
          ),
        ];
        final csv = rows.map((row) => row.map(_csvCell).join(',')).join('\r\n');
        bytes = Uint8List.fromList(utf8.encode('\uFEFF$csv'));
      }
      const channel = MethodChannel('paniz/admin-reports');
      final saved = await channel.invokeMethod<bool>('saveReport', {
        'bytes': bytes,
        'filename': 'paniz-finance.$extension',
        'mimeType':
            excel
                ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
                : 'text/csv',
      });
      if (mounted && saved == true)
        showAppMessage(context, 'گزارش مالی ذخیره شد.');
    } catch (error) {
      if (mounted)
        showAppMessage(
          context,
          'ساخت فایل گزارش انجام نشد: $error',
          error: true,
        );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = ref.watch(financeReportProvider(_reportKey));
    final todayReport = ref.watch(financeReportProvider('today'));
    return report.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:
          (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AdminApi.friendlyError(error),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed:
                        () => ref.invalidate(financeReportProvider(_reportKey)),
                    child: const Text('تلاش دوباره'),
                  ),
                ],
              ),
            ),
          ),
      data: (data) {
        final daily =
            (data['daily'] as List? ?? const [])
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList();
        final totals =
            data['totals'] is Map
                ? Map<String, dynamic>.from(data['totals'] as Map)
                : <String, dynamic>{};
        return RefreshIndicator(
          onRefresh:
              () async => ref.invalidate(financeReportProvider(_reportKey)),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              const SizedBox(height: 8),
              todayReport.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
                data:
                    (today) => _SummaryCard(
                      title: 'فروش امروز',
                      amount: (today['totals'] as Map?)?['salesRial'],
                      icon: Icons.today_outlined,
                      color: Theme.of(context).colorScheme.primaryContainer,
                    ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDate(start: true),
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: Text(
                        _from == null ? 'از تاریخ' : shamsiDate(_from!),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDate(start: false),
                      icon: const Icon(Icons.event_outlined),
                      label: Text(_to == null ? 'تا تاریخ' : shamsiDate(_to!)),
                    ),
                  ),
                ],
              ),
              if (_from != null || _to != null)
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton.icon(
                    onPressed:
                        () => setState(() {
                          _from = null;
                          _to = null;
                        }),
                    icon: const Icon(Icons.close),
                    label: const Text('پاک‌کردن بازهٔ انتخابی'),
                  ),
                ),
              Wrap(
                spacing: 7,
                runSpacing: 6,
                children:
                    _options
                        .map(
                          (item) => ChoiceChip(
                            label: Text(item.$2),
                            selected:
                                _from == null &&
                                _to == null &&
                                _range == item.$1,
                            onSelected:
                                (_) => setState(() {
                                  _range = item.$1;
                                  _from = null;
                                  _to = null;
                                }),
                          ),
                        )
                        .toList(),
              ),
              const SizedBox(height: 14),
              _SummaryCard(
                title: 'فروش پرداخت‌شده',
                amount: totals['salesRial'],
                icon: Icons.account_balance_wallet_outlined,
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              _SummaryCard(
                title: 'بهای خرید کالاهای فروخته‌شده',
                amount: totals['productCostRial'],
                icon: Icons.inventory_2_outlined,
                color: Theme.of(context).colorScheme.secondaryContainer,
              ),
              _SummaryCard(
                title: 'سود ناخالص تخمینی',
                amount: totals['grossProfitRial'],
                icon: Icons.trending_up_rounded,
                color: Theme.of(context).colorScheme.tertiaryContainer,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed:
                          _exporting ? null : () => _export(data, excel: true),
                      icon: const Icon(Icons.table_view_outlined),
                      label: const Text('Excel'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          _exporting ? null : () => _export(data, excel: false),
                      icon: const Icon(Icons.description_outlined),
                      label: const Text('CSV'),
                    ),
                  ),
                ],
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'روند فروش روزانه',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${persianNumber(totals['orderCount'] ?? 0)} سفارش پرداخت‌شده · نمودار به ریال',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 270,
                        width: double.infinity,
                        child: CustomPaint(
                          painter: _FinanceChartPainter(
                            data: daily,
                            grid: Theme.of(context).colorScheme.outlineVariant,
                            line: Theme.of(context).colorScheme.primary,
                            fill: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: .12),
                            label:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const Center(
                        child: Text(
                          'مبالغ به ریال',
                          style: TextStyle(fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'سود ناخالص از مبلغ پرداخت‌شده منهای بهای خرید ثبت‌شدهٔ محصول محاسبه شده و هزینه‌های عملیاتی را شامل نمی‌شود.',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.6,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

String _dayKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

int _asInt(Object? value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;
String _csvCell(Object? value) {
  final text = '$value';
  return '"${text.replaceAll('"', '""')}"';
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
  });
  final String title;
  final Object? amount;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  groupedNumber(amount ?? 0),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Text('ریال', style: TextStyle(fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _FinanceChartPainter extends CustomPainter {
  _FinanceChartPainter({
    required this.data,
    required this.grid,
    required this.line,
    required this.fill,
    required this.label,
  });
  final List<JsonMap> data;
  final Color grid;
  final Color line;
  final Color fill;
  final Color label;
  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) {
      _text(
        canvas,
        'داده‌ای برای این بازه نیست',
        Offset(size.width / 2 - 55, size.height / 2),
        label,
        12,
      );
      return;
    }
    const left = 70.0, right = 8.0, top = 12.0, bottom = 76.0;
    final chart = Rect.fromLTRB(
      left,
      top,
      size.width - right,
      size.height - bottom,
    );
    final values = data.map((item) => _value(item['salesRial'])).toList();
    final maximum = math.max(1, values.fold<int>(0, math.max)).toDouble();
    final gridPaint =
        Paint()
          ..color = grid.withValues(alpha: .7)
          ..strokeWidth = .7;
    for (var tick = 0; tick <= 4; tick++) {
      final y = chart.bottom - chart.height * tick / 4;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
      _text(
        canvas,
        groupedNumber((maximum * tick / 4).round()),
        Offset(0, y - 7),
        label,
        8,
      );
    }
    final points = <Offset>[];
    for (var index = 0; index < values.length; index++) {
      final x =
          values.length == 1
              ? chart.center.dx
              : chart.left + chart.width * index / (values.length - 1);
      final y = chart.bottom - chart.height * values[index] / maximum;
      points.add(Offset(x, y));
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final current = points[i];
      final middle = (previous.dx + current.dx) / 2;
      path.cubicTo(
        middle,
        previous.dy,
        middle,
        current.dy,
        current.dx,
        current.dy,
      );
    }
    final area =
        Path.from(path)
          ..lineTo(points.last.dx, chart.bottom)
          ..lineTo(points.first.dx, chart.bottom)
          ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          colors: [fill, fill.withValues(alpha: .02)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(chart),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..strokeWidth = 2.6
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    for (final point in points)
      canvas.drawCircle(point, 3.2, Paint()..color = line);
    final interval = math.max(1, (data.length / 9).ceil());
    for (var index = 0; index < data.length; index += interval) {
      final x = points[index].dx;
      final date = '${data[index]['dateJalali'] ?? ''}';
      final painter = TextPainter(
        text: TextSpan(text: date, style: TextStyle(color: label, fontSize: 8)),
        textDirection: TextDirection.rtl,
      )..layout();
      canvas.save();
      canvas.translate(x + 3, chart.bottom + 68);
      canvas.rotate(-math.pi / 2);
      painter.paint(canvas, Offset.zero);
      canvas.restore();
    }
  }

  void _text(
    Canvas canvas,
    String value,
    Offset position,
    Color color,
    double size,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(color: color, fontSize: size),
      ),
      textDirection: TextDirection.rtl,
    )..layout(maxWidth: 68);
    painter.paint(canvas, position);
  }

  int _value(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;
  @override
  bool shouldRepaint(covariant _FinanceChartPainter oldDelegate) =>
      oldDelegate.data != data ||
      oldDelegate.line != line ||
      oldDelegate.grid != grid;
}
