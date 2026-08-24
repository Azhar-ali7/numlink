import 'package:flutter_test/flutter_test.dart';
import 'package:numlink_app/game/steiner.dart';
import 'package:numlink_app/models/operation.dart';

Operation op(String id, String symbol, int n, {int tokens = 3}) =>
    Operation(id: id, symbol: symbol, n: n, tokens: tokens);

void main() {
  group('compute (prototype-faithful evaluator)', () {
    test('√ is perfect-square-only (not floored)', () {
      expect(compute(81, op('r', '√', 0)), 9);
      expect(compute(82, op('r', '√', 0)), isNull); // not a perfect square
      expect(compute(80, op('r', '√', 0)), isNull);
    });

    test('value floor is 1 (0 and negative are illegal)', () {
      expect(compute(4, op('m', '%', 4)), isNull); // 4 % 4 == 0 → illegal
      expect(compute(3, op('s', '−', 3)), isNull); // 0 → illegal
      expect(compute(3, op('s', '−', 5)), isNull); // negative → illegal
      expect(compute(3, op('s', '−', 1)), 2); // 2 ≥ 1 → legal
    });

    test('cap is 999', () {
      expect(compute(100, op('c', '⧺', 1)), isNull); // 1001 > 999
      expect(compute(99, op('c', '⧺', 9)), 999);
    });
  });

  group('steinerSolve', () {
    test('single target, one hop', () {
      final r = steinerSolve(2, [6], [op('m', '×', 3)], 3);
      expect(r.cost, 1);
      expect(r.edges, [(2, 6)]);
    });

    test('single target, two hops (finds the minimum)', () {
      final r = steinerSolve(2, [7], [op('m', '×', 3), op('p', '+', 1)], 3);
      expect(r.cost, 2);
      expect(r.edges.toSet(), {(2, 6), (6, 7)});
    });

    test('two targets share a branch → one tree', () {
      final r = steinerSolve(2, [6, 7], [op('m', '×', 3), op('p', '+', 1)], 3);
      expect(r.cost, 2);
      expect(r.edges.toSet(), {(2, 6), (6, 7)});
    });

    test('unreachable target → null cost', () {
      final r = steinerSolve(2, [5], [op('p', '+', 2)], 5); // only even values
      expect(r.cost, isNull);
      expect(r.edges, isEmpty);
    });

    test('respects the per-arm depth cap', () {
      final ops = [op('p', '+', 1)];
      expect(steinerSolve(2, [5], ops, 2).cost, isNull); // needs 3 hops
      expect(steinerSolve(2, [5], ops, 3).cost, 3);
    });
  });

  group('validateHandCovers', () {
    test('true when the hand can build the edges within token caps', () {
      final edges = [(2, 6), (6, 7)];
      expect(
        validateHandCovers(edges, [op('m', '×', 3, tokens: 1), op('p', '+', 1, tokens: 1)]),
        isTrue,
      );
    });

    test('false when a needed op is missing', () {
      expect(validateHandCovers([(2, 6), (6, 7)], [op('m', '×', 3, tokens: 1)]), isFalse);
    });

    test('false when token caps run out', () {
      // both edges need ×2 but only one token available
      expect(validateHandCovers([(2, 4), (4, 8)], [op('d', '×', 2, tokens: 1)]), isFalse);
      expect(validateHandCovers([(2, 4), (4, 8)], [op('d', '×', 2, tokens: 2)]), isTrue);
    });
  });

  group('edgesFormUniqueTree', () {
    test('true for a tree with all-distinct values', () {
      expect(edgesFormUniqueTree(2, [(2, 6), (6, 7)]), isTrue);
    });

    test('false when a value repeats', () {
      expect(edgesFormUniqueTree(2, [(2, 6), (6, 2)]), isFalse);
    });
  });
}
