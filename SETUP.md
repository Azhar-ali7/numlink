# NUMLINK — Setup & Build Log

Running record of environment setup, repo/CI config, and build fixes.
Kept up to date as work proceeds.

## Project

- **App:** NUMLINK — a Wordle-style daily number-chain puzzle (transform a
  start number into a target with token-limited arithmetic ops, scored
  against par).
- **Framework:** Flutter 3.32.0 / Dart 3.8.0.
- **Source:** `numlink_app/` (recreated from the design handoff in
  `README.md` + `NUMLINK.dc.html`).
- **State/persistence:** `provider` + `ChangeNotifier`, `shared_preferences`.
  Local-first stats with an account seam for later progress sync.
- **Tests:** 15 passing (`flutter test`) — game logic, stats, full-app flow,
  welcome screen.

## GitHub

- **Repo:** https://github.com/Azhar-ali7/numlink (private).
- **Account:** `Azhar-ali7` (via `gh` CLI).
- **Created with:** `gh repo create numlink --private --source=. --remote=origin --push`
- **.gitignore** (repo root) excludes `.claude/`, `.DS_Store`, and Flutter
  build artifacts. The app also has Flutter's own `numlink_app/.gitignore`.

## CI — APK build in the cloud

- **Workflow:** `.github/workflows/android.yml`
- **Trigger:** every push to `main`, plus manual `workflow_dispatch`.
- **Runner:** `ubuntu-latest` (Linux = 1× billing; private-repo free tier is
  2,000 min/month, so effectively free at ~5–8 min/build).
- **Steps:** checkout → JDK 17 (temurin) → Flutter 3.32.0 → `pub get` →
  `flutter test` → `flutter build apk --release` → upload
  `app-release.apk` as artifact **`numlink-release-apk`**.
- **Status:** ✅ green. APK downloadable from the run's Artifacts section.

## Local Android build

Building the APK locally required three fixes. Recorded here so the next
person (or machine) doesn't rediscover them.

### 1. Point Flutter at the Android SDK
SDK installed at `~/Library/Android/sdk` but `ANDROID_HOME` was unset and
Flutter couldn't find it.
```
flutter config --android-sdk ~/Library/Android/sdk
```
SDK has: platform `android-37`, `build-tools 36.0.0`, platform-tools,
licenses. (`cmdline-tools` is missing — only needed for `sdkmanager`/license
acceptance, not for building, since licenses are already present.)

### 2. Gradle wrapper distribution wouldn't download
`gradlew` timed out fetching `gradle-8.12-all.zip`
(`java.net.ConnectException: Operation timed out`) — the redirect to
Gradle's CDN times out from the JVM, though `curl` reaches it fine. The
wrapper cache held only a 0-byte `.zip.part`. Fix: fetch the zip with curl
into the wrapper cache, then let the wrapper use it.
```
D=~/.gradle/wrapper/dists/gradle-8.12-all/ejduaidbjup3bmmkhw3rie4zb
rm -f "$D"/*.part "$D"/*.lck
curl -L --fail -o "$D/gradle-8.12-all.zip" \
  https://services.gradle.org/distributions/gradle-8.12-all.zip
```

### 3. JDK version — pin to 17
Flutter resolved **JDK 25.0.2**, which this Android Gradle Plugin can't
parse → `java.lang.IllegalArgumentException: 25.0.2`. Only JDK 17 (Zulu) is
OS-registered. Fix:
```
flutter config --jdk-dir "/Library/Java/JavaVirtualMachines/zulu-17.jdk/Contents/Home"
```
(Verified in `~/.config/flutter/settings`.)

### Build command
```
export ANDROID_HOME=~/Library/Android/sdk
export JAVA_HOME="/Library/Java/JavaVirtualMachines/zulu-17.jdk/Contents/Home"
cd numlink_app && flutter build apk --release
# → build/app/outputs/flutter-apk/app-release.apk
```

**Status:** ✅ built — `app-release.apk`, 20.9 MB, zip-verified (contains
`classes.dex` + `AndroidManifest.xml`). First build also auto-installed SDK
Platform 35 + CMake 3.22.1 via Gradle; subsequent builds skip those.
The APK is a build artifact and is gitignored (not committed).

## Claude Code tooling

- **Ponytail** (laziness/YAGNI reviewer) — installed as a Claude Code plugin;
  a global `UserPromptSubmit` hook in `~/.claude/settings.json` injects a
  reminder every prompt. Applied "safe cuts" to the app (merged
  `SettingsRepository` into `SettingsController`; `IconSquareButton` reuses
  `HoverBorder`). Deliberate seams kept with `// ponytail: intentional YAGNI`
  markers (`solver.dart`, `account_service.dart`).
- **Headroom** (`headroom-ai`) — installed for token optimization.

## Run it

```
cd numlink_app
flutter run -d chrome     # or -d macos
flutter test              # 15 tests
```
