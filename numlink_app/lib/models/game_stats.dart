import 'dart:math' show max;

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
    this.levelStars = const <int, int>{},
    this.lastDailyDay = 0,
  });

  final int played;
  final int wins;
  final int streak;
  final int maxStreak;

  /// Day-index (days since Unix epoch, local) of the last recorded daily win.
  /// 0 = none yet. Lets [recordWin] tell a continued streak from a broken one.
  final int lastDailyDay;

  /// Distribution over buckets: `par`, `+1`, `+2`, `+3+`.
  final Map<String, int> dist;

  /// Lightweight per-mode counters (e.g. `practice`, `zen`, `timedBestStage`,
  /// `timedRuns`). Keeps the daily streak/dist above untouched by other modes.
  final Map<String, int> counters;

  /// Past daily numbers the player has replayed to a solve.
  final Set<int> archiveSolved;

  /// Unlocked achievement ids (sticky once earned).
  final Set<String> unlocked;

  /// Best star rating (1–3) earned per campaign level; a present key means the
  /// level is cleared. Drives the roadmap's unlock gate and star totals.
  final Map<int, int> levelStars;

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
    Map<int, int>? levelStars,
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
        levelStars: levelStars ?? this.levelStars,
        lastDailyDay: lastDailyDay,
      );

  /// Streak-freezes banked (earned at streak milestones, spent to survive a
  /// missed day).
  int get freezes => counters['freezes'] ?? 0;

  /// Total campaign stars earned (max 3 × level count).
  int get campaignStars =>
      levelStars.values.fold(0, (sum, s) => sum + s);

  /// Number of campaign levels cleared.
  int get campaignCleared => levelStars.length;

  /// Linear unlock gate: level 1 is always open; level [n] opens once [n]-1 is
  /// cleared.
  bool levelUnlocked(int n) => n <= 1 || levelStars.containsKey(n - 1);

  /// Record clearing level [n] with [stars]; keeps the best (replay only
  /// improves).
  GameStats recordLevel(int n, int stars) => _with(
        levelStars: {...levelStars, n: max(stars, levelStars[n] ?? 0)},
      );

  // ---- XP / player level ---------------------------------------------------
  // A single triangular curve, kept in the shared `counters` map (no schema
  // change). ponytail: one formula — tune the 25 constant once we have feel.

  /// Total lifetime XP (accrues on every solve, across all modes).
  int get xp => counters['xp'] ?? 0;

  /// Cumulative XP required to *be at* [level] (level 1 = 0). Gaps widen by 50
  /// each level: L1=0, L2=50, L3=150, L4=300, L5=500…
  static int xpForLevel(int level) => 25 * level * (level - 1);

  /// The player level [xp] buys (largest L with `xpForLevel(L) <= xp`).
  static int levelForXp(int xp) {
    var l = 1;
    while (xpForLevel(l + 1) <= xp) {
      l++;
    }
    return l;
  }

  int get playerLevel => levelForXp(xp);

  /// XP earned into the current level (0 at each level-up).
  int get xpIntoLevel => xp - xpForLevel(playerLevel);

  /// XP the current level spans (from this level-up to the next).
  int get xpLevelSpan => xpForLevel(playerLevel + 1) - xpForLevel(playerLevel);

  /// 0..1 progress toward the next level (drives the home XP bar).
  double get levelProgress => xpIntoLevel / xpLevelSpan;

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

  /// Streak milestones that each grant one streak-freeze.
  static const List<int> freezeMilestones = [3, 7, 14, 30];

  /// Records a daily win of [moves] against [par]. [today] is the day-index of
  /// the solve (days since epoch); when given it makes the streak *honest*:
  /// same day → unchanged, next day → +1, a gap → reset to 1 unless a banked
  /// freeze is spent to preserve it. Reaching a [freezeMilestones] streak earns
  /// a freeze. When [today] is null (or no prior daily), it just increments —
  /// the legacy behaviour.
  GameStats recordWin(int moves, int par, {int? today}) {
    var freezes = this.freezes;
    int nextStreak;
    if (today == null || lastDailyDay == 0) {
      nextStreak = streak + 1;
    } else {
      final gap = today - lastDailyDay;
      if (gap <= 0) {
        nextStreak = streak; // already counted today
      } else if (gap == 1) {
        nextStreak = streak + 1;
      } else if (freezes > 0) {
        freezes -= 1; // spend a freeze to survive the missed day(s)
        nextStreak = streak + 1;
      } else {
        nextStreak = 1; // streak broken
      }
    }
    if (freezeMilestones.contains(nextStreak)) freezes += 1;

    final newDist = Map<String, int>.from(dist);
    final key = bucketFor(moves, par);
    newDist[key] = (newDist[key] ?? 0) + 1;
    return GameStats(
      played: played + 1,
      wins: wins + 1,
      streak: nextStreak,
      maxStreak: nextStreak > maxStreak ? nextStreak : maxStreak,
      dist: newDist,
      counters: {...counters, 'freezes': freezes},
      archiveSolved: archiveSolved,
      unlocked: unlocked,
      levelStars: levelStars,
      lastDailyDay: today ?? lastDailyDay,
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
        'levelStars': levelStars.map((k, v) => MapEntry(k.toString(), v)),
        'lastDailyDay': lastDailyDay,
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
        levelStars: (j['levelStars'] as Map?)?.map(
              (k, v) => MapEntry(int.parse(k as String), (v as num).toInt()),
            ) ??
            const {},
        lastDailyDay: (j['lastDailyDay'] as num?)?.toInt() ?? 0,
      );
}
