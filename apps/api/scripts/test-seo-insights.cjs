const assert = require('node:assert/strict');
const { generateKeyPairSync } = require('node:crypto');
const { execFileSync } = require('node:child_process');
const { writeFileSync, unlinkSync } = require('node:fs');
const { tmpdir } = require('node:os');
const { join } = require('node:path');
const { GoogleInsightsService } = require('../dist/analytics/google-insights.service');
const { AdminSiteAnalyticsController } = require('../dist/analytics/site-analytics.controller');
const { CatalogService } = require('../dist/catalog/catalog.service');

let reads = 0;
const product = {
  id: 1n, name: '=SUM(1,2)', slug: 'product', seoTitle: 'محصول پانیذ', seoDescription: 'لباس زنانه', seoCanonicalUrl: null,
  images: [{ imagePath: '/uploads/products/test.jpg', altText: 'لباس زنانه' }],
  category: { id: 1n, name: 'لباس زنانه', slug: 'women' },
  slugRedirects: [{ oldSlug: 'old-product' }],
};
const prisma = {
  product: { findMany: async () => [product], aggregate: async () => ({ _count: { _all: 1 } }), count: async () => 0 },
  productImage: { count: async () => 0 },
  order: { count: async (input) => input.where.createdAt.gte.toISOString().startsWith('2026-09-30') ? 3 : 2 },
  $queryRaw: async () => { reads++; return [{ productId: 1n, paidOrders: 2n, unitsSold: 4n }]; },
};
const config = (values) => ({ get: (key) => values[key] });
const response = (data) => ({ ok: true, json: async () => data });

async function main() {
  let externalCalls = 0;
  global.fetch = async () => { externalCalls++; throw new Error('Network must not be used without configuration'); };
  const disconnected = new GoogleInsightsService(config({}), prisma);
  const first = await disconnected.report('custom', '2026-10-01', '2026-10-07');
  assert.equal(first.data.sources.searchConsole.state, 'needs_configuration');
  assert.equal(first.data.sources.analytics.state, 'needs_configuration');
  assert.equal(first.data.metrics.google.clicks, null);
  assert.equal(first.data.metrics.analytics.users, null);
  assert.equal(first.data.products[0].googleClicks, null);
  assert.equal(first.data.products[0].paidOrders, 2);
  assert.equal(first.data.metrics.store.paidOrders, 3);
  assert.equal(externalCalls, 0);
  await disconnected.report('custom', '2026-10-01', '2026-10-07');
  assert.equal(reads, 1, 'cached requests must not repeat database work');
  await assert.rejects(disconnected.report('unexpected-range'));
  const csv = await disconnected.csv('custom', '2026-10-01', '2026-10-07', 'products');
  assert.ok(csv.startsWith('\uFEFF'));
  assert.ok(csv.includes("'=SUM(1,2)"), 'CSV formula injection must be neutralized');
  const workbook = await disconnected.xlsx('custom', '2026-10-01', '2026-10-07', 'products');
  const workbookPath = join(tmpdir(), `paniz-seo-test-${process.pid}.xlsx`);
  writeFileSync(workbookPath, workbook);
  try {
    execFileSync('python', ['-c', 'import sys,zipfile,xml.etree.ElementTree as E\nz=zipfile.ZipFile(sys.argv[1]); assert z.testzip() is None\nr=E.fromstring(z.read("xl/worksheets/sheet1.xml")); assert len(list(r)) > 0\nassert "=SUM(1,2)" in z.read("xl/worksheets/sheet1.xml").decode("utf-8")', workbookPath]);
  } finally { unlinkSync(workbookPath); }

  const { privateKey } = generateKeyPairSync('rsa', { modulusLength: 2048, privateKeyEncoding: { type: 'pkcs8', format: 'pem' }, publicKeyEncoding: { type: 'spki', format: 'pem' } });
  const values = { GOOGLE_SERVICE_ACCOUNT_EMAIL: 'test@example.invalid', GOOGLE_SERVICE_ACCOUNT_PRIVATE_KEY: privateKey,
    GOOGLE_SEARCH_CONSOLE_SITE_URL: 'https://panizstyle.ir/', GA4_PROPERTY_ID: '123456', GA4_CURRENCY_CODE: 'IRR' };
  const tokens = [];
  global.fetch = async (url, options) => {
    if (url === 'https://oauth2.googleapis.com/token') {
      const assertion = new URLSearchParams(options.body).get('assertion');
      const claims = JSON.parse(Buffer.from(assertion.split('.')[1], 'base64url').toString('utf8'));
      assert.equal(claims.aud, url);
      const token = claims.scope.includes('webmasters') ? 'gsc-token' : 'ga-token';
      tokens.push(claims.scope);
      return response({ access_token: token, expires_in: 3600 });
    }
    const body = JSON.parse(options.body);
    const current = body.startDate === '2026-10-01' || body.dateRanges?.[0]?.startDate === '2026-10-01';
    if (url.includes('searchconsole.googleapis.com')) {
      assert.equal(options.headers.Authorization, 'Bearer gsc-token');
      if (body.dimensions[0] === 'page') return response({ rows: [
        { keys: ['https://panizstyle.ir/products/product'], clicks: 10, impressions: 100, position: 2 },
        { keys: ['https://panizstyle.ir/products/old-product'], clicks: 7, impressions: 50, position: 4 },
      ] });
      return response({ rows: [{ keys: [body.dimensions[0] === 'query' ? 'لباس زنانه' : body.startDate],
        clicks: body.dimensions[0] === 'query' ? (current ? 10 : 5) : (current ? 17 : 8), impressions: 150, position: current ? 2 : 1 }] });
    }
    assert.equal(options.headers.Authorization, 'Bearer ga-token');
    assert.equal(body.currencyCode, 'IRR');
    const names = body.metrics.map((item) => item.name);
    const metrics = { totalUsers: current ? 20 : 10, activeUsers: current ? 12 : 6, newUsers: 7,
      sessions: current ? 30 : 20, screenPageViews: 9, ecommercePurchases: 2, purchaseRevenue: current ? 1000 : 500 };
    if (body.dimensionFilter?.andGroup) {
      const filters = body.dimensionFilter.andGroup.expressions.map((item) => item.filter);
      assert.ok(filters.some((item) => item.fieldName === 'sessionSource' && item.stringFilter.value === 'google'));
      assert.ok(filters.some((item) => item.fieldName === 'sessionMedium' && item.stringFilter.value === 'organic'));
    }
    const dimension = body.dimensions[0]?.name;
    const dimensionValue = dimension === 'date' ? body.dateRanges[0].startDate.replaceAll('-', '') :
      dimension === 'pagePath' ? '/products/product' : dimension === 'deviceCategory' ? 'mobile' : 'Organic Search';
    return response({ metricHeaders: names.map((name) => ({ name })), rowCount: 1,
      rows: [{ dimensionValues: dimension ? [{ value: dimensionValue }] : [], metricValues: names.map((name) => ({ value: String(metrics[name]) })) }] });
  };
  const connected = new GoogleInsightsService(config(values), prisma);
  const report = await connected.report('custom', '2026-10-01', '2026-10-07');
  assert.equal(report.data.sources.analytics.state, 'connected');
  assert.equal(report.data.sources.searchConsole.state, 'connected');
  assert.equal(report.data.metrics.analytics.users, 20);
  assert.equal(report.data.metrics.store.organicRevenueToman, 100);
  assert.equal(report.data.metrics.store.conversionPercent, 10);
  assert.equal(report.data.products[0].googleClicks, 17, 'old product URL traffic must be joined to the current product');
  assert.equal(report.data.products[0].gaPageViews, 9);
  assert.equal(tokens.length, 2, 'parallel requests must share one read-only token per scope');
  assert.ok(tokens.every((scope) => scope.endsWith('.readonly')));

  const controller = new AdminSiteAnalyticsController({}, connected);
  const redacted = await controller.seoReport({ admin: { role: 'staff', permissions: ['reports.view'] } }, 'custom', '2026-10-01', '2026-10-07');
  assert.equal(redacted.data.metrics.store.organicRevenueToman, null);
  assert.equal(report.data.metrics.store.organicRevenueToman, 100, 'redaction must not mutate the cached report');
  const catalog = new CatalogService({ productSlugRedirect: { findUnique: async () => ({ product: {
    slug: 'new-product', status: 'published', publishedAt: new Date('2026-01-01'), deletedAt: null,
    category: { isActive: true }, variants: [{ id: 1n }],
  } }) } }, {});
  assert.equal((await catalog.productSlugRedirect('old-product')).data.redirectTo, '/products/new-product');
  console.log('SEO backend checks passed: truthful empty states, cache, read-only scopes, attribution, old URL history, exports and financial permissions.');
}
main().catch((error) => { console.error(error); process.exitCode = 1; });
