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
}
