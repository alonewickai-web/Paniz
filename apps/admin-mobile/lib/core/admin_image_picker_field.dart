import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import 'admin_api.dart';
import 'providers.dart';
import 'ui_helpers.dart';

const _maxUploadBytes = 8 * 1024 * 1024;
const _maxOriginalBytes = 40 * 1024 * 1024;

/// Lets an admin crop and review an image before compressing and uploading it.
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
  final _cropper = ImageCropper();
  CroppedFile? _pendingImage;
  Uint8List? _pendingPreview;
  int? _originalSize;
  String? _compressionSummary;
  String? _busyMessage;

  bool get _busy => _busyMessage != null;
  String? get _imagePath => _cleanPath(widget.imagePath);

  Future<void> _pickImage() async {
    if (_busy) return;
    try {
      setState(() {
        _busyMessage = 'در حال باز کردن تصویر…';
        _compressionSummary = null;
      });
      final selected = await _picker.pickImage(source: ImageSource.gallery);
      if (selected == null || !mounted) return;

      var mimeType = selected.mimeType?.toLowerCase().trim();
      if (mimeType?.isEmpty == true) mimeType = null;
      final extension = selected.name.split('.').last.toLowerCase();
      const extensions = {'jpg', 'jpeg', 'png', 'webp', 'heic', 'heif'};
      final supportedMime =
          mimeType == null ||
          const {
            'image/jpeg',
            'image/jpg',
            'image/png',
            'image/webp',
            'image/heic',
            'image/heif',
          }.contains(mimeType);
      if (!supportedMime ||
          (mimeType == null && !extensions.contains(extension))) {
        showAppMessage(
          context,
          'فرمت تصویر باید JPG، PNG، WebP یا HEIC باشد.',
          error: true,
        );
        return;
      }

      final size = await selected.length();
      if (size > _maxOriginalBytes) {
        showAppMessage(
          context,
          'حجم فایل انتخابی بیش از ۴۰ مگابایت است.',
          error: true,
        );
        return;
      }
      await _cropSelectedImage(
        selected.path,
        preserveTransparency:
            extension == 'png' ||
            extension == 'webp' ||
            mimeType == 'image/png' ||
            mimeType == 'image/webp',
        sourceSize: size,
      );
    } catch (error) {
      if (mounted) {
        showAppMessage(context, AdminApi.friendlyError(error), error: true);
      }
    } finally {
      if (mounted) setState(() => _busyMessage = null);
    }
  }

  Future<void> _editCrop() async {
    final image = _pendingImage;
    if (_busy || image == null) return;
    try {
      setState(() => _busyMessage = 'در حال باز کردن ویرایش تصویر…');
      await _cropSelectedImage(
        image.path,
        preserveTransparency: image.path.toLowerCase().endsWith('.png'),
        sourceSize: _originalSize ?? _pendingPreview?.length ?? 0,
      );
    } catch (error) {
      if (mounted) {
        showAppMessage(context, AdminApi.friendlyError(error), error: true);
      }
    } finally {
      if (mounted) setState(() => _busyMessage = null);
    }
  }

  Future<void> _cropSelectedImage(
    String sourcePath, {
    required bool preserveTransparency,
    required int sourceSize,
  }) async {
    final theme = Theme.of(context);
    final aspectRatioPresets = <CropAspectRatioPresetData>[
      CropAspectRatioPreset.original,
      CropAspectRatioPreset.square,
      CropAspectRatioPreset.ratio3x2,
      CropAspectRatioPreset.ratio4x3,
      CropAspectRatioPreset.ratio16x9,
      if ((widget.aspectRatio - 0.8).abs() < 0.08)
        const _CustomCropAspectRatioPreset(4, 5),
    ];
    final cropped = await _cropper.cropImage(
      sourcePath: sourcePath,
      maxWidth: 3200,
      maxHeight: 3200,
      compressFormat:
          preserveTransparency
              ? ImageCompressFormat.png
              : ImageCompressFormat.jpg,
      compressQuality: 96,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'برش و ویرایش تصویر',
          toolbarColor: theme.colorScheme.surface,
          toolbarWidgetColor: theme.colorScheme.onSurface,
          activeControlsWidgetColor: theme.colorScheme.primary,
          initAspectRatio: _initialAspectRatio,
          lockAspectRatio: false,
          aspectRatioPresets: aspectRatioPresets,
        ),
      ],
    );
    if (cropped == null || !mounted) return;

    final bytes = await cropped.readAsBytes();
    if (bytes.isEmpty) {
      throw const AdminApiException('تصویر ویرایش‌شده قابل خواندن نیست.');
    }
    setState(() {
      _pendingImage = cropped;
      _pendingPreview = bytes;
      _originalSize = sourceSize;
      _compressionSummary = null;
    });
  }

  CropAspectRatioPreset get _initialAspectRatio {
    final ratio = widget.aspectRatio;
    if ((ratio - 1).abs() < 0.08) return CropAspectRatioPreset.square;
    if (ratio < 1) return CropAspectRatioPreset.original;
    if ((ratio - (16 / 9)).abs() < 0.12) {
      return CropAspectRatioPreset.ratio16x9;
    }
    if ((ratio - (3 / 2)).abs() < 0.12) {
      return CropAspectRatioPreset.ratio3x2;
    }
    return CropAspectRatioPreset.original;
  }

  Future<Uint8List> _compressForUpload(CroppedFile cropped) async {
    Uint8List? smallest;
    final preview = _pendingPreview ?? await cropped.readAsBytes();
    final codec = await ui.instantiateImageCodec(preview);
    late final int sourceWidth;
    late final int sourceHeight;
    try {
      final frame = await codec.getNextFrame();
      sourceWidth = frame.image.width;
      sourceHeight = frame.image.height;
      frame.image.dispose();
    } finally {
      codec.dispose();
    }

    for (final settings in const [
      (maxDimension: 1800, quality: 82),
      (maxDimension: 1600, quality: 74),
      (maxDimension: 1400, quality: 66),
    ]) {
      final scale = math.min(
        1.0,
        settings.maxDimension / math.max(sourceWidth, sourceHeight),
      );
      final targetWidth =
          (sourceWidth * scale).round().clamp(1, sourceWidth).toInt();
      final targetHeight =
          (sourceHeight * scale).round().clamp(1, sourceHeight).toInt();
      final bytes = await FlutterImageCompress.compressWithFile(
        cropped.path,
        minWidth: targetWidth,
        minHeight: targetHeight,
        quality: settings.quality,
        format: CompressFormat.webp,
      );
      if (bytes == null || bytes.isEmpty) {
        throw const AdminApiException('فشرده‌سازی تصویر انجام نشد.');
      }
      if (smallest == null || bytes.length < smallest.length) {
        smallest = bytes;
      }
      if (bytes.length <= _maxUploadBytes) return bytes;
    }

    if (smallest != null && smallest.length <= _maxUploadBytes) return smallest;
    throw const AdminApiException(
      'حجم تصویر پس از فشرده‌سازی هنوز زیاد است؛ کادر را کوچک‌تر کن یا تصویر دیگری انتخاب کن.',
    );
  }

  Future<void> _confirmAndUpload() async {
    final cropped = _pendingImage;
    if (_busy || cropped == null) return;
    final originalSize = _originalSize ?? _pendingPreview?.length ?? 0;
    try {
      setState(() => _busyMessage = 'در حال فشرده‌سازی و بارگذاری…');
      final bytes = await _compressForUpload(cropped);
      final filename = 'paniz-${DateTime.now().microsecondsSinceEpoch}.webp';
      final result = await ref
          .read(adminApiProvider)
          .uploadImage(bytes, filename);
      final imagePath = _cleanPath('${result['imagePath'] ?? ''}');
      if (imagePath == null) {
        throw const AdminApiException('مسیر تصویر از سرور دریافت نشد.');
      }
      if (!mounted) return;
      widget.onChanged(imagePath);
      setState(() {
        _pendingImage = null;
        _pendingPreview = null;
        _compressionSummary =
            'حجم تصویر از ${_formatBytes(originalSize)} به ${_formatBytes(bytes.length)} رسید · WebP';
      });
      showAppMessage(context, 'تصویر فشرده و بارگذاری شد.');
    } catch (error) {
      if (mounted) {
        showAppMessage(context, AdminApi.friendlyError(error), error: true);
      }
    } finally {
      if (mounted) setState(() => _busyMessage = null);
    }
  }

  void _cancelPendingImage() {
    setState(() {
      _pendingImage = null;
      _pendingPreview = null;
      _originalSize = null;
      _compressionSummary = null;
    });
  }

  void _removeImage() {
    _cancelPendingImage();
    widget.onChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    final path = _imagePath;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final pending = _pendingPreview;

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
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: AspectRatio(
            aspectRatio: widget.aspectRatio,
            child:
                pending != null
                    ? Image.memory(
                      pending,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (_, __, ___) => _brokenPreview(theme),
                    )
                    : path == null
                    ? _emptyPreview(theme)
                    : Image.network(
                      AdminApi.imageUrl(path),
                      fit: BoxFit.contain,
                      cacheWidth: 1280,
                      errorBuilder: (_, __, ___) => _brokenPreview(theme),
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
        if (_busy) ...[
          const SizedBox(height: 6),
          const LinearProgressIndicator(minHeight: 2),
          const SizedBox(height: 4),
          Text(
            _busyMessage!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 8),
        if (pending != null) ...[
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _editCrop,
                  icon: const Icon(Icons.crop_rotate_rounded),
                  label: const Text('ویرایش برش'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _pickImage,
                  icon: const Icon(Icons.swap_horiz_rounded),
                  label: const Text('تصویر دیگر'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FilledButton.icon(
            onPressed: _busy ? null : _confirmAndUpload,
            icon: const Icon(Icons.check_rounded),
            label: const Text('تأیید، فشرده‌سازی و بارگذاری'),
          ),
          TextButton(
            onPressed: _busy ? null : _cancelPendingImage,
            child: const Text('لغو تصویر جدید'),
          ),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _pickImage,
                  icon: Icon(
                    path == null
                        ? Icons.add_photo_alternate_outlined
                        : Icons.swap_horiz_rounded,
                  ),
                  label: Text(
                    path == null ? 'انتخاب و ویرایش تصویر' : 'جایگزینی تصویر',
                  ),
                ),
              ),
              if (path != null) ...[
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'حذف تصویر انتخاب‌شده',
                  onPressed: _busy ? null : _removeImage,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ],
          ),
        ],
        Padding(
          padding: const EdgeInsetsDirectional.only(top: 3),
          child: Text(
            pending != null
                ? 'پیش‌نمایش برش نهایی است؛ با تأیید، ضلع بلند تصویر تا ۱۸۰۰ پیکسل و حجم فایل تا ۸ مگابایت بهینه می‌شود.'
                : _compressionSummary ??
                    'JPG، PNG، WebP یا HEIC · فایل ورودی تا ۴۰ مگابایت · برش در اپ و فشرده‌سازی تا ۸ مگابایت پس از تأیید',
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

  Widget _emptyPreview(ThemeData theme) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(
        Icons.add_photo_alternate_outlined,
        size: 32,
        color: theme.colorScheme.primary,
      ),
      const SizedBox(height: 6),
      Text('هنوز تصویری انتخاب نشده', style: theme.textTheme.bodySmall),
    ],
  );

  Widget _brokenPreview(ThemeData theme) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(
        Icons.broken_image_outlined,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      const SizedBox(height: 4),
      Text('پیش‌نمایش تصویر در دسترس نیست', style: theme.textTheme.bodySmall),
    ],
  );
}

String? _cleanPath(String? path) {
  final value = path?.trim() ?? '';
  return value.isEmpty ? null : value;
}

String _formatBytes(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} مگابایت';
  }
  return '${(bytes / 1024).ceil()} کیلوبایت';
}

class _CustomCropAspectRatioPreset implements CropAspectRatioPresetData {
  const _CustomCropAspectRatioPreset(this.width, this.height);

  final int width;
  final int height;

  @override
  (int, int)? get data => (width, height);

  @override
  String get name => '${width}x$height';
}
