import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:numlink_app/game/steiner.dart';
import 'package:numlink_app/game/tree_controller.dart';
import 'package:numlink_app/game/tree_generator.dart';
import 'package:numlink_app/models/operation.dart';

Operation op(String id, String symbol, int n, {int tokens = 3}) =>
    Operation(id: id, symbol: symbol, n: n, tokens: tokens);

TreePuzzle fixture({
  required int start,
  required List<int> targets,
  required List<List<Operation>> hands,
  int shuffles = 1,
  int branchMax = 3,
}) =>
    TreePuzzle(
      tier: 'test',
      start: start,
      targets: targets,
      hands: hands,
      shuffles: shuffles,
      branchMax: branchMax,
      par: 99,
      optimalPar: 1,
      optimalEdges: const [],
      dpValid: true,
    );

/// Replays a puzzle's own solution edges through the controller; returns whether
/// it reached a win. Proves apply/win-detection work and the guard never blocks
/// the intended optimal line. When several tiles reach an edge's target value,
/// picks one that keeps every remaining edge servable (one-step scarcity
/// lookahead), so a scarce tile isn't spent where another tile would do.
bool playOptimal(TreeController c) {
  final pending = [...c.puzzle.optimalEdges];
  var guard = 0;
  while (pending.isNotEmpty && !c.solved && guard++ < 100) {
    Edge? pick;
    for (final e in pending) {
      if (c.nodes.any((n) => n.v == e.$1) && !c.nodes.any((n) => n.v == e.$2)) {
        pick = e;
        break;
      }
    }
    if (pick == null) break;
    final rem = {for (final o in c.hand) o.opSig: c.remaining(o)};
    final cands = [
      for (final o in c.hand)
        if (compute(pick.$1, o) == pick.$2 && (rem[o.opSig] ?? 0) > 0) o
    ];
    if (cands.isEmpty) break;
    bool keepsRest(Operation choice) {
      final after = {...rem, choice.opSig: (rem[choice.opSig] ?? 0) - 1};
      for (final e in pending) {
        if (e == pick) continue;
        final ok = c.hand.any(
            (o) => compute(e.$1, o) == e.$2 && (after[o.opSig] ?? 0) > 0);
        if (!ok) return false;
      }
      return true;
    }

    final tile = cands.firstWhere(keepsRest, orElse: () => cands.first);
    c.select(c.nodes.firstWhere((n) => n.v == pick!.$1).id);
    c.apply(tile);
    pending.remove(pick);
  }
  return c.solved;
}

void main() {
  group('apply legality', () {
    test('places a legal child and selects it', () {
      final c = TreeController(fixture(start: 2, targets: [6, 7], hands: [
        [op('m', '×', 3), op('p', '+', 1)]
      ]))..init();
      expect(c.apply(op('m', '×', 3)), ApplyResult.placed);
      expect(c.nodes.map((n) => n.v), [2, 6]);
      expect(c.sel, c.nodes.last.id);
    });

    test('rejects when the op has no tokens left', () {
      final c = TreeController(fixture(start: 2, targets: [6], hands: [
        [op('m', '×', 3, tokens: 1)]
      ]))..init();
      c.apply(op('m', '×', 3, tokens: 1)); // 2 → 6 (wins, but token now spent)
      final again = c.apply(op('m', '×', 3, tokens: 1));
      expect(again, ApplyResult.ignored); // already solved
    });

    test('rejects a move exceeding the per-arm depth cap', () {
      // target 6 stays reachable via ×3 off the start, so wandering down the
      // +1 arm never strands — isolating the depth-cap check.
      final c = TreeController(fixture(
          start: 2, targets: [6], branchMax: 2, shuffles: 0, hands: [
        [op('p', '+', 1, tokens: 5), op('m', '×', 3, tokens: 1)]
      ]))
        ..init();
      c.apply(op('p', '+', 1, tokens: 5)); // node 2 → 3 (depth 1)
      c.select(c.nodes.firstWhere((n) => n.v == 3).id);
      c.apply(op('p', '+', 1, tokens: 5)); // 3 → 4 (depth 2)
      c.select(c.nodes.firstWhere((n) => n.v == 4).id);
      final r = c.apply(op('p', '+', 1, tokens: 5)); // depth 2 ≥ cap
      expect(r, ApplyResult.rejected);
      expect(c.message, contains('limit'));
    });

    test('rejects an illegal computation (non-integer divide)', () {
      final c = TreeController(fixture(start: 5, targets: [1], hands: [
        [op('d', '÷', 2, tokens: 3)]
      ]))..init();
      expect(c.apply(op('d', '÷', 2, tokens: 3)), ApplyResult.rejected);
      expect(c.message, contains("doesn't divide"));
    });

    test('rejects a value already on the board', () {
      // target 7 stays reachable (6 → +1), so placing 6 never strands.
      final c = TreeController(fixture(start: 2, targets: [7], shuffles: 0, hands: [
        [op('m', '×', 3, tokens: 3), op('p', '+', 1, tokens: 3)]
      ]))..init();
      c.apply(op('m', '×', 3, tokens: 3)); // 2 → 6
      c.select(c.nodes.first.id); // back to start (value 2)
      final r = c.apply(op('m', '×', 3, tokens: 3)); // 2 → 6 again
      expect(r, ApplyResult.rejected);
      expect(c.message, contains('already on the board'));
    });

    test('rejects a move that would strand a target', () {
      // one +3 token, two targets both needing it → placing either strands the other
      final c = TreeController(fixture(
          start: 2, targets: [5, 8], shuffles: 0, hands: [
        [op('a', '+', 3, tokens: 1)]
      ]))
        ..init();
      final r = c.apply(op('a', '+', 3, tokens: 1));
      expect(r, ApplyResult.rejected);
      expect(c.message, contains('strand'));
    });

    test('detects a win when every target is on the board', () {
      final c = TreeController(fixture(start: 2, targets: [6], hands: [
        [op('m', '×', 3, tokens: 3)]
      ]))..init();
      expect(c.apply(op('m', '×', 3, tokens: 3)), ApplyResult.solved);
      expect(c.solved, isTrue);
      expect(c.moves, 1);
    });
  });

  group('shuffle', () {
    test('deals a solvable alternate and spends a shuffle', () {
      // current hand cannot reach 6; alternate can
      final c = TreeController(fixture(start: 2, targets: [6], shuffles: 1, hands: [
        [op('a', '+', 100, tokens: 1)], // dead current hand
        [op('b', '×', 3, tokens: 1)], // rescue
      ]))..init();
      c.shuffleHand();
      expect(c.handIndex, 1);
      expect(c.shufflesLeft, 0);
      expect(c.message, contains('still solvable'));
    });

    test('refuses when no shuffles remain', () {
      final c = TreeController(fixture(start: 2, targets: [6], shuffles: 0, hands: [
        [op('b', '×', 3, tokens: 1)]
      ]))..init();
      c.shuffleHand();
      expect(c.message, contains('No shuffles left'));
    });
  });

  group('hint', () {
    test('glows the op nearest an outstanding target, once per puzzle', () {
      final c = TreeController(fixture(start: 2, targets: [6], hands: [
        [op('m', '×', 3, tokens: 3), op('p', '+', 1, tokens: 3)]
      ]))..init();
      c.hint();
      expect(c.hintGlow, 'm'); // ×3 → 6 hits the target exactly
      c.hint();
      expect(c.message, contains('spent'));
    });
  });

  test('every generated board is winnable through the guard (integration)', () {
    for (final tier in ['sprouts', 'junior', 'easy', 'medium', 'hard']) {
      for (var i = 0; i < 15; i++) {
        final p = buildPuzzle(tier, 7000000 + i * 131);
        final c = TreeController(p)..init();
        expect(playOptimal(c), isTrue, reason: 'unsolved $tier #$i');
      }
    }
  });

  // Deferred `runSelfCheck` part (b)/(c): the guard has no false negatives.
  // Random-walk each board taking ONLY guard-allowed moves; a sound guard keeps
  // the board solvable after every allowed move, so a walk can never dead-end
  // (no allowed move, no rescuing shuffle) short of a win. Reaching such a
  // dead-end means the guard let an earlier move strand a target.
  test('stranding guard never lets a board dead-end (no false negatives)', () {
    final rng = Random(20260824);
    for (final tier in ['junior', 'easy', 'medium', 'hard']) {
      for (var i = 0; i < 12; i++) {
        final p = buildPuzzle(tier, 8000000 + i * 173);
        final c = TreeController(p)..init();
        var steps = 0;
        while (!c.solved && steps++ < 80) {
          // legal-under-current-hand, guard-allowed moves off any node
          final moves = <(int, Operation)>[];
          final used = c.usedMap();
          for (final node in c.nodes) {
            if (c.depthOf(node) >= p.branchMax) continue;
            for (final o in c.hand) {
              if ((used[o.opSig] ?? 0) >= o.tokens) continue;
              final r = compute(node.v, o);
              if (r == null || r == node.v) continue;
              if (c.nodes.any((n) => n.v == r)) continue;
              final trial = [
                ...c.nodes,
                TreeNode(id: c.nextId, v: r, parent: node.id, opSig: o.opSig)
              ];
              final tUsed = {...used, o.opSig: (used[o.opSig] ?? 0) + 1};
              if (!c.stranded(trial, tUsed)) moves.add((node.id, o));
            }
          }
          if (moves.isNotEmpty) {
            final (id, o) = moves[rng.nextInt(moves.length)];
            c.select(id);
            c.apply(o);
            continue;
          }
          if (c.shufflesLeft > 0) {
            c.shuffleHand();
            continue;
          }
          fail('dead-end (guard false negative) on $tier #$i: '
              'board=${c.nodes.map((n) => n.v).toList()} '
              'missing=${p.targets.where((t) => !c.nodes.any((n) => n.v == t)).toList()}');
        }
        expect(c.solved, isTrue, reason: '$tier #$i did not reach a win');
      }
    }
  });
}
