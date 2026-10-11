import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'admin_api.dart';
import 'providers.dart';
import 'ui_helpers.dart';

/// Uploads an image to the store API and returns its public path to the form.
class AdminImagePickerField extends ConsumerStatefulWidget {
  const AdminImagePickerField({
    super.key,
    required this.imagePath,
    required this.onChanged,
    this.label = 'تصویر',
    this.aspectRatio = 16 / 9,
    this.errorText,
  });

  final String? imagePath;
  final ValueChanged<String?> onChanged;
  final String label;
  final double aspectRatio;
  final String? errorText;

  @override
  ConsumerState<AdminImagePickerField> createState() =>
      _AdminImagePickerFieldState();
}

class _AdminImagePickerFieldState extends ConsumerState<AdminImagePickerField> {
  final _picker = ImagePicker();
  bool _uploading = false;

  String? get _imagePath => _cleanPath(widget.imagePath);

  Future<void> _pickAndUpload() async {
    try {
      final selected = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2400,
        imageQuality: 86,
      );
      if (selected == null || !mounted) return;

      final mimeType = selected.mimeType?.toLowerCase();
      if (mimeType != null &&
          !const {'image/jpeg', 'image/png', 'image/webp'}.contains(mimeType)) {
        showAppMessage(
          context,
          'فرمت تصویر باید JPG، PNG یا WebP باشد.',
          error: true,
        );
        return;
      }

      setState(() => _uploading = true);
      final bytes = await selected.readAsBytes();
      if (bytes.length > 8 * 1024 * 1024) {
        showAppMessage(
          context,
          'حجم تصویر باید کمتر از ۸ مگابایت باشد.',
          error: true,
        );
        return;
      }

      final result = await ref
          .read(adminApiProvider)
          .uploadImage(bytes, selected.name);
      final imagePath = _cleanPath('${result['imagePath'] ?? ''}');
      if (imagePath == null) {
        throw const AdminApiException('مسیر تصویر از سرور دریافت نشد.');
      }
      if (!mounted) return;
      widget.onChanged(imagePath);
      showAppMessage(context, 'تصویر بارگذاری شد.');
    } catch (error) {
      if (mounted) {
        showAppMessage(context, AdminApi.friendlyError(error), error: true);
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final path = _imagePath;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(widget.label, style: theme.textTheme.labelLarge),
        ),
        const SizedBox(height: 8),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: AspectRatio(
            aspectRatio: widget.aspectRatio,
            child:
                path == null
                    ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 32,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'هنوز تصویری انتخاب نشده',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    )
                    : Image.network(
                      AdminApi.imageUrl(path),
                      fit: BoxFit.cover,
                      errorBuilder:
                          (_, __, ___) => Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.broken_image_outlined,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'پیش‌نمایش تصویر در دسترس نیست',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                      loadingBuilder:
                          (context, child, progress) =>
                              progress == null
                                  ? child
                                  : const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                    ),
          ),
        ),
        if (_uploading) ...[
          const SizedBox(height: 6),
          const LinearProgressIndicator(minHeight: 2),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _uploading ? null : _pickAndUpload,
                icon:
                    _uploading
                        ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : Icon(
                          path == null
                              ? Icons.add_photo_alternate_outlined
                              : Icons.swap_horiz_rounded,
                        ),
                label: Text(
                  _uploading
                      ? 'در حال بارگذاری…'
                      : path == null
                      ? 'انتخاب و بارگذاری تصویر'
                      : 'جایگزینی تصویر',
                ),
              ),
            ),
            if (path != null) ...[
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'حذف تصویر انتخاب‌شده',
                onPressed: _uploading ? null : () => widget.onChanged(null),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ],
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(top: 3),
          child: Text(
            'JPG، PNG یا WebP · حداکثر ۸ مگابایت',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (widget.errorText != null) ...[
          const SizedBox(height: 4),
          Text(
            widget.errorText!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }
}

String? _cleanPath(String? path) {
  final value = path?.trim() ?? '';
  return value.isEmpty ? null : value;
}
