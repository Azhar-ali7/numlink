import 'package:flutter_test/flutter_test.dart';
import 'package:numlink_app/data/stats_repository.dart';
import 'package:numlink_app/models/game_stats.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('LocalStatsRepository round-trips stats', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = LocalStatsRepository(prefs);

    // First run returns the demo seed.
    final seeded = await repo.load();
    expect(seeded.played, GameStats.seed.played);

    final updated = seeded.recordWin(3, 3);
    await repo.save(updated);

    final reloaded = await repo.load();
    expect(reloaded.played, seeded.played + 1);
    expect(reloaded.wins, seeded.wins + 1);
    expect(reloaded.streak, seeded.streak + 1);
    expect(reloaded.dist['par'], (seeded.dist['par'] ?? 0) + 1);
  });

  test('bucketFor maps moves-over-par correctly', () {
    expect(GameStats.bucketFor(3, 3), 'par');
    expect(GameStats.bucketFor(2, 3), 'par');
    expect(GameStats.bucketFor(4, 3), '+1');
    expect(GameStats.bucketFor(5, 3), '+2');
    expect(GameStats.bucketFor(7, 3), '+3+');
  });

  group('XP / player level', () {
    test('xpForLevel is the triangular curve, level 1 at 0', () {
      expect(GameStats.xpForLevel(1), 0);
      expect(GameStats.xpForLevel(2), 50);
      expect(GameStats.xpForLevel(3), 150);
      expect(GameStats.xpForLevel(4), 300);
    });

    test('levelForXp inverts xpForLevel and is monotonic', () {
      expect(GameStats.levelForXp(0), 1);
      expect(GameStats.levelForXp(49), 1);
      expect(GameStats.levelForXp(50), 2);
      expect(GameStats.levelForXp(149), 2);
      expect(GameStats.levelForXp(150), 3);
      // Every threshold lands exactly on its level.
      for (var l = 1; l <= 20; l++) {
        expect(GameStats.levelForXp(GameStats.xpForLevel(l)), l);
      }
    });

    test('derived progress fields track XP within a level', () {
      final s = GameStats.empty.bumpCounter('xp', 75); // level 2 (50..150)
      expect(s.playerLevel, 2);
      expect(s.xpIntoLevel, 25); // 75 - 50
      expect(s.xpLevelSpan, 100); // 150 - 50
      expect(s.levelProgress, 0.25);
    });
  });

  group('honest streak + freeze', () {
    // A day-2 win at streak 2, no freezes banked, no prior-day gap.
    GameStats at(int streak, int lastDay, {int freezes = 0}) => GameStats(
          played: 5,
          wins: 5,
          streak: streak,
          maxStreak: streak,
          dist: const {},
          counters: {'freezes': freezes},
          lastDailyDay: lastDay,
        );

    test('first-ever daily win increments (no prior day)', () {
      final s = GameStats.empty.recordWin(3, 3, today: 100);
      expect(s.streak, 1);
      expect(s.lastDailyDay, 100);
    });

    test('next-day win extends the streak', () {
      final s = at(2, 100).recordWin(3, 3, today: 101);
      expect(s.streak, 3);
      expect(s.lastDailyDay, 101);
    });

    test('same-day re-record does not double-count', () {
      final s = at(2, 100).recordWin(3, 3, today: 100);
      expect(s.streak, 2);
    });

    test('a missed day with no freeze resets to 1', () {
      final s = at(5, 100).recordWin(3, 3, today: 103); // 3-day gap
      expect(s.streak, 1);
    });

    test('a missed day spends a freeze and preserves the run', () {
      final s = at(5, 100, freezes: 1).recordWin(3, 3, today: 103);
      expect(s.streak, 6);
      expect(s.freezes, 0); // freeze consumed
    });

    test('hitting a milestone streak earns a freeze', () {
      final s = at(2, 100).recordWin(3, 3, today: 101); // → streak 3
      expect(s.streak, 3);
      expect(s.freezes, 1);
    });

    test('lastDailyDay round-trips through JSON', () {
      final s = at(4, 200, freezes: 2);
      final back = GameStats.fromJson(s.toJson());
      expect(back.lastDailyDay, 200);
      expect(back.freezes, 2);
    });
  });
}
