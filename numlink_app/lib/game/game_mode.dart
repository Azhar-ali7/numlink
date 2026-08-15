/// The play modes. `daily` is the shared, deterministic puzzle of the day;
/// `practice` is unlimited generated puzzles at a chosen difficulty; `zen` is
/// pressure-free (no par/score); `timed` is an escalating ladder against a
/// clock; `archive` replays a past daily (no streak effect).
enum GameMode { daily, practice, zen, timed, archive }

/// Difficulty tiers for generated puzzles. Player-chosen in practice/zen; the
/// timed ladder walks up these; daily uses a fixed tier ([Difficulty.daily]).
enum Difficulty { easy, medium, hard }

/// The generation knobs for one difficulty tier. Tuned during play-test.
///
/// A puzzle is reverse-generated to a solution of length in [minPar, maxPar],
/// then its true par is BFS-verified (see `generator.dart`).
class DifficultySpec {
  const DifficultySpec({
    required this.minPar,
    required this.maxPar,
    required this.maxTarget,
    required this.startMax,
    required this.allowDivide,
    required this.extraTokens,
  });

  /// Inclusive par band (solution length).
  final int minPar;
  final int maxPar;

  /// Upper bound for the generated target and every intermediate value —
  /// keeps easy tiers in small, eyeball-able numbers.
  final int maxTarget;

  /// Upper bound for the random start value (inclusive, min 1).
  final int startMax;

  /// Whether `÷` may appear in the op set.
  final bool allowDivide;

  /// Token headroom above each op's actual usage in the solution. Smaller =
  /// tighter = harder (hard = 0 = exactly enough).
  final int extraTokens;

  static const Map<Difficulty, DifficultySpec> table = {
    Difficulty.easy: DifficultySpec(
      minPar: 2,
      maxPar: 3,
      maxTarget: 50,
      startMax: 9,
      allowDivide: false,
      extraTokens: 2,
    ),
    Difficulty.medium: DifficultySpec(
      minPar: 3,
      maxPar: 4,
      maxTarget: 200,
      startMax: 15,
      allowDivide: true,
      extraTokens: 1,
    ),
    Difficulty.hard: DifficultySpec(
      minPar: 4,
      maxPar: 6,
      maxTarget: 999,
      startMax: 20,
      allowDivide: true,
      extraTokens: 0,
    ),
  };

  static DifficultySpec of(Difficulty d) => table[d]!;
}

extension DifficultyLabel on Difficulty {
  String get label => switch (this) {
        Difficulty.easy => 'Easy',
        Difficulty.medium => 'Medium',
        Difficulty.hard => 'Hard',
      };
}
