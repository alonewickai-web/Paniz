// Run after building the API; no database or external color provider is used.
const assert = require('node:assert/strict');
const { productColorKey, resolveProductColorHex, resolveProductColorName } = require('../dist/catalog/product-color.js');

assert.equal(resolveProductColorHex('آبی نفتی'), '#14566B');
assert.equal(resolveProductColorHex('آبي روشن'), '#80BCE8');
assert.equal(resolveProductColorHex('سرمه ای'), '#202E4F');
assert.equal(resolveProductColorName('ابي'), 'آبی');
assert.equal(resolveProductColorName('آبی نفتی'), 'آبی نفتی');
assert.equal(productColorKey('سرمه‌ای'), productColorKey('سرمه ای'));
assert.equal(resolveProductColorHex('صورتی', '#efb4c4'), '#EFB4C4');
assert.equal(resolveProductColorHex('رنگ ناشناخته'), '#89898D');

console.log('PASS: canonical shade names and aliases resolve accurately; explicit HEX is preserved; unknown shades use neutral gray.');
