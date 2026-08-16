# NUMLINK — Glossary & References

Definitions of the domain-specific terms used across the code and docs.

## Core play terms

**Chain** — the sequence of numbers you build, from **start** down to (ideally)
**target**. Each link is one applied operation. Modeled as a list of
`ChainNode`.

**ChainNode** — one value in the chain, plus the label of the op that produced
it (`ChainNode(value, [opLabel])`).

**Start** — the number a puzzle begins on.

**Target** — the number you must land on **exactly** to win.

**Operation (op)** — one arithmetic move: `× + − ÷` with an operand `n`
(e.g. `×3`). `Operation { id, symbol, n, tokens }`; `label = "$symbol$n"`.

**Operand (`n`)** — the number the operation applies (the `3` in `×3`).

**Apply** — perform an op on the current value: `Operation.apply(current, cap)`.
Returns the new value or rejects the move if illegal.

**Token** — a per-operation use budget. Each op can be used only a limited number
of times; using it decrements the count. Shown as the `N×` pill on a button.

**Cap** — the maximum legal value in a chain (default **999**). Any op result
above the cap is illegal.

**Legal / illegal move** — a move is illegal if it divides unevenly, goes
negative, exceeds the cap, or the op is out of tokens. Illegal moves shake the
button and don't alter the chain.

**Decoy op** — an operation offered in the 6-button pad that the optimal
solution doesn't need; there to mislead.

**Solve / win** — reaching the target value exactly.

## Scoring terms

**Par** — the *true minimum* number of operations a puzzle can be solved in,
computed by BFS. See **honest par**.

**Honest par** — the guarantee that published par equals the BFS minimum:
`minMoves(puzzle) == puzzle.par` for every puzzle. Par is never guessed or
inflated.

**minMoves** — `solver.dart`'s BFS-derived minimum move count for a puzzle (or
`null` if unsolvable), now a one-line alias over `solvePath`. The source of
honest par.

**solvePath** — `solver.dart`'s BFS returning the **op-id sequence of a shortest
solution** (not just its length), optionally from a mid-game `from`/`used` state.
Powers the stored answer path, live hints, and the reveal.

**Solution path / answer path** — the stored shortest op sequence from start to
target (`Puzzle.solution`), emitted by the generator in the same BFS pass that
sets par. Guarantees every puzzle has a definite answer, not a random number.

**Hint** — a "next best move from the current board" cue: `hint()` re-solves live
via `solvePath(from: current)` and glows the recommended op. Capped per puzzle by
`DifficultySpec.hints`.

**Reveal** — the earned "Show solution": unlocks once `canReveal` is true
(`resets ≥ DifficultySpec.revealAfter` **or** all hints spent, scaled by
difficulty), opening the solution sheet.

**Resume / GameSession** — a snapshot of the in-progress game
(`mode, difficulty, puzzle, chain, used, hintsUsed, resets`) persisted by
`SessionRepository` (key `numlink_session`) so a killed app resumes on the same
board. `resumeFrom` re-seeds it at startup.

**Golf scoring** — scoring relative to par, borrowed from golf: fewer moves =
better score.

**Eagle / Birdie / Par / Bogey / Double bogey / Over** — the score bands
(`ScoreLabel`): par−2+, par−1, par, par+1, par+2, par+3+ respectively.

**Par-distribution histogram** — the stats chart of how often you finish at
`par / +1 / +2 / +3+` (the `bucketKeys` in `GameStats`).

## Mode terms

**Daily** — the single shared puzzle for a calendar date, identical on every
device; the only mode that affects **streak**.

**Practice** — unlimited generated puzzles at a difficulty you pick; doesn't
affect streak.

**Zen** — pressure-free mode with no par, score, or clock.

**Timed** — an 8-stage escalating **ladder** raced against a clock.

**Ladder** — the ordered run of puzzles in Timed mode (difficulty ramp
`[easy, easy, medium, medium, hard]`, cycling; `_ladderLength = 8`).

**Archive** — replay any past **daily** puzzle by its number.

## Generation & scheduling terms

**Generator** — `PuzzleGenerator`: forward-builds a solution, adds decoys,
BFS-verifies par, and republishes the honest par.

**Seed** — the deterministic input to generation. For the daily, **seed = puzzle
number**, so every device produces the same board.

**Epoch** — the reference date anchoring puzzle numbering:
`DateTime.utc(2026, 8, 8)` = puzzle **#128**. A date's number = `128 + days
since epoch`.

**Puzzle number (`no`)** — the sequential id of a daily (e.g. `#128`), shown on
the board and in the share text.

**Difficulty tier** — `easy / medium / hard`, each with a `DifficultySpec`
(par band, target/start ceilings, division allowed, extra tokens). Daily is
always **medium**.

**DifficultySpec** — the config bounding the generator for a tier
(`minPar, maxPar, maxTarget, startMax, allowDivide, extraTokens`) plus the
hint/reveal knobs (`hints, revealAfter`).

**Trivial puzzle** — one solvable by addition alone; rejected by the generator.

**Fallback puzzle** — the fixed puzzle (start 2 → target 26, par 3) used if
generation fails after all attempts, so play never stalls.

## Progression terms

**Streak** — consecutive days the **Daily** was solved. `maxStreak` is the best
ever reached.

**Achievement** — a sticky badge earned by meeting a condition
(`SolveContext {scoreOver, usedDivision}`); once earned it stays. The 8:
`first_link, birdie, eagle, purist, streak3, streak7, ten, climber`.

**GameStats** — the persisted profile: `played, wins, streak, maxStreak, dist,
counters, archiveSolved, unlocked`.

**Counters** — per-mode solve tallies (practice/zen/etc.) kept separate from the
Daily streak.

## UI / theming terms

**Heat / heat bar** — the closeness indicator to target (`Heat {onTarget, near,
far}`); `heatPercent` clamped to `[6,100]`.

**Toast** — a transient one-line on-screen message (`GameToast`).

**Win pulse** — the confetti trigger fired on a win (`winPulse`).

**Design token** — a named color/value in `NumTokens` (`bg, surface, elevated,
text, muted, border, success, progress`), themed for dark and light.

**Okabe–Ito palette** — the colorblind-safe color set the tokens draw from.

**Orange-success / `altSuccessOrange`** — opt-in colorblind override
(`#F5793A`) replacing the blue success color.

**Reduced motion** — OS accessibility setting (`MediaQuery.disableAnimations`)
that suppresses shakes and flourishes.

**Motion budget** — the fixed set of animation durations/curves in `motion.dart`
(`micro, standard, celebrate, toast, shake, sheet`).

**Intro carousel** — the 3-slide first-run tutorial, shown once
(`tutorialSeen`), replayable from Settings.

## Architecture terms

**Controller** — a `ChangeNotifier` holding state and exposing actions
(`GameController`, `SettingsController`).

**Repository** — an interface abstracting data access (`PuzzleRepository`,
`StatsRepository`, `SessionRepository`), with a `Local…` implementation today.

**Service** — a helper for a cross-cutting concern (`FeedbackService`,
`AccountService`).

**Seam** — a single-implementation interface kept deliberately as a future
extension point (`AccountService`, the remote-stats seam) — not speculative
abstraction.

**Overlay / sheet** — a UI layer selected by `SheetOverlay`
(`how / stats / settings / win / archive / solution`), shown as a bottom sheet.

## References

- **`README.md` (repo root)** — the authoritative design handoff spec: domain
  terms, screens, tokens, typography, motion budget, share-text, state model.
- **`numlink_app/README.md`** — the project README (setup + overview).
- **Companion docs:**
  [01 Project Brief & Progress](01-project-brief-and-progress.md) ·
  [02 Architecture & Technical Spec](02-architecture-and-technical-spec.md) ·
  [03 Rules & Constraints](03-rules-and-constraints.md) ·
  [04 Front End & UI](04-frontend-and-ui.md).
- **Key source files:** `game/game_controller.dart`, `game/generator.dart`,
  `game/solver.dart`, `game/puzzle_repository.dart`, `game/game_mode.dart`,
  `models/`, `data/settings_controller.dart`, `data/session_repository.dart`,
  `sheets/solution_sheet.dart`, `theme/tokens.dart`, `theme/motion.dart`.
- **External:** [Flutter docs](https://docs.flutter.dev/) ·
  [Okabe–Ito color set](https://jfly.uni-koeln.de/color/) ·
  [`provider`](https://pub.dev/packages/provider) ·
  [`shared_preferences`](https://pub.dev/packages/shared_preferences).
