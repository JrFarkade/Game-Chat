# GameChat — Setup and Build Guide (Windows)

This guide walks you through setting up Flutter and the Android SDK on Windows, running the signaling server, and compiling the installable Android APK.

---

## 1. Prerequisites Installation

### A. Install Git
If not already installed, download and install Git:
👉 https://git-scm.com/download/win

---

### B. Install Java Development Kit (JDK 17)
1. Download Microsoft Build of OpenJDK 17 (or Eclipse Temurin 17):
   👉 https://learn.microsoft.com/en-us/java/openjdk/download#openjdk-17
2. Run the `.msi` installer.
3. Verify by opening a new PowerShell window:
   ```powershell
   java -version
   ```

---

### C. Install Flutter SDK
1. Download the Flutter SDK bundle for Windows:
   👉 https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.24.5-stable.zip
2. Extract the zip file to `C:\flutter` (Do **not** install in `Program Files`).
3. Add `C:\flutter\bin` to your User `PATH` environment variable:
   - Press `Win + S` → Type `env` → Select **Edit the system environment variables**.
   - Click **Environment Variables...**
   - Under **User variables**, select `Path` → Click **Edit...**
   - Click **New** → Type `C:\flutter\bin` → Click **OK**.
4. Open a new PowerShell window and verify:
   ```powershell
   flutter --version
   ```

---

### D. Install Android Studio & Android SDK
1. Download and install Android Studio:
   👉 https://developer.android.com/studio
2. In Android Studio, open **SDK Manager** (More Actions → SDK Manager):
   - Under **SDK Platforms**, check:
     - `Android 14.0 (UpsideDownCake)` (API 34)
   - Under **SDK Tools**, check:
     - `Android SDK Build-Tools`
     - `Android SDK Command-line Tools (latest)`
     - `Android SDK Platform-Tools`
3. Click **Apply** and wait for downloads to complete.
4. Accept Android licenses by running:
   ```powershell
   flutter doctor --android-licenses
   ```
   (Press `y` to accept each license)
5. Verify your setup:
   ```powershell
   flutter doctor
   ```

---

## 2. Running the Signaling Server

The signaling server relays room joins, WebRTC offers/answers, and soundboard audio triggers.

### Option 1: Run Locally (Same Wi-Fi Network)
1. Find your computer's local IP address:
   ```powershell
   ipconfig
   ```
   Look for `IPv4 Address` under your active Wi-Fi or Ethernet adapter (e.g. `192.168.1.100`).
2. Navigate to the server folder and start it:
   ```powershell
   cd d:\Z-A\TALK\server
   npm start
   ```
   The server starts on port `4000`:
   ```text
   🚀 GameChat Signaling Server running on http://0.0.0.0:4000
   📡 Ready for WebRTC room connections!
   ```
3. When opening GameChat on your phones, go to **Settings** (⚙️) → Set **Signaling Server URL** to `http://192.168.1.100:4000`.

### Option 2: Deploy to Free Cloud Host (For Friends Across the Internet)
To let friends connect over 4G/different Wi-Fi networks without port forwarding:
1. Deploy `server/` to **Render.com** or **Railway.app**:
   - Create a free account on Render.com.
   - Click **New Web Service** → Connect your repository or upload `server/`.
   - Set Build Command: `npm install`
   - Set Start Command: `node index.js`
   - Render gives you a free HTTPS URL: `https://your-app.onrender.com`.
2. In the GameChat mobile app settings, set **Signaling Server URL** to:
   ```text
   https://your-app.onrender.com
   ```

---

## 3. Building the Android APK

1. Navigate to the mobile project folder:
   ```powershell
   cd d:\Z-A\TALK\mobile
   ```
2. Get Flutter packages:
   ```powershell
   flutter pub get
   ```
3. Build the release APK:
   ```powershell
   flutter build apk --release
   ```
4. Once compilation finishes, your installable APK will be located at:
   ```text
   d:\Z-A\TALK\mobile\build\app\outputs\flutter-apk\app-release.apk
   ```

---

## 4. Installing APK on Your Phones

1. Transfer `app-release.apk` to your phone via:
   - USB cable
   - WhatsApp / Telegram file transfer
   - Google Drive / Discord file upload
2. On your Android phone, tap the APK file.
3. If prompted with *"For your security, your phone is not allowed to install unknown apps"*, tap **Settings** and enable **Allow from this source**.
4. Tap **Install**.

---

## 5. First-Time Phone Permissions Checklist

When launching GameChat for the first time:
1. **Microphone**: Allow *"While using the app"*.
2. **Notifications**: Allow (Required on Android 13+ so the background service notification keeps the audio alive while you are gaming).
3. **Battery Optimization**:
   - For uninterrupted voice while playing heavy 3D games (PUBG, COD Mobile), go to phone **Settings → Apps → GameChat → Battery → Select "Unrestricted"**.
