/// Persisted player statistics, mirroring the prototype's `numlink_stats`
/// localStorage shape.
class GameStats {
  const GameStats({
    required this.played,
    required this.wins,
    required this.streak,
    required this.maxStreak,
    required this.dist,
    this.counters = const <String, int>{},
    this.archiveSolved = const <int>{},
    this.unlocked = const <String>{},
  });

  final int played;
  final int wins;
  final int streak;
  final int maxStreak;

  /// Distribution over buckets: `par`, `+1`, `+2`, `+3+`.
  final Map<String, int> dist;

  /// Lightweight per-mode counters (e.g. `practice`, `zen`, `timedBestStage`,
  /// `timedRuns`). Keeps the daily streak/dist above untouched by other modes.
  final Map<String, int> counters;

  /// Past daily numbers the player has replayed to a solve.
  final Set<int> archiveSolved;

  /// Unlocked achievement ids (sticky once earned).
  final Set<String> unlocked;

  static const List<String> bucketKeys = ['par', '+1', '+2', '+3+'];

  int get winRate => played == 0 ? 0 : (100 * wins / played).round();

  /// Solves across every mode (drives cumulative achievements). Timed is a
  /// run, not a single-puzzle solve, so it's excluded here.
  int get totalSolves =>
      wins +
      (counters['practice'] ?? 0) +
      (counters['zen'] ?? 0) +
      archiveSolved.length;

  GameStats _with({
    Map<String, int>? counters,
    Set<int>? archiveSolved,
    Set<String>? unlocked,
  }) =>
      GameStats(
        played: played,
        wins: wins,
        streak: streak,
        maxStreak: maxStreak,
        dist: dist,
        counters: counters ?? this.counters,
        archiveSolved: archiveSolved ?? this.archiveSolved,
        unlocked: unlocked ?? this.unlocked,
      );

  /// +[by] to counter [key].
  GameStats bumpCounter(String key, [int by = 1]) =>
      _with(counters: {...counters, key: (counters[key] ?? 0) + by});

  /// Raise counter [key] to [v] if higher (for "best" values like stage).
  GameStats setCounterMax(String key, int v) =>
      v > (counters[key] ?? 0) ? _with(counters: {...counters, key: v}) : this;

  GameStats markArchive(int no) =>
      _with(archiveSolved: {...archiveSolved, no});

  /// Union newly-earned achievement [ids] into the unlocked set.
  GameStats withUnlocked(Set<String> ids) => ids.difference(unlocked).isEmpty
      ? this
      : _with(unlocked: {...unlocked, ...ids});

  /// Demo seed used on first run, matching the prototype.
  static const GameStats seed = GameStats(
    played: 12,
    wins: 11,
    streak: 4,
    maxStreak: 7,
    dist: {'par': 3, '+1': 5, '+2': 2, '+3+': 1},
  );

  static const GameStats empty = GameStats(
    played: 0,
    wins: 0,
    streak: 0,
    maxStreak: 0,
    dist: {},
  );

  /// Returns the bucket key for a game finished [moves] over/under [par].
  static String bucketFor(int moves, int par) {
    final over = moves - par;
    if (over <= 0) return 'par';
    if (over == 1) return '+1';
    if (over == 2) return '+2';
    return '+3+';
  }

  /// Records a win of [moves] against [par] and returns the updated stats.
  GameStats recordWin(int moves, int par) {
    final nextStreak = streak + 1;
    final newDist = Map<String, int>.from(dist);
    final key = bucketFor(moves, par);
    newDist[key] = (newDist[key] ?? 0) + 1;
    return GameStats(
      played: played + 1,
      wins: wins + 1,
      streak: nextStreak,
      maxStreak: nextStreak > maxStreak ? nextStreak : maxStreak,
      dist: newDist,
      counters: counters,
      archiveSolved: archiveSolved,
      unlocked: unlocked,
    );
  }

  Map<String, dynamic> toJson() => {
        'played': played,
        'wins': wins,
        'streak': streak,
        'maxStreak': maxStreak,
        'dist': dist,
        'counters': counters,
        'archiveSolved': archiveSolved.toList(),
        'unlocked': unlocked.toList(),
      };

  factory GameStats.fromJson(Map<String, dynamic> j) => GameStats(
        played: (j['played'] as num?)?.toInt() ?? 0,
        wins: (j['wins'] as num?)?.toInt() ?? 0,
        streak: (j['streak'] as num?)?.toInt() ?? 0,
        maxStreak: (j['maxStreak'] as num?)?.toInt() ?? 0,
        dist: (j['dist'] as Map?)?.map(
              (k, v) => MapEntry(k as String, (v as num).toInt()),
            ) ??
            {},
        counters: (j['counters'] as Map?)?.map(
              (k, v) => MapEntry(k as String, (v as num).toInt()),
            ) ??
            {},
        archiveSolved: ((j['archiveSolved'] as List?) ?? [])
            .map((e) => (e as num).toInt())
            .toSet(),
        unlocked:
            ((j['unlocked'] as List?) ?? []).map((e) => e as String).toSet(),
      );
}
