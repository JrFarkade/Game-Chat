# GameChat — Cloudflare Serverless Deployment Guide

This guide walks you through deploying the **GameChat** backend to Cloudflare Workers, Durable Objects, and Cloudflare Realtime (Calls SFU), so that the application runs 24/7 on Cloudflare edge servers with **zero dependency on your laptop remaining on**.

---

## Architecture Overview

```text
📱 Sahil (Android) ─────────┐
                             │ (WebSocket & WebRTC Voice)
📱 Rahul (Android) ─────────┼──> ☁️ Cloudflare Edge
                             │    ├── Cloudflare Workers (REST API)
📱 Akash (Android) ─────────┘    ├── Durable Objects (Room state & WebSocket Hibernation)
                                  └── Cloudflare Realtime SFU (Calls global audio fanout)
```

---

## Prerequisites

1. A [Cloudflare Account](https://dash.cloudflare.com/sign-up).
2. [Node.js](https://nodejs.org/) (v18+ or v20+) installed on your development machine.
3. [Flutter SDK](https://docs.flutter.dev/get-started/install) installed on your machine.
4. A GitHub account.

---

## Step 1: Login to Cloudflare via Wrangler

From your terminal inside the `worker` directory:

```bash
cd worker
npx wrangler login
```

A browser window will open. Click **Allow** to authorize Wrangler to deploy to your Cloudflare account.

---

## Step 2: Create a Cloudflare Realtime (Calls) Application

1. Open the [Cloudflare Dashboard](https://dash.cloudflare.com/).
2. In the left navigation sidebar, navigate to **Realtime** (or **Calls**).
3. Click **Create Application**.
4. Set the name to `gamechat-calls`.
5. Once created, Cloudflare will display:
   - **App ID** (e.g. `9f8e7d6c5b4a...`)
   - **App Secret / Token** (e.g. `eyJhbGciOi...`)
6. Copy both values safely.

> [!IMPORTANT]
> Never commit your `CALLS_APP_SECRET` to GitHub or hardcode it in the mobile app. The Cloudflare Worker keeps it securely on the server side.

---

## Step 3: Configure Cloudflare Secrets in Wrangler

Set the Realtime credentials on your Worker using Wrangler secrets:

```bash
cd worker

# 1. Set the Calls App ID
npx wrangler secret put CALLS_APP_ID
# (Paste your App ID when prompted)

# 2. Set the Calls App Secret
npx wrangler secret put CALLS_APP_SECRET
# (Paste your App Secret when prompted)
```

---

## Step 4: Deploy the Worker to Cloudflare

Deploy your Worker and Durable Objects directly from your laptop:

```bash
cd worker
npm run deploy
```

Wrangler will output your live production URL:

```text
Uploaded gamechat-backend (34 KiB)
Deployed gamechat-backend triggers:
  https://gamechat-backend.<your-subdomain>.workers.dev
```

### Test your live endpoint

Open `https://gamechat-backend.<your-subdomain>.workers.dev/health` in your browser. You should see:

```json
{
  "status": "online",
  "service": "GameChat Cloudflare Edge Backend",
  "environment": "production",
  "callsConfigured": true,
  "timestamp": "2026-09-22T..."
}
```

---

## Step 5: Connect GitHub for Automatic Deployment (Optional / Recommended)

To deploy automatically every time you `git push`:

1. In the Cloudflare Dashboard, go to **Workers & Pages** -> **Create application** -> **Workers** -> **Connect to Git**.
2. Select your `gamechat` repository and branch `master`.
3. Set **Root directory** to `worker`.
4. Build command: `npm install && npx wrangler deploy`.
5. Under **Settings -> Variables and Secrets**, add your secrets:
   - `CALLS_APP_ID` (Type: Secret)
   - `CALLS_APP_SECRET` (Type: Secret)
6. Click **Save and Deploy**. Now, every `git push` will automatically build and deploy the backend.

---

## Step 6: Configure the Flutter Android App

1. Open [`mobile/lib/utils/constants.dart`](file:///d:/Z-A/TALK/mobile/lib/utils/constants.dart).
2. Set `defaultServerUrl` to your production Worker URL:

```dart
class AppConstants {
  // Production Cloudflare Worker URL:
  static const String defaultServerUrl = 'https://game-chat.jrfarkade.workers.dev';
  ...
}
```

---

## Step 7: Landing Page & Automated APK Download

GameChat now provides an automated distribution portal directly at your production Worker URL:

- **Web Landing Page:** [`https://game-chat.jrfarkade.workers.dev/`](https://game-chat.jrfarkade.workers.dev/)
  - Real-time gaming dark-mode UI with live edge server ping.
  - Prominent **[ DOWNLOAD LATEST APK ]** button.
  - Dynamic metadata display (version, size, release date).
- **Direct APK Download:** [`https://game-chat.jrfarkade.workers.dev/download`](https://game-chat.jrfarkade.workers.dev/download)
  - Always downloads the newest production APK (`application/vnd.android.package-archive`).
- **Update Metadata API:** [`https://game-chat.jrfarkade.workers.dev/api/latest`](https://game-chat.jrfarkade.workers.dev/api/latest)
  - Returns JSON metadata with current version, file size, and download URLs.

### Optional: Cloudflare R2 Storage (Zero-Egress Hosting)
For direct edge-hosted APK downloads without GitHub redirects:
1. In Cloudflare Dashboard, go to **R2 Object Storage**.
2. Click **Create bucket** and name it `gamechat-releases`.
3. In GitHub Repository (**Settings > Secrets and variables > Actions**), add:
   - `CLOUDFLARE_API_TOKEN` (API token with R2 and Workers permissions)
   - `CLOUDFLARE_ACCOUNT_ID` (`dec7061d171b2c48ce510dd4f1e39728`)
4. Any push to `main` with mobile changes will automatically build the APK and upload it directly to R2 and GitHub Releases via `.github/workflows/release-apk.yml`.

---

## Step 8: Verification Checklist

Test between two physical Android devices:

- [ ] **Phone A (Wi-Fi)** and **Phone B (Mobile 4G/5G)** install the release APK.
- [ ] Laptop is **completely turned OFF**.
- [ ] User A opens GameChat, enters username, and taps **CREATE ROOM**. Room code `X7K92` is generated.
- [ ] User A shares code `X7K92` with User B.
- [ ] User B taps **JOIN ROOM**, enters `X7K92`, and connects.
- [ ] **Two-way Voice**: Both users speak and hear each other with low latency through Cloudflare Realtime.
- [ ] **Speaking Indicator**: Green ring illuminates when user speaks.
- [ ] **Mute / Deafen**: Tapping MUTE silences microphone; status syncs across both phones.
- [ ] **Soundboard**: User A triggers sound (e.g. `FAAAAH` or `VINE BOOM`); both users hear it simultaneously.
- [ ] **Background Gaming**: User A minimizes GameChat, opens BGMI / COD / Free Fire. The sticky microphone notification remains active in the notification shade, and voice chat continues uninterrupted during gameplay.
