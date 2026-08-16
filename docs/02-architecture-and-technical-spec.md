# NUMLINK — Architecture & Technical Specification

## Stack

- **Flutter 3.32.0 / Dart 3.8.0** (`sdk: ^3.8.0`), single codebase.
- **State:** `provider` + `ChangeNotifier` (no BLoC, no Redux).
- **Persistence:** `shared_preferences` — local key/value only. No backend.
- **UI libs:** `google_fonts`, `flutter_animate`, `confetti`, `audioplayers`,
  `cupertino_icons`. Dev: `flutter_lints`.
- pubspec `version: 1.0.0+1` (release tag is `v0.1.0` — to be reconciled).

No new runtime dependency is added for anything the stdlib or an installed
package already does.

## Layering

```
main.dart              bootstrap: build repos/services, load data, wire providers
  └─ app.dart          NumlinkApp (MaterialApp + theme) → _AppShell (Stack of layers)
       ├─ screens/     GameScreen, WelcomeScreen, IntroCarousel
       ├─ sheets/      win, stats, how-to-play, settings, archive (bottom sheets)
       ├─ widgets/     reusable UI (chain node, heat bar, buttons, countdown…)
       ├─ game/        GameController + rules engine (generator, solver, modes)
       ├─ models/      plain data (Puzzle, Operation, ChainNode, GameStats…)
       ├─ data/        SettingsController, StatsRepository, SessionRepository
       ├─ account/     AccountService (local-only stub)
       ├─ services/    FeedbackService (sound + haptics)
       └─ theme/       tokens, motion, fonts, app_theme
```

Dependency direction is one-way: `screens`/`sheets`/`widgets` depend on
`game`/`models`/`data`/`theme`; the game layer never imports UI.

## Bootstrap (`main.dart`)

1. `WidgetsFlutterBinding.ensureInitialized()`.
2. `SharedPreferences.getInstance()`.
3. Construct: `LocalStatsRepository(prefs)`, `const LocalPuzzleRepository()`,
   `LocalSessionRepository(prefs)`, `const LocalOnlyAccountService()`,
   `FeedbackService`.
4. Load today's puzzle (`repo.today`) + saved stats (`stats.load()`) + any saved
   in-progress session (`sessionRepo.load()`).
5. `MultiProvider`:
   - `AccountService` (`.value`),
   - `SettingsController` (loads its own prefs),
   - `GameController(...)` — `resumeFrom(saved)` if an unsolved session exists
     (land back on that board), else `.init()`.
6. `runApp(NumlinkApp())`.

## The app shell (`app.dart`)

`_AppShell` centers a `maxWidth: 440` column (2px L/R borders) inside a
`SafeArea`, then stacks layers bottom→top:

1. `GameScreen` (always present — the board).
2. `ConfettiOverlay(pulse: g.winPulse)`.
3. `GameToast` (only when a transient message is set).
4. `WelcomeScreen` (when `!g.started` — the home/menu).
5. The active bottom sheet, chosen by `g.overlay` (`SheetOverlay` enum:
   `win / stats / how / settings / archive / solution`).
6. `IntroCarousel` (when `settings.tutorialOpen` — topmost, first-run tutorial).

This is a single-route app; navigation is layer visibility, not `Navigator`
routes.

## The game engine

### `GameController` (`game/game_controller.dart`)

The core `ChangeNotifier`. Holds the live chain, remaining tokens per op,
current mode, overlay, timer state, and a transient toast message. Ported 1:1
from the design prototype's loop. Key methods:

- **Play:** `apply(op)`, `undo()`, `reset()`, `load(puzzle)`.
- **Hints / reveal:** `hint()` (highlights the next best move, re-solved live via
  `solvePath(from: current, used:)`, capped by `DifficultySpec.hints`),
  `revealSolution()` (opens the solution sheet); getters `hintsLeft`,
  `hintOpId`, `canReveal`, `answerPath`. `reset()` bumps a `_resets` failure
  counter (only when the board was played), which drives `canReveal`.
- **Mode entry:** `startDaily()`, `startPractice(d)`, `startZen(d)`,
  `startTimed()`, `startArchive(no)`, `goHome()`, `newPuzzle()`, `playAgain()`.
- **Resume:** `resumeFrom(GameSession)` re-seeds the board at startup; a private
  `_persist()` snapshots progress to `SessionRepository` on every mutation,
  `_clearSession()` wipes it on solve.
- **Timed ladder:** `_solveTimed()` advances an 8-stage run
  (`_ladderLength = 8`), ticking once per second.
- **Overlays:** `open(SheetOverlay)`, `close()`.
- **Recording:** `_recordSolve(...)` — **only Daily** touches streak +
  par-distribution; other modes bump their own counters.
- **Share:** `shareText` →
  `"NUMLINK #<no>\n<moves> moves · par <par>\n<🟦×within><🟧×over> 🎯"`.

Enums it owns: `SheetOverlay`, `ScoreLabel {eagle,birdie,par,bogey,doubleBogey,over}`,
`Heat {onTarget,near,far}`. `heatPercent` is clamped to `[6,100]`.

### Puzzle model (`models/`)

- `Puzzle { no, dateLabel, start, target, par, ops, cap=999, solution }` —
  `solution` is the op-id sequence of the stored answer path (see solver).
- `Operation { id, symbol, n, tokens }`; `label = "$symbol$n"`;
  `apply(cur, cap)` supports `× + − ÷`. Division must be exact (integer), and
  results must stay in `[0, cap]` — otherwise the op is illegal.
- `ChainNode(value, [opLabel])` — one row in the visible chain.
- `Puzzle`, `Operation`, `ChainNode` all carry `toJson`/`fromJson` (needed to
  serialize a `GameSession` for resume).

### Generator (`game/generator.dart`)

`PuzzleGenerator` (`_cap = 999`) produces a puzzle for a difficulty + seed:

1. **Forward-build** a solution of length in `[minPar, maxPar]` from a random
   start value, applying legal ops.
2. **Assemble 6 ops** — the ones the solution used, plus decoys.
3. **BFS-verify** via `solvePath` (see solver): honest minimum move count **and**
   the actual shortest path, from one pass.
4. **Republish `par`** as that true minimum and **store the path** on
   `Puzzle.solution` — choices and answer path are emitted atomically.
5. **Reject** if the verified par escapes the difficulty band, or the puzzle is
   `_trivial` (solvable by pure addition).
6. Retry: 300 strict attempts, then 300 relaxed (`par >= 2`), then a fixed
   `_fallback` (start 2, target 26, par 3).

Op id prefixes: `m` multiply, `p` plus, `s` subtract, `d` divide.

### Solver (`game/solver.dart`)

`List<String>? solvePath(Puzzle p, {int? from, Map<String,int>? used})` —
**breadth-first search** over states of `(value, per-op used-counts)`, respecting
each op's token cap, with a depth safety bound of 20. Because BFS is level-order,
the first state reaching the target carries a **shortest** path; it returns that
op-id sequence, or `null` if unsolvable. `from`/`used` default to the puzzle
start with nothing spent, but let it also solve from a **mid-game** state — this
is what powers live hints ("next best move from here").

`int? minMoves(Puzzle p) => solvePath(p)?.length;` — one BFS, no duplicated
logic; existing callers unchanged.

**Invariant:** for every published puzzle, `minMoves(puzzle) == puzzle.par` and
replaying `puzzle.solution` from the start reaches the target legally. This is
what makes par *honest* and guarantees every puzzle has a definite answer.

> Ponytail note: `solvePath` serves the generator (par + stored path), hints, and
> the reveal from a single primitive; `minMoves` is a one-line alias over it.

### Modes & difficulty (`game/game_mode.dart`)

- `enum GameMode { daily, practice, zen, timed, archive }`.
- `enum Difficulty { easy, medium, hard }`.
- `DifficultySpec { minPar, maxPar, maxTarget, startMax, allowDivide,
  extraTokens, hints, revealAfter }`:

  | Difficulty | par band | maxTarget | startMax | divide? | extraTokens | hints | revealAfter |
  |-----------|:--------:|:---------:|:--------:|:-------:|:-----------:|:-----:|:-----------:|
  | easy | 2–3 | 50 | 9 | no | 2 | 3 | 2 |
  | medium | 3–4 | 200 | 15 | yes | 1 | 3 | 3 |
  | hard | 4–6 | 999 | 20 | yes | 0 | 3 | 4 |

  `hints` = "next best move" hints per puzzle; `revealAfter` = resets (or all
  hints spent) before "Show solution" unlocks — harder tiers make the player
  work longer.

  `DifficultySpec.of(d)` looks it up; `DifficultyLabel` gives display names.

### Daily determinism (`game/puzzle_repository.dart`)

`abstract PuzzleRepository` exposes `today`, `daily(date)`, `generate(d,seed)`,
`archive(no)`, `archiveNumbers`, `ladder(count, runSeed)`.

`LocalPuzzleRepository`:

- **Epoch:** `DateTime.utc(2026, 8, 8)` = puzzle **#128**.
- Puzzle number for a date = `128 + days since epoch`.
- Daily tier is fixed at **medium**; the puzzle **seed = its number**, so every
  device generates the identical board for a given date.
- Date label format: `"MON D YYYY"`.
- Timed `ladder` ramps difficulty `[easy, easy, medium, medium, hard]`, cycling.

## Data & persistence

- **Stats** — `abstract StatsRepository { load, save }`; `LocalStatsRepository`
  under key `numlink_stats`. First run / parse failure returns `GameStats.seed`
  (a pre-populated demo profile) rather than empty.
- `GameStats { played, wins, streak, maxStreak, dist, counters, archiveSolved,
  unlocked }`; bucket keys `['par','+1','+2','+3+']`; derived `winRate`,
  `totalSolves`; mutators `recordWin`, `bumpCounter`, `setCounterMax`,
  `markArchive`, `withUnlocked`; `toJson`/`fromJson`.
- **Settings** — `SettingsController` persists `theme`, `highContrast`,
  `orangeSuccess`, `sound`, `haptics`, and `tutorialSeen`. `tutorialOpen` is a
  transient flag initialized to `!tutorialSeen` on load (drives the first-run
  carousel).
- **Session (resume)** — `abstract SessionRepository { load, save, clear }`;
  `LocalSessionRepository` under key `numlink_session`. `GameSession { mode,
  difficulty, puzzle, chain, used, hintsUsed, resets }` → JSON (reuses the model
  `toJson`s). Saved on every move / hint / reset / go-home, cleared on solve;
  loaded once at startup to resume an in-progress board. A corrupt/old snapshot
  parses to `null` (start fresh), never a crash.

## Seams for later (interfaces with a stub today)

- `AccountService { userId, signInWithEmail, signOut, syncUp, syncDown }` —
  `LocalOnlyAccountService` is a no-op. Where email login + cloud profile
  would plug in.
- The `StatsRepository` interface is the seam for a `RemoteStatsRepository`
  (cloud-synced stats) without touching game code. `SessionRepository` is the
  same seam for cross-device resume (sync the in-progress game per account).

> Ponytail: both are single-implementation interfaces **on purpose** — they're
> the documented extension points, not speculative abstraction. Everything else
> is concrete.

## Feedback (`services/feedback_service.dart`)

`FeedbackService` — sound + haptics, both **off by default**, gated by settings.
Lazy `AudioPlayer`; assets `sfx/tap.wav | win.wav | error.wav`; haptics via
`HapticFeedback` (selectionClick / heavyImpact / mediumImpact). Audio is
best-effort inside try/catch — a missing/blocked player never breaks play.

## Testing

51 tests, green: `app_flow_test`, `game_controller_test` (includes hints, reveal,
and session round-trip/resume), `generator_test` (honest-par invariant),
`solver_path_test` (path exists, `== par`, replays to target, mid-game solve),
`settings_controller_test`, `stats_repository_test`, `welcome_widget_test`.

## Build & run notes

RAM-light machine (8 GB) needs a capped Gradle heap:

```bash
# Release APK
GRADLE_OPTS="-Dorg.gradle.jvmargs=-Xmx1536m -Dorg.gradle.workers.max=2" \
  flutter build apk --release

# Debug run on emulator
GRADLE_OPTS="-Dorg.gradle.jvmargs=-Xmx1536m -Dorg.gradle.workers.max=2" \
  flutter run -d emulator-5554 --debug
```

The current release APK is debug-signed (no release keystore configured in
`android/app/build.gradle.kts`).
