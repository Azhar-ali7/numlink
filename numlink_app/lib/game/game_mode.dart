/// The play modes. `daily` is the shared, deterministic puzzle of the day;
/// `practice` is unlimited generated puzzles at a chosen difficulty (Free Play);
/// `zen` is pressure-free (no par/score); `timed` is an escalating ladder
/// against a clock; `archive` replays a past daily (no streak effect);
/// `campaign` is a curated, star-rated level from the roadmap.
enum GameMode { daily, practice, zen, timed, archive, campaign }

/// The four difficulty tiers. `.name` is the key into `kTiers`
/// (`tree_generator.dart`), which holds the actual generation knobs — this enum
/// is only the ordered, typed spelling of them for the campaign table and the
/// Free Play picker. Declaration order is the ramp; `campaign_test` asserts
/// levels never step backwards through it.
enum Difficulty { kids, easy, medium, hard }

/// Player-facing copy for a tier — the one place it lives. Read by the Free
/// Play difficulty sheet, the in-board ⋯ menu and the roadmap chapter bands.
extension DifficultyLabel on Difficulty {
  String get label => switch (this) {
        Difficulty.kids => 'Kids',
        Difficulty.easy => 'Easy',
        Difficulty.medium => 'Normal',
        Difficulty.hard => 'Expert',
      };

  String get emoji => switch (this) {
        Difficulty.kids => '🧸',
        Difficulty.easy => '🌱',
        Difficulty.medium => '🎯',
        Difficulty.hard => '🔥',
      };

  /// One-line "what am I in for" — mirrors the matching `kTiers` row.
  String get blurb => switch (this) {
        Difficulty.kids => '1 target · 1 move · + − ×',
        Difficulty.easy => '2 targets · 2 deep · + − × ÷',
        Difficulty.medium => '3 targets · 3 deep · adds % and Σ',
        Difficulty.hard => '4–5 targets · 4 deep · everything',
      };
}

/// The tier a `kTiers` key names, for UI that only has the string.
Difficulty? difficultyOf(String key) =>
    Difficulty.values.where((d) => d.name == key).firstOrNull;
