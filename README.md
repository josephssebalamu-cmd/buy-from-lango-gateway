# Buy From Lango SMS Gateway

The Android gateway listens for inbound SMS, sends messages to the Supabase
`sms-webhook` Edge Function, and polls Supabase for queued outbound SMS every
10 seconds from a foreground background service.

## Dashboard

The app dashboard refreshes every 10 seconds and shows:

- Background-service, Supabase, SMS permission, notification, and battery
  optimization status indicators.
- Outbound message totals for queued, sent, delivered, and failed statuses.
- Recent inbound and outbound SMS log entries with delivery status and time.

SMS delivery reports are based on Android/telephony delivery callbacks and
depend on carrier support and the recipient device being reachable. `sent`
means the platform accepted the send request; `failed` is recorded when the
send call throws. Delivery callbacks can be delayed or unavailable, and the
telephony callback does not include a message ID, so callbacks are associated
with queued SMS in send order.

## `sms_log` fields

The gateway expects the Supabase `sms_log` table to expose `id`, `phone`,
`message`, `direction`, `status`, and `created_at`. Queued outbound rows should
use `direction = 'outbound'` and `status = 'queued'`. The gateway changes these
statuses to `sent`, `delivered`, or `failed` as send and delivery results are
reported.

## Incoming SMS authentication

The `sms-webhook` Edge Function requires `SMS_WEBHOOK_TOKEN`. Configure the
same value as a Supabase function secret and pass it to the Android build with
`--dart-define=SMS_WEBHOOK_TOKEN=...`. The token is included in the installed
app, so treat it as defense in depth, use the gateway only on a managed device,
and rotate it if the app package is exposed. It is not a substitute for
provider-signed inbound SMS webhooks.

## Run and test

```shell
flutter pub get
flutter run --dart-define=SMS_WEBHOOK_TOKEN=<value>
flutter test
```

Grant SMS, notification, and ignore-battery-optimization permissions on the
dedicated Android device. Keep the foreground-service notification enabled so
Android can keep the gateway active while the screen is off.

## GitHub Actions

The Android workflow runs dependency resolution, analysis, tests, and a debug
APK build on pushes, pull requests, or manual dispatch. Add the repository
secret `SMS_WEBHOOK_TOKEN` with the same value configured for the Supabase
function to also build and upload a configured release APK. The secret is
embedded in that APK, so restrict artifact access and rotate the token if the
artifact is exposed.
