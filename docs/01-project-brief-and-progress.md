# NUMLINK — Project Brief & Progress

## What it is

NUMLINK is a daily number-chain puzzle. You start on one number and build a
downward chain of arithmetic moves — each move consumes a limited **token** —
to land **exactly** on a target in as few moves as possible. Every puzzle is
scored golf-style against **par** (Birdie / Par / Bogey). A new shared puzzle
appears every day, generated deterministically from the date, so everyone
plays the same board and can compare results.

Think *Wordle's* daily-shared, streak-and-share loop applied to mental
arithmetic.

## Goals

- A calm, tactile, single-screen daily puzzle that takes 1–3 minutes.
- **Honest par** — the published par is the true minimum move count, verified,
  never a guess. A "birdie" means you genuinely beat the optimal solver.
- Accessible by default: colorblind-safe cues, high-contrast mode, reduced
  motion, dark/light themes.
- Local-first, no backend, no account required — but with clean seams so cloud
  sync can be added later without rewriting the game.

## Non-goals (for now)

- No server, login, or cross-device sync (interfaces exist; no implementation).
- No ads, no monetization, no analytics.
- No multiplayer / real-time play.

## Platform & stack (at a glance)

- **Flutter 3.32 / Dart 3.8**, single codebase.
- State: `provider` + `ChangeNotifier`. Persistence: `shared_preferences`.
- No backend — the daily puzzle is generated on-device from the date.
- Full detail in [02-architecture-and-technical-spec.md](02-architecture-and-technical-spec.md).

## Modes

| Mode | What it is | Affects streak? |
|------|-----------|-----------------|
| **Daily** | The shared puzzle of the day, one per date | Yes |
| **Practice** | Unlimited generated puzzles at a chosen difficulty | No (own counter) |
| **Zen** | Pressure-free — no par, score, or clock | No |
| **Timed** | An 8-stage escalating ladder against a clock | No (own counters) |
| **Archive** | Replay any past daily by number | No (marks completion) |

## Progress / status

**Shipped & running on-device (Android):**

- Core play loop (chain, tokens, undo, reset, heat bar, win sheet, share text).
- Deterministic daily generator with **BFS-verified honest par**.
- **Every puzzle carries a definite answer path** (stored alongside its op
  choices), powering **live hints** (next best move from the current board, 3
  per puzzle) and an **earned "Show solution"** that unlocks after enough
  failed attempts (resets or spent hints, scaled by difficulty).
- **Resume:** an in-progress game survives an app kill — the board, tokens,
  hints, resets, and current checkpoint are saved and restored on next launch.
- **Eight operators:** the original `× + − ÷` plus **modulo `%`**, **square
  `x²`**, **integer root `√`**, and **digit-sum `Σ`**, difficulty-gated (medium
  adds `%`; hard adds the unary trio).
- **Milestones:** puzzles can carry ordered **checkpoint values** you must
  thread in sequence before the final target; honest par is the BFS minimum
  *through* the checkpoints, and the target bar shows the active sub-goal.
- **Decluttered board:** one-line header with a single `⋯` overflow menu
  (How/Stats/Settings) and a trimmed action row, giving the chain more room.
- All five modes: Daily, Practice, Zen, Timed ladder, Archive replay.
- Stats: streak, win rate, par-distribution histogram, per-mode counters.
- Achievements (8 badges, sticky once earned).
- Home redesign: Hero "Play today's puzzle" + next-daily countdown + 2×2 mode
  grid, difficulty chosen in a popup after tapping Practice/Zen.
- First-run intro carousel (3 slides, shown once, replayable from Settings).
- Theming: dark/light, high-contrast cues, colorblind orange-success option,
  reduced-motion support. Sound + haptics (off by default).

**Verification bar met:** `flutter analyze` clean; `flutter test` green;
launched on emulator + device.

**Release:** pre-release **v0.1.0** published on GitHub with an attached APK.
Repo is public.

## Known gaps / follow-ups

- APK is **debug-signed** — installs via "unknown sources" but is **not**
  Play-Store-uploadable. Needs a release keystore + signing config.
- `pubspec.yaml` still reads `version: 1.0.0+1` while the release tag is
  `v0.1.0` — reconcile before the next release.
- Account/cloud sync is an **interface only** (`AccountService`,
  `RemoteStatsRepository` seam) — no implementation yet.
- Android NDK version warning during release build (plugins want 27.x, project
  pins 26.x) — non-fatal, backward compatible; bump when convenient.
- Timed "best time" is session-only (not persisted).

## Timeline of major commits

`feat(modes)` Zen + Timed ladder → `feat(phase4)` archive replay, per-mode
stats + achievements → `feat(phase5)` next-daily countdown → `feat(home)`
Hero Daily + mode grid + first-run intro carousel → `feat(hints)` answer
path + live hints + earned reveal + resume → `refactor(ui)` compact header →
`feat(ops)` four new operators → `feat(milestones)` in-order checkpoints.
