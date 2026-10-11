const canonicalColors = new Map<string, { name: string; hex: string }>();

export function productColorKey(value: string) {
  return value
    .normalize('NFKC')
    .trim()
    .toLocaleLowerCase('fa-IR')
    .replace(/[يى]/g, 'ی')
    .replace(/ك/g, 'ک')
    .replace(/[آأإ]/g, 'ا')
    .replace(/[\u200c\u200f\u200e\s\-ـ]/g, '');
}

function registerColor(hex: string, names: string[]) {
  const color = { name: names[0], hex };
  for (const name of names) canonicalColors.set(productColorKey(name), color);
}

registerColor('#242326', ['مشکی', 'سیاه', 'ذغالی خیلی تیره']);
registerColor('#FFFFFF', ['سفید', 'سفید خالص']);
registerColor('#F3EBDD', ['شیری', 'استخوانی', 'آف وایت']);
registerColor('#D8C7AF', ['کرم', 'نود', 'کرم روشن']);
registerColor('#A78369', ['نسکافه‌ای', 'نسکافه ای', 'موکا']);
registerColor('#765844', ['قهوه‌ای', 'قهوه ای', 'شکلاتی']);
registerColor('#A77B5B', ['قهوه‌ای روشن', 'قهوه ای روشن', 'کاراملی']);
registerColor('#49352D', ['قهوه‌ای تیره', 'قهوه ای تیره', 'دارک چاکلت']);
registerColor('#B88A5A', ['شتری', 'کمل']);
registerColor('#C6A15B', ['طلایی', 'طلایی مات']);
registerColor('#AEB3B8', ['نقره‌ای', 'نقره ای', 'سیلور']);
registerColor('#89898D', ['خاکستری', 'طوسی', 'فیلی']);
registerColor('#C9C9C9', ['خاکستری روشن', 'طوسی روشن', 'نقره‌ای روشن']);
registerColor('#55545A', ['خاکستری تیره', 'طوسی تیره', 'دودی']);
registerColor('#39383D', ['ذغالی', 'زغالی', 'چارکول']);
registerColor('#C6283D', ['قرمز', 'سرخ']);
registerColor('#E34B54', ['قرمز روشن', 'قرمز گوجه‌ای', 'گوجه ای']);
registerColor('#781F3A', ['زرشکی', 'شرابی', 'عنابی', 'آلبالویی']);
registerColor('#E69AAA', ['صورتی', 'پینک']);
registerColor('#F3C5CE', ['صورتی روشن', 'صورتی ملایم', 'صورتی پاستلی']);
registerColor('#B97883', ['صورتی چرک', 'رز چرک']);
registerColor('#E9A08D', ['گلبهی', 'هلویی صورتی']);
registerColor('#E9A47D', ['هلویی', 'پیچ']);
registerColor('#C32675', ['سرخابی', 'فوشیا', 'ماژنتا']);
registerColor('#C78378', ['رزگلد', 'رز گلد']);
registerColor('#7652A8', ['بنفش', 'ارغوانی']);
registerColor('#B89AD8', ['بنفش روشن', 'لیلاک روشن']);
registerColor('#4C326E', ['بنفش تیره', 'بنفش بادمجانی']);
registerColor('#A99ACB', ['یاسی', 'لیلاک', 'اسطوخودوسی']);
registerColor('#3478B8', ['آبی', 'ابی', 'آبی متوسط', 'آبی کلاسیک']);
registerColor('#80BCE8', ['آبی روشن', 'ابی روشن', 'آبی پاستلی']);
registerColor('#79C5E8', ['آبی آسمانی', 'آسمانی', 'آبی آسمونی']);
registerColor('#C5E4EF', ['آبی یخی', 'یخی آبی']);
registerColor('#14566B', ['آبی نفتی', 'ابی نفتی', 'نفتی']);
registerColor('#1754A0', ['آبی کاربنی', 'کاربنی', 'آبی سلطنتی']);
registerColor('#2850A4', ['آبی لاجوردی', 'لاجوردی']);
registerColor('#202E4F', ['سرمه‌ای', 'سرمه ای', 'سرمه‌ای تیره', 'سرمه ای تیره', 'نیوی']);
registerColor('#394A83', ['نیلی', 'ایندیگو', 'آبی نیلی']);
registerColor('#42B7B1', ['فیروزه‌ای', 'فیروزه ای', 'ترکواز', 'آبی فیروزه‌ای', 'آبی فیروزه ای']);
registerColor('#238A91', ['سبزآبی', 'سبز آبی', 'تیل', 'آبی سبز']);
registerColor('#4D8B58', ['سبز', 'سبز معمولی']);
registerColor('#9BCB92', ['سبز روشن', 'سبز پاستلی']);
registerColor('#A8C8B0', ['سبز نعنایی', 'نعنایی', 'مینت']);
registerColor('#777C45', ['سبز زیتونی', 'زیتونی']);
registerColor('#247A61', ['سبز یشمی', 'یشمی', 'زمردی']);
registerColor('#24564D', ['سبز کله‌غازی', 'سبز کله غازی', 'سبز تیره آبی']);
registerColor('#68724E', ['سبز لجنی', 'ارتشی', 'سبز خاکی']);
registerColor('#31543B', ['سبز تیره', 'سبز یشمی تیره']);
registerColor('#E8C94A', ['زرد', 'لیمویی']);
registerColor('#F5E59B', ['زرد روشن', 'وانیلی']);
registerColor('#C49A32', ['خردلی', 'مستارد']);
registerColor('#E98535', ['نارنجی', 'پرتقالی']);
registerColor('#B85D32', ['نارنجی سوخته', 'آجری نارنجی']);
registerColor('#B96552', ['آجری', 'آجرى']);
registerColor('#AD6F4A', ['مسی', 'مس‌گون']);
registerColor('#CDB99E', ['بژ', 'بژ متوسط']);
registerColor('#D5C3A1', ['شنی', 'کاهی']);
registerColor('#C3A68C', ['نسکافه‌ای روشن', 'نسکافه ای روشن', 'لاته']);
registerColor('#888888', ['چند رنگ', 'مولتی کالر', 'طرح‌دار']);

/**
 * Return the selected HEX when supplied, or a shade-aware fallback for older
 * product rows whose color_hex is null. Unknown names use neutral gray rather
 * than misleading shoppers with the previous universal beige swatch.
 */
export function resolveProductColorHex(colorName: string, hex?: string | null) {
  if (hex && /^#[0-9a-f]{6}$/i.test(hex)) return hex.toUpperCase();
  return canonicalColors.get(productColorKey(colorName))?.hex ?? '#89898D';
}

export function resolveProductColorName(colorName: string) {
  return canonicalColors.get(productColorKey(colorName))?.name ?? colorName.trim();
}
