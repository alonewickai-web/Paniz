import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/admin_api.dart';
import '../../core/paniz_theme.dart';
import '../../core/providers.dart';
import '../../core/ui_helpers.dart';

class AppUpdateScreen extends ConsumerStatefulWidget {
  const AppUpdateScreen({super.key});
  @override
  ConsumerState<AppUpdateScreen> createState() => _AppUpdateScreenState();
}

class _AppUpdateScreenState extends ConsumerState<AppUpdateScreen>
    with WidgetsBindingObserver {
  static const _native = MethodChannel('paniz/admin-updates');
  final _notes = TextEditingController();
  final _cancel = CancelToken();
  JsonMap? _installed;
  JsonMap? _latest;
  JsonMap? _selected;
  List<JsonMap> _history = [];
  bool _loading = true;
  bool _busy = false;
  double? _progress;
  String? _error;
  String? _status;
  String? _downloadedPath;

  bool get _canPublish =>
      ref.read(authProvider).asData?.value?.can('system.release') ?? false;
  int _code(JsonMap? value) => (value?['versionCode'] as num?)?.toInt() ?? 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancel.cancel();
    _notes.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadInstalled();
  }

  Future<void> _loadInstalled() async {
    try {
      final result = await _native.invokeMapMethod<String, dynamic>('appInfo');
      if (mounted && result != null) setState(() => _installed = result);
    } on MissingPluginException {
      /* Web/desktop can show release details, installation requires Android. */
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _loadInstalled();
      final api = ref.read(adminApiProvider);
      final latest = await api.latestAppRelease();
      final history = _canPublish ? await api.appReleases() : <JsonMap>[];
      if (mounted)
        setState(() {
          _latest = latest;
          _history = history;
        });
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _message(Object error) =>
      error is PlatformException
          ? error.message ?? 'عملیات بروزرسانی انجام نشد.'
          : AdminApi.friendlyError(error);

  Future<void> _download() async {
    final release = _latest;
    if (release == null || _installed == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _progress = 0;
      _status = 'در حال دانلود نسخهٔ جدید…';
      _downloadedPath = null;
    });
    try {
      final path = await _native.invokeMethod<String>('downloadPath');
      if (path == null)
        throw const AdminApiException('محل دانلود در دسترس نیست.');
      await ref.read(adminApiProvider).downloadAppRelease(
        release,
        path,
        _cancel,
        (done, total) {
          if (mounted)
            setState(() => _progress = total > 0 ? done / total : null);
        },
      );
      if (mounted)
        setState(() {
          _status = 'در حال بررسی فایل و امضای برنامه…';
          _progress = null;
        });
      await _native.invokeMethod('verifyApk', {
        'path': path,
        'sha256': release['sha256'],
        'versionCode': release['versionCode'],
      });
      if (mounted)
        setState(() {
          _downloadedPath = path;
          _status = 'نسخهٔ جدید آمادهٔ نصب است.';
        });
    } catch (error) {
      if (mounted)
        setState(() {
          _error = _message(error);
          _status = null;
        });
    } finally {
      if (mounted)
        setState(() {
          _busy = false;
          _progress = null;
        });
    }
  }

  Future<void> _install() async {
    if (_downloadedPath == null) return;
    try {
      final allowed =
          await _native.invokeMethod<bool>('installPermission') ?? false;
      if (!allowed) {
        if (mounted)
          showAppMessage(
            context,
            'اجازهٔ نصب را فعال کنید، سپس به برنامه برگردید و نصب را بزنید.',
          );
        return;
      }
      await _native.invokeMethod('installApk', {
        'path': _downloadedPath,
        'sha256': _latest?['sha256'],
        'versionCode': _latest?['versionCode'],
      });
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    }
  }

  Future<void> _selectApk() async {
    try {
      final value = await _native.invokeMapMethod<String, dynamic>('selectApk');
      if (mounted && value != null)
        setState(() {
          _selected = value;
          _error = null;
        });
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    }
  }

  Future<void> _publish() async {
    final selected = _selected;
    if (selected == null || _busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('انتشار نسخهٔ جدید'),
            content: Text(
              'نسخهٔ ${selected['versionName']} برای همهٔ مدیران روی سرور فروشگاه منتشر شود؟',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('انصراف'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('انتشار'),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _progress = 0;
      _error = null;
      _status = 'در حال بارگذاری روی سرور فروشگاه…';
    });
    try {
      await ref.read(adminApiProvider).publishAppRelease(
        '${selected['path']}',
        '${selected['versionName']}',
        _code(selected),
        _notes.text,
        (done, total) {
          if (mounted)
            setState(() => _progress = total > 0 ? done / total : null);
        },
      );
      if (!mounted) return;
      setState(() {
        _selected = null;
        _status = 'نسخهٔ جدید روی سرور منتشر شد.';
      });
      _notes.clear();
      await _load();
    } catch (error) {
      if (mounted)
        setState(() {
          _error = _message(error);
          _status = null;
        });
    } finally {
      if (mounted)
        setState(() {
          _busy = false;
          _progress = null;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasUpdate =
        _latest != null &&
        _installed != null &&
        _code(_latest) > _code(_installed);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const PanizPageHeader(
            title: 'بروزرسانی',
            subtitle: 'آخرین نسخه مستقیماً از سرور فروشگاه دریافت می‌شود.',
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.system_update_outlined,
                    size: 44,
                    color: context.paniz.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _installed == null
                        ? 'نصب بروزرسانی در نسخهٔ اندروید'
                        : 'نسخهٔ نصب‌شده: ${persianNumber(_installed!['versionName'])}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  if (_installed != null)
                    Text(
                      'شمارهٔ ساخت ${persianNumber(_code(_installed))}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: context.paniz.muted,
                        fontSize: 12,
                      ),
                    ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _loading || _busy ? null : _load,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('بررسی نسخهٔ جدید'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_loading) const LinearProgressIndicator(),
          if (_latest != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'آخرین نسخه: ${persianNumber(_latest!['versionName'])}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Icon(
                          hasUpdate
                              ? Icons.new_releases_outlined
                              : Icons.check_circle_outline,
                          color: context.paniz.primary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'حجم فایل: ${persianNumber(((_latest!['fileSizeBytes'] as num) / 1048576).toStringAsFixed(1))} مگابایت',
                      style: TextStyle(color: context.paniz.muted),
                    ),
                    if ('${_latest!['releaseNotes'] ?? ''}'.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          '${_latest!['releaseNotes']}',
                          style: const TextStyle(height: 1.7),
                        ),
                      ),
                    if (!hasUpdate && _installed != null)
                      const Text('برنامهٔ شما به‌روز است.'),
                    if (hasUpdate) ...[
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed:
                            _busy
                                ? null
                                : _downloadedPath != null
                                ? _install
                                : _download,
                        icon: Icon(
                          _downloadedPath != null
                              ? Icons.install_mobile_outlined
                              : Icons.download_outlined,
                        ),
                        label: Text(
                          _downloadedPath != null
                              ? 'نصب بروزرسانی'
                              : 'دانلود نسخهٔ جدید',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'پس از دانلود، پنجرهٔ نصب اندروید باز می‌شود. اطلاعات فروشگاه روی سرور محفوظ است.',
                        style: TextStyle(
                          color: context.paniz.muted,
                          fontSize: 12,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            )
          else if (!_loading && _error == null)
            const PanizEmptyState(
              icon: Icons.cloud_upload_outlined,
              title: 'هنوز نسخه‌ای منتشر نشده',
              description:
                  'مدیر می‌تواند فایل نسخهٔ جدید را از همین صفحه روی سرور قرار دهد.',
            ),
          if (_busy)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: LinearProgressIndicator(value: _progress),
            ),
          if (_status != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                _status!,
                style: TextStyle(color: context.paniz.primary),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                _error!,
                style: TextStyle(color: context.paniz.error),
              ),
            ),
          if (_canPublish) ...[
            const SizedBox(height: 24),
            sectionTitle('انتشار نسخه روی سرور'),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'APK باید با امضای نسخهٔ فعلی ساخته شده باشد. نام و شمارهٔ نسخه از خود فایل خوانده می‌شود.',
                      style: TextStyle(color: context.paniz.muted, height: 1.6),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _selectApk,
                      icon: const Icon(Icons.attach_file_outlined),
                      label: const Text('انتخاب فایل APK'),
                    ),
                    if (_selected != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        'نسخهٔ ${persianNumber(_selected!['versionName'])} · ساخت ${persianNumber(_code(_selected))}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _notes,
                        maxLines: 4,
                        maxLength: 5000,
                        decoration: const InputDecoration(
                          labelText: 'توضیحات این نسخه',
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _busy ? null : _publish,
                        icon: const Icon(Icons.cloud_upload_outlined),
                        label: const Text('انتشار روی سرور'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (_history.isNotEmpty) ...[
              const SizedBox(height: 20),
              sectionTitle('نسخه‌های منتشرشده'),
              const SizedBox(height: 10),
              ..._history.map(
                (item) => Card(
                  child: ListTile(
                    leading: Icon(
                      item['isCurrent'] == true
                          ? Icons.check_circle_outline
                          : Icons.history_rounded,
                      color: context.paniz.primary,
                    ),
                    title: Text('نسخهٔ ${persianNumber(item['versionName'])}'),
                    subtitle: Text(
                      'ساخت ${persianNumber(item['versionCode'])}',
                    ),
                    trailing:
                        item['isCurrent'] == true ? const Text('فعلی') : null,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
