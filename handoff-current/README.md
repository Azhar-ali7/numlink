# Handoff: NUMLINK — Branching Number-Chain Puzzle

## Overview
NUMLINK is a puzzle game built around one core loop: starting from a **start number**, tap a node then an operator tile to grow a **branching tree** outward, until every one of 2–5 **target numbers** exists somewhere in the tree. There is no single required path or order — any existing node can branch, up to a per-arm depth cap. Moves are scored against a provably-achievable **par**, golf-style (Eagle/Birdie/Par/Bogey/Double bogey). Around that loop sits a progression layer: a home hub, a cartoon **campaign map** of star-rated levels, extra modes (Daily, Practice, Zen, Timed, Archive, Weekend Co-op), XP & levels, signature medals, a leaderboard, and settings/accessibility controls. This bundle contains a working HTML prototype of the full UI and play loop.

## About the Design Files
`NUMLINK.dc.html` is a **design reference created in HTML** — a working prototype showing intended look, logic, and behavior, **not production code to copy directly**. It is authored in a proprietary "Design Component" streaming format (an HTML template + a `Component` logic class) that runs in a specific sandbox; do not attempt to ship it as-is.

The task is to **recreate this design in the target codebase's existing environment** (React, Vue, SwiftUI, native, etc.) using its established patterns, component library, and state management — or, if no codebase exists yet, choose an appropriate framework (React + TypeScript is a good default for this kind of interactive puzzle) and implement it there. The generator/solver logic (board generation, the Steiner-tree par calculation, the stranding guard) is real, working algorithmic code in the prototype — port its *logic*, not its exact JS shape, into whatever language/runtime the target stack uses.

## Fidelity
**High-fidelity.** Final colors, typography, spacing, motion, and interactions are all specified below and are live/working in the prototype (not static mockups). Recreate the UI pixel-accurately using the target codebase's libraries; exact tokens are listed under **Design Tokens**.

## Aesthetic
Playful, rounded, "friendly game" look — a warm cream light theme (plum-dark alternative via a theme toggle), saturated accent bands (rose / indigo / amber / teal), chunky rounded cards, a heavy display face for numbers and headings. The puzzle board itself stays calm and legible (a plain background, radial layout); the surrounding hub/campaign/settings screens are bright and characterful. The campaign map specifically adopts a cartoon "board-game trail" style (chunky bordered nodes, a bezier path, star rows, a bouncing current-level marker) but uses the app's own token palette, not literal reference colors. All state colors are colorblind-safe (Okabe–Ito) and always paired with a shape or text label — a **High-contrast mode** (on by default) enforces this everywhere.

## Screens / Views

### 1. Home hub (entry)
Scrolling overlay shown until the player enters a puzzle. Top to bottom:
- **Greeting row**: "Hi {playerName}" (Baloo 2 800, 28px) + date; a notification bell (badge count, rings when unread) and settings/profile affordance.
- **Streak card**: flame icon, "This week" streak summary, a Stats chip.
- **Week strip**: 7 day chips (Mon–Sun), each showing a checkmark/star mark for solved days, today highlighted.
- **Game modes card**: icon tile (mode-select glyph), eyebrow "EXPLORE · {n} MODES", title "Game modes", subtitle "Daily · Archive · Co-op", chevron — opens the mode roadmap. (Campaign is **not** listed here; it has its own card, see below.)
- **Campaign card**: icon tile (a 3-node trail glyph, matching the campaign map's own visual language), eyebrow "STORY MODE", title "Campaign", subtitle "Levels · easy to hard", chevron — opens the campaign map directly.
- **Daily puzzle CTA**, level/XP ring, and quick actions to start play.

### 2. Puzzle screen (main game)
Fixed max-width **440px** column, full-height, 2px left/right borders. Four fixed zones stacked vertically, with only the board flexing:
- **Header** (`padding:14px 16px`): **Back** (←) 38×38 icon button, center **mode title** (e.g. "DAILY", "LEVEL 3") + subtitle, then three 38×38 icon buttons: **Shuffle** (with a shuffles-left badge), **Hint** (with a hints-left badge), **Overflow (⋯)** (restart, settings, etc. live here — there is no separate on-screen Reset button).
- **Status bar**: `{reached}/{total} TARGETS` on the left; `{moves}/{par}` with a budget label ("N left on this arm" / "arm full") on the right.
- **Board** (flexes, scrollable/pannable, plain background): a **radial tree layout** — the start node sits centered, children fan outward by angle with depth encoded as ring radius. Nodes: filled circle for placed numbers (start ring tinted `--hero`, others `--surface`), dashed ghost pills for unreached targets (gently "breathing" pulse), animated SVG path edges between parent/child, with a distinct pop + hue-shift animation for digit-alchemy ops (Σ, ↺, x², √) vs a plain spring pop-in for arithmetic ops. Pinch/scroll to zoom, drag to pan, double-tap/double-click to re-fit. A brief zoom hint shows on first load.
- **Operator pad** (footer, 3-column grid, gap 8px): tiles are **50px min-height** (deliberately tightened from an earlier 68px pass), 2px border, radius 14px, `--elevated`-tinted background per operator hue; each shows the op label (e.g. "×9", "Σ") and a token-count badge. Disabled state at 0 tokens (42% opacity). An illegal tap always gets a toast + a brief accent-tinted border/background flash on the tile — the flash alone (no shake motion) is the sole cue when Reduce Motion is on; otherwise a 340ms shake plays too.

### 3. Win sheet
Bottom sheet with a confetti burst. Kicker "CHAIN COMPLETE", score label ("Eagle!"/"Birdie!"/"Par!"/"+2"), moves vs. par line. Shows a campaign star row (1–3★) in campaign mode, a "New title unlocked" banner (with the title's plain-language unlock criteria) when a signature medal fires, a board-character read (Alchemist/Minimalist/Sprawl/Balanced), an animated **+XP · Level** pill, a spoiler-free share preview, Share/Copy and Next-level/Play-again actions.

### 4. Game modes (roadmap)
Full-screen overlay. Header with a "{n} Modes" summary. Mode cards: **Daily Puzzle, The Archive, Weekend Co-op** (Campaign has moved to its own home-hub entry point and roadmap card, see Screen 1 and 5).

### 5. Campaign map
Full-screen cartoon "board-game trail" screen, oriented with **Level 1 at the top** so progress is visible the instant it opens. A bezier path winds down through chunky bordered circular level nodes (locked = 🔒 + dimmed, current = number + bouncing animation + rotating halo ring, cleared = number + star row above it). Levels are grouped into **chapter bands** by tier (FOUNDATIONS / ADVANCED / EXPERT), with faded operator glyphs (×, ÷, +, Σ, %, −) scattered as background texture. Stars are true 5-point (★/☆), sized ~20px, colored amber/pink/purple, staggered pop-in plus a continuous glow/scale twinkle. Tapping the current level's node opens the puzzle screen; boss/unlock levels show a flag marker.

### 6. Leaderboard
Full-screen overlay, "This Week / All-time / Today's par" tabs, a top-3 podium, the rest of the roster below, a "Today's par" tab ranking friends by score-relative-to-par on the daily board. (Reachable from the Statistics/roadmap flow — no longer surfaced as a home-hub preview card, which now shows Campaign instead.)

### 7. Statistics
Bottom sheet. Played/Win%/Streak/Best stat cells, a moves-vs-par histogram, golf handicap (best-8-of-last-20 differential × 0.9) and personal course record, per-operator mastery chips, signature-medal chips, and a streak-freeze status row.

### 8. Notifications
Bottom sheet/list. Exactly one **live, unread** push per day (the daily-board-ready ritual notification, neutral copy — no "beat par to protect your streak" pressure framing); a real streak-summary entry that only appears once the player actually has a streak, showing the true streak length (not a hardcoded sample number); everything else (badge unlocks, double-XP windows) is a read-only log entry. A "friend passed you" competitive nudge is gated behind an opt-in **Social nudges** Settings toggle, off by default.

### 9. How to play, Settings, Archive, Solution reveal, Overflow menu, Intro carousel
Standard bottom-sheet/overlay treatments consistent with the rest of the app. Settings includes Dark/Light, High-contrast cues, Sound, Haptics, Reduce motion, and Social nudges toggles. Archive is a calendar of past daily boards, colored from real result history where available. Solution reveal shows the Steiner-DP's actual optimal tree, walked start-outward with real operator labels.

## Interactions & Behavior
- **Apply an operator**: computes the result and, if legal, appends it as a new child of the selected node. A move is rejected up front (tile shake/flash + toast, board unchanged) if: the tile has no tokens left *for its own signature* (see Token economy below), the arm is at its per-move depth cap, the result isn't a positive integer ≤999, `÷` doesn't divide evenly, the result equals the current value, the result is already on the board, or the move would **strand** a target — checked by a real solver, not a heuristic guess (see Stranding guard below).
- **Token economy**: tokens are tracked by **operator signature** (`kind+operand`, e.g. `×9`, or a `u`-prefixed key for unary ops like `Σ`), not by the tile's per-hand id. This matters because Shuffle deals a fresh hand with newly-generated tile ids — keying by id would let Shuffle silently refund every spent token. A tile's remaining count = its current hand's token count minus the running total ever spent under that signature.
- **Stranding guard**: after a hypothetical move, a real depth-aware solver (full permutation search over the outstanding targets, not a fixed sample of orderings, and never revisiting a value already on the board) checks whether every remaining target is still reachable from some live node using the current hand's remaining tokens. If the current hand can't finish it but shuffles remain, the guard checks every hand still in the deck before blocking the move — a hand a future shuffle could rescue never blocks play.
- **Shuffle**: verifies the *incoming* hand against the **live tree** (not just the bare starting number) before dealing it; tries each remaining alternate in turn, and if none keep the board solvable, keeps the current hand and says so rather than claiming an unverified "still solvable."
- **Hint** (one per puzzle): glows the tile that gets nearest an outstanding target.
- **Par / solver**: boards are generated solution-first (grow a random legal tree, prune to the minimal subtree spanning the chosen targets — that pruned tree *is* the constructed solution). True par is then computed by a depth-bounded directed-Steiner-tree DP, restricted to the operators in the **dealt hand only** (not shuffle alternates the player may never draw) and capped at the board's own per-arm depth limit, then cross-checked against that hand's real token counts and the board's no-repeated-value rule; if the DP's tree isn't actually buildable, par falls back to the constructed solution's real move count. `par = trueOptimum + a flat 2-move slack`, so Eagle through Double-bogey are all reachable on every tier, including Hard.
- **XP**: `10 + 5×(par − moves under par)`, flat 10 in Zen — every finish pays at least a base 10 XP regardless of score, which the win sheet should make clear rather than implying worse scores pay less. In campaign mode a star bonus is added, weighted by tier (Sprouts/Junior/Easy ×1, Medium ×1.5, Hard ×2) so a 3-star clear on Hard is worth more than on Sprouts.
- **Cosmetic titles**: five titles unlock deterministically off real medal criteria (no randomness) — the win sheet's "New title unlocked" banner also states the plain-language criterion that earned it.
- **Reduced motion**: a Settings toggle (plus the OS-level `prefers-reduced-motion` query) disables spring pop-ins, pulses, and the shake animation; illegal-move feedback falls back to a static tinted border/background flash so the cue survives even with motion off.

## State Management
- `nodes: {id, v, parent, opId, opSig, opLabel}[]` — the full tree, starting `[{v: start}]`. `opSig` (the operator signature) is what token accounting keys off; `opId`/`opLabel` are per-hand-tile bookkeeping/display only.
- `hand: number` (index into the puzzle's dealt hands), `shufflesLeft`, `sel` (selected node id), `zoom`/`panX`/`panY`/`manual` (board camera).
- `mode: 'daily'|'campaign'|'practice'|'zen'|'timed'|'archive'|'coop'`, `levelNo`, `puzzle` (active board definition), `ramp` (campaign/practice difficulty drift).
- `overlay` drives every sheet/full-screen page (`menu|win|roadmap|stats|how|settings|archive|solution|leaderboard|notifications|null`); `started` gates the home hub; `intro`/`introIndex` for the first-run carousel; `tutorial` for the guided first puzzle.
- `theme`, `cb` (high-contrast), `sound`/`haptics`/`reduceMotion`/`socialNudges` toggles, `hintGlow`, `hintsUsed`, `resets`, `shake` (op id being flashed).
- `stats: {played, wins, streak, maxStreak, freezes, xp, dist, history, handicap, record, opMastery, titles, equippedTitle, hasBirdie/hasPurist/hasHoleInOne/hasTokenMiser/hasDigitAlchemist}` — persisted to `localStorage` key `numlink_stats2`.
- **Puzzle definition** (`{tier, start, targets, hands, shuffles, branchMax, par, optimalPar, optimalEdges}`) is produced by the generator/solver described above. The Daily and Weekend Co-op boards are precomputed/hardcoded (same generator, run once) so app boot never re-runs the generator or the Steiner DP.

## Design Tokens

**Colors — light (default)**
- bg `#f4ecdf`, surface `#fbf6ec`, elevated `#ffffff`, text `#2b2622`, muted `#6f6458`, border `#e7ddcb`
- success `#237e72` (teal), progress `#efa42f` (amber), amber-ink `#9a5f12`, accent `#ec6a8d` (rose)
- hero `#6b61e6` (indigo), hero-2 `#a99ff5`, tile-orange `#ef8f4c`, nav `#211f38`, star `#f5c748`
- shadow `0 12px 26px rgba(74,54,32,0.12)`

**Colors — dark**
- bg `#241f27`, surface `#2e2830`, elevated `#38313f`, text `#f1eae1`, muted `#a99fa6`, border `#463e4b`
- success `#46bbaa`, progress `#f5b843`, amber-ink `#f5b843`, accent `#f27fa1`
- hero `#7d74f2`, hero-2 `#b3aaf7`, tile-orange `#f0a05e`, nav `#17162a`, star `#f7cd58`
- shadow `0 12px 26px rgba(0,0,0,0.38)`

**Alt success hue** (Coral option, `data-success="orange"`): `#ee7a4f`.
State colors follow the colorblind-safe **Okabe–Ito** palette and are **always paired with a shape or text label**, never color alone (High-contrast mode, on by default, enforces this).

**Typography**
- Display: **Baloo 2** 500/600/700/800 (wordmark, greetings, sheet titles, score labels, big numerals).
- UI / body / numeric: **Nunito** 400/600/700/800/900 (labels, buttons, body, and all changing numbers — paired with `font-variant-numeric: tabular-nums`).

**Radius**: icon buttons 16px, cards 22–30px, board nodes ~26px, operator tiles 14px, sheets 34px (top only), pills/toggles 999px.
**Borders**: 2px throughout. **Spacing**: 16–20px screen padding, 8–12px control gaps. Operator tiles are 50px min-height (tightened from an earlier 68px pass to match the app's tighter visual scale).
**Motion**: 120 / 260 / 480ms; ease-out `cubic-bezier(0.4,0,0.2,1)` default; overshoot spring for pop-ins and sheet entrances; `glow` for hints; a continuous glow/scale twinkle for campaign stars. All motion respects both the in-app Reduce Motion toggle and the OS `prefers-reduced-motion` query.
**Scrim**: `color-mix(in srgb, #000 55%, transparent)` for sheets, `30%` for the overflow menu.

## Assets
- **Fonts**: Baloo 2, Nunito — Google Fonts (`display=swap`).
- **Icons**: inline SVG, 2px stroke (back arrow, shuffle, hint/lightbulb, overflow dots, bell, chevrons, etc.). No icon library dependency. The home hub's Campaign card icon and the campaign map's own node styling share one visual language (a simple 3-node trail glyph) rather than a literal map emoji.
- **Emoji** used as decorative glyphs (🎯 🗂️ 🤝 🔥 🛡 🎖 🔒 ★ ☆ ✦-style sparkles are now true 5-point ★/☆) and in the spoiler-free share grid (🟦/🟧 blocks) — system emoji, no custom icon needed.
- No raster images required by the design (the boot splash previously used a mascot icon image; it has since been simplified to wordmark-only, so no image asset is needed there either).

## Files
- `NUMLINK.dc.html` — the full prototype (home hub, radial-tree puzzle board with shuffle/hint/stranding-guard logic, win sheet, game modes, campaign map, leaderboard, stats, notifications, settings, archive, solution reveal, intro carousel, weekend co-op). Open in a browser to interact; read the `Component` class for the exact generator/solver/token-economy logic — it is real working code, not pseudocode.
- `support.js` — runtime required by the prototype (loaded via `<script src="./support.js">`).
