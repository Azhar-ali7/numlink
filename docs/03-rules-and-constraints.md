# NUMLINK — Rules & Constraints

## The puzzle

Each puzzle gives you a **start** number and a **target** number. Build a
**chain** downward from start: at every step you pick one arithmetic
**operation** and it produces the next value. Reach the target **exactly** to
win.

```
start ──(op)──▶ value ──(op)──▶ value ──(op)──▶ target
```

## Operations

- Eight kinds, four **binary** (take an operand `n`) and four **unary** (ignore
  `n`):
  - **× multiply**, **+ add**, **− subtract**, **÷ divide** — `×3`, `+7`, `−4`,
    `÷2`.
  - **% modulo** (`%n`, remainder), **x² square** (`^`), **√ integer root**
    (floored, unary), **Σ digit-sum** (sum of decimal digits, unary).
  - `Operation.label` renders `$symbol$n` for binary ops, but drops the operand
    for the unary/square glyphs: `%7`, `x²`, `√`, `Σ`.
- Each puzzle offers **6 operation buttons** (the ones the optimal solution
  needs, plus decoys).
- Every operation has a **token budget** — a small number of times it may be
  used. Using it decrements the count; at 0 the button is spent.

## Legality (an operation is rejected if…)

`Operation.apply(current, cap)` enforces:

1. **Division must be exact** — `÷n` is illegal unless `current` is evenly
   divisible by `n` (no fractions ever).
2. **Modulo needs `n > 0`** — `%n` with `n ≤ 0` is illegal.
3. **No negatives** — a result below 0 is illegal.
4. **Cap** — a result above the puzzle **cap** (default **999**) is illegal.
   (This is what self-limits **x²**: `40²` = 1600 > 999 is rejected.)
5. **No tokens left** — an op at 0 remaining tokens can't be used.

Every op is guarded uniformly: the result must be a whole number in `[0, cap]`,
so **√** and **Σ** (which only ever shrink the value) are always in range.

An illegal tap doesn't change the chain: it triggers a **shake** on the button
and a toast, so the feedback is immediate but harmless. It is **not** counted as
a failed attempt (only resets of a played board are — see below).

## Milestones (checkpoints)

Some puzzles carry **ordered checkpoint values** (`Puzzle.milestones`) that you
must pass through **in sequence** before the final target — small sub-goals on
the way down.

- The target bar shows your **active target**: the next unreached checkpoint, or
  the final target once all are banked. A `CHECKPOINT n/total` → `FINAL TARGET`
  label and a dots row track progress.
- Landing your chain value **exactly** on the active checkpoint **banks** it
  (a win-pulse fires) and advances the active target to the next one. You do
  **not** win by hitting the final target value early — every checkpoint must be
  banked first, in order.
- Heat / proximity guidance points at the **active target**, not the final one,
  so the closeness cue always tracks the current sub-goal.
- Milestones sit on the puzzle's real forward solution, so an in-order route
  always exists, and **honest par threads them**: published par is the BFS
  minimum *through* the checkpoints in order (see below).
- The generator adds them only to **medium/hard** puzzles with room to (par ≥ 4
  → 1 checkpoint, par ≥ 6 → 2, evenly spaced; start/target excluded). Easy
  puzzles and short pars stay checkpoint-free — an empty list behaves exactly
  as before.

## Winning & par

- You **win** when the chain value equals the target exactly **and** every
  milestone has been banked in order.
- Every puzzle has a **par** = the *true minimum* number of operations needed,
  found by breadth-first search over all legal chains (`minMoves`). When a puzzle
  has milestones, the BFS is constrained to pass them in order, so par is the
  shortest **checkpoint-threading** route.
- **Honest par is a hard invariant:** `minMoves(puzzle) == puzzle.par` for every
  published puzzle. Par is never estimated.

## Answer path, hints & the reveal

Every puzzle carries **one definite answer path** — the shortest op sequence
from start to target — stored on `Puzzle.solution`. It is produced by the *same*
BFS pass that verifies par (`solvePath`), so the 6 offered ops and the answer
path are always in sync: regenerating a puzzle refreshes both atomically (the
"one option updates every choice and the path" guarantee lives in the generator,
not in an editor UI). No published puzzle is a random number without a solution.

- **Hints** point at the **next best move from the current board**. A hint
  re-solves live from where you are (respecting tokens already spent), so it's
  always valid even after you've diverged from the canonical path. The pointed-at
  op button glows for ~2.5s. Hints are capped per puzzle (`DifficultySpec.hints`,
  currently **3** on every tier).
- **Show solution** is earned, not free. It unlocks once you've **failed enough**:
  `resets ≥ DifficultySpec.revealAfter` **OR** all hints spent. The reset
  threshold **scales with difficulty** — easy **2**, medium **3**, hard **4** —
  so harder puzzles make you work longer before the answer is offered. Only a
  reset of a *played* board (moves > 0, unsolved) counts as a failed attempt.
- The reveal shows the full start→target path as labeled steps; it never alters
  the board, so you can still finish the puzzle yourself.

## Resume

An in-progress game **survives an app kill**. The board, tokens spent, hints
used, and reset count are snapshotted to `shared_preferences` (`numlink_session`)
on every move / hint / reset / return-to-home, and cleared on solve. On next
launch the player lands **back on the puzzle they were playing** (any mode),
continuing exactly where they left off. Within a live session, backing out to
the Home hub already preserves the board in memory; persistence only adds
durability across process death.

## Scoring (golf)

Your score is your move count relative to par:

| Result | Moves vs par | `ScoreLabel` |
|--------|--------------|--------------|
| Eagle | par − 2 or better | `eagle` |
| Birdie | par − 1 | `birdie` |
| Par | exactly par | `par` |
| Bogey | par + 1 | `bogey` |
| Double bogey | par + 2 | `doubleBogey` |
| Over | par + 3 or worse | `over` |

Because par is honest, beating par (birdie/eagle) means genuinely out-solving
the optimal BFS solver — it's real, not inflated.

### Campaign stars

Campaign levels re-rank the same golf score as **1–3 stars** via
`starsFor(moves, par)`: **≤ par → 3★**, **+1 → 2★**, **+2 or worse → 1★**
(clearing always earns at least one). `recordLevel` keeps the **best** rating,
so replaying a level can only improve it. These bands are a `ponytail:` tuning
knob.

## Difficulty tiers

`DifficultySpec` bounds the generator (see architecture doc for the table):

- **easy** — par 2–3, targets ≤ 50, start ≤ 9, **no division**, +2 extra tokens.
  Only `× + −`; no checkpoints.
- **medium** — par 3–4, targets ≤ 200, start ≤ 15, division allowed, +1 token.
  Adds **`÷` and `%`** to the pool; may carry 1 checkpoint.
- **hard** — par 4–6, targets ≤ 999, start ≤ 20, division allowed, no extra
  tokens. Adds the high-target unary trio **`x²`, `√`, `Σ`** on top; may carry
  1–2 checkpoints.

The new operators are **difficulty-gated** play-test knobs (`ponytail:` in
`_candidates`): `%` unlocks once division is allowed, and `x²`/`√`/`Σ` only when
`maxTarget ≥ 999`. The **Daily** puzzle is always **medium**.

## Generation constraints

A generated puzzle is only published if **all** hold:

- Verified par lands inside the difficulty's `[minPar, maxPar]` band.
- It is **not trivial** (not solvable by addition alone).
- All values stay within `[0, cap]`.

If 300 strict + 300 relaxed (`par ≥ 2`) attempts fail, a fixed fallback puzzle
(start 2 → target 26, par 3) is used so play never stalls.

## Daily rules

- **One shared puzzle per calendar date**, identical on every device
  (deterministic: seed = puzzle number; epoch #128 = 2026-08-08).
- Only the **Daily** result affects your **streak** and **par-distribution
  histogram**.
- A new daily unlocks each day; a **countdown** shows time to the next one.

## Mode constraints

| Mode | Par/score? | Clock? | Streak? | Notes |
|------|:---------:|:------:|:-------:|-------|
| Daily | yes | no | **yes** | one per date; the only streak source |
| Practice | yes | no | no | unlimited, pick difficulty; own counter |
| Zen | **no** | no | no | no par/score/clock — pure play |
| Timed | yes | **yes** | no | 8-stage ladder, per-second tick; own counters |
| Archive | yes | no | no | replay any past daily by number; marks solved |
| Campaign | yes | no | no | curated roadmap level; earns 1–3 stars, replayable |

### Campaign / roadmap rules

- The campaign is a fixed, ordered list of curated levels (`kCampaign`), the
  same for every player (deterministic seeds).
- **Linear unlock:** level 1 is always open; level `n` unlocks only once level
  `n − 1` is cleared (`levelUnlocked(n)`).
- Clearing a level records its best star rating; the roadmap shows earned stars
  per level and the running total. Campaign play never touches the daily streak.

## Streak rules

- Advanced only by solving the **Daily**.
- `GameStats` tracks `streak` and `maxStreak`.
- Missing a day breaks the current streak (max is preserved).

## Achievements

8 badges (`kAchievements`), evaluated from a `SolveContext {scoreOver,
usedDivision}` after each solve; **sticky once earned** (stored in `unlocked`):

`first_link`, `birdie`, `eagle`, `purist`, `streak3`, `streak7`, `ten`,
`climber`.

## Constraints on the build itself

- **Local-first:** no network calls, no account required, all state in
  `shared_preferences`. Works fully offline.
- **No new dependencies** are added for what the stdlib, the platform, or an
  installed package already does.
- **Accessibility is non-negotiable:** colorblind-safe palette (color always
  paired with shape/text), high-contrast mode, reduced-motion support,
  dark/light themes.
- **Sound & haptics default OFF** — opt-in only.
