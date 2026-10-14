import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../core/admin_api.dart';
import '../../core/admin_avatar.dart';
import '../../core/paniz_theme.dart';
import '../../core/providers.dart';
import '../../core/ui_helpers.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, required this.admin});
  final AdminIdentity admin;
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.admin.fullName);
  late final _phone = TextEditingController(text: widget.admin.phone);
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _photo() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('انتخاب از گالری'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: const Text('گرفتن عکس'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
              ],
            ),
          ),
    );
    if (source == null) return;
    try {
      final image = await ImagePicker().pickImage(
        source: source,
        maxWidth: 640,
        maxHeight: 640,
        imageQuality: 80,
      );
      if (image == null || !mounted) return;
      final cropped = await ImageCropper().cropImage(
        sourcePath: image.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'تنظیم عکس پروفایل',
            lockAspectRatio: true,
            aspectRatioPresets: [CropAspectRatioPreset.square],
          ),
          IOSUiSettings(
            title: 'تنظیم عکس پروفایل',
            aspectRatioLockEnabled: true,
            aspectRatioPresets: [CropAspectRatioPreset.square],
          ),
        ],
      );
      if (cropped == null || !mounted) return;
      final bytes = await cropped.readAsBytes();
      if (bytes.length > 1024 * 1024)
        throw const AdminApiException(
          'حجم تصویر باید کمتر از یک مگابایت باشد.',
        );
      setState(() {
        _busy = true;
        _error = null;
      });
      await ref
          .read(adminApiProvider)
          .uploadProfileAvatar(
            bytes,
            'profile.${cropped.path.split('.').last}',
          );
      await ref.read(authProvider.notifier).refreshIdentity();
      if (mounted) {
        showAppMessage(context, 'تصویر پروفایل ذخیره شد.');
        Navigator.of(context).maybePop();
      }
    } catch (error) {
      if (mounted) setState(() => _error = AdminApi.friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removePhoto() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('حذف عکس پروفایل؟'),
            content: const Text('عکس پروفایل از حساب شما حذف می‌شود.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('لغو'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('حذف'),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(adminApiProvider).deleteProfileAvatar();
      await ref.read(authProvider.notifier).refreshIdentity();
      if (mounted) showAppMessage(context, 'عکس پروفایل حذف شد.');
    } catch (error) {
      if (mounted) setState(() => _error = AdminApi.friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _previewPhoto(AdminIdentity admin) {
    if (admin.avatarPath?.trim().isEmpty != false) return;
    showDialog<void>(
      context: context,
      builder:
          (context) => Dialog(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: InteractiveViewer(
                child: Image.network(
                  AdminApi.imageUrl(admin.avatarPath!),
                  fit: BoxFit.contain,
                  errorBuilder:
                      (_, __, ___) => const SizedBox(
                        height: 220,
                        child: Center(child: Text('نمایش عکس ممکن نیست.')),
                      ),
                ),
              ),
            ),
          ),
    );
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(adminApiProvider).updateProfile({
        'fullName': _name.text.trim(),
        'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      });
      await ref.read(authProvider.notifier).refreshIdentity();
      if (mounted) {
        showAppMessage(context, 'اطلاعات حساب ذخیره شد.');
        Navigator.of(context).maybePop();
      }
    } catch (error) {
      if (mounted) setState(() => _error = AdminApi.friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = ref.watch(authProvider).asData?.value ?? widget.admin;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                InkWell(
                  onTap: () => _previewPhoto(admin),
                  customBorder: const CircleBorder(),
                  child: AdminAvatar(
                    name: admin.fullName,
                    path: admin.avatarPath,
                    size: 88,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  admin.fullName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '@${admin.username}',
                  textDirection: TextDirection.ltr,
                  style: TextStyle(color: context.paniz.muted),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _photo,
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: const Text('تغییر عکس پروفایل'),
                    ),
                    if (admin.avatarPath?.trim().isNotEmpty == true)
                      TextButton.icon(
                        onPressed: _busy ? null : _removePhoto,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('حذف عکس'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Form(
          key: _form,
          child: Column(
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'نام و نام خانوادگی',
                ),
                validator:
                    (value) =>
                        (value?.trim().length ?? 0) >= 2
                            ? null
                            : 'نام کامل را وارد کنید.',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                textDirection: TextDirection.ltr,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'شماره تماس'),
              ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(_error!, style: TextStyle(color: context.paniz.error)),
          ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _busy ? null : _save,
          icon: const Icon(Icons.check_outlined),
          label: Text(_busy ? 'در حال ذخیره…' : 'ذخیرهٔ اطلاعات'),
        ),
      ],
    );
  }
}
