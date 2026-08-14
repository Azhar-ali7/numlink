/// Persisted player statistics, mirroring the prototype's `numlink_stats`
/// localStorage shape.
class GameStats {
  const GameStats({
    required this.played,
    required this.wins,
    required this.streak,
    required this.maxStreak,
    required this.dist,
  });

  final int played;
  final int wins;
  final int streak;
  final int maxStreak;

  /// Distribution over buckets: `par`, `+1`, `+2`, `+3+`.
  final Map<String, int> dist;

  static const List<String> bucketKeys = ['par', '+1', '+2', '+3+'];

  int get winRate => played == 0 ? 0 : (100 * wins / played).round();

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
    );
  }

  Map<String, dynamic> toJson() => {
        'played': played,
        'wins': wins,
        'streak': streak,
        'maxStreak': maxStreak,
        'dist': dist,
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
      );
}
