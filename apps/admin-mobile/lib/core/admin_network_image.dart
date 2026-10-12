import 'package:flutter/material.dart';

import 'admin_api.dart';

/// Displays a remote store image and lets the admin retry transient failures.
class AdminNetworkImage extends StatefulWidget {
  const AdminNetworkImage({
    super.key,
    required this.imagePath,
    this.width,
    this.height,
    this.cacheWidth,
    this.fit = BoxFit.contain,
    this.placeholderColor,
  });

  final String? imagePath;
  final double? width;
  final double? height;
  final int? cacheWidth;
  final BoxFit fit;
  final Color? placeholderColor;

  @override
  State<AdminNetworkImage> createState() => _AdminNetworkImageState();
}

class _AdminNetworkImageState extends State<AdminNetworkImage> {
  int _retry = 0;

  void _retryLoading() => setState(() => _retry++);

  @override
  Widget build(BuildContext context) {
    final path = widget.imagePath?.trim() ?? '';
    final baseUrl = AdminApi.imageUrl(path);
    if (baseUrl.isEmpty) return _placeholder(context);

    final uri = Uri.parse(baseUrl);
    final imageUri =
        _retry == 0
            ? uri
            : uri.replace(
              queryParameters: {
                ...uri.queryParameters,
                '_paniz_retry':
                    '$_retry-${DateTime.now().microsecondsSinceEpoch}',
              },
            );

    return Image.network(
      imageUri.toString(),
      width: widget.width,
      height: widget.height,
      cacheWidth: widget.cacheWidth,
      fit: widget.fit,
      errorBuilder: (context, error, stackTrace) => _retryPrompt(context),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value:
                  progress.expectedTotalBytes == null
                      ? null
                      : progress.cumulativeBytesLoaded /
                          progress.expectedTotalBytes!,
            ),
          ),
        );
      },
    );
  }

  Widget _placeholder(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: ColoredBox(
        color: widget.placeholderColor ?? colors.surfaceContainerHighest,
        child: Icon(Icons.checkroom_rounded, color: colors.onSurfaceVariant),
      ),
    );
  }

  Widget _retryPrompt(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Material(
        color: widget.placeholderColor ?? colors.surfaceContainerHighest,
        child: InkWell(
          onTap: _retryLoading,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact =
                  constraints.maxWidth < 120 || constraints.maxHeight < 80;
              return Center(
                child:
                    compact
                        ? Tooltip(
                          message: 'بارگذاری دوباره تصویر',
                          child: Icon(
                            Icons.refresh_rounded,
                            color: colors.primary,
                          ),
                        )
                        : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.broken_image_outlined,
                              color: colors.onSurfaceVariant,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'بارگذاری دوباره',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
              );
            },
          ),
        ),
      ),
    );
  }
}
