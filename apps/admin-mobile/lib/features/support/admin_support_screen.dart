import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/admin_api.dart';
import '../../core/paniz_theme.dart';
import '../../core/providers.dart';
import '../../core/ui_helpers.dart';

class AdminSupportScreen extends ConsumerStatefulWidget {
  const AdminSupportScreen({super.key});
  @override
  ConsumerState<AdminSupportScreen> createState() => _AdminSupportScreenState();
}

class _AdminSupportScreenState extends ConsumerState<AdminSupportScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  List<JsonMap> _tickets = [];
  List<JsonMap> _returns = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = ref.read(adminApiProvider);
      final values = await Future.wait([api.adminSupportTickets(), api.adminReturns()]);
      if (mounted) setState(() { _tickets = values[0]; _returns = values[1]; });
    } catch (error) { if (mounted) setState(() => _error = AdminApi.friendlyError(error)); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 4), child: TabBar(controller: _tabs, tabs: const [Tab(icon: Icon(Icons.forum_outlined), text: 'گفت‌وگوی مشتریان'), Tab(icon: Icon(Icons.assignment_return_outlined), text: 'مرجوعی‌ها')])),
    if (_error != null) Padding(padding: const EdgeInsets.all(12), child: MaterialBanner(content: Text(_error!), actions: [TextButton(onPressed: _load, child: const Text('تلاش دوباره'))])),
    if (_loading) const LinearProgressIndicator(minHeight: 2),
    Expanded(child: TabBarView(controller: _tabs, children: [
      RefreshIndicator(onRefresh: _load, child: _tickets.isEmpty ? ListView(children: const [SizedBox(height: 150), Center(child: Text('درخواست پشتیبانی‌ای ثبت نشده است.'))]) : ListView.builder(padding: const EdgeInsets.all(12), itemCount: _tickets.length, itemBuilder: (context, index) {
        final ticket = _tickets[index];
        final customer = ticket['customer'] is Map ? Map<String, dynamic>.from(ticket['customer'] as Map) : <String, dynamic>{};
        final messages = ticket['messages'] is List ? ticket['messages'] as List : const [];
        return Card(child: ListTile(
          leading: CircleAvatar(backgroundColor: context.paniz.primarySoft, child: Icon(Icons.support_agent_rounded, color: context.paniz.primary)),
          title: Text('${ticket['subject'] ?? 'پشتیبانی'}', maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${customer['fullName'] ?? 'مشتری'} · ${customer['phone'] ?? ''} · ${persianNumber(messages.length)} پیام\n${_ticketStatus('${ticket['status']}')}', maxLines: 2),
          isThreeLine: true,
          trailing: const Icon(Icons.chevron_left_rounded),
          onTap: () async { await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _TicketConversation(ticket: ticket))); await _load(); },
        ));
      })),
      RefreshIndicator(onRefresh: _load, child: _returns.isEmpty ? ListView(children: const [SizedBox(height: 150), Center(child: Text('درخواست مرجوعی‌ای ثبت نشده است.'))]) : ListView.builder(padding: const EdgeInsets.all(12), itemCount: _returns.length, itemBuilder: (context, index) => _ReturnCard(item: _returns[index], onChanged: _load))),
    ])),
  ]);
}

String _ticketStatus(String value) => switch (value) { 'waiting_customer' => 'منتظر پاسخ مشتری', 'closed' => 'بسته‌شده', _ => 'در حال پیگیری' };
class _TicketConversation extends ConsumerStatefulWidget {
  const _TicketConversation({required this.ticket});
  final JsonMap ticket;
  @override
  ConsumerState<_TicketConversation> createState() => _TicketConversationState();
}

class _TicketConversationState extends ConsumerState<_TicketConversation> {
  final _text = TextEditingController();
  final _picker = ImagePicker();
  XFile? _image;
  bool _busy = false;
  List<JsonMap> get _messages => (widget.ticket['messages'] as List? ?? const []).whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  @override
  void dispose() { _text.dispose(); super.dispose(); }

  Future<void> _chooseImage() async {
    final image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 82, maxWidth: 1800);
    if (image != null && mounted) setState(() => _image = image);
  }

  Future<void> _send() async {
    final body = _text.text.trim();
    if (_busy || (body.isEmpty && _image == null)) return;
    setState(() => _busy = true);
    try {
      String? imagePath;
      if (_image != null) {
        final bytes = await _image!.readAsBytes();
        imagePath = (await ref.read(adminApiProvider).uploadSupportImage(bytes, _image!.name))['imagePath'] as String?;
      }
      await ref.read(adminApiProvider).replyToSupportTicket('${widget.ticket['id']}', body.isEmpty ? 'تصویر پیوست شد.' : body, imagePath: imagePath);
      if (mounted) Navigator.of(context).pop();
    } catch (error) { if (mounted) showAppMessage(context, AdminApi.friendlyError(error), error: true); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  @override
  Widget build(BuildContext context) {
    final customer = widget.ticket['customer'] is Map ? Map<String, dynamic>.from(widget.ticket['customer'] as Map) : <String, dynamic>{};
    return Scaffold(appBar: AppBar(title: Text('${widget.ticket['subject'] ?? 'پشتیبانی'}', maxLines: 1, overflow: TextOverflow.ellipsis)), body: Column(children: [
      ListTile(leading: const Icon(Icons.person_outline), title: Text('${customer['fullName'] ?? 'مشتری'}'), subtitle: Text('${customer['phone'] ?? ''}')),
      const Divider(height: 1),
      Expanded(child: ListView(padding: const EdgeInsets.all(14), children: _messages.map((message) {
        final isAdmin = message['senderType'] == 'admin';
        final path = message['imagePath'] as String?;
        return Align(alignment: isAdmin ? Alignment.centerLeft : Alignment.centerRight, child: Container(width: double.infinity, constraints: const BoxConstraints(maxWidth: 420), margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: isAdmin ? context.paniz.primarySoft : Theme.of(context).colorScheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(16)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(isAdmin ? 'پشتیبان پانیذ' : 'مشتری', style: TextStyle(fontSize: 10, color: context.paniz.primary, fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text('${message['body'] ?? ''}'), if (path != null) Padding(padding: const EdgeInsets.only(top: 8), child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(AdminApi.imageUrl(path), height: 180, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Text('تصویر در دسترس نیست')))), const SizedBox(height: 4), Text(_time('${message['createdAt']}'), style: TextStyle(fontSize: 10, color: context.paniz.muted))])));
      }).toList())),
      SafeArea(top: false, child: Padding(padding: const EdgeInsets.all(10), child: Column(children: [
        if (_image != null) Row(children: [const Icon(Icons.image_outlined), Expanded(child: Text(_image!.name, maxLines: 1, overflow: TextOverflow.ellipsis)), IconButton(onPressed: () => setState(() => _image = null), icon: const Icon(Icons.close_rounded))]),
        Row(children: [IconButton(tooltip: 'پیوست تصویر', onPressed: _busy ? null : _chooseImage, icon: const Icon(Icons.attach_file_rounded)), Expanded(child: TextField(controller: _text, maxLines: 3, minLines: 1, decoration: const InputDecoration(hintText: 'پاسخ به مشتری…', border: OutlineInputBorder()))), const SizedBox(width: 8), IconButton.filled(onPressed: _busy ? null : _send, icon: _busy ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_rounded))]),
      ]))),
    ]));
  }
}

class _ReturnCard extends ConsumerStatefulWidget {
  const _ReturnCard({required this.item, required this.onChanged});
  final JsonMap item;
  final Future<void> Function() onChanged;
  @override
  ConsumerState<_ReturnCard> createState() => _ReturnCardState();
}

class _ReturnCardState extends ConsumerState<_ReturnCard> {
  late String _status = '${widget.item['status'] ?? 'requested'}';
  late final _note = TextEditingController(text: '${widget.item['adminNote'] ?? ''}');
  bool _busy = false;
  final _picker = ImagePicker();
  @override
  void dispose() { _note.dispose(); super.dispose(); }

  Future<void> _save() async {
    setState(() => _busy = true);
    try { await ref.read(adminApiProvider).updateReturnRequest('${widget.item['id']}', _status, _note.text.trim()); await widget.onChanged(); if (mounted) showAppMessage(context, 'وضعیت مرجوعی ذخیره شد.'); }
    catch (error) { if (mounted) showAppMessage(context, AdminApi.friendlyError(error), error: true); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _receipt() async {
    final image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 82, maxWidth: 1800);
    if (image == null || !mounted) return;
    setState(() => _busy = true);
    try { await ref.read(adminApiProvider).uploadReturnReceipt('${widget.item['id']}', await image.readAsBytes(), image.name); await widget.onChanged(); if (mounted) showAppMessage(context, 'رسید واریز برای مشتری ارسال شد.'); }
    catch (error) { if (mounted) showAppMessage(context, AdminApi.friendlyError(error), error: true); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  @override
  Widget build(BuildContext context) {
    final customer = widget.item['customer'] is Map ? Map<String, dynamic>.from(widget.item['customer'] as Map) : <String, dynamic>{};
    return Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text('سفارش ${widget.item['orderNumber'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w900))), statusPill(context, _status, dense: true)]),
      Text('${customer['fullName'] ?? ''} · ${customer['phone'] ?? ''}', style: TextStyle(color: context.paniz.muted, fontSize: 12)),
      const SizedBox(height: 7), Text('${widget.item['reason'] ?? ''}'),
      const SizedBox(height: 7), SelectableText('شبا: ${widget.item['iban'] ?? '—'}\nشماره کارت: ${widget.item['cardNumber'] ?? '—'}\nمبلغ فاکتور: ${toman(widget.item['refundAmountToman'] ?? 0)}', style: const TextStyle(height: 1.8)),
      TextField(controller: _note, maxLength: 2000, decoration: const InputDecoration(labelText: 'پیام برای مشتری')),
      DropdownButtonFormField<String>(initialValue: _status, decoration: const InputDecoration(labelText: 'وضعیت مرجوعی'), items: const [DropdownMenuItem(value: 'requested', child: Text('در انتظار بررسی')), DropdownMenuItem(value: 'approved', child: Text('درخواست تأیید شد')), DropdownMenuItem(value: 'received', child: Text('کالا دریافت شد')), DropdownMenuItem(value: 'refunded', child: Text('وجه بازگردانده شد')), DropdownMenuItem(value: 'rejected', child: Text('رد درخواست'))], onChanged: _busy ? null : (value) => setState(() => _status = value ?? _status)),
      Wrap(spacing: 8, children: [FilledButton.tonalIcon(onPressed: _busy ? null : _save, icon: const Icon(Icons.save_outlined), label: const Text('ذخیره و اطلاع به مشتری')), if (_status == 'received' || _status == 'refunded') OutlinedButton.icon(onPressed: _busy ? null : _receipt, icon: const Icon(Icons.receipt_long_outlined), label: const Text('ارسال تصویر رسید'))]),
      if (widget.item['refundReceiptPath'] is String) Padding(padding: const EdgeInsets.only(top: 5), child: Text('رسید ثبت‌شده: ${widget.item['refundReceiptPath']}', style: TextStyle(fontSize: 10, color: context.paniz.muted))),
    ])));
  }
}

String _time(String value) { final time = DateTime.tryParse(value)?.toLocal(); return time == null ? '' : '${persianNumber(time.year)}/${persianNumber(time.month.toString().padLeft(2, '0'))}/${persianNumber(time.day.toString().padLeft(2, '0'))} · ${persianNumber(time.hour.toString().padLeft(2, '0'))}:${persianNumber(time.minute.toString().padLeft(2, '0'))}'; }
