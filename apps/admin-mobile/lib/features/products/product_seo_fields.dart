import 'package:flutter/material.dart';

class ProductSeoFields extends StatelessWidget {
  const ProductSeoFields({
    super.key,
    required this.title,
    required this.description,
    required this.slug,
    required this.canonical,
    required this.productName,
    this.categoryName = '',
    this.productDescription = '',
    this.showSlug = true,
    this.imageAlt,
  });
  final TextEditingController title;
  final TextEditingController description;
  final TextEditingController slug;
  final TextEditingController canonical;
  final TextEditingController? imageAlt;
  final String productName;
  final String categoryName;
  final String productDescription;
  final bool showSlug;

  void _suggest() {
    final name = productName.trim();
    if (name.isEmpty) return;
    title.text = '$name | فروشگاه پانیذ';
    final details = productDescription.trim();
    description.text =
        (details.isNotEmpty
                ? '$name؛ $details'
                : categoryName.isNotEmpty
                ? 'مشاهدهٔ $name در دستهٔ $categoryName فروشگاه پانیذ؛ رنگ‌ها، سایزها و قیمت محصول.'
                : 'مشاهدهٔ $name در فروشگاه پانیذ؛ رنگ‌ها، سایزها و قیمت محصول.')
            .characters
            .take(500)
            .toString();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'تنظیمات سئو',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
          TextButton.icon(
            onPressed: _suggest,
            icon: const Icon(Icons.auto_fix_high_outlined, size: 18),
            label: const Text('پیشنهاد متن'),
          ),
        ],
      ),
      TextFormField(
        controller: title,
        maxLength: 240,
        decoration: const InputDecoration(labelText: 'عنوان نتیجهٔ گوگل'),
      ),
      const SizedBox(height: 8),
      TextFormField(
        controller: description,
        minLines: 2,
        maxLines: 4,
        maxLength: 500,
        decoration: const InputDecoration(labelText: 'توضیح نتیجهٔ گوگل'),
      ),
      if (showSlug) ...[
        const SizedBox(height: 8),
        TextFormField(
          controller: slug,
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(
            labelText: 'آدرس کوتاه محصول (اختیاری)',
            helperText: 'مانند women-sport-set؛ اگر خالی باشد ساخته می‌شود.',
          ),
          validator:
              (value) =>
                  value == null ||
                          value.isEmpty ||
                          RegExp(
                            r'^[a-z0-9]+(?:-[a-z0-9]+)*$',
                          ).hasMatch(value.trim())
                      ? null
                      : 'از حروف انگلیسی کوچک، عدد و خط فاصله استفاده کن.',
        ),
      ],
      const SizedBox(height: 8),
      TextFormField(
        controller: canonical,
        textDirection: TextDirection.ltr,
        keyboardType: TextInputType.url,
        decoration: const InputDecoration(
          labelText: 'نشانی اصلی (Canonical، اختیاری)',
          helperText: 'با خالی گذاشتن، آدرس خود محصول استفاده می‌شود.',
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) return null;
          final uri = Uri.tryParse(value.trim());
          return uri != null &&
                  uri.scheme == 'https' &&
                  uri.host.isNotEmpty &&
                  uri.userInfo.isEmpty
              ? null
              : 'یک آدرس HTTPS معتبر وارد کن.';
        },
      ),
      if (imageAlt != null) ...[
        const SizedBox(height: 8),
        TextFormField(
          controller: imageAlt,
          maxLength: 240,
          decoration: const InputDecoration(
            labelText: 'متن جایگزین تصاویر',
            helperText: 'اگر خالی باشد، نام محصول و رنگ تصویر ثبت می‌شود.',
          ),
        ),
      ],
      const SizedBox(height: 12),
      AnimatedBuilder(
        animation: Listenable.merge([title, description, slug, canonical]),
        builder:
            (context, _) => Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'پیش‌نمایش تقریبی گوگل',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(height: 7),
                  Text(
                    canonical.text.trim().isNotEmpty
                        ? canonical.text.trim()
                        : 'panizstyle.ir/products/${slug.text.trim().isEmpty ? '...' : slug.text.trim()}',
                    textDirection: TextDirection.ltr,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    title.text.trim().isEmpty
                        ? '$productName | پانیذ'
                        : title.text.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    description.text.trim().isEmpty
                        ? productDescription
                        : description.text.trim(),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
      ),
    ],
  );
}
