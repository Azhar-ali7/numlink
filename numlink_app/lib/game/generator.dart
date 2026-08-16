import 'dart:math';

import '../models/operation.dart';
import '../models/puzzle.dart';
import 'game_mode.dart';
import 'solver.dart';

/// Generates solvable puzzles with an honest, BFS-verified par.
///
/// Strategy (the research-backed "guaranteed solvable" pattern): build a
/// solution *forward* from a random start by applying `d` legal ops, so a chain
/// of length `d` provably exists. Assemble the op set (used ops + decoys), then
/// verify the true minimum with [minMoves] — par is republished as that true
/// minimum, so `minMoves(puzzle) == puzzle.par` always holds. Reject and retry
/// when the honest par escapes the tier band or the puzzle is trivial.
class PuzzleGenerator {
  const PuzzleGenerator();

  static const int _cap = 999;

  /// Op-id prefixes by symbol, matching the handoff (`m3`, `p7`, `s1`, `d2`).
  static const Map<String, String> _prefix = {
    '×': 'm',
    '+': 'p',
    '−': 's',
    '÷': 'd',
  };

  /// Generates a puzzle for tier [d]. Pass [seed] for deterministic output
  /// (daily/archive/ladder); omit for a fresh random puzzle (practice/zen).
  Puzzle generate(
    Difficulty d, {
    int no = 0,
    String dateLabel = '',
    int? seed,
  }) {
    final spec = DifficultySpec.of(d);
    final rng = Random(seed ?? DateTime.now().microsecondsSinceEpoch);

    for (var attempt = 0; attempt < 300; attempt++) {
      final p = _tryBuild(spec, rng, no, dateLabel, relaxed: false);
      if (p != null) return p;
    }
    // Relaxed pass: accept any solvable, non-trivial puzzle (par >= 2).
    for (var attempt = 0; attempt < 300; attempt++) {
      final p = _tryBuild(spec, rng, no, dateLabel, relaxed: true);
      if (p != null) return p;
    }
    return _fallback(no, dateLabel);
  }

  Puzzle? _tryBuild(
    DifficultySpec spec,
    Random rng,
    int no,
    String dateLabel, {
    required bool relaxed,
  }) {
    final targetPar = spec.minPar + rng.nextInt(spec.maxPar - spec.minPar + 1);
    final start = 1 + rng.nextInt(spec.startMax);

    // Walk forward, recording usage so token caps can be set exactly.
    var cur = start;
    final usage = <String, int>{};
    final usedOp = <String, Operation>{};
    for (var step = 0; step < targetPar; step++) {
      final legal = _legalFrom(cur, spec);
      if (legal.isEmpty) return null;
      final op = legal[rng.nextInt(legal.length)];
      cur = op.apply(cur, cap: _cap)!; // legal by construction
      usage[op.id] = (usage[op.id] ?? 0) + 1;
      usedOp[op.id] = op;
    }
    final target = cur;
    if (target == start) return null;

    // Op set: used ops (tokens = usage + headroom) + decoys to fill the pad.
    final ops = <Operation>[];
    usage.forEach((id, count) {
      final o = usedOp[id]!;
      final t = count + spec.extraTokens;
      ops.add(Operation(id: id, symbol: o.symbol, n: o.n, tokens: t < 1 ? 1 : t));
    });
    final ids = ops.map((o) => o.id).toSet();
    var guard = 0;
    while (ops.length < 6 && guard++ < 200) { // 6 ops fill the 3-col pad
      final o = _randomOp(rng, spec);
      if (ids.add(o.id)) {
        ops.add(Operation(
          id: o.id,
          symbol: o.symbol,
          n: o.n,
          tokens: spec.extraTokens > 0 ? 2 : 1,
        ));
      }
    }
    ops.shuffle(rng); // don't leak the solution by op ordering

    // Honest par via BFS over the assembled op set.
    final probe = Puzzle(
      no: no,
      dateLabel: dateLabel,
      start: start,
      target: target,
      par: targetPar,
      ops: ops,
      cap: _cap,
    );
    // One BFS yields both the honest par and the answer path — so the op
    // choices and the stored solution are always in sync.
    final path = solvePath(probe);
    if (path == null) return null; // unreachable — a chain exists by build
    final trueMin = path.length;

    if (relaxed) {
      if (trueMin < 2) return null;
    } else {
      if (trueMin < spec.minPar || trueMin > spec.maxPar) return null;
      if (_trivial(usage, usedOp)) return null;
    }

    return Puzzle(
      no: no,
      dateLabel: dateLabel,
      start: start,
      target: target,
      par: trueMin,
      ops: ops,
      cap: _cap,
      solution: path,
    );
  }

  /// Reject boring chains: pure addition (monotonic, greedy-obvious).
  bool _trivial(Map<String, int> usage, Map<String, Operation> usedOp) {
    return usage.keys.every((id) => usedOp[id]!.symbol == '+');
  }

  /// Legal forward ops from [cur], keeping every intermediate in `[1, maxTarget]`.
  List<Operation> _legalFrom(int cur, DifficultySpec spec) {
    final out = <Operation>[];
    for (final o in _candidates(spec)) {
      final r = o.apply(cur, cap: _cap);
      if (r == null || r < 1 || r > spec.maxTarget || r == cur) continue;
      out.add(o);
    }
    return out;
  }

  Operation _randomOp(Random rng, DifficultySpec spec) {
    final pool = _candidates(spec);
    return pool[rng.nextInt(pool.length)];
  }

  /// The operand pool for a tier. Tokens here are placeholders (set on use).
  List<Operation> _candidates(DifficultySpec spec) {
    final list = <Operation>[
      _op('×', 2), _op('×', 3),
      for (var n = 1; n <= 9; n++) _op('+', n),
      for (var n = 1; n <= 5; n++) _op('−', n),
    ];
    if (spec.maxTarget >= 300) list.add(_op('×', 4));
    if (spec.allowDivide) {
      list..add(_op('÷', 2))..add(_op('÷', 3));
    }
    return list;
  }

  Operation _op(String symbol, int n) =>
      Operation(id: '${_prefix[symbol]}$n', symbol: symbol, n: n, tokens: 0);

  /// Absolute safety net — the handoff puzzle. Only reached if generation
  /// somehow exhausts every attempt (not observed in tests).
  Puzzle _fallback(int no, String dateLabel) => Puzzle(
        no: no,
        dateLabel: dateLabel,
        start: 2,
        target: 26,
        par: 3,
        solution: const ['m3', 'p7', 'm2'], // 2 →×3→ 6 →+7→ 13 →×2→ 26
        ops: const [
          Operation(id: 'm3', symbol: '×', n: 3, tokens: 2),
          Operation(id: 'p7', symbol: '+', n: 7, tokens: 2),
          Operation(id: 'm2', symbol: '×', n: 2, tokens: 3),
          Operation(id: 's1', symbol: '−', n: 1, tokens: 3),
          Operation(id: 'd2', symbol: '÷', n: 2, tokens: 2),
          Operation(id: 'p5', symbol: '+', n: 5, tokens: 2),
        ],
      );
}
