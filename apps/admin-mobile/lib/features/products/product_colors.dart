import 'package:flutter/material.dart';

@immutable
class ProductColorOption {
  const ProductColorOption(this.name, this.hex, {this.aliases = const []});

  final String name;
  final String hex;
  final List<String> aliases;

  Color get color => Color(int.parse(hex.substring(1), radix: 16) | 0xFF000000);
}

/// One canonical name and HEX value per selectable shade. Keep this in sync
/// with the API's legacy color-name resolver.
const productColorPalette = <ProductColorOption>[
  ProductColorOption('مشکی', '#242326', aliases: ['سیاه', 'ذغالی خیلی تیره']),
  ProductColorOption('سفید', '#FFFFFF', aliases: ['سفید خالص']),
  ProductColorOption('شیری', '#F3EBDD', aliases: ['استخوانی', 'آف وایت']),
  ProductColorOption('کرم', '#D8C7AF', aliases: ['نود', 'کرم روشن']),
  ProductColorOption('نسکافه‌ای', '#A78369', aliases: ['نسکافه ای', 'موکا']),
  ProductColorOption('قهوه‌ای', '#765844', aliases: ['قهوه ای', 'شکلاتی']),
  ProductColorOption('قهوه‌ای روشن', '#A77B5B', aliases: ['کاراملی']),
  ProductColorOption('قهوه‌ای تیره', '#49352D', aliases: ['دارک چاکلت']),
  ProductColorOption('شتری', '#B88A5A', aliases: ['کَمِل']),
  ProductColorOption('طلایی', '#C6A15B', aliases: ['طلایی مات']),
  ProductColorOption('نقره‌ای', '#AEB3B8', aliases: ['نقره ای', 'سیلور']),
  ProductColorOption('خاکستری', '#89898D', aliases: ['طوسی', 'فیلی']),
  ProductColorOption('خاکستری روشن', '#C9C9C9', aliases: ['طوسی روشن', 'نقره‌ای روشن']),
  ProductColorOption('خاکستری تیره', '#55545A', aliases: ['طوسی تیره', 'دودی']),
  ProductColorOption('ذغالی', '#39383D', aliases: ['زغالی', 'چارکول']),
  ProductColorOption('قرمز', '#C6283D', aliases: ['سرخ']),
  ProductColorOption('قرمز روشن', '#E34B54', aliases: ['قرمز گوجه‌ای', 'گوجه ای']),
  ProductColorOption('زرشکی', '#781F3A', aliases: ['شرابی', 'عنابی', 'آلبالویی']),
  ProductColorOption('صورتی', '#E69AAA', aliases: ['پینک']),
  ProductColorOption('صورتی روشن', '#F3C5CE', aliases: ['صورتی ملایم', 'صورتی پاستلی']),
  ProductColorOption('صورتی چرک', '#B97883', aliases: ['رز چرک']),
  ProductColorOption('گلبهی', '#E9A08D', aliases: ['هلویی صورتی']),
  ProductColorOption('هلویی', '#E9A47D', aliases: ['پِیچ']),
  ProductColorOption('سرخابی', '#C32675', aliases: ['فوشیا', 'ماژنتا']),
  ProductColorOption('رزگلد', '#C78378', aliases: ['رز گلد']),
  ProductColorOption('بنفش', '#7652A8', aliases: ['ارغوانی']),
  ProductColorOption('بنفش روشن', '#B89AD8', aliases: ['لیلاک روشن']),
  ProductColorOption('بنفش تیره', '#4C326E', aliases: ['بنفش بادمجانی']),
  ProductColorOption('یاسی', '#A99ACB', aliases: ['لیلاک', 'اسطوخودوسی']),
  ProductColorOption('آبی', '#3478B8', aliases: ['ابی', 'آبی متوسط', 'آبی کلاسیک']),
  ProductColorOption('آبی روشن', '#80BCE8', aliases: ['ابی روشن', 'آبی پاستلی']),
  ProductColorOption('آبی آسمانی', '#79C5E8', aliases: ['آسمانی', 'آبی آسمونی']),
  ProductColorOption('آبی یخی', '#C5E4EF', aliases: ['یخی آبی']),
  ProductColorOption('آبی نفتی', '#14566B', aliases: ['ابی نفتی', 'نفتی']),
  ProductColorOption('آبی کاربنی', '#1754A0', aliases: ['کاربنی', 'آبی سلطنتی']),
  ProductColorOption('آبی لاجوردی', '#2850A4', aliases: ['لاجوردی']),
  ProductColorOption('سرمه‌ای', '#202E4F', aliases: ['سرمه ای', 'سرمه‌ای تیره', 'سرمه ای تیره', 'آبی سرمه‌ای', 'آبی سرمه ای', 'نِیوی']),
  ProductColorOption('نیلی', '#394A83', aliases: ['ایندیگو', 'آبی نیلی']),
  ProductColorOption('فیروزه‌ای', '#42B7B1', aliases: ['فیروزه ای', 'ترکواز', 'آبی فیروزه‌ای', 'آبی فیروزه ای']),
  ProductColorOption('سبزآبی', '#238A91', aliases: ['تیل', 'سبز آبی', 'آبی سبز']),
  ProductColorOption('سبز', '#4D8B58', aliases: ['سبز معمولی']),
  ProductColorOption('سبز روشن', '#9BCB92', aliases: ['سبز پاستلی']),
  ProductColorOption('سبز نعنایی', '#A8C8B0', aliases: ['نعنایی', 'مینت']),
  ProductColorOption('سبز زیتونی', '#777C45', aliases: ['زیتونی']),
  ProductColorOption('سبز یشمی', '#247A61', aliases: ['یشمی', 'زمردی']),
  ProductColorOption('سبز کله‌غازی', '#24564D', aliases: ['کله غازی', 'سبز تیره آبی']),
  ProductColorOption('سبز لجنی', '#68724E', aliases: ['ارتشی', 'سبز خاکی']),
  ProductColorOption('سبز تیره', '#31543B', aliases: ['سبز یشمی تیره']),
  ProductColorOption('زرد', '#E8C94A', aliases: ['لیمویی']),
  ProductColorOption('زرد روشن', '#F5E59B', aliases: ['وانیلی']),
  ProductColorOption('خردلی', '#C49A32', aliases: ['مستارد']),
  ProductColorOption('نارنجی', '#E98535', aliases: ['پرتقالی']),
  ProductColorOption('نارنجی سوخته', '#B85D32', aliases: ['آجری نارنجی']),
  ProductColorOption('آجری', '#B96552', aliases: ['آجرى']),
  ProductColorOption('مسی', '#AD6F4A', aliases: ['مس‌گون']),
  ProductColorOption('بژ', '#CDB99E', aliases: ['بژ متوسط']),
  ProductColorOption('شنی', '#D5C3A1', aliases: ['کاهی']),
  ProductColorOption('نسکافه‌ای روشن', '#C3A68C', aliases: ['لاته']),
  ProductColorOption('چند رنگ', '#888888', aliases: ['مولتی کالر', 'طرح‌دار']),
];

String normalizeProductColorText(String value) => value
    .toLowerCase()
    .replaceAll('ي', 'ی')
    .replaceAll('ى', 'ی')
    .replaceAll('ك', 'ک')
    .replaceAll('آ', 'ا')
    .replaceAll('أ', 'ا')
    .replaceAll(RegExp(r'[\u200c\u200f\u200e\s\-ـ]'), '');

List<ProductColorOption> suggestProductColors(String query, {int limit = 12}) {
  final normalizedQuery = normalizeProductColorText(query.trim());
  if (normalizedQuery.isEmpty) return productColorPalette.take(limit).toList();

  final ranked = <({ProductColorOption option, int score, int index})>[];
  for (var index = 0; index < productColorPalette.length; index++) {
    final option = productColorPalette[index];
    final terms = [option.name, ...option.aliases]
        .map(normalizeProductColorText)
        .toList();
    var bestScore = 1 << 20;
    for (final term in terms) {
      final score = _matchScore(normalizedQuery, term);
      if (score < bestScore) bestScore = score;
    }
    if (bestScore < 1 << 20) {
      ranked.add((option: option, score: bestScore, index: index));
    }
  }
  ranked.sort((a, b) {
    final byScore = a.score.compareTo(b.score);
    return byScore != 0 ? byScore : a.index.compareTo(b.index);
  });
  return ranked.take(limit).map((entry) => entry.option).toList();
}

int _matchScore(String query, String term) {
  if (query == term) return 0;
  if (term.startsWith(query)) return 100 + term.length - query.length;
  if (term.contains(query)) return 200 + term.indexOf(query);

  var bestDistance = 1 << 20;
  final tolerance = query.length >= 7 ? 2 : 1;
  final minimumLength =
      (query.length - tolerance).clamp(1, query.length).toInt();
  final maximumLength = query.length + tolerance;
  for (var length = minimumLength; length <= maximumLength; length++) {
    if (length > term.length) continue;
    for (var start = 0; start + length <= term.length; start++) {
      final distance = _editDistance(query, term.substring(start, start + length));
      if (distance < bestDistance) bestDistance = distance;
    }
  }
  return bestDistance <= tolerance ? 300 + bestDistance : 1 << 20;
}

int _editDistance(String first, String second) {
  var previous = List<int>.generate(second.length + 1, (index) => index);
  for (var row = 1; row <= first.length; row++) {
    final current = List<int>.filled(second.length + 1, row);
    for (var column = 1; column <= second.length; column++) {
      final substitution = previous[column - 1] +
          (first.codeUnitAt(row - 1) == second.codeUnitAt(column - 1) ? 0 : 1);
      current[column] = [
        current[column - 1] + 1,
        previous[column] + 1,
        substitution,
      ].reduce((left, right) => left < right ? left : right);
    }
    previous = current;
  }
  return previous[second.length];
}

class ProductColorField extends StatelessWidget {
  const ProductColorField({
    super.key,
    required this.initialValue,
    required this.selectedColor,
    required this.onSelected,
    required this.onQueryChanged,
  });

  final String initialValue;
  final ProductColorOption? selectedColor;
  final ValueChanged<ProductColorOption> onSelected;
  final ValueChanged<String> onQueryChanged;

  @override
  Widget build(BuildContext context) => Autocomplete<ProductColorOption>(
    initialValue: TextEditingValue(text: initialValue),
    displayStringForOption: (option) => option.name,
    optionsBuilder: (value) => suggestProductColors(value.text),
    onSelected: onSelected,
    optionsViewBuilder: (context, onSelected, options) => Align(
      alignment: AlignmentDirectional.topStart,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 6),
            shrinkWrap: true,
            itemCount: options.length,
            itemBuilder: (context, index) {
              final option = options.elementAt(index);
              return ListTile(
                dense: true,
                leading: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: option.color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
                title: Text(option.name),
                subtitle: Text(option.hex, textDirection: TextDirection.ltr),
                onTap: () => onSelected(option),
              );
            },
          ),
        ),
      ),
    ),
    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) =>
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          textInputAction: TextInputAction.search,
          onFieldSubmitted: (_) => onFieldSubmitted(),
          onChanged: onQueryChanged,
          validator: (value) {
            if (value == null || value.trim().isEmpty) return 'رنگ را انتخاب کن';
            if (selectedColor == null ||
                normalizeProductColorText(value) !=
                    normalizeProductColorText(selectedColor!.name)) {
              return 'یک رنگ را از پیشنهادها انتخاب کن';
            }
            return null;
          },
          decoration: InputDecoration(
            labelText: 'رنگ',
            hintText: 'مثلاً «آبی» را جست‌وجو کن',
            suffixIcon: selectedColor == null
                ? const Icon(Icons.search_rounded)
                : Padding(
                    padding: const EdgeInsets.all(13),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: selectedColor!.color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      child: const SizedBox(width: 16, height: 16),
                    ),
                  ),
          ),
        ),
  );
}
