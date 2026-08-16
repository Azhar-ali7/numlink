import 'package:flutter_test/flutter_test.dart';
import 'package:numlink_app/game/campaign.dart';
import 'package:numlink_app/game/puzzle_repository.dart';
import 'package:numlink_app/game/solver.dart';
import 'package:numlink_app/models/game_stats.dart';

void main() {
  const repo = LocalPuzzleRepository();

  test('level numbers are 1..N and contiguous', () {
    for (var i = 0; i < kCampaign.length; i++) {
      expect(kCampaign[i].no, i + 1);
    }
    expect(repo.campaignCount, kCampaign.length);
  });

  test('tiers ramp non-decreasing (easy → medium → hard)', () {
    for (var i = 1; i < kCampaign.length; i++) {
      expect(kCampaign[i].tier.index,
          greaterThanOrEqualTo(kCampaign[i - 1].tier.index));
    }
  });

  test('every level is deterministic and honestly solvable at its par',
      () async {
    for (var n = 1; n <= repo.campaignCount; n++) {
      final a = await repo.campaign(n);
      final b = await repo.campaign(n);
      expect(a.start, b.start);
      expect(a.target, b.target);
      expect(a.par, b.par);
      expect(a.no, n);
      expect(minMoves(a), a.par, reason: 'level $n par must be honest');
    }
  });

  test('starsFor bands: ≤par→3, +1→2, else 1', () {
    expect(starsFor(3, 3), 3); // exactly par
    expect(starsFor(2, 3), 3); // under par
    expect(starsFor(4, 3), 2); // +1
    expect(starsFor(5, 3), 1); // +2
    expect(starsFor(9, 3), 1); // worse
  });

  group('levelStars gate + persistence', () {
    test('linear unlock: level n opens once n-1 is cleared', () {
      var s = GameStats.empty;
      expect(s.levelUnlocked(1), isTrue);
      expect(s.levelUnlocked(2), isFalse);
      s = s.recordLevel(1, 2);
      expect(s.levelUnlocked(2), isTrue);
      expect(s.levelUnlocked(3), isFalse);
    });

    test('recordLevel keeps the best stars (replay only improves)', () {
      var s = GameStats.empty.recordLevel(1, 1);
      expect(s.levelStars[1], 1);
      s = s.recordLevel(1, 3);
      expect(s.levelStars[1], 3);
      s = s.recordLevel(1, 2); // worse replay doesn't downgrade
      expect(s.levelStars[1], 3);
      expect(s.campaignStars, 3);
      expect(s.campaignCleared, 1);
    });

    test('levelStars round-trip through JSON', () {
      final s = GameStats.empty.recordLevel(1, 3).recordLevel(2, 2);
      final back = GameStats.fromJson(s.toJson());
      expect(back.levelStars, {1: 3, 2: 2});
      expect(back.campaignStars, 5);
    });
  });
}
