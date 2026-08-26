import 'package:flutter_test/flutter_test.dart';
import 'package:numlink_app/game/stranding.dart';
import 'package:numlink_app/models/operation.dart';

Operation op(String id, String symbol, int n, {int tokens = 3}) =>
    Operation(id: id, symbol: symbol, n: n, tokens: tokens);

List<({int v, int d})> tree(List<(int, int)> vs) =>
    [for (final e in vs) (v: e.$1, d: e.$2)];

void main() {
  group('permute', () {
    test('all orderings, no loss', () {
      final ps = permute([1, 2, 3]);
      expect(ps.length, 6);
      expect(ps.map((p) => p.join()).toSet(),
          {'123', '132', '213', '231', '312', '321'});
    });
    test('trivial sizes', () {
      expect(permute([]).length, 1);
      expect(permute([9]), [
        [9]
      ]);
    });
  });

  group('solveFrom', () {
    test('single target reachable in one hop', () {
      expect(solveFrom(tree([(2, 0)]), [6], [op('m', '×', 3, tokens: 1)], 3),
          isTrue);
    });

    test('two arms sharing a hand (distinct ops)', () {
      expect(
        solveFrom(tree([(2, 0)]), [6, 12],
            [op('m', '×', 3, tokens: 1), op('d', '×', 2, tokens: 1)], 3),
        isTrue,
      );
    });

    test('false when a token budget is exhausted across arms', () {
      // 6 = 2×3, 18 = 6×3, but only ONE ×3 token exists → cannot do both.
      expect(
        solveFrom(tree([(2, 0)]), [6, 18], [op('m', '×', 3, tokens: 1)], 3),
        isFalse,
      );
    });

    test('respects the per-arm depth cap', () {
      final hand = [op('p', '+', 1, tokens: 5)];
      expect(solveFrom(tree([(2, 0)]), [5], hand, 2), isFalse); // needs 3 hops
      expect(solveFrom(tree([(2, 0)]), [5], hand, 3), isTrue);
    });

    test('a target already on the tree is trivially satisfied', () {
      expect(solveFrom(tree([(2, 0), (6, 1)]), [6],
          [op('m', '×', 3, tokens: 0)], 3), isTrue);
    });

    test('tokensLeft override caps the available budget', () {
      final hand = [op('m', '×', 3, tokens: 3)];
      expect(solveFrom(tree([(2, 0)]), [6], hand, 3, {'×3': 0}), isFalse);
      expect(solveFrom(tree([(2, 0)]), [6], hand, 3, {'×3': 1}), isTrue);
    });
  });
}
