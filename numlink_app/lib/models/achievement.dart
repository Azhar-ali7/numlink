import 'game_stats.dart';

/// Per-solve facts an achievement predicate may need but that aren't kept in
/// [GameStats] (which only stores cumulative daily distribution).
class SolveContext {
  const SolveContext({required this.scoreOver, required this.usedDivision});

  /// moves − par for the just-finished puzzle (< 0 = under par).
  final int scoreOver;

  /// Whether the solving chain used a `÷` operation.
  final bool usedDivision;
}

/// A derived badge. [earned] is checked after every solve against the updated
/// stats + the solve context; newly-true ids are unioned into the persisted
/// unlocked set (so one-shot badges like Eagle stay lit).
class Achievement {
  const Achievement(this.id, this.name, this.desc, this.earned);

  final String id;
  final String name;
  final String desc;
  final bool Function(GameStats s, SolveContext c) earned;
}

const List<Achievement> kAchievements = [
  Achievement('first_link', 'First Link', 'Solve your first puzzle', _firstLink),
  Achievement('birdie', 'Birdie', 'Beat par on a puzzle', _birdie),
  Achievement('eagle', 'Eagle', 'Finish 2+ under par', _eagle),
  Achievement('purist', 'Purist', 'Solve without dividing', _purist),
  Achievement('streak3', 'On a Roll', 'Reach a 3-day streak', _streak3),
  Achievement('streak7', 'Week Warrior', 'Reach a 7-day streak', _streak7),
  Achievement('ten', 'Dedicated', 'Solve 10 puzzles', _ten),
  Achievement('climber', 'Ladder Climber', 'Reach stage 5 in Timed', _climber),
];

bool _firstLink(GameStats s, SolveContext c) => s.totalSolves >= 1;
bool _birdie(GameStats s, SolveContext c) => c.scoreOver < 0;
bool _eagle(GameStats s, SolveContext c) => c.scoreOver <= -2;
bool _purist(GameStats s, SolveContext c) => !c.usedDivision;
bool _streak3(GameStats s, SolveContext c) => s.maxStreak >= 3;
bool _streak7(GameStats s, SolveContext c) => s.maxStreak >= 7;
bool _ten(GameStats s, SolveContext c) => s.totalSolves >= 10;
bool _climber(GameStats s, SolveContext c) =>
    (s.counters['timedBestStage'] ?? 0) >= 5;

/// The set of achievement ids currently satisfied by [s] + [c].
Set<String> earnedAchievements(GameStats s, SolveContext c) =>
    {for (final a in kAchievements) if (a.earned(s, c)) a.id};
