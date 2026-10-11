import 'package:flutter_test/flutter_test.dart';
import 'package:panizstyle_admin/features/products/product_colors.dart';

void main() {
  test('Persian and Arabic keyboard variants find the same blue shades', () {
    final persianSearch = suggestProductColors('آبی');
    final arabicSearch = suggestProductColors('ابي');

    expect(persianSearch, isNotEmpty);
    expect(persianSearch.first.name, 'آبی');
    expect(
      persianSearch.map((color) => color.name),
      containsAll(['آبی روشن', 'آبی آسمانی', 'آبی نفتی', 'سرمه‌ای']),
    );
    expect(
      arabicSearch.map((color) => color.name),
      persianSearch.map((color) => color.name),
    );
  });

  test('one-character typos still offer likely canonical colors', () {
    final suggestions = suggestProductColors('ابب');

    expect(suggestions.map((color) => color.name), contains('آبی'));
  });

  test('palette options have valid HEX values and unique canonical names', () {
    final names = productColorPalette
        .map((color) => normalizeProductColorText(color.name))
        .toList();

    expect(names.toSet(), hasLength(names.length));
    expect(
      productColorPalette.every((color) => RegExp(r'^#[0-9A-F]{6}$').hasMatch(color.hex)),
      isTrue,
    );
  });
}
