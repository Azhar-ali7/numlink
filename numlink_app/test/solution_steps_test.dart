import 'package:flutter_test/flutter_test.dart';
import 'package:numlink_app/game/tree_generator.dart';
import 'package:numlink_app/models/operation.dart';
import 'package:numlink_app/screens/tree_game_page.dart';

Operation op(String id, String symbol, int n) =>
    Operation(id: id, symbol: symbol, n: n, tokens: 3);

void main() {
  test('solutionSteps orders start-outward and labels each edge', () {
    // 2 →×3→ 6 →+1→ 7. Edges given out of order to exercise the ordering.
    final p = TreePuzzle(
      tier: 'test',
      start: 2,
      targets: const [6, 7],
      hands: [
        [op('m', '×', 3), op('p', '+', 1)]
      ],
      hints: 1,
      shuffles: 1,
      branchMax: 3,
      par: 3,
      optimalPar: 2,
      optimalEdges: const [(6, 7), (2, 6)],
      dpValid: true,
    );
    final steps = solutionSteps(p);
    expect(steps.map((s) => (s.n, s.from, s.op, s.to)).toList(), [
      (1, 2, '×3', 6),
      (2, 6, '+1', 7),
    ]);
  });
}
