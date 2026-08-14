# Handoff: NUMLINK — Daily Number-Chain Puzzle

## Overview
NUMLINK is a daily puzzle game (Wordle-style: one shared puzzle per day for all players). The player transforms a **start number** into a **target number** by chaining arithmetic operations (`×3`, `+7`, `÷2`…), each with a limited number of uses ("tokens"). Fewer moves is better — scored against **par** with golf language (Birdie / Par / Bogey). This bundle contains a working HTML prototype of the full UI and play loop.

## About the Design Files
`NUMLINK.dc.html` is a **design reference created in HTML** — a prototype showing intended look and behavior, **not production code to copy directly**. It is authored in a proprietary "Design Component" streaming format (a template + a `Component` logic class) that runs in a specific sandbox; do not attempt to ship it as-is.

The task is to **recreate this design in the target codebase's existing environment** (React, Vue, SwiftUI, native, etc.) using its established patterns, component library, and state management — or, if no codebase exists yet, choose an appropriate framework (React + TypeScript is a good default for this kind of interactive puzzle) and implement it there.

## Fidelity
**High-fidelity.** Final colors, typography, spacing, motion, and interactions are all specified below. Recreate the UI pixel-accurately using the target codebase's libraries; the exact tokens are listed under **Design Tokens**.

## Screens / Views

### 1. Welcome screen (entry)
- **Purpose**: Branded landing before play; shows the daily's identity and the player's streak, launches the puzzle.
- **Layout**: Full-container overlay (`position:absolute; inset:0`), opaque background, `padding: 0 28px`, flex column. A vertically-centered content block (gap 26px) over a bottom button group (`padding-bottom: 32px`, gap 12px).
- **Components**:
  - **Mini chain preview**: centered — a `start` node (surface fill, 2px border) → 2px connector → dashed `?` pill → connector → a `target` node (success-colored border + 12% success tint fill). Numbers in mono, 34px/700.
  - **Wordmark** "NUMLINK": Fraunces 700, 64px, letter-spacing −1.5px, line-height 0.92, color `--text`.
  - **Tagline**: Space Grotesk 16px, `--muted`, max-width 300px.
  - **Two stat cards** (flex row, gap 10px): "DAY STREAK" (mono 24px, `--success`) and "#128 / AUG 8 2026" (mono 24px, `--text`). 2px border, radius 14px, padding 12×14.
  - **Primary button** "Play today's puzzle": full width, `--success` fill, white text, Space Grotesk 700 17px, radius 14px, padding 18px, **center-aligned** text.
  - **Secondary button** "How to play": transparent, 2px `--border`, radius 14px, padding 14px; hover border → `--success`.
- **Enter animation**: `fadeInWelcome` 300ms ease-out; preview block `popIn` 320ms `cubic-bezier(0.34,1.4,0.64,1)`.

### 2. Puzzle screen (main game)
- **Purpose**: The core play loop.
- **Layout**: Fixed max-width **440px** column, full-height, 2px left/right borders. Vertical stack: header → target/stats bar → scrollable chain area (flex:1) → operation pad (footer).
- **Header** (`padding: 18px 20px 14px`, 2px bottom border): wordmark "NUMLINK" (Fraunces 700 26px) + subline "#128 · AUG 8 2026" (Space Mono 11px `--muted`); right side three 40×40 icon buttons (radius 12px, 2px border, hover border `--success`) — How-to (?), Stats (bars), Settings (sliders). Icons are **Lucide** (help-circle, bar-chart-2, sliders).
- **Target / stats bar** (`padding: 16px 20px`, 2px bottom border, gap 12px):
  - "GET TO" label (Space Grotesk 11px/700, letter-spacing 2px, `--muted`) + target number (Space Mono 700 **52px**, `--success`, `tabular-nums`).
  - Two stat cells "MOVES" and "PAR" (mono 22px, 2px border, radius 12px).
  - **Proximity heat bar**: 8px tall, 2px border, radius 999px; fill width = `100 * (1 - dist/initialDist)`%, min 6%; fill color = `--success` when solved, `--progress` when within 3 of target, else `--muted`; `transition: width 260ms cubic-bezier(0.4,0,0.2,1)`. Caption "N away from target" in the heat color.
- **Chain area** (scrollable, `padding: 22px 20px 12px`, centered column): for each node —
  - Optional **edge** above (nodes after the first): 2px×12px connector, an **operation chip** (mono 13px/700, 2px border, `--elevated` fill, radius 999px, e.g. "×3"), another connector.
  - **Node**: min-width 132px, 2px border, radius 18px, padding 12×26; number mono 700 **40px** `tabular-nums`; optional badge below (Space Grotesk 10px/700, letter-spacing 1.5px). `popIn` 240ms `cubic-bezier(0.34,1.4,0.64,1)` on mount.
  - Node states: **start** = `--border`, badge "START", `--text` number, transparent bg. **intermediate** = `--border`, no badge, `--muted` number, `--surface` bg. **current (last, unsolved)** = `--progress` border, badge "YOU ARE HERE" (only when high-contrast on), `--text` number, 12% progress tint bg. **solved (last)** = `--success` border, badge "TARGET · SOLVED ✓", `--success` number, 14% success tint bg.
  - **Target placeholder** (only while unsolved): dashed `?` pill + dashed `--muted` target node labeled "TARGET". **On solve this disappears** — the final chain node becomes the target (merge behavior).
- **Operation pad** (footer, 2px top border, `padding: 14px 20px 18px`):
  - 3-column grid (gap 10px) of **operation buttons**: `--surface` bg, 2px border, radius 14px, padding 11×14, hover border `--progress`. Content: op label (mono 700 23px, e.g. "×3"), preview line (mono 12px `--muted`, "→ 6" or "—" if illegal), and a **token pill** top-right (mono 11px/700) reading "2×" — `--text` normally, `--progress` at 1 left, `--muted` at 0. Disabled (opacity 0.38) when solved, result illegal, or 0 tokens left. Illegal tap → `shake` 340ms + toast.
  - Below: three text buttons UNDO / RESET / STATS (flex row, gap 10px, transparent, 2px border, mono-ish Space Grotesk 700 12px letter-spacing 1px, radius 12px, **left-aligned** text, hover border `--text`).

### 3. Win sheet
- Bottom sheet (`animation: sheetUp 280ms cubic-bezier(0.34,1.2,0.64,1)`), `--elevated` bg, top corners radius 24px, 2px top border, `padding: 24px 24px 28px`, over a 55%-black scrim.
- Kicker "CHAIN COMPLETE" (`--success`), title "Solved!" (Fraunces 700 38px), subline "N moves · par 3 · <verdict>" (mono 14px `--muted`). Close (X) icon button top-right.
- **Share preview** `<pre>` block (mono 15px, `--surface` bg, 2px border, radius 14px) showing the spoiler-free text grid.
- Primary "Share result" button (`--success` fill) → copies to clipboard, label flips to "Copied to clipboard" for 1.8s. Two secondary buttons: "View stats", "Play again".

### 4. Statistics
- Same bottom-sheet chrome. Title "Statistics" (Fraunces 700 28px).
- **4 stat cells**: PLAYED, WIN %, STREAK (`--success`), BEST (mono 28px each).
- **"MOVES vs PAR" histogram**: rows PAR / +1 / +2 / +3+ — label (mono 13px, 40px wide) + bar (26px tall, `--surface` track, radius 6px) filled to `count/max`% with count at the right end (white mono 12px). The bucket matching the just-finished game is `--success`, others `--muted`.
- "Share result" button at the bottom.

### 5. How to play
- Bottom sheet. Title "How to play" (Fraunces 700 28px), intro paragraph, then 4 numbered steps (mono numeral in `--success` + Space Grotesk 14px body). "Got it" primary button.

### 6. Settings
- Bottom sheet. Title "Settings" (Fraunces 700 28px). Rows separated by 2px borders:
  - **Appearance**: segmented Dark / Light control (2px border, radius 12px; active label `--success`, inactive `--muted`).
  - **High-contrast cues**: pill toggle (52×30, radius 999px; track `--success` when on / `--border` when off; 24px white knob slides left 3px→25px, `transition: left 160ms cubic-bezier(0.4,0,0.2,1)`).
  - Footer note about Okabe–Ito palette + shape/label pairing.

## Interactions & Behavior
- **Apply op**: appends `{value, opLabel}` to the chain, decrements that op's token, checks solve (`result === target`). Illegal (non-integer, out of range 0–999, or 0 tokens) → toast + 340ms shake, no state change.
- **Undo**: pops the last node and refunds its op token. Disabled once solved.
- **Reset**: restores chain to `[start]`, clears tokens and solved flag.
- **Solve**: records stats, opens Win sheet, merges target node into the final chain node.
- **Navigation**: header/welcome buttons set an `overlay` value (`how|stats|settings|win`); overlays render at **z-index 50** (above the z-40 welcome screen). Close returns to whatever is beneath.
- **Motion budget** (from research): 120ms micro / 260ms standard / 480ms celebrate; ease-out `cubic-bezier(0.4,0,0.2,1)` default, gentle overshoot spring only for node pop-in and sheet entrances. **All animations disabled under `prefers-reduced-motion: reduce`.**
- **Share text** (spoiler-free): `NUMLINK #128\n{moves} moves · par {par}\n` + `🟦`×min(moves,par) + `🟧`×max(0,moves−par) + ` 🎯` if solved.

## State Management
- `chain: {value, opLabel}[]` — starts `[{value: START}]`.
- `used: {[opId]: number}` — token consumption per op.
- `solved: bool`, `started: bool` (welcome dismissed), `overlay: 'how'|'stats'|'settings'|'win'|null`.
- `theme: 'dark'|'light'`, `cb: bool` (high-contrast), `copied: bool`, transient `message` (toast) and `shake` (op id).
- `stats: {played, wins, streak, maxStreak, dist: {par, '+1', '+2', '+3+'}}` — **persisted to `localStorage` key `numlink_stats`**; seeded with demo values on first run.
- **Puzzle definition** is currently hardcoded: `START=2, TARGET=26, PAR=3, PUZZLE=128`, six ops with token caps `{×3:2, +7:2, ×2:3, −1:3, ÷2:2, +5:2}`. Par-3 solution: `2 ×3→6 +7→13 ×2→26`. **Production TODO**: generate the daily puzzle server-side (BFS over the op set to guarantee solvability and honest par; ramp difficulty Mon→Sun).

## Design Tokens

**Colors — dark (default)**
- bg `#121213`, surface `#1e1e1e`, elevated `#272727`, text `#d7dadc`, muted `#818488`, border `#3a3a3c`
- success (state/primary) `#4c9fd6`, progress (near/current) `#e0a83a`

**Colors — light**
- bg `#ffffff`, surface `#f6f7f8`, elevated `#eef0f2`, text `#1a1a1b`, muted `#787c7e`, border `#d3d6da`
- success `#0072B2`, progress `#c77f00`

**Alt success hue** (colorblind option): orange `#f5793a`.
State colors follow the colorblind-safe **Okabe–Ito** palette and are **always paired with a shape or text label**, never color alone.

**Typography**
- Display: **Fraunces** 400/700 (wordmark, sheet titles, "Solved!")
- UI: **Space Grotesk** 400/500/700 (labels, buttons, body)
- Numeric: **Space Mono** 400/700 — all changing numbers, with `font-variant-numeric: tabular-nums` so digits don't jitter.
- Key sizes: hero target 52px, node numbers 40px, sheet titles 28–38px, wordmark 26px (header) / 64px (welcome).

**Radius**: buttons/cards 12–14px, nodes 18px, sheets 24px (top only), pills/toggles 999px.
**Borders**: 2px throughout. **Spacing**: 20px screen padding, 10–12px control gaps.
**Motion**: 120 / 260 / 480ms; ease-out `cubic-bezier(0.4,0,0.2,1)`; overshoot `cubic-bezier(0.34,1.2–1.4,0.64,1)` for pop/sheet.
**Scrim**: `color-mix(in srgb, #000 55%, transparent)`.

## Assets
- **Fonts**: Fraunces, Space Grotesk, Space Mono — Google Fonts (`display=swap`).
- **Icons**: Lucide (help-circle, bar-chart-2, sliders, X) — inline SVG, 2px stroke.
- No raster images. Emoji in the share grid are system emoji.

## Files
- `NUMLINK.dc.html` — the full prototype (all six screens, play loop, stats, share). Open in a browser to interact; read the `Component` class for exact logic.
