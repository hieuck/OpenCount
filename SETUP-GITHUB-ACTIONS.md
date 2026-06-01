# GitHub Actions Setup Guide

## Workflow 1: CI (Build & Test) — No setup needed

The `ci.yml` workflow runs automatically on every push and pull request.  
It builds for the iOS Simulator — **no Apple Developer account or signing required**.

Just push your code and check the **Actions** tab on GitHub.

---

## Workflow 2: Build IPA (for AltStore / Sideloadly)

This workflow produces a real `.ipa` file you can install on your iPhone.  
It requires a **free Apple ID** (no $99 Developer Program needed).

### Step 1 — Get your signing certificate

1. Open **Xcode** on your Mac
2. Go to **Xcode → Settings → Accounts** → add your Apple ID
3. Click **Manage Certificates** → click **+** → **Apple Development**
4. Open **Keychain Access** (search in Spotlight)
5. Under **My Certificates**, find **Apple Development: your@email.com**
6. Right-click → **Export** → save as `certificate.p12`
7. Set a password (remember it — this is `P12_PASSWORD`)

Convert to base64:
```bash
base64 -i certificate.p12 | pbcopy
```
This copies `BUILD_CERTIFICATE_BASE64` to your clipboard.

### Step 2 — Get your provisioning profile

1. Connect your iPhone to your Mac via USB
2. In Xcode, open any project → **Signing & Capabilities**
3. Set **Team** to your Apple ID, **Bundle Identifier** to `com.opencount.app`
4. Xcode will auto-create a provisioning profile
5. Find it:
```bash
ls ~/Library/MobileDevice/Provisioning\ Profiles/
```
6. Convert the newest `.mobileprovision` to base64:
```bash
base64 -i ~/Library/MobileDevice/Provisioning\ Profiles/XXXXXXXX.mobileprovision | pbcopy
```
This is `BUILD_PROVISION_PROFILE_BASE64`.

### Step 3 — Find your Team ID

In Xcode → project settings → **Signing & Capabilities** → look for the 10-character Team ID  
(e.g. `ABC1234567`). This is `DEVELOPMENT_TEAM`.

### Step 4 — Add secrets to GitHub

Go to your GitHub repo → **Settings → Secrets and variables → Actions → New repository secret**

Add these 5 secrets:

| Secret name | Value |
|---|---|
| `BUILD_CERTIFICATE_BASE64` | base64 string from Step 1 |
| `P12_PASSWORD` | password you set in Step 1 |
| `BUILD_PROVISION_PROFILE_BASE64` | base64 string from Step 2 |
| `KEYCHAIN_PASSWORD` | any strong password (e.g. `MyBuildKeychain123!`) |
| `DEVELOPMENT_TEAM` | your 10-char Team ID from Step 3 |

### Step 5 — Trigger the build

Go to **Actions → Build IPA (AltStore / Sideloadly) → Run workflow → Run workflow**

After ~10 minutes, download the `.ipa` from the **Artifacts** section.

---

## Installing the IPA on your iPhone

### Option A — AltStore (recommended)

1. Install **AltStore** on your iPhone: https://altstore.io
2. Install **AltServer** on your Mac/PC
3. Connect iPhone via USB, open AltServer
4. In AltStore on iPhone: **My Apps → +** → select the downloaded `.ipa`
5. The app installs and is valid for **7 days** (free Apple ID limit)
6. Re-sign via AltStore every 7 days (it can do this automatically via Wi-Fi)

### Option B — Sideloadly

1. Download **Sideloadly**: https://sideloadly.io
2. Connect iPhone via USB
3. Open Sideloadly, drag the `.ipa` in, enter your Apple ID, click **Start**
4. Trust the developer certificate on iPhone: **Settings → General → VPN & Device Management**

---

## Troubleshooting

**Build fails with "No signing certificate"**  
→ Make sure `BUILD_CERTIFICATE_BASE64` is correct. Re-export the `.p12` and re-encode.

**"Provisioning profile doesn't include the device"**  
→ In Xcode, go to **Signing & Capabilities**, make sure your iPhone is registered.  
   Xcode → **Window → Devices and Simulators** → your device should appear.

**App crashes on launch**  
→ The iCloud entitlements require a real Team ID. If you don't have iCloud set up,  
   remove the iCloud keys from `OpenCount/OpenCount.entitlements` before building.

**7-day expiry**  
→ This is an Apple limitation for free accounts. Use AltStore's auto-refresh  
   or re-sideload every 7 days. The $99 Developer Program removes this limit.
