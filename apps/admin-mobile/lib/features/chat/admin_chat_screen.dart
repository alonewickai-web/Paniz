import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/admin_api.dart';
import '../../core/paniz_theme.dart';
import '../../core/providers.dart';
import '../../core/ui_helpers.dart';

class AdminChatScreen extends ConsumerStatefulWidget {
  const AdminChatScreen({super.key});
  @override
  ConsumerState<AdminChatScreen> createState() => _AdminChatScreenState();
}

class _AdminChatScreenState extends ConsumerState<AdminChatScreen> {
  final _message = TextEditingController();
  final _scroll = ScrollController();
  List<JsonMap> _contacts = [];
  List<JsonMap> _messages = [];
  String? _selectedId;
  bool _loading = true;
  bool _sending = false;
  String? _error;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    _poll = Timer.periodic(const Duration(seconds: 15), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    _message.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) setState(() { _loading = true; _error = null; });
    try {
      final api = ref.read(adminApiProvider);
      final contacts = await api.adminChatContacts();
      var selected = _selectedId;
      if (selected == null || !contacts.any((item) => '${item['id']}' == selected)) {
        selected = contacts.isEmpty ? null : '${contacts.first['id']}';
      }
      final messages = selected == null ? <JsonMap>[] : await api.adminChatMessages(selected);
      if (!mounted) return;
      setState(() { _contacts = contacts; _selectedId = selected; _messages = messages; _error = null; });
      if (_messages.isNotEmpty) WidgetsBinding.instance.addPostFrameCallback((_) { if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent); });
    } catch (error) {
      if (mounted && !silent) setState(() => _error = AdminApi.friendlyError(error));
    } finally { if (mounted && !silent) setState(() => _loading = false); }
  }

  Future<void> _send({bool broadcast = false}) async {
    final text = _message.text.trim();
    if (_sending || text.isEmpty) return;
    if (broadcast) {
      final confirm = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
        title: const Text('ارسال اعلان برای همهٔ ادمین‌ها'),
        content: const Text('این پیام به گفت‌وگوی همهٔ ادمین‌های فعال فرستاده می‌شود.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('ارسال'))],
      ));
      if (confirm != true || !mounted) return;
    }
    setState(() => _sending = true);
    try {
      await ref.read(adminApiProvider).sendAdminChat(recipientAdminId: _selectedId, body: text, broadcast: broadcast);
      _message.clear();
      await _load(silent: true);
      if (mounted) showAppMessage(context, broadcast ? 'پیام برای ادمین‌های فعال فرستاده شد.' : 'پیام فرستاده شد.');
    } catch (error) { if (mounted) showAppMessage(context, AdminApi.friendlyError(error), error: true); }
    finally { if (mounted) setState(() => _sending = false); }
  }

  @override
  Widget build(BuildContext context) {
    final admin = ref.watch(authProvider).value;
    final owner = admin?.role == 'owner';
    JsonMap? selected;
    for (final item in _contacts) { if ('${item['id']}' == _selectedId) { selected = item; break; } }
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Padding(padding: const EdgeInsets.all(22), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!, textAlign: TextAlign.center), const SizedBox(height: 10), FilledButton(onPressed: _load, child: const Text('تلاش دوباره'))])));
    return Column(children: [
      if (_contacts.isNotEmpty) Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        child: Row(children: [
          Expanded(child: DropdownButtonFormField<String>(
            initialValue: _selectedId,
            decoration: InputDecoration(labelText: owner ? 'گفت‌وگو با ادمین' : 'گفت‌وگو با سوپرادمین', prefixIcon: const Icon(Icons.person_outline_rounded)),
            items: _contacts.map((item) => DropdownMenuItem(value: '${item['id']}', child: Text('${item['fullName']} · @${item['username']}', overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (value) async { setState(() { _selectedId = value; _messages = []; }); if (value != null) { setState(() => _loading = true); await _load(); } },
          )),
          if (owner) IconButton(tooltip: 'اعلان به همهٔ ادمین‌ها', onPressed: _contacts.isEmpty ? null : () => _send(broadcast: true), icon: const Icon(Icons.campaign_outlined)),
        ]),
      ),
      if (selected != null) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: Align(alignment: AlignmentDirectional.centerStart, child: Text('${selected['fullName']} · ${selected['role'] == 'owner' ? 'سوپرادمین' : 'ادمین'}', style: TextStyle(color: context.paniz.muted, fontSize: 12)))),
      const Divider(height: 1),
      Expanded(child: _contacts.isEmpty
        ? const Center(child: Text('ادمین فعالی برای گفت‌وگو وجود ندارد.'))
        : _messages.isEmpty
          ? Center(child: Text('گفت‌وگو تازه است. اولین پیام را بفرست.', style: TextStyle(color: context.paniz.muted)))
          : ListView.builder(controller: _scroll, padding: const EdgeInsets.all(14), itemCount: _messages.length, itemBuilder: (context, index) {
              final message = _messages[index];
              final mine = '${message['senderAdminId']}' == admin?.id;
              final time = DateTime.tryParse('${message['createdAt']}')?.toLocal();
              return Align(alignment: mine ? Alignment.centerRight : Alignment.centerLeft, child: Container(
                constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .78),
                margin: const EdgeInsets.only(bottom: 9), padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                decoration: BoxDecoration(color: mine ? context.paniz.primary.withValues(alpha: .14) : Theme.of(context).colorScheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(17)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (message['broadcast'] == true) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('اعلان گروهی', style: TextStyle(color: context.paniz.primary, fontSize: 10, fontWeight: FontWeight.w800))),
                  Text('${message['body']}', style: const TextStyle(height: 1.6)),
                  if (time != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${persianNumber(time.hour.toString().padLeft(2, '0'))}:${persianNumber(time.minute.toString().padLeft(2, '0'))}', style: TextStyle(fontSize: 10, color: context.paniz.muted))),
                ]),
              ));
            })),
      SafeArea(top: false, child: Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 10), child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(child: TextField(controller: _message, minLines: 1, maxLines: 4, textInputAction: TextInputAction.newline, decoration: const InputDecoration(hintText: 'پیام متنی…', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12)))),
        const SizedBox(width: 8),
        IconButton.filled(onPressed: _sending || _contacts.isEmpty ? null : () => _send(), icon: _sending ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_rounded)),
      ]))),
    ]);
  }
}
