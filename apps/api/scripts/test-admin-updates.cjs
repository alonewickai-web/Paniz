// Local HTTP integration checks with an in-memory store. Never connects to production.
require('reflect-metadata');
const assert = require('node:assert/strict');
const { mkdtemp, readdir, rm } = require('node:fs/promises');
const { join } = require('node:path');
const { tmpdir } = require('node:os');
const { createHash } = require('node:crypto');
const { Module, ValidationPipe } = require('@nestjs/common');
const { NestFactory, Reflector } = require('@nestjs/core');
const { AdminAppReleaseController } = require('../dist/admin/admin-app-release.controller');
const { AdminAppReleaseService } = require('../dist/admin/admin-app-release.service');
const { AdminSessionGuard } = require('../dist/admin-auth/admin-session.guard');
const { AdminPermissionGuard, RequireAdminPermission } = require('../dist/admin-auth/admin-permission.guard');
const { hasAdminPermission } = require('../dist/admin-auth/admin-permissions');
const { AdminManagementService } = require('../dist/admin/admin-management.service');
const { PrismaService } = require('../dist/database/prisma.service');

const owner = { id: 1n, role: 'owner', permissions: [], fullName: 'Local owner' };
const staff = { ...owner, id: 2n, role: 'staff', permissions: ['staff.activity'] };
function ctx(request, handler = () => {}) { return { switchToHttp: () => ({ getRequest: () => request }), getHandler: () => handler, getClass: () => class Local {} }; }
function apkFixture() {
  const entries = ['AndroidManifest.xml', 'classes.dex'].map((name) => {
    const text = Buffer.from(name); const entry = Buffer.alloc(46 + text.length);
    entry.writeUInt32LE(0x02014b50, 0); entry.writeUInt16LE(text.length, 28); text.copy(entry, 46); return entry;
  });
  const directory = Buffer.concat(entries); const end = Buffer.alloc(22);
  end.writeUInt32LE(0x06054b50); end.writeUInt16LE(2, 8); end.writeUInt16LE(2, 10); end.writeUInt32LE(directory.length, 12);
  return Buffer.concat([directory, end]);
}

(async () => {
  assert.equal(hasAdminPermission(owner, 'system.release'), true);
  assert.equal(hasAdminPermission(staff, 'system.release'), false);
  const protectedHandler = () => {};
  RequireAdminPermission('system.release')({}, 'publish', { value: protectedHandler });
  const permissions = new AdminPermissionGuard(new Reflector());
  assert.throws(() => permissions.canActivate(ctx({ admin: staff }, protectedHandler)), (error) => error.getStatus() === 403);
  assert.equal(permissions.canActivate(ctx({ admin: owner }, protectedHandler)), true);

  const session = { id: 3n, revokedAt: null, expiresAt: new Date(Date.now() + 60000), admin: {
    ...staff, isActive: true, mustChangePassword: true, permissions: [
      { permissionKey: 'products.view', expiresAt: new Date(Date.now() + 60000) },
      { permissionKey: 'system.release', expiresAt: new Date(Date.now() - 60000) },
    ],
  } };
  const guard = new AdminSessionGuard({ adminSession: { findUnique: async () => session, update: async () => {} } });
  const request = { headers: { authorization: 'Bearer local-test-only' }, method: 'GET', path: '/api/v1/admin/auth/me' };
  await guard.canActivate(ctx(request));
  assert.deepEqual(request.admin.permissions, ['products.view']);
  await assert.rejects(guard.canActivate(ctx({ ...request, path: '/api/v1/admin/dashboard' })), (error) => error.getStatus() === 403);
  session.revokedAt = new Date();
  await assert.rejects(guard.canActivate(ctx(request)), (error) => error.getStatus() === 401);

  const activity = { id: 1n, adminId: 1n, action: 'product.updated', entityType: 'product', entityId: 5n,
    details: { before: { priceToman: '500', phone: 'local-phone', password: 'local-secret' }, productName: 'Local product' }, result: 'success', requestIp: null, createdAt: new Date(), admin: null };
  const management = new AdminManagementService({ adminAuditLog: { findUnique: async () => activity } });
  const filtered = (await management.getAuditLog(staff, '1')).data.details;
  assert.equal(filtered.before.priceToman, '[حذف‌شده]');
  assert.equal(filtered.before.phone, '[حذف‌شده]');
  assert.equal((await management.getAuditLog(owner, '1')).data.details.before.priceToman, '500');
  assert.equal((await management.getAuditLog(owner, '1')).data.details.before.password, '[حذف‌شده]');
  await assert.rejects(management.createStaff({ ...staff, permissions: ['staff.manage'] }, { fullName: 'Local', username: 'local', permissions: ['system.release'] }), (error) => error.getStatus() === 403);
  await assert.rejects(management.updateStaff(owner, '1', { permissions: [] }), (error) => error.getStatus() === 403);

  const directory = await mkdtemp(join(tmpdir(), 'paniz-release-test-'));
  process.env.UPLOADS_DIR = directory;
  const rows = [], audits = [];
  const store = {
    adminSession: { findUnique: async () => ({ id: 5n, revokedAt: null, expiresAt: new Date(Date.now() + 60000), admin: { ...owner, isActive: true, mustChangePassword: false } }), update: async () => {} },
    adminAppRelease: {
      findFirst: async () => rows.at(-1) ?? null,
      findMany: async () => [...rows].reverse(),
      updateMany: async () => { rows.forEach((row) => row.isCurrent = false); },
      create: async ({ data }) => { const row = { ...data, id: BigInt(rows.length + 1), publishedAt: new Date() }; rows.push(row); return row; },
    }, adminAuditLog: { create: async ({ data }) => audits.push(data) },
  };
  store.$transaction = async (operation) => operation(store);
  const releases = new AdminAppReleaseService(store);
  class LocalModule {}
  Module({ controllers: [AdminAppReleaseController], providers: [
    { provide: AdminAppReleaseService, useValue: releases },
    { provide: PrismaService, useValue: store },
    AdminPermissionGuard,
  ] })(LocalModule);
  let app;
  try {
    app = await NestFactory.create(LocalModule, { logger: false, abortOnError: false });
    app.useGlobalPipes(new ValidationPipe({ transform: true, whitelist: true, forbidNonWhitelisted: true }));
    await app.listen(0, '127.0.0.1');
    const base = await app.getUrl();
    const apk = apkFixture();
    const publish = async (version, bytes = apk) => {
      const form = new FormData(); form.set('file', new Blob([bytes]), 'local.apk');
      form.set('versionName', '1.0.12'); form.set('versionCode', version); form.set('releaseNotes', 'Local test');
      return fetch(`${base}/admin/app-releases`, { method: 'POST', body: form, headers: { Authorization: 'Bearer local-integration-only' } });
    };
    assert.equal((await fetch(`${base}/admin/app-releases/latest`)).status, 200);
    assert.equal((await publish('invalid')).status, 400);
    assert.deepEqual(await readdir(join(directory, 'admin-releases')), []);
    assert.equal((await publish('10', Buffer.from('not-an-apk'))).status, 400);
    assert.deepEqual(await readdir(join(directory, 'admin-releases')), []);
    const first = await publish('10'); assert.equal(first.status, 201);
    const manifest = (await first.json()).data;
    assert.equal(manifest.sha256, createHash('sha256').update(apk).digest('hex'));
    assert.equal(manifest.fileSizeBytes, apk.length);
    assert.match(manifest.downloadPath, /^\/uploads\/admin-releases\/[a-f0-9-]+\.apk$/);
    assert.equal((await publish('10')).status, 409);
    assert.equal((await readdir(join(directory, 'admin-releases'))).length, 1);
    assert.equal((await publish('11')).status, 201);
    const latest = (await (await fetch(`${base}/admin/app-releases/latest`)).json()).data;
    assert.equal(latest.versionCode, 11); assert.equal(rows[0].isCurrent, false); assert.equal(audits.length, 2);
    assert.equal((await readdir(join(directory, 'admin-releases'))).length, 2);
    console.log('PASS: release HTTP validation, file cleanup, monotonic versions, SHA-256, retained history, permission enforcement, expired/revoked sessions, forced password, audit redaction, self-change and escalation protection.');
  } finally { if (app) await app.close(); await rm(directory, { recursive: true, force: true }); }
})().catch((error) => { console.error(error); process.exitCode = 1; });
