import 'package:flutter_test/flutter_test.dart';
import 'package:numlink_app/game/game_mode.dart';
import 'package:numlink_app/game/generator.dart';
import 'package:numlink_app/game/puzzle_repository.dart';
import 'package:numlink_app/game/solver.dart';

void main() {
  const gen = PuzzleGenerator();

  group('generated puzzles are honest', () {
    for (final d in Difficulty.values) {
      test('${d.label}: solvable, par == minMoves, within band', () {
        final spec = DifficultySpec.of(d);
        for (var i = 0; i < 40; i++) {
          final p = gen.generate(d, seed: i);
          final min = minMoves(p);
          expect(min, isNotNull, reason: '$d #$i must be solvable');
          expect(min, equals(p.par), reason: '$d #$i par must be honest');
          expect(p.par, inInclusiveRange(spec.minPar, spec.maxPar),
              reason: '$d #$i par ${p.par} outside band');
          expect(p.target, lessThanOrEqualTo(spec.maxTarget));
          expect(p.start, isNot(equals(p.target)));
          expect(p.ops.length, equals(spec.opCount));
        }
      });
    }
  });

  test('same seed → identical puzzle (deterministic daily/archive)', () {
    final a = gen.generate(Difficulty.medium, seed: 12345);
    final b = gen.generate(Difficulty.medium, seed: 12345);
    expect(a.start, b.start);
    expect(a.target, b.target);
    expect(a.par, b.par);
    expect(a.ops.map((o) => '${o.id}:${o.tokens}').join(','),
        b.ops.map((o) => '${o.id}:${o.tokens}').join(','));
  });

  test('daily is reproducible and numbered from the epoch', () async {
    const repo = LocalPuzzleRepository();
    final a = await repo.daily(DateTime.utc(2026, 8, 8));
    final b = await repo.daily(DateTime.utc(2026, 8, 8));
    expect(a.no, 128);
    expect(a.dateLabel, 'AUG 8 2026');
    expect(a.target, b.target);
    expect(minMoves(a), a.par);

    final tomorrow = await repo.daily(DateTime.utc(2026, 8, 9));
    expect(tomorrow.no, 129);
  });
}
