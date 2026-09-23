# GameChat — Cloudflare Serverless Voice Chat Android App

A private, ultra low-latency real-time voice chat Android application designed specifically for mobile gamers playing games together with friends (BGMI, COD Mobile, Free Fire, etc.).

Powered by:
- **Cloudflare Workers**: Edge API gateway and routing.
- **Cloudflare Durable Objects**: Per-room state, WebSocket Hibernation, and presence tracking.
- **Cloudflare Realtime SFU (Calls API)**: Edge-accelerated WebRTC audio fanout across 335+ Anycast locations.
- **Flutter (Android)**: Tactical gaming UI with native Kotlin `VoiceForegroundService`.
- **Zero Laptop Dependency**: Completely serverless. Runs 24/7 on Cloudflare's global edge network with your laptop **turned off**.

### 🔗 Live Production Links
- **Official Web Portal & Landing Page:** [https://game-chat.jrfarkade.workers.dev/](https://game-chat.jrfarkade.workers.dev/)
- **Direct APK Download:** [https://game-chat.jrfarkade.workers.dev/download](https://game-chat.jrfarkade.workers.dev/download)
- **Latest Metadata API:** [https://game-chat.jrfarkade.workers.dev/api/latest](https://game-chat.jrfarkade.workers.dev/api/latest)
- **Health Check:** [https://game-chat.jrfarkade.workers.dev/health](https://game-chat.jrfarkade.workers.dev/health)

---

## 🌐 Architecture Overview

```text
                         GITHUB
                           │
                           │ deployment (wrangler / git push)
                           ▼
                 ☁️ CLOUDFLARE WORKERS
                           │
              ┌────────────┴────────────┐
              │                         │
       Durable Objects            Cloudflare
       Room / Presence            Realtime SFU
       WebSockets (Hibernation)   Voice routing
              │                         │
              └────────────┬────────────┘
                           │
                        INTERNET
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
            📱 Sahil     📱 Rahul     📱 Akash
            (Wi-Fi)      (Mobile 5G)  (Different City)
```

---

## 📁 Repository Structure

```text
gamechat/
│
├── mobile/                      # Flutter Android application
│   ├── lib/
│   │   ├── models/              # UserPeer, SoundClip models
│   │   ├── screens/             # Home, JoinRoom, VoiceRoom, Soundboard, Settings
│   │   ├── services/            # AudioService, ForegroundService, SignalingService, WebRtcService
│   │   └── utils/               # AppConstants, RoomCodeGen
│   └── android/                 # Native Kotlin VoiceForegroundService (microphone & wake lock)
│
├── worker/                      # Cloudflare Worker & Durable Objects backend
│   ├── src/
│   │   ├── index.ts             # REST API & Cloudflare Calls Proxy
│   │   ├── room_do.ts           # Room Durable Object (WebSocket Hibernation)
│   │   └── types.ts             # Data models & signaling protocol
│   ├── wrangler.toml            # Cloudflare Worker configuration
│   └── package.json             # Worker dependencies & TypeScript
│
├── .github/workflows/           # GitHub Actions automatic deployment
│   └── deploy-worker.yml
│
├── DEPLOYMENT.md                # Comprehensive deployment reference
└── README.md                    # This guide
```

---

## 🎓 Student-Friendly Step-by-Step Deployment Guide

Follow these 11 simple steps to deploy your GameChat backend to Cloudflare and build your Android APK.

### STEP 1: Connect GitHub Repository to Cloudflare
1. Log in to your [Cloudflare Dashboard](https://dash.cloudflare.com/).
2. In the left sidebar, click **Compute (Workers) > Workers & Pages**.
3. Click **Create** > select the **Workers** tab > click **Connect to Git**.
4. Authorize Cloudflare to access your GitHub account and select your repository:
   ```text
   JrFarkade/Game-Chat
   ```

### STEP 2: Configure Worker Root Directory / Path
On the project configuration screen in Cloudflare:
- **Project name**: `gamechat-backend`
- **Production branch**: `main`
- **Root directory / Path**: 
  ```text
  worker
  ```
  *(Important: Do NOT leave this as root `/`. Set it to `worker` because `wrangler.toml` and `package.json` are inside the `worker` directory).*

### STEP 3: Build Command
In the build settings:
- **Build command**:
  ```text
  npm run build
  ```
  *(Or leave empty if deploying with Wrangler defaults).*

### STEP 4: Deploy Command
- **Deploy command**:
  ```text
  npx wrangler deploy
  ```

### STEP 5: Enable Cloudflare Services (Realtime / Calls)
1. In the Cloudflare Dashboard left sidebar, click **Realtime** (or **Calls**).
2. Click **Create Application**.
3. Enter an application name (e.g. `gamechat-calls`).
4. Once created, Cloudflare will display:
   - **App ID**
   - **App Secret**
5. Keep this tab open.

### STEP 6: Configure Environment Variables & Secrets
In your Worker project in Cloudflare Dashboard:
1. Go to **Settings > Variables and Secrets**.
2. Add the following two variables:

| Variable Name | Type | Description |
| :--- | :--- | :--- |
| `CALLS_APP_ID` | **Plain text** (or Secret) | The App ID from Step 5 |
| `CALLS_APP_SECRET` | **Secret** (Click "Encrypt") | The App Secret from Step 5 |

> [!WARNING]
> Never put your `CALLS_APP_SECRET` into GitHub or the Flutter app. It stays safely on the Cloudflare Worker server.

### STEP 7: Deploy the Worker
Click **Save and Deploy**. Cloudflare will automatically pull code from GitHub, bundle the Worker, and deploy it to all 335+ global edge locations.

*(Alternative: You can also deploy directly from your computer terminal by running `cd worker && npx wrangler deploy`).*

### STEP 8: Get Your Production Worker URL
Once deployed, Cloudflare shows your live Worker URL on the project dashboard:
```text
https://gamechat-backend.<your-subdomain>.workers.dev
```
Verify it by opening `https://gamechat-backend.<your-subdomain>.workers.dev/health` in your browser. It should return:
```json
{"status":"online","service":"GameChat Cloudflare Edge Backend","callsConfigured":true}
```

### STEP 9: Set Production URL in the Android App
Open [`mobile/lib/utils/constants.dart`](mobile/lib/utils/constants.dart) on your computer and update `defaultServerUrl`:
```dart
class AppConstants {
  static const String defaultServerUrl = 'https://gamechat-backend.<your-subdomain>.workers.dev';
  ...
}
```
*(Note: Users can also test and override this URL anytime inside the app under **Settings > Server & Network Connection**).*

### STEP 10: Build the Release Android APK
Open a terminal in the `mobile` directory and run:
```bash
cd mobile
flutter clean
flutter pub get
flutter build apk --release
```
The compiled APK will be located at:
```text
mobile/build/app/outputs/flutter-apk/app-release.apk
```
A ready-to-use copy is also placed in the project root: `GameChat-v2.0-cloudflare-release.apk`.

### STEP 11: Two-Phone Real Device Testing Procedure
1. Send the APK to two physical Android phones (e.g. **Phone A** connected to Home Wi-Fi, **Phone B** connected to Mobile 4G/5G).
2. **Turn your laptop completely OFF.**
3. **Phone A**: Open GameChat, enter your name, tap **CREATE ROOM** (e.g. Room code `X7K92` appears).
4. **Phone B**: Open GameChat, tap **JOIN ROOM**, enter `X7K92`.
5. **Speak & Listen**: Talk into Phone A's microphone; sound plays through Phone B's speaker with low latency.
6. **Test Controls**:
   - Tap **MUTE** on Phone A -> verify Phone B sees the red mute icon.
   - Tap **SOUNDS** -> tap `FAAAAH` or `VINE BOOM` -> verify both phones hear the sound effect.
7. **Test Background Gaming**:
   - Minimize GameChat on Phone A. Notice the persistent sticky microphone notification in the notification bar.
   - Open BGMI, COD Mobile, or Free Fire.
   - Continue talking while gaming — microphone and voice chat remain fully active!
