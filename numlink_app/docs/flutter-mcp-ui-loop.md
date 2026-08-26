# Fast UI-iteration loop for Flutter (MCP + hot reload)

A setup that lets you — and Claude Code — **see and drive a running Flutter app
without rebuilding an APK**. Two capabilities, no custom server to build:

1. **Hot reload** — *you* see UI changes in <1s on a running app (web, emulator,
   or a real device). Built into Flutter; no tooling.
2. **The Dart & Flutter MCP server** — *the agent* sees the UI (screenshots),
   drives it (tap / type / scroll), hot-reloads, reads runtime errors, and
   inspects the widget tree. A closed visual feedback loop.

Nothing here is custom. The MCP server ships with the Dart SDK
(`dart mcp-server`). You only wire a one-line opt-in gate for the tap/type/scroll
part.

---

## Prerequisites

- **Dart 3.9+** (Flutter 3.35+; latest stable recommended). The MCP server needs
  it. Check with `dart --version`.
- **Claude Code** with MCP support.
- A run target: Chrome/web (fastest), an emulator, or a USB device (real-device
  fidelity). `flutter devices` lists them.

### Upgrading safely (only if you're below 3.9)

Do it on a branch — fully reversible:

```bash
git switch -c chore/flutter-upgrade
flutter upgrade            # you're on the stable channel → latest stable
flutter pub get
flutter analyze            # fix any new deprecation warnings
flutter test               # keep green
```

If anything breaks stubbornly, pin back via the [Flutter SDK
archive](https://docs.flutter.dev/release/archive) or [FVM](https://fvm.app);
the branch isolates everything and `build/` + `.dart_tool/` are disposable.

Upgrades across a few minor versions are usually mechanical. The APIs that most
often break are `MaterialStateProperty` (→ `WidgetStateProperty`),
`WillPopScope` (→ `PopScope`), `textScaleFactor`, and `Color.withOpacity` (→
`withValues`). `grep -rn` your `lib/` for those before upgrading to gauge scope.

---

## Setup (once per project)

### 1. Register the MCP server

Project-scoped (recommended):

```bash
claude mcp add --transport stdio dart -- dart mcp-server
claude mcp list        # → dart: dart mcp-server - ✔ Connected
```

Or install the **official Flutter plugin for Claude Code** (bundles the MCP
server + agent skills) per <https://docs.flutter.dev/ai/mcp-server>.

> **Restart Claude Code** after adding the server — MCP tools load at session
> start, so a freshly-added server isn't callable until the next session.

### 2. Add the driver dependency

Only needed for agent **tap/type/scroll** (screenshots + hot reload work
without it). In `pubspec.yaml`:

```yaml
dependencies:
  flutter_driver:
    sdk: flutter
```

Put it under `dependencies`, **not** `dev_dependencies`: your `main.dart` imports
it, and recent Flutter strips `dev_dependencies` from release builds — which
would break the import. The runtime gate below keeps it inert unless you opt in.

### 3. Add the opt-in gate in `main()`

```dart
import 'package:flutter_driver/driver_extension.dart';

Future<void> main() async {
  // Opt-in only (--dart-define=ENABLE_FLUTTER_DRIVER=true). Normal and release
  // builds are untouched; this only lets the MCP/agent loop drive the UI.
  if (const bool.fromEnvironment('ENABLE_FLUTTER_DRIVER')) {
    enableFlutterDriverExtension();
  }
  WidgetsFlutterBinding.ensureInitialized();
  // ...your existing bootstrap...
}
```

`const bool.fromEnvironment` is compile-time: with the flag off, the tree-shaker
drops the extension entirely, so release builds carry no driver surface.

### 4. Run the app with the gate on

```bash
flutter run -d <device> --dart-define=ENABLE_FLUTTER_DRIVER=true
```

Leave it running. This is the app the agent attaches to.

---

## The loop

Per UI change:

```
edit Dart  →  MCP hot_reload  →  MCP screenshot  →  inspect  →  repeat
```

No APK builds in the loop. Ask Claude Code things like *"screenshot the app",
"tap the Play button and screenshot", "make the header teal, hot reload, show
me"*. It uses the `dart` MCP tools to see the result and self-correct.

---

## Capabilities

| Tool (MCP feature)      | What it does                                        |
|-------------------------|-----------------------------------------------------|
| `hot_reload`            | Apply Dart edits to the running app (<1s)           |
| `hot_restart`          | Full restart (resets state) when hot reload can't    |
| screenshot (vm_service) | Capture the current frame — *the agent sees the UI* |
| `flutter_driver_command`| Tap / type / scroll / wait on widgets               |
| `widget_inspector`      | Read the live widget tree / properties              |
| `get_runtime_errors`    | Read exceptions thrown at runtime                    |
| `get_app_logs`          | Read `print`/logger output from the app             |
| `list_devices` / `launch_app` / `stop_app` | Manage run targets           |
| `run_tests`             | Run `flutter test`                                  |
| `analyze_files`         | Run the analyzer                                    |
| `pub`                   | Manage packages                                     |

Narrow the surface with `--enable`/`--disable` on `dart mcp-server` (categories:
`dart`, `flutter`, `flutter_driver`, `analysis`, …). All are on by default.

**Limits:** screenshots are on-demand snapshots, not live video. Tap/type/scroll
needs the driver gate on (step 4). The agent sees what a screenshot captures —
off-screen or overlaid widgets may need a scroll first.

---

## Troubleshooting

- **`dart` server not listed / not callable** — restart Claude Code (MCP loads
  at session start). Re-check `claude mcp list`.
- **Can't tap/type** — the driver gate is off. Confirm you launched with
  `--dart-define=ENABLE_FLUTTER_DRIVER=true` and that `enableFlutterDriverExtension()`
  runs before `runApp`.
- **`depend_on_referenced_packages` on the driver import** — `flutter_driver` is
  in `dev_dependencies`; move it to `dependencies` (see step 2).
- **No connection to the running app** — the server talks to the app over the
  Dart Tooling Daemon / VM service. Keep `flutter run` alive; make sure only one
  target is running or name it explicitly.
- **Upgrade broke the build** — pin back via the SDK archive or FVM on your
  branch (see Prerequisites).
- **`Gradle version … is lower than Flutter's minimum`** (Android release) — bump
  `distributionUrl` in `android/gradle/wrapper/gradle-wrapper.properties` to the
  version Flutter names. A newer Flutter also runs an Android migrator that adds
  `android.newDsl=false` / `android.builtInKotlin=false` to `gradle.properties`;
  keep those unless you're moving to AGP 9+.
- **Don't want to upgrade Flutter** — the community
  [`mcp_flutter`](https://github.com/Arenukvern/mcp_flutter) server gives the
  same screenshot/hot-reload loop without the Dart 3.9 floor, as a fallback.

---

## Worked example (this repo, NUMLINK)

- Was Flutter 3.32 / Dart 3.8 → upgraded on branch `chore/flutter-3.44-upgrade`
  to Flutter 3.47 / Dart 3.13. Upgrade was mechanical: `analyze` clean, 86 tests
  green (two latent test assertions — an off-screen tap and a checkpoint-fragile
  label check — were fixed, both unrelated to the upgrade).
- `pubspec.yaml`: SDK floor `^3.9.0`, `flutter_driver` added under `dependencies`.
- `lib/main.dart`: the `ENABLE_FLUTTER_DRIVER` gate at the top of `main()`.
- Run: `flutter run -d <device> --dart-define=ENABLE_FLUTTER_DRIVER=true`.

---

## Sources

- Dart & Flutter MCP server — <https://docs.flutter.dev/ai/mcp-server>
- Announcing Dart 3.9 (MCP minimum) — <https://dart.dev/blog/announcing-dart-3-9>
- Flutter SDK archive — <https://docs.flutter.dev/release/archive>
