import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/admin_api.dart';
import '../../core/admin_avatar.dart';
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
    _poll = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _load(silent: true),
    );
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
    if (!silent)
      setState(() {
        _loading = true;
        _error = null;
      });
    try {
      final api = ref.read(adminApiProvider);
      final contacts = await api.adminChatContacts();
      var selected = _selectedId;
      if (selected == null ||
          !contacts.any((item) => '${item['id']}' == selected)) {
        selected = contacts.isEmpty ? null : '${contacts.first['id']}';
      }
      final messages =
          selected == null
              ? <JsonMap>[]
              : await api.adminChatMessages(selected);
      if (!mounted) return;
      setState(() {
        _contacts = contacts;
        _selectedId = selected;
        _messages = messages;
        _error = null;
      });
      if (_messages.isNotEmpty)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients)
            _scroll.jumpTo(_scroll.position.maxScrollExtent);
        });
    } catch (error) {
      if (mounted && !silent)
        setState(() => _error = AdminApi.friendlyError(error));
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  Future<void> _send({bool broadcast = false}) async {
    final text = _message.text.trim();
    if (_sending || text.isEmpty) return;
    if (broadcast) {
      final confirm = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('ارسال اعلان برای همهٔ ادمین‌ها'),
              content: const Text(
                'این پیام به گفت‌وگوی همهٔ ادمین‌های فعال فرستاده می‌شود.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('انصراف'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('ارسال'),
                ),
              ],
            ),
      );
      if (confirm != true || !mounted) return;
    }
    setState(() => _sending = true);
    try {
      await ref
          .read(adminApiProvider)
          .sendAdminChat(
            recipientAdminId: _selectedId,
            body: text,
            broadcast: broadcast,
          );
      _message.clear();
      await _load(silent: true);
      if (mounted)
        showAppMessage(
          context,
          broadcast
              ? 'پیام برای ادمین‌های فعال فرستاده شد.'
              : 'پیام فرستاده شد.',
        );
    } catch (error) {
      if (mounted)
        showAppMessage(context, AdminApi.friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _editMessage(JsonMap message) async {
    final controller = TextEditingController(text: '${message['body'] ?? ''}');
    final value = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('ویرایش پیام'),
            content: TextField(
              controller: controller,
              minLines: 2,
              maxLines: 6,
              maxLength: 4000,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('لغو'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, controller.text.trim()),
                child: const Text('ذخیره'),
              ),
            ],
          ),
    );
    controller.dispose();
    if (value == null || value.isEmpty || !mounted) return;
    try {
      await ref
          .read(adminApiProvider)
          .editAdminChatMessage('${message['id']}', value);
      await _load(silent: true);
    } catch (error) {
      if (mounted)
        showAppMessage(context, AdminApi.friendlyError(error), error: true);
    }
  }

  Future<void> _deleteMessage(JsonMap message, {required bool mine}) async {
    final scope = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('حذف پیام'),
            content: const Text(
              'می‌خواهی پیام فقط از صفحهٔ خودت پاک شود یا برای هر دو طرف؟',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('لغو'),
              ),
              OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('فقط برای من'),
              ),
              if (mine)
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('برای همه'),
                ),
            ],
          ),
    );
    if (scope == null || !mounted) return;
    try {
      await ref
          .read(adminApiProvider)
          .deleteAdminChatMessage('${message['id']}', forEveryone: scope);
      await _load(silent: true);
    } catch (error) {
      if (mounted)
        showAppMessage(context, AdminApi.friendlyError(error), error: true);
    }
  }

  Future<void> _insertEmoji() async {
    const emojis = [
      '😀',
      '😊',
      '😍',
      '🥰',
      '😘',
      '😂',
      '😉',
      '😎',
      '❤️',
      '🧡',
      '💛',
      '💚',
      '💙',
      '💜',
      '✨',
      '🎉',
      '👍',
      '🙏',
      '🌹',
      '🛍️',
      '✅',
      '📦',
      '👗',
      '🧥',
      '💌',
      '🤍',
    ];
    final emoji = await showModalBottomSheet<String>(
      context: context,
      builder:
          (context) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in emojis)
                    InkWell(
                      onTap: () => Navigator.pop(context, item),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(item, style: const TextStyle(fontSize: 26)),
                      ),
                    ),
                ],
              ),
            ),
          ),
    );
    if (emoji == null) return;
    final old = _message.value;
    final selection = old.selection;
    final start = selection.isValid ? selection.start : old.text.length;
    final end = selection.isValid ? selection.end : old.text.length;
    _message.value = TextEditingValue(
      text: old.text.replaceRange(start, end, emoji),
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final admin = ref.watch(authProvider).value;
    final owner = admin?.role == 'owner';
    JsonMap? selected;
    for (final item in _contacts) {
      if ('${item['id']}' == _selectedId) {
        selected = item;
        break;
      }
    }
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null)
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 10),
              FilledButton(onPressed: _load, child: const Text('تلاش دوباره')),
            ],
          ),
        ),
      );
    return Column(
      children: [
        if (_contacts.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        owner ? 'گفت‌وگو با مدیران' : 'گفت‌وگو با سوپرادمین',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (owner)
                      IconButton(
                        tooltip: 'اعلان به همهٔ ادمین‌ها',
                        onPressed:
                            _contacts.isEmpty
                                ? null
                                : () => _send(broadcast: true),
                        icon: const Icon(Icons.campaign_outlined),
                      ),
                  ],
                ),
                SizedBox(
                  height: 76,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final contact in _contacts)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 12),
                          child: InkWell(
                            onTap: () async {
                              final id = '${contact['id']}';
                              if (id == _selectedId) return;
                              setState(() {
                                _selectedId = id;
                                _messages = [];
                                _loading = true;
                              });
                              await _load();
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: SizedBox(
                              width: 68,
                              child: Column(
                                children: [
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      AdminAvatar(
                                        name: '${contact['fullName'] ?? ''}',
                                        path: contact['avatarPath'] as String?,
                                        size: 44,
                                      ),
                                      if ((contact['unreadCount'] as num? ??
                                              0) >
                                          0)
                                        PositionedDirectional(
                                          end: -6,
                                          top: -5,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 5,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.error,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              persianNumber(
                                                contact['unreadCount'],
                                              ),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 9,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${contact['fullName'] ?? ''}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight:
                                          '${contact['id']}' == _selectedId
                                              ? FontWeight.w900
                                              : FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (selected != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                '${selected['fullName']} · ${selected['role'] == 'owner' ? 'سوپرادمین' : 'ادمین'}',
                style: TextStyle(color: context.paniz.muted, fontSize: 12),
              ),
            ),
          ),
        const Divider(height: 1),
        Expanded(
          child:
              _contacts.isEmpty
                  ? const Center(
                    child: Text('ادمین فعالی برای گفت‌وگو وجود ندارد.'),
                  )
                  : _messages.isEmpty
                  ? Center(
                    child: Text(
                      'گفت‌وگو تازه است. اولین پیام را بفرست.',
                      style: TextStyle(color: context.paniz.muted),
                    ),
                  )
                  : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(14),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final mine = '${message['senderAdminId']}' == admin?.id;
                      final time =
                          DateTime.tryParse(
                            '${message['createdAt']}',
                          )?.toLocal();
                      return Align(
                        alignment:
                            mine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Flexible(
                              child: Container(
                                constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.sizeOf(context).width * .70,
                                ),
                                margin: const EdgeInsets.only(bottom: 9),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 13,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      mine
                                          ? context.paniz.primary.withValues(
                                            alpha: .14,
                                          )
                                          : Theme.of(
                                            context,
                                          ).colorScheme.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(17),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (message['broadcast'] == true)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 4,
                                        ),
                                        child: Text(
                                          'اعلان گروهی',
                                          style: TextStyle(
                                            color: context.paniz.primary,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    Text(
                                      '${message['body']}',
                                      style: const TextStyle(height: 1.6),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (message['editedAt'] != null)
                                          Padding(
                                            padding:
                                                const EdgeInsetsDirectional.only(
                                                  end: 5,
                                                ),
                                            child: Text(
                                              'ویرایش‌شده',
                                              style: TextStyle(
                                                fontSize: 9,
                                                color: context.paniz.muted,
                                              ),
                                            ),
                                          ),
                                        if (time != null)
                                          Text(
                                            '${persianNumber(time.hour.toString().padLeft(2, '0'))}:${persianNumber(time.minute.toString().padLeft(2, '0'))}',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: context.paniz.muted,
                                            ),
                                          ),
                                        if (mine)
                                          Padding(
                                            padding:
                                                const EdgeInsetsDirectional.only(
                                                  start: 5,
                                                ),
                                            child: Icon(
                                              Icons.done_all_rounded,
                                              size: 14,
                                              color:
                                                  message['readAt'] != null
                                                      ? context.paniz.primary
                                                      : context.paniz.muted,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (mine)
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') _editMessage(message);
                                  if (value == 'delete')
                                    _deleteMessage(message, mine: mine);
                                },
                                itemBuilder:
                                    (_) => const [
                                      PopupMenuItem(
                                        value: 'edit',
                                        child: Text('ویرایش'),
                                      ),
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Text('حذف'),
                                      ),
                                    ],
                              ),
                          ],
                        ),
                      );
                    },
                  ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: _insertEmoji,
                  tooltip: 'شکلک',
                  icon: const Icon(Icons.emoji_emotions_outlined),
                ),
                Expanded(
                  child: TextField(
                    controller: _message,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      hintText: 'پیام متنی…',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed:
                      _sending || _contacts.isEmpty ? null : () => _send(),
                  icon:
                      _sending
                          ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
