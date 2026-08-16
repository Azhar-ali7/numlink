# NUMLINK — Front End & UI

## Layout frame

The whole app lives in a **centered column, `maxWidth: 440`**, with 2px left/
right borders — a phone-width "card" that also reads well on desktop/web. Inside
a `SafeArea`, everything is a single `Stack` of layers (no route navigation):

1. **GameScreen** — the board (always present).
2. **ConfettiOverlay** — fires on a win (`pulse: g.winPulse`).
3. **GameToast** — transient one-line messages.
4. **WelcomeScreen** — the home/menu (shown when not in a game).
5. **Active bottom sheet** — win / stats / how-to / settings / archive / solution.
6. **IntroCarousel** — first-run tutorial (topmost).

## Screens

### Home (`screens/welcome_screen.dart`)

Top → bottom:

1. **Preview chain** — a mini `_PreviewNode`/`_Connector` illustration.
2. **Wordmark** `NUMLINK` + one-line description.
3. **Stat cards** — streak · puzzle #/date (`_StatCard`). The streak card shows a
   `❄` freeze badge with the banked count when the player holds any streak-freezes.
   - Below them an **XP bar** (`_XpBar`): player level, a `LinearProgressIndicator`
     fill toward the next level, and the `into / span XP` readout.
4. **Hero** — filled `_WelcomeButton("Play today's puzzle")` starting the Daily,
   with `NextDailyCountdown(center: true)` right beneath it.
5. **`MORE MODES`** section label.
6. **`LEVELS` entry** (`_LevelsEntry`) — a full-width, success-tinted card above
   the grid showing campaign progress (`cleared/total` · total ⭐); taps open the
   roadmap sheet.
7. **2×2 mode grid** (`_ModeTile`): Practice, Zen, Timed, Archive.
   - Practice / Zen → a native `showModalBottomSheet` **difficulty popup**
     (reused `_DifficultyPicker` + a Start button) *before* starting.
   - Timed → `startTimed()`; Archive → opens the archive sheet.
8. **How-to link** at the bottom (opens the quick-reference sheet).

The page is a `SingleChildScrollView` over a `ConstrainedBox(minHeight)` — it
scrolls rather than overflowing (an earlier `IntrinsicHeight` was removed to fix
overflow; do not reintroduce it).

### Game board (`screens/game_screen.dart`)

A **compact one-line header** (`_Header`): back button · inline `mode #no`
title+subtitle · a single **overflow `⋯` menu** (`PopupMenuButton<SheetOverlay>`,
Flutter stdlib) folding **How to play / Stats / Settings** into one control — no
more three stacked icon buttons, freeing vertical space for the chain.

Below it the **target bar** (`_TargetBar`) shows the **active target** as the big
number with a label that flips `GET TO` → `CHECKPOINT n/total` → `FINAL TARGET`,
plus a small **dots row** (`_MilestoneDots`: filled check per banked checkpoint,
outline ahead, flag for the final target) when a puzzle has milestones.

Then the live chain of `ChainNode`s rendered top-down (current value highlighted
in the progress/orange color), a **heat bar** showing closeness to the active
target, the **6 operation buttons** (whose labels now include `%`, `x²`, `√`, `Σ`
glyphs), and the trimmed action row: **UNDO · RESET · HINT·N** (STATS moved into
the overflow menu). `HINT·N` shows hints remaining and, when tapped, makes the
recommended op button **glow** (progress-colored `boxShadow`) for ~2.5s. Once the
reveal is earned (`g.canReveal`), a full-width **SHOW SOLUTION** button appears
below the row and opens the solution sheet. Banking a checkpoint fires a
win-pulse and advances the active target; landing on the final target (all
checkpoints banked) opens the **win sheet**.

### Intro carousel (`screens/intro_carousel.dart`)

Full-screen, opaque, topmost. A 3-slide swipeable `PageView` (glyph/mini-preview
+ heading + body), a dot indicator, a top-right **Skip**, and a bottom button
that reads **Next** until the last slide then **Get started**. Both Skip and
Get-started call `settings.dismissTutorial()`. Shown once on first launch
(`tutorialSeen`), replayable from Settings.

## Bottom sheets (`sheets/`)

All share `BottomSheetShell` (a `PrimaryButton` for primary actions):

- **Win** — score label (Eagle…Over), moves vs par, **share text** button,
  play-again / new-puzzle, achievements just earned, and a **+XP · Level** pill
  (`g.lastXpGain`) for the solve. In **campaign** mode it also shows the earned
  **star row** (`_StarRow`) and a **"Next level →"** button when a further level
  exists.
- **Roadmap** (`roadmap_sheet.dart`) — the campaign path: a header showing total
  ⭐ / max and `cleared/total`, then a vertical list of `_LevelNode`s joined by
  connectors. Each node shows the level #, tier label (+ new-operator hint on
  boundary levels), and either earned **mini-stars**, a **PLAY** cue, or a
  **lock** (dimmed) per the linear gate. Tapping an unlocked node starts it.
- **Stats** — played, win rate, streak/max streak, the **par-distribution
  histogram** (buckets `par / +1 / +2 / +3+`), per-mode counters, achievement
  badges.
- **How to play** — quick reference (the `_steps` copy).
- **Settings** — theme, high-contrast, colorblind orange-success, sound,
  haptics, and a **"Replay the intro"** row (`openTutorial()`).
- **Archive** — grid of past daily numbers; tap to replay (solved ones marked).
- **Solution** (`solution_sheet.dart`) — the earned reveal: replays
  `g.answerPath` from start to target as numbered `value  op  → next` steps, with
  a "Back to puzzle" button. Never mutates the board.

## Reusable widgets (`widgets/`)

`chain_node_widget`, `operation_button`, `heat_bar`, `next_daily_countdown`,
`rolling_number` (animated number roll), `streak_flame`, `confetti_overlay`,
and shared primitives in `ui.dart` (`HoverBorder`, buttons, etc.).

**Operation button** example: big mono op label, a result-preview line, a
token-count pill (`N×`) top-right that turns muted at 0 and warns at 1;
disabled (0.38 opacity) when spent/illegal/solved but still tappable so an
illegal tap produces the **shake + toast**. Shake is suppressed under reduced
motion. A `highlighted` flag (set when a hint points here) adds a
progress-colored border + glow — width stays at 2px to avoid re-triggering the
old 1.6px overflow.

## Design tokens (`theme/tokens.dart`)

`NumTokens` is a `ThemeExtension` (`NumTheme.of(context)`), full dark + light
palettes:

| Token | Dark | Light | Role |
|-------|------|-------|------|
| bg | `#121213` | `#FFFFFF` | page background |
| surface | `#1E1E1E` | `#F6F7F8` | cards, buttons |
| elevated | `#272727` | `#EEF0F2` | raised surfaces |
| text | `#D7DADC` | `#1A1A1B` | primary text |
| muted | `#818488` | `#787C7E` | secondary text |
| border | `#3A3A3C` | `#D3D6DA` | outlines |
| success | `#4C9FD6` | `#0072B2` | win / on-target (blue) |
| progress | `#E0A83A` | `#C77F00` | current node / near (amber) |

`altSuccessOrange #F5793A` is the **colorblind orange-success** override
(opt-in). `tint(c, pct)` lightens/darkens a token.

**Palette is Okabe–Ito colorblind-safe**, and color is *always* paired with a
shape or text label — never the only signal.

## Motion (`theme/motion.dart`)

A fixed budget of durations + curves so animation feels consistent:

- Durations: `micro 120` · `standard 260` · `celebrate 480` · `toast 160` ·
  `shake 340` · `sheet 280` (ms).
- Curves: `easeOut Cubic(.4,0,.2,1)` · `overshoot Cubic(.34,1.4,.64,1)` ·
  `overshootSoft` variant.
- `reducedMotion(context)` reads `MediaQuery.disableAnimations` — when set,
  shakes and flourishes are skipped.

## Typography (`theme/fonts.dart`)

Three families via `google_fonts`:

- **Fraunces** — display / wordmark.
- **Space Grotesk** — UI text.
- **Space Mono** — numbers, op labels, the game board (monospace keeps digits
  aligned).

## Theming controls

- **Dark / light** via `SettingsController.themeMode` (drives `MaterialApp`).
- **High contrast** (on by default).
- **Colorblind orange-success** (off by default).
- **Reduced motion** (from the OS).

## Accessibility summary

- Colorblind-safe palette; color never the sole cue.
- High-contrast mode + dark/light.
- Reduced-motion honored throughout.
- Sound and haptics available but off by default.
