# Rebrand

Setup gives the app one name and one id on every platform. This page shows how to change them later, how to change the icons and colors, and what to do with a name setup refuses.

The examples use a project set up with `--name notes_app --org com.example`. Its display name is `Notes App` and its application id is `com.example.notesapp`.

Commit before you start, so `git diff` shows exactly what changed.

## The display name

The name people see is in the language files and each platform's files. List every place:

```bash
git grep -n "Notes App" -- . ':!.agents'
```

| Platform | Files |
|---|---|
| All | every file in `assets/lang/` (`app_name`) |
| Android | `android/app/src/main/AndroidManifest.xml` (`android:label`) |
| iOS | `ios/Runner/Info.plist`, `ios/Runner/PrivacyInfo.xcprivacy`, `ios/Runner.xcodeproj/project.pbxproj` |
| macOS | `macos/Runner/Configs/AppInfo.xcconfig` (`PRODUCT_NAME`), `macos/Runner/PrivacyInfo.xcprivacy`, `macos/Runner.xcodeproj/project.pbxproj`, the scheme in `macos/Runner.xcodeproj/xcshareddata/` |
| Web | `web/index.html`, `web/manifest.json` |
| Linux | `linux/runner/my_application.cc` |
| Windows | `windows/runner/main.cpp`, `windows/runner/Runner.rc` |

When the new name is one setup's `--title` would accept, one command changes all of them. Setup deletes itself, so a created project no longer has it. `--title` accepts letters, digits, spaces, `.`, `_` and `-`, starting with a letter or digit; setup's refusal message names them too.

```bash
git grep -l "Notes App" -- . ':!.agents' | xargs perl -pi -e 's/Notes App/Daily Notes/g'
```

The Persian `app_name` in `assets/lang/fa.json` may deserve its own translation. Then check:

```bash
tool/check.sh
```

## A name setup refuses

`--title` accepts only characters that are safe in every platform file; its refusal message names them, as does `dart tool/setup.dart --help` in the template before setup. A name such as `Tom & Jerry's Notes` needs escaping that differs per file. Set up with a plain title, then change each file by hand:

| File | Write `&` as | Write `'` as | Write `"` as |
|---|---|---|---|
| `AndroidManifest.xml`, `Info.plist`, `web/index.html` | `&amp;` | `&apos;` | `&quot;` |
| `assets/lang/*.json`, `web/manifest.json` | `&` | `'` | `\"` |
| `project.pbxproj` (inside `"…"`) | `&` | `'` | `\"` |
| `my_application.cc`, `main.cpp` | `&` | `'` | `\"` |
| `Runner.rc` | `&` | `'` | `""` |

On macOS, `PRODUCT_NAME` is also the name of the `.app` file. Keep it plain and set the name people see with `INFOPLIST_KEY_CFBundleDisplayName` in `macos/Runner.xcodeproj/project.pbxproj`.

Build each platform you changed; a mistake in these files shows only there. See [Platforms](platforms.md).

## The application id

Change the id before the app is in a store. A store treats a new id as a new app.

List every place:

```bash
git grep -n "com.example.notesapp"
```

Change them all, then move the Android Kotlin folder to match the new id:

```bash
git grep -l "com.example.notesapp" | xargs perl -pi -e 's/com\.example\.notesapp/com.acme.notes/g'
mkdir -p android/app/src/main/kotlin/com/acme
git mv android/app/src/main/kotlin/com/example/notesapp android/app/src/main/kotlin/com/acme/notes
```

This covers `android/app/build.gradle.kts`, `MainActivity.kt`, the iOS and macOS project files, `macos/Runner/Configs/AppInfo.xcconfig` and `linux/CMakeLists.txt`. Web has no application id. Windows has none either, but `windows/runner/Runner.rc` holds the organization as `CompanyName`.

The Dart package name (`notes_app`) is a different thing. Changing it means changing every `package:notes_app/` import; it is easier to set up a new project.

## Icons

Replace the image files in each platform folder. Keep each file's name and size.

| Platform | Files |
|---|---|
| Android | `android/app/src/main/res/mipmap-*/` |
| iOS | `ios/Runner/Assets.xcassets/AppIcon.appiconset/` |
| macOS | `macos/Runner/Assets.xcassets/AppIcon.appiconset/` |
| Web | `web/favicon.png`, `web/icons/` |
| Windows | `windows/runner/resources/app_icon.ico` |
| Linux | none by default |

To make them from one image, add the `flutter_launcher_icons` package to `dev_dependencies` and follow its instructions. The template does not include it.

## Colors

The light and dark colors are constants in `lib/core/theme/app_colors.dart`. Every screen and the chat read them through the theme, so change them there. A color written anywhere else fails the gate's `no_hardcoded_colors` rule.

```bash
git grep -n "static const Color" lib/core/theme/app_colors.dart
```

## Check

```bash
git grep -n -e "Notes App" -e "com.example.notesapp"
tool/check.sh
```

The first command prints only the lines you meant to keep.
