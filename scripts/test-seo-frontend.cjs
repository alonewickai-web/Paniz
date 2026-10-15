const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const vm = require('node:vm');
const ts = require('typescript');
const { NextRequest } = require('next/server');

function load(file, overrides = {}, extra = {}) {
  const module = { exports: {} };
  const code = ts.transpileModule(readFileSync(resolve(__dirname, '..', file), 'utf8'), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022, jsx: ts.JsxEmit.ReactJSX },
  }).outputText;
  const context = { module, exports: module.exports, require: (name) => overrides[name] ?? require(name),
    URL, AbortSignal, console, process: { env: {} }, ...extra };
  vm.runInNewContext(code, context, { filename: file });
  return module.exports;
}

async function main() {
  const saved = new Map();
  const browser = { dataLayer: [], sessionStorage: { getItem: (key) => saved.get(key), setItem: (key, value) => saved.set(key, value) } };
  const disabled = load('app/lib/ga4.ts', {}, { window: browser });
  disabled.trackGa4Purchase('order-1', 110, 10, [{ item_id: 'sku-1', item_name: 'لباس', quantity: 1 }]);
  assert.equal(browser.dataLayer.length, 0);
  assert.equal(saved.size, 0, 'disabled analytics must not mark a purchase as sent');
  const enabled = load('app/lib/ga4.ts', {}, { window: browser, process: { env: { NEXT_PUBLIC_GA4_MEASUREMENT_ID: 'G-TEST123' } } });
  enabled.trackGa4Purchase('order-1', 110, 10, [{ item_id: 'sku-1', item_name: 'لباس', quantity: 1 }]);
  enabled.trackGa4Purchase('order-1', 110, 10, [{ item_id: 'sku-1', item_name: 'لباس', quantity: 1 }]);
  assert.equal(browser.dataLayer.length, 1);
  assert.equal(browser.dataLayer[0][1], 'purchase');
  assert.equal(browser.dataLayer[0][2].transaction_id, 'order-1');
  assert.equal(browser.dataLayer[0][2].value, 1000, 'purchase value must exclude shipping and use IRR');
  assert.equal(browser.dataLayer[0][2].shipping, 100);
  assert.equal(browser.dataLayer[0][2].currency, 'IRR');

  let payload = { data: { id: '1', name: 'لباس زنانه', slug: 'women-set', seoTitle: 'عنوان اختصاصی پانیذ', seoDescription: 'توضیح اختصاصی محصول',
    seoCanonicalUrl: null, shortDescription: null, description: null, image: { path: '/uploads/products/test.jpg', alt: 'لباس' },
    images: [], category: null, variants: [] } };
  const productPage = load('app/products/[slug]/page.tsx', {
    'next/navigation': { notFound: () => { throw new Error('not-found'); }, permanentRedirect: (path) => { throw new Error(`redirect:${path}`); } },
    '../../components/storefront-shell': { StorefrontShell: () => null },
    '../../components/product-detail-view': { ProductDetailView: () => null },
    '../../lib/catalog': { apiBaseUrl: () => 'https://api.panizstyle.ir/api/v1' },
    '../../lib/site-url': { siteUrl: (path = '/') => new URL(path, 'https://panizstyle.ir/').toString() },
  }, { fetch: async () => ({ ok: true, json: async () => payload }) });
  const metadata = await productPage.generateMetadata({ params: Promise.resolve({ slug: 'women-set' }) });
  assert.equal(metadata.title, 'عنوان اختصاصی پانیذ');
  assert.equal(metadata.description, 'توضیح اختصاصی محصول');
  assert.equal(metadata.alternates.canonical, '/products/women-set');
  assert.equal(metadata.openGraph.images[0].url, 'https://api.panizstyle.ir/uploads/products/test.jpg');
  payload = { data: { redirectTo: '/products/new-slug', statusCode: 301 } };
  await assert.rejects(productPage.generateMetadata({ params: Promise.resolve({ slug: 'old-slug' }) }), /redirect:\/products\/new-slug/);

  const { proxy } = load('proxy.ts', { './app/lib/catalog': { apiBaseUrl: () => 'https://api.panizstyle.ir/api/v1' } },
    { fetch: async () => ({ ok: true, json: async () => ({ data: { redirectTo: '/products/new-slug' } }) }) });
  const result = await proxy(new NextRequest('https://panizstyle.ir/products/old-slug'));
  assert.equal(result.status, 301);
  assert.equal(result.headers.get('location'), 'https://panizstyle.ir/products/new-slug');
  const fallback = load('proxy.ts', { './app/lib/catalog': { apiBaseUrl: () => 'https://api.panizstyle.ir/api/v1' } },
    { fetch: async () => { throw new Error('offline'); } });
  assert.equal((await fallback.proxy(new NextRequest('https://panizstyle.ir/products/women-set'))).headers.get('x-middleware-next'), '1');
  console.log('SEO frontend checks passed: product metadata, upload-image URLs, 301, unavailable API fallback and purchase deduplication.');
}
main().catch((error) => { console.error(error); process.exitCode = 1; });
