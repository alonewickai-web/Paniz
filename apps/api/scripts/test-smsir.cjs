// Run after building the API. No database or customer records are used.
const assert = require('node:assert/strict');
const { CustomerSmsService } = require('../dist/customer/sms.service.js');

const originalFetch = global.fetch;
const service = (values) => new CustomerSmsService({ get: (name, fallback) => values[name] ?? fallback });
const sandboxConfig = { NODE_ENV: 'development', SMS_PROVIDER: 'smsir-sandbox', SMSIR_SANDBOX_API_KEY: 'test-only' };
const phone = '+989120000000';
const code = '123456';
let requests = [];
function respond(body, status = 200) {
  requests = [];
  global.fetch = async (url, options) => {
    requests.push({ url, body: JSON.parse(options.body), headers: options.headers });
    return new Response(JSON.stringify(body), { status });
  };
}
async function rejected(instance, expected) {
  await assert.rejects(() => instance.sendLoginCode(phone, code), (error) => error.getResponse().code === expected);
}

async function main() {
  respond({ status: 1 });
  assert.deepEqual(await service(sandboxConfig).sendLoginCode(phone, code), { developmentCode: code });
  assert.equal(requests[0].url, 'https://api.sms.ir/v1/send/verify');
  assert.deepEqual(requests[0].body, { mobile: '09120000000', templateId: 123456, parameters: [{ name: 'Code', value: code }] });

  requests = [];
  await rejected(service({ ...sandboxConfig, NODE_ENV: 'production' }), 'SMS_PROVIDER_NOT_CONFIGURED');
  assert.equal(requests.length, 0);
  await rejected(service({ NODE_ENV: 'development', SMS_PROVIDER: 'smsir-sandbox', SMSIR_API_KEY: 'test-only' }), 'SMS_PROVIDER_NOT_CONFIGURED');
  assert.equal(requests.length, 0);

  for (const status of [0, 10, 101, 102, 113, undefined]) {
    respond({ status });
    await rejected(service(sandboxConfig), 'SMS_PROVIDER_UNAVAILABLE');
  }
  respond({ status: 1 }, 503);
  await rejected(service(sandboxConfig), 'SMS_PROVIDER_UNAVAILABLE');
  global.fetch = async () => { throw new Error('network unavailable'); };
  await rejected(service(sandboxConfig), 'SMS_PROVIDER_UNAVAILABLE');

  const productionConfig = { NODE_ENV: 'production', SMS_PROVIDER: 'smsir', SMSIR_API_KEY: 'test-only', SMSIR_LINE_NUMBER: '500038627652837' };
  respond({ status: 1 });
  assert.deepEqual(await service(productionConfig).sendLoginCode(phone, code), {});
  assert.equal(requests[0].url, 'https://api.sms.ir/v1/send/bulk');
  assert.equal(requests[0].body.lineNumber, Number(productionConfig.SMSIR_LINE_NUMBER));
  assert.equal(requests[0].body.messageText, `کد ورود شما به فروشگاه پانیذ: ${code}`);
  assert.deepEqual(requests[0].body.mobiles, ['09120000000']);
  respond({ status: 1 });
  assert.deepEqual(await service({ ...productionConfig, SMSIR_OTP_TEMPLATE_ID: '234567', SMSIR_OTP_PARAMETER: 'OTP' }).sendLoginCode(phone, code), {});
  assert.equal(requests[0].body.templateId, 234567);
  assert.equal(requests[0].body.parameters[0].name, 'OTP');
  for (const invalid of ['invalid', '0', '-1', '1.5']) {
    await rejected(service({ ...productionConfig, SMSIR_OTP_TEMPLATE_ID: invalid }), 'SMS_PROVIDER_NOT_CONFIGURED');
  }
  global.fetch = originalFetch;
  console.log('PASS: Sandbox request, production guard, separate credentials, provider errors, network errors, Bulk compatibility, Verify mode and template validation.');

  if (process.argv.includes('--live-sandbox')) {
    assert.equal(process.env.SMS_PROVIDER, 'smsir-sandbox');
    assert.ok(process.env.SMSIR_SANDBOX_API_KEY);
    const result = await service(process.env).sendLoginCode(phone, code);
    assert.deepEqual(result, { developmentCode: code });
    console.log('PASS: Actual service accepted by SMS.ir Sandbox. Simulated response only; no delivery or charge.');
  }
}
main().catch((error) => {
  // Keep credentials and request contents out of diagnostics.
  console.error('FAIL:', error.getResponse?.().code ?? error.code ?? error.name);
  process.exitCode = 1;
}).finally(() => { global.fetch = originalFetch; });
