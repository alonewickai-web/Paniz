// Run after building the API. No database or customer records are used.
const assert = require('node:assert/strict');
const { AdminToolsService } = require('../dist/admin/admin-tools.service.js');

const originalSetInterval = global.setInterval;
const originalSetTimeout = global.setTimeout;
const intervalCallbacks = [];
const timeoutCallbacks = [];
let databaseCalls = 0;

async function main() {
  global.setInterval = (callback, delay) => {
    intervalCallbacks.push({ callback, delay });
    return { unref() {} };
  };
  global.setTimeout = (callback, delay) => {
    timeoutCallbacks.push({ callback, delay });
    return { unref() {} };
  };
  const service = Object.create(AdminToolsService.prototype);
  Object.assign(service, {
    config: { get: (key, fallback) => ({ NODE_ENV: 'production', SMS_CAMPAIGNS_ENABLED: 'false' })[key] ?? fallback },
    logger: { log() {}, warn() {}, error() {} },
    recoverInterruptedJobs: async () => {},
    prisma: { smsCampaign: { findFirst: async () => { databaseCalls++; }, updateMany: async () => { databaseCalls++; } } },
  });

  await service.onModuleInit();
  assert.equal(intervalCallbacks.some(({ callback }) => callback.toString().includes('processQueuedSms')), false);
  assert.equal(timeoutCallbacks.some(({ callback }) => callback.toString().includes('processQueuedSms')), false);
  await service.processQueuedSms();
  assert.equal(databaseCalls, 0);
  await assert.rejects(() => service.sendSmsCampaign({ role: 'owner' }, '1'), (error) => error.getResponse().code === 'SMS_CAMPAIGNS_DISABLED');
  assert.equal(databaseCalls, 0);
  console.log('PASS: Production campaign worker does not schedule, claim queued work, or accept new campaigns while disabled.');
}

main().catch((error) => {
  console.error('FAIL:', error.getResponse?.().code ?? error.code ?? error.name);
  process.exitCode = 1;
}).finally(() => {
  global.setInterval = originalSetInterval;
  global.setTimeout = originalSetTimeout;
});
