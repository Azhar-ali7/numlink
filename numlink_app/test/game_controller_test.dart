import 'package:flutter_test/flutter_test.dart';
import 'package:numlink_app/data/stats_repository.dart';
import 'package:numlink_app/game/game_controller.dart';
import 'package:numlink_app/game/game_mode.dart';
import 'package:numlink_app/models/game_stats.dart';

/// In-memory stats repo for tests.
class FakeStatsRepository implements StatsRepository {
  GameStats saved = GameStats.empty;
  @override
  Future<GameStats> load() async => saved;
  @override
  Future<void> save(GameStats stats) async => saved = stats;
}

GameController _controller() => GameController(
  statsRepo: FakeStatsRepository(),
  initialStats: GameStats.empty,
);

void main() {
  _dstDayIndex();
  group('daily identity + calendar', () {
    test('exposes the daily number/date and archive/campaign counts', () {
      final g = _controller();
      expect(g.dailyPuzzle.no, greaterThanOrEqualTo(128));
      expect(g.dailyPuzzle.dateLabel, isNotEmpty);
      expect(g.campaignCount, greaterThan(0));
      // Archive lists every past daily since the epoch (#128), newest first.
      expect(g.archiveNumbers, isNot(contains(g.dailyPuzzle.no)));
    });
  });

  group('recordDailyWin (branching-engine bridge)', () {
    test('records streak/wins/xp and is idempotent for the day', () {
      final g = _controller();
      expect(g.stats.wins, 0);
      g.recordDailyWin(3, 5); // 2 under par
      expect(g.stats.wins, 1);
      expect(g.stats.streak, 1);
      expect(g.stats.xp, greaterThan(0));
      final winsAfter = g.stats.wins;
      final xpAfter = g.stats.xp;
      g.recordDailyWin(4, 5); // same day → no double count
      expect(g.stats.wins, winsAfter);
      expect(g.stats.xp, xpAfter);
    });
  });

  group('recordBranchingWin (practice/zen/archive bridge)', () {
    test('practice bumps the practice counter + XP, leaves streak alone', () {
      final g = _controller();
      g.recordBranchingWin(GameMode.practice, 3, 5);
      expect(g.stats.counters['practice'], 1);
      expect(g.stats.xp, greaterThan(0));
      expect(g.stats.streak, 0); // non-daily never touches the streak
      expect(g.stats.wins, 0);
    });

    test('zen bumps the zen counter with flat XP', () {
      final g = _controller();
      g.recordBranchingWin(GameMode.zen, 9, 5); // over par: still flat 10
      expect(g.stats.counters['zen'], 1);
      expect(g.stats.xp, 10);
    });

    test('archive marks the puzzle number solved', () {
      final g = _controller();
      g.recordBranchingWin(GameMode.archive, 3, 5, archiveNo: 130);
      expect(g.stats.archiveSolved, contains(130));
    });
  });

  group('recordTimedStage (branching timed bridge)', () {
    test('each stage lifts best-stage; only the final run bumps runs + XP', () {
      final g = _controller();
      g.recordTimedStage(1);
      g.recordTimedStage(2);
      expect(g.stats.counters['timedBestStage'], 2);
      expect(g.stats.counters['timedRuns'] ?? 0, 0); // no run banked mid-ladder
      expect(g.stats.xp, 0);
      g.recordTimedStage(8, runDone: true);
      expect(g.stats.counters['timedBestStage'], 8);
      expect(g.stats.counters['timedRuns'], 1);
      expect(g.stats.xp, 40); // 5 XP per stage cleared
    });
  });

  group('recordCampaignWin (branching campaign bridge)', () {
    test('records stars (keeps the max) and unlocks the next level', () {
      final g = _controller();
      g.recordCampaignWin(1, 5, 3); // 2 over par → 1 star
      expect(g.stats.levelStars[1], 1);
      expect(g.stats.levelUnlocked(2), isTrue);
      expect(g.stats.xp, greaterThan(0));
      g.recordCampaignWin(1, 3, 3); // par → 3 stars, replaces the lower score
      expect(g.stats.levelStars[1], 3);
    });
  });

  group('overlay routing', () {
    test('open/close toggles the active sheet', () {
      final g = _controller();
      expect(g.overlay, isNull);
      g.open(SheetOverlay.stats);
      expect(g.overlay, SheetOverlay.stats);
      g.close();
      expect(g.overlay, isNull);
    });
  });
}

/// The DST cases that the old local-midnight flooring got wrong. Constructed
/// dates only — CI runs in UTC, where the bug is invisible.
void _dstDayIndex() {
  test('dayIndexOf advances by exactly one across a DST transition', () {
    for (final (a, b) in [
      (DateTime(2024, 3, 31), DateTime(2024, 4, 1)), // spring forward (London)
      (DateTime(2024, 10, 27), DateTime(2024, 10, 28)), // fall back
      (DateTime(2024, 3, 10), DateTime(2024, 3, 11)), // spring forward (US)
      (DateTime(2024, 11, 3), DateTime(2024, 11, 4)), // fall back (US)
    ]) {
      expect(
        GameController.dayIndexOf(b) - GameController.dayIndexOf(a),
        1,
        reason: '$a → $b',
      );
    }
  });
}
