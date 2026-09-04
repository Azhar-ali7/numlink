# NUMLINK

A daily number-chain puzzle built in Flutter. Transform a **start** number into a
**target** by chaining arithmetic operations (`×3`, `+7`, `÷2`…), each with a
limited number of uses ("tokens"). Fewer moves is better — you're scored against
**par**.

Flutter recreation of the `NUMLINK.dc.html` design handoff (see the repo-root
`README.md` for the full design spec and tokens).

## Modes

- **Daily** — one shared puzzle per day (Wordle-style), reproducible from the date.
- **Practice** — unlimited puzzles at a chosen difficulty.
- **Timed** — an 8-stage ladder against one clock, or a per-board countdown you
  can switch on in Free Play at any difficulty (the budget scales with par).
- **Archive** — replay any past daily.

Per-mode stats, streaks, achievements, and a next-daily countdown. A first-run
intro carousel introduces the rules, and a six-step spotlight tour points at the
board itself the first time you open one; both replay from Settings -> How to
play.

Streaks survive a missed day only while a banked freeze covers it. Freezes are
earned at streak milestones and capped at two, so a third missed day always
breaks the run -- and the streak reads "frozen" on Home and in Stats while a
freeze is what is holding it up, rather than showing a healthy flame.

## Run

```bash
flutter pub get
flutter run                 # attached device or emulator
flutter run -d chrome       # web
```

RAM-light Android debug run (capped Gradle heap):

```bash
GRADLE_OPTS="-Dorg.gradle.jvmargs=-Xmx1536m -Dorg.gradle.workers.max=2" \
  flutter run -d emulator-5554 --debug
```

## Test

```bash
flutter analyze
flutter test
```

`test/generator_test.dart` verifies every generated puzzle is solvable and that
`par == minMoves` (honest par), plus daily reproducibility.

## Layout

- `lib/game/` — puzzle generation (`generator.dart`), solver (`solver.dart`,
  BFS `minMoves`), difficulty specs (`game_mode.dart`), controller.
- `lib/screens/` — home (`welcome_screen.dart`), intro carousel, puzzle screen.
- `lib/sheets/` — win / stats / settings / how-to bottom sheets.
- `lib/widgets/`, `lib/theme/` — UI components and design tokens.
- `lib/data/` — `settings_controller.dart` and persistence (`shared_preferences`).

Tech: Flutter 3.32 / Dart 3.8, `provider` + `ChangeNotifier`, `shared_preferences`.
No backend — the daily is generated deterministically from the date.
