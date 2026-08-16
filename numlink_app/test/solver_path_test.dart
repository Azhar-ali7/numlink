import 'package:flutter_test/flutter_test.dart';
import 'package:numlink_app/game/game_mode.dart';
import 'package:numlink_app/game/generator.dart';
import 'package:numlink_app/game/solver.dart';
import 'package:numlink_app/models/operation.dart';
import 'package:numlink_app/models/puzzle.dart';

/// Replay an op-id path from [start], respecting caps, returning the final
/// value — or null if any step is illegal or over-uses a token.
int? _replay(Puzzle p, List<String> ids, {int? start, Map<String, int>? used}) {
  final byId = {for (final o in p.ops) o.id: o};
  final u = <String, int>{if (used != null) ...used};
  var v = start ?? p.start;
  for (final id in ids) {
    final o = byId[id];
    if (o == null) return null;
    final n = (u[id] ?? 0) + 1;
    if (n > o.tokens) return null; // exceeds token cap
    final r = o.apply(v, cap: p.cap);
    if (r == null) return null;
    u[id] = n;
    v = r;
  }
  return v;
}

void main() {
  const gen = PuzzleGenerator();

  group('solvePath is a real, honest solution', () {
    for (final d in Difficulty.values) {
      test('${d.label}: path exists, length == par, replays to target', () {
        for (var i = 0; i < 40; i++) {
          final p = gen.generate(d, seed: i);
          final path = solvePath(p);
          expect(path, isNotNull, reason: '$d #$i must be solvable');
          expect(path!.length, equals(p.par), reason: '$d #$i path == par');
          expect(_replay(p, path), equals(p.target),
              reason: '$d #$i replaying the path must reach the target');
        }
      });
    }
  });

  test('stored Puzzle.solution matches a fresh solve and reaches target', () {
    for (var i = 0; i < 20; i++) {
      final p = gen.generate(Difficulty.medium, seed: 100 + i);
      expect(p.solution, isNotEmpty, reason: 'generator must publish a path');
      expect(p.solution.length, equals(p.par));
      expect(_replay(p, p.solution), equals(p.target));
    }
  });

  test('milestone-aware solve threads the checkpoint in order', () {
    const ops = [
      Operation(id: 'm3', symbol: '×', n: 3, tokens: 3),
      Operation(id: 'p7', symbol: '+', n: 7, tokens: 3),
      Operation(id: 'm2', symbol: '×', n: 2, tokens: 3),
      Operation(id: 's1', symbol: '−', n: 1, tokens: 3),
    ];
    const base =
        Puzzle(no: 1, dateLabel: '', start: 2, target: 26, par: 3, ops: ops);
    const withMs = Puzzle(
        no: 1, dateLabel: '', start: 2, target: 26, par: 3, ops: ops,
        milestones: [13]);

    final basePath = solvePath(base)!;
    final msPath = solvePath(withMs);
    expect(msPath, isNotNull, reason: 'checkpoint sits on a real route');
    expect(_replay(withMs, msPath!), 26, reason: 'still reaches the target');
    // Required checkpoints can only lengthen (never shorten) the shortest route.
    expect(msPath.length, greaterThanOrEqualTo(basePath.length));

    // The running value must hit the checkpoint before the final target.
    final byId = {for (final o in ops) o.id: o};
    final values = <int>[withMs.start];
    var v = withMs.start;
    for (final id in msPath) {
      v = byId[id]!.apply(v, cap: withMs.cap)!;
      values.add(v);
    }
    final idx = values.indexOf(13);
    expect(idx, greaterThan(0), reason: 'checkpoint value appears on the path');
    expect(idx, lessThan(values.length - 1), reason: 'before the final target');
  });

  test('mid-game solvePath respects value + tokens already spent', () {
    final p = gen.generate(Difficulty.hard, seed: 7);
    final first = p.solution.first;
    final o = p.ops.firstWhere((o) => o.id == first);
    final afterOne = o.apply(p.start, cap: p.cap)!;

    final rest = solvePath(p, from: afterOne, used: {first: 1});
    expect(rest, isNotNull, reason: 'must still solve from mid-game state');
    expect(_replay(p, rest!, start: afterOne, used: {first: 1}),
        equals(p.target));
    // Continuing from the first move, the rest is one shorter than full par.
    expect(rest.length, equals(p.par - 1));
  });
}
