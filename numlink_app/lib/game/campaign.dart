import 'game_mode.dart';

/// One curated campaign level: a fixed `(tier, seed)` pair so every player gets
/// the same, replayable puzzle. Generalizes `PuzzleRepository.ladder`'s ramp.
class LevelDef {
  const LevelDef(this.no, this.tier, this.seed, [this.unlocks]);

  /// 1-based level number.
  final int no;
  final Difficulty tier;

  /// Deterministic generator seed — fixed so the level is stable for everyone.
  final int seed;

  /// If set, a one-time "new operators unlocked" banner shown on first reach
  /// (the tier boundaries where the op pool widens). Cosmetic teaching cue.
  final String? unlocks;
}

/// The ordered campaign. Tiers ramp so operators are introduced gradually:
/// easy = `+ − ×`, medium adds `÷ %` (+ first milestones), hard adds `x² √ Σ`.
/// ponytail: this table + the seeds are play-test tunables — retune for feel.
const List<LevelDef> kCampaign = [
  // 1–6 — easy: + − ×, no division, small numbers.
  LevelDef(1, Difficulty.easy, 4217),
  LevelDef(2, Difficulty.easy, 4231),
  LevelDef(3, Difficulty.easy, 4258),
  LevelDef(4, Difficulty.easy, 4276),
  LevelDef(5, Difficulty.easy, 4293),
  LevelDef(6, Difficulty.easy, 4312),
  // 7–14 — medium: ÷ and % join the pool, checkpoints may appear.
  LevelDef(7, Difficulty.medium, 4338, '÷ divide & % modulo'),
  LevelDef(8, Difficulty.medium, 4351),
  LevelDef(9, Difficulty.medium, 4377),
  LevelDef(10, Difficulty.medium, 4390),
  LevelDef(11, Difficulty.medium, 4416),
  LevelDef(12, Difficulty.medium, 4432),
  LevelDef(13, Difficulty.medium, 4459),
  LevelDef(14, Difficulty.medium, 4471),
  // 15–24 — hard: x² √ Σ join, up to two checkpoints.
  LevelDef(15, Difficulty.hard, 4498, 'x²  √  Σ'),
  LevelDef(16, Difficulty.hard, 4513),
  LevelDef(17, Difficulty.hard, 4539),
  LevelDef(18, Difficulty.hard, 4552),
  LevelDef(19, Difficulty.hard, 4578),
  LevelDef(20, Difficulty.hard, 4591),
  LevelDef(21, Difficulty.hard, 4617),
  LevelDef(22, Difficulty.hard, 4634),
  LevelDef(23, Difficulty.hard, 4658),
  LevelDef(24, Difficulty.hard, 4672),
];

/// Star rating for finishing a level [moves] against [par]: par or better = 3,
/// +1 = 2, anything completed = 1. ponytail: bands are a tuning knob.
int starsFor(int moves, int par) {
  final over = moves - par;
  if (over <= 0) return 3;
  if (over == 1) return 2;
  return 1;
}
