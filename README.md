# SMS Forwarder

Lightweight Android utility that reads incoming SMS on a dedicated merchant/agent device, stores them locally when offline, and forwards matching messages to your backend via HTTPS.

> **Distribution:** Sideload as APK only. This app uses `RECEIVE_SMS` / `READ_SMS` and is **not** intended for Google Play. Pair it with a Play Store–compliant main app that consumes transactions from your server API.

---

## Goal

Reliable SMS → API forwarder for phones that receive bKash, Nagad, bank, and similar alerts:

1. Capture SMS in the background 24/7 (queue-first — never depend on the UI)
2. Never lose messages when offline, locked, or after app exit / reboot
3. Forward only configured senders / keyword rules to a configurable HTTPS API
4. Minimal UI with light / dark themes and optional PIN lock

---

## Architecture

```
[Dedicated Android phone]
        │
        ▼
┌──────────────────────────┐
│  SMS Forwarder APK       │  ← this repo (sideloaded)
│  RECEIVE_SMS + READ_SMS  │
│  AlarmManager sync       │  ← default (optional FGS keepalive)
│  Local Hive queue        │
└────────────┬─────────────┘
             │ HTTPS POST (when online)
             ▼
┌──────────────────────────┐
│  Your backend API        │
└────────────┬─────────────┘
             │
             ▼
┌──────────────────────────┐
│  Main business app       │  ← Play Store compliant (API only)
└──────────────────────────┘
```

---

## Features (shipped)

### Core
- [x] SMS listen (foreground + background handler)
- [x] Offline queue with durable Hive flush after each enqueue
- [x] Auto-forward when online; manual sync button
- [x] API URL, auth, custom headers, JSON payload template
- [x] Sender allow-list + include / exclude keyword (or regex) filters
- [x] Light / dark / system theme
- [x] Minimal Home, Settings, message detail UI

### Reliability
- [x] Optional realtime keepalive (foreground service + sticky notification)
- [x] Default AlarmManager background sync (no sticky notification; interval 5–60m)
- [x] FG isolate flushes queue every 15s when realtime mode is on
- [x] Retry with exponential backoff (transient network / 5xx do not burn budget the same way)
- [x] Delivery status: `pending` → `sending` → `sent` / `failed`
- [x] Manual retry on failed / pending items
- [x] Duplicate guard (TxnID hash, or sender + body + minute)
- [x] Stuck `sending` recovery after crash / kill
- [x] Inbox backfill (configurable lookback, default 72h) after start / resume / reboot / alarm / pull-to-refresh
- [x] Battery optimization + OEM auto-start guides
- [x] High-priority SMS broadcast receiver

### API & security
- [x] Auth: None / Bearer / API key header / Basic
- [x] Custom headers + payload placeholders
- [x] Test connection + `http://` warning
- [x] Stable `device_id` on every POST
- [x] Pause forwarding (SMS still queues locally)
- [x] Optional PIN app lock (UI-only — capture continues)

### Ops & parsing
- [x] Structured parse: amount, TxnID, type, counterparty, currency
- [x] Label presets (bKash, Nagad, Rocket, Upay, NexusPay, banks)
- [x] Export log as JSON (share)
- [x] Clear sent / failed / all history
- [x] Queue counters + online / listening / service status chips

---

## Screens

1. **Home** — listening / service / online status, counters, message list, sync, export/clear menu  
2. **Lock** — PIN gate (does not stop SMS or forwarding)  
3. **Settings** — API, filters, presets, structured parse, app lock, reliability, theme, data export  
4. **Message detail** — raw body, parsed fields, status, error, retry  

---

## Reliability guarantees

SMS is **queued first**, then forwarded. UI state never blocks capture.

| Scenario | Behavior |
|----------|----------|
| **Offline** | Stored in Hive immediately; sync when network returns |
| **App exit / swipe away** | SMS receiver still captures; default AlarmManager retries sync; optional FGS for faster retries |
| **App lock (PIN)** | UI-only; listening + queue + forward continue |
| **Device reboot** | Alarm (and optional FGS) reschedule; inbox backfill (configurable, default 72h) recovers misses |
| **Crash mid-send** | `sending` → `pending` on next start / sync tick |
| **OEM force-stop** | Cannot intercept — use battery + auto-start exemptions |

### Merchant device setup (required)

1. Grant **SMS** (+ **notifications** if using realtime keepalive)  
2. Settings → **Reliability** → disable battery optimization  
3. Run **device-specific guide** (Xiaomi / Oppo / Vivo / Samsung / Huawei auto-start)  
4. Optional: enable **Realtime keepalive** for sticky notification + ~15s retries  
5. Or leave realtime off and rely on AlarmManager interval + pull-to-refresh sync

---

## Data model (local)

```
QueuedSms
  id, sender, body, receivedAt
  status          // pending | sending | sent | failed
  attempts, lastError, forwardedAt, nextRetryAt
  payloadHash     // duplicate detection
  amount, txnId, txnType, counterparty   // structured parse
```

```
AppSettings
  apiUrl, authType, apiToken, apiKeyHeader, customHeaders
  payloadTemplate
  allowedSenders, includeKeywords, excludeKeywords, filtersUseRegex
  structuredParseEnabled, forwardingEnabled
  realtimeKeepAliveEnabled, syncIntervalMinutes, inboxLookbackHours
  themeMode, deviceId, appLock PIN (hashed)
```

---

## API contract

Default POST body (template-overridable). Structured fields are merged when parsing is enabled:

```json
{
  "device_id": "uuid",
  "sender": "bKash",
  "body": "You have received Tk 500.00 from 017XXXXXXXX. TxnID ABC123.",
  "received_at": "2026-09-04T17:30:00.000Z",
  "amount": 500,
  "txn_id": "ABC123",
  "type": "credit",
  "counterparty": "017XXXXXXXX",
  "currency": "BDT"
}
```

**Auth:** None / Bearer / API key header / Basic  

**Fixed headers (every request):**
- Built-in: `Content-Type`, `Accept`, `X-Device-Id`, `X-Client: SMS-Forwarder`
- Plus any lines you set in Settings → Fixed headers (`Name: Value`, supports `{{device_id}}`)
- Auth headers are applied on top of these

**Placeholders:** `{{device_id}}` `{{sender}}` `{{body}}` `{{received_at}}` `{{amount}}` `{{txn_id}}` `{{type}}` `{{counterparty}}` `{{currency}}`

**Success:** HTTP `2xx`. Anything else → stay in queue and retry.

---

## Permissions (Android)

| Permission | Why |
|------------|-----|
| `RECEIVE_SMS` | Capture new messages in background |
| `READ_SMS` | Inbox backfill after reboot / missed broadcasts |
| `INTERNET` | Forward to API |
| `ACCESS_NETWORK_STATE` | Detect online / offline |
| `FOREGROUND_SERVICE` / `FOREGROUND_SERVICE_DATA_SYNC` | Optional realtime keepalive |
| `POST_NOTIFICATIONS` | Sticky notification when realtime keepalive is on |
| `WAKE_LOCK` / `RECEIVE_BOOT_COMPLETED` | Survive doze / restart on boot |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | Reduce OEM killing the process |
| `SCHEDULE_EXACT_ALARM` | Available if exact alarms are used (default sync is inexact) |

---

## Tech stack

| Area | Package / approach |
|------|--------------------|
| SMS | `another_telephony` (background handler + inbox read) |
| Local DB | Hive (`sms_queue` + `settings`) |
| Network | `http` + `connectivity_plus` |
| Background | Default: `android_alarm_manager_plus`; optional: `flutter_foreground_task` |
| Battery / OEM | `disable_battery_optimization` |
| Export | `share_plus` |
| State | `ValueNotifier` + Hive `listenable` |

---

## Development roadmap

All planned phases are complete.

### Phase 1 — Core forwarder
- [x] Rebrand, SMS listen, local queue, API forward, offline sync, senders, themes, minimal UI

### Phase 2 — Reliability
- [x] Foreground service, retry / backoff, duplicates, battery onboarding

### Phase 3 — Hardening
- [x] Auth / headers / template, keyword filters, test + HTTPS warning, device ID / pause / counters, PIN lock

### Phase 4 — Ops polish
- [x] Export / clear history, label presets, structured parse (amount / TxnID)

### Post-roadmap hardening
- [x] Inbox backfill, stuck-send recovery, FG isolate flush, durable enqueue flush, offline-safe retries

---

## Out of scope

- Google Play publishing  
- Being the user’s default SMS app  
- Full business UI (balances, reports, settlements) — belongs in the main app that reads from your API  

---

## Getting started

```bash
flutter pub get
flutter run
```

Release APK for sideload:

```bash
flutter build apk --release
```

Install on the dedicated merchant device and complete the [merchant device setup](#merchant-device-setup-required) steps above.

---

## CI/CD — APK → Google Drive

On every push to `main`, version tags (`v*`), or a manual **Run workflow**, GitHub Actions builds a signed release APK and uploads it to a Google Drive folder.

Workflow: [`.github/workflows/build-and-upload-apk.yml`](.github/workflows/build-and-upload-apk.yml)

### 1. Signing secrets

Encode your keystore (from the repo root):

```bash
base64 -i android/upload-keystore.jks | pbcopy
```

Add these repository secrets (**Settings → Secrets and variables → Actions**):

| Secret | Value |
|--------|--------|
| `KEYSTORE_BASE64` | Base64-encoded `upload-keystore.jks` |
| `KEYSTORE_PASSWORD` | Keystore store password |
| `KEY_PASSWORD` | Key password |
| `KEY_ALIAS` | Key alias (e.g. `upload`) |

`android/key.properties` and `*.jks` are gitignored — keep signing material out of git.

### 2. Google Drive secrets (OAuth)

Service accounts **cannot** upload to personal Drive (no storage quota). Use OAuth instead.

1. In [Google Cloud Console](https://console.cloud.google.com/), create/select a project and enable **Google Drive API**.
2. **APIs & Services → OAuth consent screen** → External → fill app name + your email → add scope `https://www.googleapis.com/auth/drive` → add yourself as a test user.
3. **Credentials → Create credentials → OAuth client ID** → type **Web application**.
4. Add authorized redirect URI: `https://developers.google.com/oauthplayground` → Create. Copy **Client ID** and **Client Secret**.
5. Open [OAuth 2.0 Playground](https://developers.google.com/oauthplayground/):
   - Gear ⚙️ → check **Use your own OAuth credentials** → paste Client ID + Secret
   - Select **Drive API v3** → `https://www.googleapis.com/auth/drive` → **Authorize APIs**
   - **Exchange authorization code for tokens** → copy `refresh_token`
6. Create a Drive folder for APKs. Folder ID is the part after `/folders/` in the URL.
7. Add GitHub secrets:

| Secret | Value |
|--------|--------|
| `GOOGLE_CLIENT_ID` | OAuth client ID |
| `GOOGLE_CLIENT_SECRET` | OAuth client secret |
| `GOOGLE_REFRESH_TOKEN` | Refresh token from Playground |
| `GDRIVE_FOLDER_ID` | Drive folder ID |

You can delete the old `GDRIVE_CREDENTIALS` service-account secret — it is no longer used.

Upload uses a small Python script (`.github/scripts/upload_to_gdrive.py`) with OAuth.
The marketplace action `logickoder/google-drive-upload@1.0.1` is intentionally not used:
its published `dist/` still requires service-account `credentials` and runs on deprecated Node 20.

### 3. Run it

- Push to `main`, or tag `v1.0.1`, or use **Actions → Build APK & Upload to Google Drive → Run workflow**.
- The APK is also kept as a GitHub Actions artifact (30 days).
- Drive filename examples: `sms-forwarder-1.0.0-1-42.apk` or `sms-forwarder-v1.0.1.apk` on tags.

---

## License

Private / unlisted utility. Not for Play Store distribution.
