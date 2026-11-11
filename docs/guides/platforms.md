# Platforms

The app is one Flutter project for Android, iOS, macOS, web, Linux and Windows. This page says what each one needs, and which ones have been tested.

`flutter doctor` tells you which tools are missing on your machine:

```bash
flutter doctor
```

## What has been built where

| Platform | Built | Machine |
|---|---|---|
| macOS | yes, debug build | macOS, Flutter 3.47.6 |
| Web | yes | macOS, Flutter 3.47.6 |
| Android | yes, debug build, run on a Redmi A5 (Android 15) | macOS, Flutter 3.47.6 |
| iOS | yes, debug build, run on an iPhone 13 Pro Max (iOS 26.6.2) | macOS, Xcode 27.2, Flutter 3.47.6 |
| Linux | yes, release build, not run | GitHub Actions (ubuntu-latest), Flutter 3.50.0 |
| Windows | yes, release build, not run | GitHub Actions (windows-latest), Flutter 3.50.0 |

On both phones the in-app model was measured; see [Measured](choose-where-the-model-runs.md#measured). CI builds Linux and Windows on every push to `main`, after running `dart tool/setup.dart` there, but neither app has been run yet. If one fails on your machine, the settings below are the first place to look.

A project with the model inside the app (`--model both` or `on-device`) has higher floors: Android 11 (API 30) on arm64, macOS 14 on Apple Silicon, the increased memory limit entitlement on iOS, and web only when turned on. iOS 15 is the floor in every mode. Its first build needs the network, because the engine downloads its native libraries then. A `server` project has none of this. See [Choose where the model runs](choose-where-the-model-runs.md#which-devices-can-run-it).

The template's own check builds a new project for web, and for macOS on a Mac, with a server only and with the model inside the app:

```bash
tool/check_template.sh --build
```

## Android

Needs: the Android SDK, through Android Studio.

`android/app/src/main/AndroidManifest.xml` already has:

- the `INTERNET` permission;
- `android:usesCleartextTraffic="true"`, so a model server on your network works over plain `http://`. If your app only talks to an `https://` server, remove it before you ship;
- `android:allowBackup="false"`, so keys and settings are not copied off the device.

```bash
flutter build apk
```

## iOS

Needs: a Mac with Xcode and its iOS platform installed. Running on a phone also needs a development team, and on Apple Silicon Rosetta (`softwareupdate --install-rosetta`), because Flutter connects to the phone with an Intel-only tool.

`ios/Runner/Info.plist` already allows `http://` to the local network (`NSAllowsLocalNetworking`) and explains why with `NSLocalNetworkUsageDescription`. Keep that text true for your app.

```bash
flutter build ios --no-codesign
```

## macOS

Needs: Xcode.

The app runs in the macOS sandbox. Both `macos/Runner/DebugProfile.entitlements` and `macos/Runner/Release.entitlements` allow outgoing network calls (`com.apple.security.network.client`). A new capability, such as the camera or files, needs its entitlement in both files.

Debug builds are signed to run locally (ad hoc, `CODE_SIGN_IDENTITY` `-`), because the in-app model's engine does not load in an unsigned app. Signing turns the sandbox on in debug builds too, so the app's data lives in its container under `~/Library/Containers/`. The saved API key still works.

```bash
flutter build macos
```

## Web

Needs: Chrome for `flutter run -d chrome`.

- The database runs in the browser. It needs `web/sqlite3.wasm` and `web/drift_worker.dart.js`; keep them.
- No key is stored on web. Use a local model server, or your own proxy; see [Ship without user keys](ship-without-user-keys.md).
- The browser blocks calls to a server that does not allow the page's address (CORS). See [Connect a model](connect-a-model.md#web).

```bash
flutter build web
```

## Linux

Needs: the Linux desktop tools that `flutter doctor` lists, and libsecret, which keeps the API key. On Debian or Ubuntu:

```bash
sudo apt install libsecret-1-0 libsecret-1-dev
flutter build linux
```

## Windows

Needs: Visual Studio with the "Desktop development with C++" workload.

`.claude/skills` is a symbolic link to `.agents/skills`. Git makes it a plain file on Windows unless symbolic links are on. Turn on Developer Mode in the Windows settings, then run this before you clone:

```powershell
git config --global core.symlinks true
```

```powershell
flutter build windows
```

## Names and icons

Setup writes the app's name and id into every platform folder. To change them later, see [Rebrand](rebrand.md).
