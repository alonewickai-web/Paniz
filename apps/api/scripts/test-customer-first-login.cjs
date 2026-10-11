// Run after building the API. Uses in-memory Prisma fakes, never a database.
const assert = require('node:assert/strict');
const { createHash } = require('node:crypto');
const { CustomerAuthService } = require('../dist/customer/customer-auth.service.js');

const secret = 'local-test-secret-for-customer-auth-only';
const phone = '+989121234567';
const code = '314159';
const codeHash = createHash('sha256').update(`${secret}:${phone}:${code}`).digest('hex');

async function verifyAgainst(existingCustomer, submittedCode = code) {
  let upsertArgs;
  let sessionData;
  let otpAttempts = 0;
  const otpRequest = { id: 9n, phone, codeHash, attemptCount: 0 };
  const tx = {
    otpRequest: {
      updateMany: async ({ data }) => {
        if (data.status === 'locked') otpAttempts = data.attemptCount;
        return { count: 1 };
      },
    },
    customer: {
      upsert: async (args) => {
        upsertArgs = args;
        return existingCustomer ?? { id: 20n, phone: args.create.phone, fullName: null, email: null, status: 'active' };
      },
    },
    customerSession: { create: async ({ data }) => { sessionData = data; } },
  };
  const prisma = {
    otpRequest: {
      findFirst: async () => otpRequest,
      update: async ({ data }) => { otpAttempts = data.attemptCount; },
    },
    $transaction: async (callback) => callback(tx),
  };
  const config = { get: (key, fallback) => key === 'CUSTOMER_AUTH_SECRET' ? secret : fallback };
  const service = new CustomerAuthService(prisma, config, {});
  return { result: await service.verifyCode({ phone, code: submittedCode }), getState: () => ({ upsertArgs, sessionData, otpAttempts }) };
}

async function main() {
  const existingCustomer = { id: 7n, phone, fullName: 'نام قبلی', email: 'customer@example.test', status: 'active' };
  const existing = await verifyAgainst(existingCustomer);
  const existingState = existing.getState();
  assert.equal(existing.result.customer.id, '7');
  assert.equal(existing.result.customer.fullName, 'نام قبلی');
  assert.equal(existing.result.customer.email, 'customer@example.test');
  assert.deepEqual(existingState.upsertArgs.where, { phone });
  assert.deepEqual(Object.keys(existingState.upsertArgs.update), ['phoneVerifiedAt']);
  assert.equal(Boolean(existingState.sessionData), true);

  const firstLogin = await verifyAgainst(null);
  const firstLoginState = firstLogin.getState();
  assert.equal(firstLogin.result.customer.id, '20');
  assert.equal(firstLogin.result.customer.fullName, null);
  assert.equal(firstLoginState.upsertArgs.create.phone, phone);
  assert.equal(firstLoginState.upsertArgs.create.fullName, undefined);
  assert.equal(Boolean(firstLoginState.sessionData), true);

  let incorrectCodeRejected = false;
  try { await verifyAgainst(null, '000000'); }
  catch (error) { incorrectCodeRejected = error.getStatus?.() === 401; }
  assert.equal(incorrectCodeRejected, true);
  console.log('PASS: verified new phone becomes a customer; existing profile is preserved; wrong code never creates a customer or session.');
}

main().catch((error) => {
  console.error('FAIL:', error.getResponse?.().code ?? error.code ?? error.name);
  process.exitCode = 1;
});
