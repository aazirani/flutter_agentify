---
name: permissions-and-platform
description: Network and platform settings for Android, iOS, macOS, Linux, Windows and web, and how to rename the app and change its icons and identifiers. Use when the app cannot reach a server on one platform, when adding a permission, or when rebranding.
---

# Permissions and platform

Don't load this for what to run in the background; see `background-work`. For the model server choice, see `model-providers`.

## Rule

Add a platform permission only for a feature that uses it, and describe in the change which platform files you touched. Enforcement: none automatic for the settings themselves. The CI workflow `.github/workflows/flutter-ci.yml` builds `apk`, `web`, `linux`, `windows`, `macos` and `ios` after the gate, but it runs only where GitHub Actions is enabled, so without it a missing setting shows up only when you run the app on that platform. (The doctor does not check `.github/` paths.)

## Why

Each platform blocks something by default: plain `http://` on Android and iOS, outgoing connections in the macOS sandbox, cross-origin calls in browsers. The failure looks like "the assistant cannot reach the model" and is easy to misread.

## How

What is configured:

- **Android** (`android/app/src/main/AndroidManifest.xml`): `INTERNET` permission, `android:allowBackup="false"` (backups off, so stored keys and settings are not copied off the device), and `android:usesCleartextTraffic="true"`, so `http://` local servers work. Android cannot limit cleartext to private address ranges; the app itself refuses `http://` to public hosts when a key is in use. Before shipping, prefer HTTPS and remove cleartext if the app only uses a proxy.
- **iOS** (`ios/Runner/Info.plist`): `NSAllowsLocalNetworking` under `NSAppTransportSecurity` and an `NSLocalNetworkUsageDescription` text, which allow `http://` to the local network and show the permission prompt. Keep the text accurate.
- **macOS** (`macos/Runner/DebugProfile.entitlements`, `macos/Runner/Release.entitlements`): the sandbox with `network.client` in both (outgoing calls), and `network.server` and `allow-jit` in debug only. Debug builds are signed ad hoc (`CODE_SIGN_IDENTITY` `-`) so the in-app model's engine loads; that is why debug has no `keychain-access-groups` (it needs a development certificate). A new capability (camera, files) needs its entitlement in both files.
<!-- @on-device:begin -->
- **The model inside the app** (projects set up with `--model both` or `on-device`): Android `minSdk = 30` in `android/app/build.gradle.kts`; iOS `ios/Runner/Runner.entitlements` with the increased memory limit; macOS `MACOSX_DEPLOYMENT_TARGET = 14.0`; web `web/cache_api.js`, `web/opfs_helper.js` and their script tags in `web/index.html`. The first build needs the network. The full list, both ways, is in the Flutter Agentify guide *Choose where the model runs*.
<!-- @on-device:end -->
- **Linux and Windows:** no network settings needed.
- **Web** (`web/`): no key is stored; the browser enforces CORS, and an `http://` model server on a page served over HTTPS is blocked. Use a CORS-enabled server or `backend-proxy`. The database needs `web/sqlite3.wasm` and `web/drift_worker.dart.js`; keep them.

A phone cannot reach the computer's `localhost`; use the computer's network address (`model-providers`).

Renaming the app, in one pass: change the display name in the Android manifest (`android:label`), `CFBundleDisplayName` and `CFBundleName` in `ios/Runner/Info.plist`, `PRODUCT_NAME` and `PRODUCT_BUNDLE_IDENTIFIER` in `macos/Runner/Configs/AppInfo.xcconfig`, `web/manifest.json` and `web/index.html`, the window title in `linux/runner/my_application.cc` and `windows/runner/main.cpp`, and the names in `windows/runner/Runner.rc`. The application id appears as `applicationId` and `namespace` in `android/app/build.gradle.kts` and as the iOS bundle identifier in `ios/Runner.xcodeproj/project.pbxproj`; change all of them together. Replace the icons in each platform folder by hand, or add `flutter_launcher_icons` and `flutter_native_splash` yourself if you want them generated. Then search the repo for the old name.

## Anti-patterns

- Adding every permission "just in case".
- Leaving cleartext traffic allowed in a release that only uses HTTPS.
- Changing the bundle id on one platform only.
- Testing network changes only on desktop.

## Verification

- Run the app on each platform you changed. `flutter build <target>` for the target (`apk`, `web`, `ios --no-codesign`, and so on) is what the CI matrix does.
- `tool/check.sh` does not build platforms (see `verify`).

## Related skills
- `model-providers` — localhost, cleartext and CORS from the model side
- `backend-proxy` — the web answer
- `secrets` — why web stores no key
