# SMS.ir OTP setup

Official API and Sandbox contract: https://sms.ir/rest-api/

## Local Sandbox

Use `NODE_ENV=development`, `SMS_PROVIDER=smsir-sandbox` and
`SMSIR_SANDBOX_API_KEY` in an ignored local environment file.
Keep `CUSTOMER_OTP_BYPASS=false`. The provider uses SMS.ir's fixed Sandbox
template `123456`, parameter `Code`, and `/v1/send/verify`; no sender line
is needed. Sandbox responses are simulated, with no SMS delivery or charge.
The API returns `developmentCode` only after Sandbox accepts the request.
Production rejects this provider before making a network request.

The local `.env.smsir-sandbox` contains only test configuration, not database
credentials. It is ignored by Git and is not automatically loaded by Nest.
After building the API, test without a database from `apps/api`:

```powershell
node --env-file=.env.smsir-sandbox scripts/test-smsir.cjs --live-sandbox
```

To run the full local API, configure a separate development database and
`CUSTOMER_AUTH_SECRET` in `.env`, then start with:

```powershell
node --env-file=.env.smsir-sandbox dist/main.js
```

Do not use the production database for this test. Sandbox does not exercise
actual delivery, campaign sending, customer persistence or browser sessions.

## Production

Use a production key in `SMSIR_API_KEY`, `SMS_PROVIDER=smsir` and a strong
`CUSTOMER_AUTH_SECRET`. For OTP Verify set the account's approved
`SMSIR_OTP_TEMPLATE_ID` and exact `SMSIR_OTP_PARAMETER` (default `Code`).
The Sandbox template ID must not be assumed to exist in the real account.
If no template is configured, the existing Bulk mode uses `SMSIR_LINE_NUMBER`.
An invalid configured template is rejected rather than falling back to Bulk.
Campaigns continue to use the production key and sender line separately.

The success contract is HTTP success **and** SMS.ir `status=1`; all other
statuses, invalid responses and network failures reject the OTP send.
Production never returns a development OTP through this adapter.

SMS campaign dispatch is separately controlled by `SMS_CAMPAIGNS_ENABLED`.
It defaults to disabled in production, blocks both queued campaign dispatch
and requests to start a campaign, and can be enabled after reviewing the
campaign queue and obtaining explicit authorization for marketing sends.

## Verification

After generating Prisma and building, run:

```powershell
node scripts/test-smsir.cjs
```

This uses mocked HTTP for failure cases and does not send real messages.
The optional `--live-sandbox` mode above exercises the actual adapter against
SMS.ir using only a synthetic phone and a Sandbox key.

The production campaign hold can be verified without a database by running
`node scripts/test-campaign-worker-guard.cjs` after the build.
