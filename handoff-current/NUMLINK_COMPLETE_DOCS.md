# NUMLINK — Complete Documentation

Single source of truth: design, functionality, and code, in one place. Built as a Design Component (`NUMLINK.dc.html`), a single-file HTML app (template + logic class), companion spec (`NUMLINK_SPEC.md`), and handoff package (`design_handoff_numlink/`).

---

## 1. What it is

A mobile-format (max-width 440px) number-linking puzzle. Tap a node, tap an operator tile, a new number appears as that node's child — the tree grows outward from a **start number** until every one of 2–5 **target numbers** exists somewhere in it. No single required path: any node can branch, up to a per-arm depth cap. Scored on moves vs. a provably-achievable **par**, golf-style (Eagle/Birdie/Par/Bogey/Double bogey).

Around that core loop: a home hub, a cartoon campaign map, extra modes (Daily/Practice/Zen/Timed/Archive/Weekend Co-op), XP/levels, signature medals, leaderboard, settings/accessibility.

---

## 2. Files

| File | Role |
|---|---|
| `NUMLINK.dc.html` | The entire app — template + `Component` logic class. Real working generator/solver code, not pseudocode. |
| `support.js` | Runtime the DC needs (`<script src="./support.js">`). Don't edit. |
| `NUMLINK_SPEC.md` | Build spec: concept, generation algorithm, juice, roadmap/build-order, known simplifications. |
| `design_handoff_numlink/README.md` | Developer handoff: screens, tokens, interactions, state shape, assets — for porting to a production stack. |
| `NUMLINK Screens.dc.html` + `NUMLINK Card.dc.html` | Visual inventory: every screen/overlay mounted live side-by-side (see §8). |

---

## 3. Core loop & rules

- **Operators**: `× + − ÷ % Σ` (Σ unary — digit-sum, ignores its tile's number). Standard tier also deals `↺` (digit-reverse), `x²` (square), `⧺` (concat-digit); Expert adds `√` (perfect-square-only).
- A move is rejected (tile shake/flash + toast, board unchanged) if: its tile has no tokens left, the arm is at `branchMax` depth, the result isn't a positive integer ≤999, `÷` doesn't divide evenly, the result equals the current value, the result is already on the board, or the move would **strand** a target.
- **Stranding guard**: after a hypothetical move, a real solver checks every remaining target is still reachable from some live node with tokens left in hand (checked against current hand first, then every hand still in the deck if shuffles remain — a hand a future shuffle could rescue never blocks play).
- **Token economy**: tokens tracked by **signature** (`kind+operand`, e.g. `×9`; `u`-prefixed for unary), not per-hand tile id — so Shuffle dealing fresh tile ids can't refund spent tokens.
- **Tutorial mode**: `depthEnforced()` / `strandingGuarded()` / `tokensEnforced()` are three independent switches, all disabled during the guided first puzzle (not a single shared flag).

---

## 4. Board generation & solver

Solution-first — every board is provably solvable:
1. Seeded RNG (`rng(seed)`) — Daily/Co-op boards share one fixed seed.
2. Tier config (`TIERS.sprouts/junior/easy/medium/hard`) sets target count, branch depth, shuffle count, number pool, operator set.
3. `buildPuzzle(tier, seed)` grows a random legal tree from a random start + hand (`makeHand`).
4. Pick deep-enough nodes as targets, spread across arms where possible.
5. Prune to the minimal subtree connecting start → all targets — that pruned tree *is* the solution.
6. Generate verified alternate hands for Shuffle (kept only if the solver proves they can still finish the board).
7. Falls back to a fixed deterministic puzzle after 160 failed attempts.

**True par**: `steinerSolve(start, targets, ops, branchMax)` — a depth-bounded directed-Steiner-tree bitmask DP (root = start, ≤5 targets), restricted to the dealt hand's operators, cross-checked against real token counts (`validateHandCovers`) and the no-repeated-value rule (`edgesFormUniqueTree`). `par = trueOptimum + flat 2-move slack`. Falls back to the constructed solution's real move count if the DP tree isn't buildable.

**Same solver family drives**:
- `solveFrom` / `armTo` — permutation search over outstanding targets, memoized by (target, board-state, tokens-left); powers Hint and the stranding guard.
- `steinerSolve`'s choice table reconstructs the actual optimal tree for Solution Reveal (walked start-outward, real operator labels).

**Self-check**: `runSelfCheck(n=200)`, gated behind `window.__NUMLINK_SELFCHECK__`, validates `n` boards per tier (par ≥ optimum, full reachability, no invalid values, no fallback overuse).

---

## 5. Progression

- **XP**: `10 + 5×(par − moves under par)`; flat 10 in Zen. Campaign mode adds a star bonus weighted by tier (Sprouts/Junior/Easy ×1, Medium ×1.5, Hard ×2) via `xpGain(moves)`.
- **Stars**: `starsFor(moves)` — par or better = 3★, +1 = 2★, +2+ = 1★.
- **Level curve**: triangular — `xpForLevel(L) = 25·L·(L−1)`, inverted by `levelForXp(xp)`.
- **Streak**: Daily wins only; a freeze every 5-day streak.
- **Golf handicap**: best 8 of last 20 (moves − par) differentials × 0.9, plus a personal course record and per-operator mastery counts — all computed in `recordWin(moves)`.
- **Titles**: five unlock **deterministically** off real medal flags (Digit Alchemist, Token Miser, Hole-in-One, first-link/birdie/purist/streak/climber) — no randomness. Win sheet states the plain-language criterion.
- Persisted to `localStorage` key `numlink_stats2`.

---

## 6. Screens / overlay routing

One `overlay` state field drives every sheet/full-screen page; `started` gates the home hub; `booting` gates the boot splash.

| Screen | `overlay` value | Notes |
|---|---|---|
| Boot splash | — (`booting: true`) | Wordmark only, no loading icon/animation. |
| Home hub | — (`started: false`) | Greeting, streak card, week strip, Game modes card, Campaign card, Daily CTA. |
| Puzzle board | `null` (`started: true`) | Header (back, title, Shuffle/Hint/⋯ icon buttons) → status bar → radial board → operator pad. Fixed 4-zone layout. |
| Overflow menu | `menu` | Restart, settings, etc. — no separate on-screen Reset button. |
| Win sheet | `win` | Score label, star row (campaign), title-unlock banner, board-character tag, XP pill, share actions. |
| Game modes | `roadmap` | Daily, Archive, Weekend Co-op cards (Campaign lives on its own home-hub entry). |
| Campaign map | `camp` | Cartoon board-game trail, chapter bands, 5-point stars. |
| Statistics | `stats` | Histogram, handicap, course record, op-mastery chips, medal chips. |
| Notifications | `notifications` | One real unread ritual push/day; rest are read-only log entries. |
| How to play | `how` | — |
| Settings | `moreSettings` | Theme, high-contrast, sound, haptics, reduce motion, social nudges. |
| Profile | `profile` | Name edit, avatar, purchases (mock). |
| Info sheet | `info` | Generic detail sheet (Help/About/Privacy/etc). |
| Archive | `archive` | Calendar colored from real result history (last 20 sessions). |
| Solution reveal | `solution` | DP-reconstructed optimal tree. |
| Leaderboard | `leaderboard` | Week/All-time/Today's-par tabs, podium. |
| Weekend Co-op board | `null`, `mode:'coop'` | Shared fixed board pre-seeded with mock teammate moves. |

A `forceScreen` prop (debug-only, not surfaced as a Tweak) can force any of the above for previewing — see §8.

---

## 7. State shape (`Component` class)

```
nodes: {id, v, parent, opId, opSig, opLabel}[]   // the tree; opSig drives token accounting
hand, shufflesLeft, sel, zoom/panX/panY/manual    // active hand index, camera
mode: daily|campaign|practice|zen|timed|archive|coop, levelNo, puzzle, ramp
overlay, started, booting, intro/introIndex, tutorial
theme, cb (high-contrast), sound/haptics/reduceMotion/socialNudges
hintGlow, hintsUsed, resets, shake
stats: {played, wins, streak, maxStreak, freezes, xp, dist, history,
        handicap, record, opMastery, titles, equippedTitle,
        hasBirdie/hasPurist/hasHoleInOne/hasTokenMiser/hasDigitAlchemist}
```

**Puzzle definition**: `{tier, start, targets, hands, shuffles, branchMax, par, optimalPar, optimalEdges}` — produced by `buildPuzzle`. `DAILY` and `COOP` boards are hardcoded precomputed literals (same generator, run once) so boot never re-runs generation or the Steiner DP.

### Key methods by concern
- **Generation/solving**: `rng`, `makeHand`, `buildPuzzle`, `steinerSolve`, `steinerOptimum`, `validateHandCovers`, `edgesFormUniqueTree`, `solveFrom`, `armTo`, `permute`, `runSelfCheck`.
- **Play**: `compute`, `opLabel`, `sig`, `apply`, `usedMap`, `select`, `shuffleHand`, `hint`, `stranded`, `depthOf`, `hitTargets`.
- **Board camera**: `layout` (radial: start centered, children fan by angle, depth → ring radius), `ringGapFor`, `autoFit`, `effZoom`, `effPan`, `boardRef`.
- **Feedback**: `flash`, `shakeOp`, `actx`/`tone`/`playTapTone`/`playAlchemyTone`/`playWinChime`, `buzz`.
- **Progression**: `recordWin`, `tickXp`, `xpGain`, `starsFor`, `xpForLevel`, `levelForXp`.
- **Navigation**: `startPuzzle`, `retry`, `playDaily`, `startTimed`, `pickPractice`, `pickZen`, `startLevel`, `startCoop`, `reset`, `toggleTheme`, `open`/`close`.

---

## 8. Screens gallery

`NUMLINK Screens.dc.html` mounts `NUMLINK Card.dc.html` (which mounts the real `NUMLINK` component, scaled into a 260×490 card) once per screen, using the debug-only `force-screen` prop — every card is the live component, not a screenshot. Grouped: Onboarding & Home, Core Game, Menus & Settings, Progression & Social (17 states total).

---

## 9. Visual system

- **Fonts**: Baloo 2 (display: wordmark, greetings, titles, score labels, numerals) + Nunito (body/UI/all changing numbers, `font-variant-numeric: tabular-nums`).
- **Palette**: warm cream light / plum dark (`data-theme`). Accent rose `--accent`, teal `--success`, indigo `--hero`/`--hero-2`, amber `--progress`. Success hue switchable Teal↔Coral (`data-success="orange"`).
- **Light tokens**: bg `#f4ecdf`, surface `#fbf6ec`, elevated `#ffffff`, text `#2b2622`, muted `#6f6458`, border `#e7ddcb`, success `#237e72`, progress `#efa42f`, accent `#ec6a8d`, hero `#6b61e6`/`#a99ff5`, star `#f5c748`.
- **Dark tokens**: bg `#241f27`, surface `#2e2830`, elevated `#38313f`, text `#f1eae1`, muted `#a99fa6`, border `#463e4b`, success `#46bbaa`, progress `#f5b843`, accent `#f27fa1`, hero `#7d74f2`/`#b3aaf7`, star `#f7cd58`.
- **High-contrast mode** (default on): Okabe–Ito-safe cues + text labels, never color alone.
- **Radius**: icon buttons 16px, cards 22–30px, board nodes ~26px, operator tiles 14px, sheets 34px (top only), pills 999px. **Borders**: 2px throughout.
- **Operator tiles**: 50px min-height (tightened from an earlier 68px pass).
- **Motion**: 120/260/480ms, ease-out default, overshoot spring for pop-ins/sheets, continuous glow/scale twinkle for campaign stars. Respects both in-app Reduce Motion and OS `prefers-reduced-motion`; illegal-move feedback always shows a static accent flash even with motion off (shake itself is gated).

---

## 10. Component props (Tweaks)

| Prop | Type | Default | Effect |
|---|---|---|---|
| `defaultTheme` | enum dark/light | dark | initial theme |
| `highContrastDefault` | boolean | true | high-contrast cues on/off |
| `successHue` | enum Teal/Coral | Teal | success accent color |
| `startTutorial` | boolean | false | launch straight into the intro carousel |
| `launchOnHome` | boolean | false | show home hub instead of jumping into a puzzle |
| `debugTier` | enum none/sprouts/junior/easy/medium/hard | none | preview a difficulty tier directly, skipping Home |
| `forceScreen` | string (debug, not a Tweak) | — | force a specific screen/overlay; used only by the screens gallery |

---

## 11. Known simplifications / roadmap status

All nine roadmap phases (core-loop juice, true-par Steiner DP + handicap, variable rewards + leaderboards, difficulty tiers + new operators, archive heatmap, DP-powered solution reveal, share-card par line, notification throttling, weekend co-op) are built at **prototype scope**. Remaining simplifications:
- Leaderboard, notifications, avatars, and most achievements beyond the five real medals are static mock data.
- No adaptive difficulty by design — everyone gets the same board per tier, so par and share cards stay honest.
- Weekend Co-op is a shared-board interaction demo, not live multiplayer (no real-time sync or day-of-week gating).

Full design detail (screen-by-screen copy, exact interaction rules, asset notes) lives in `design_handoff_numlink/README.md`; algorithmic/build-order detail lives in `NUMLINK_SPEC.md`. This file is the merged index of both plus the code map above.
