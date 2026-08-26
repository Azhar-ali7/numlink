import 'package:flutter_test/flutter_test.dart';
import 'package:numlink_app/game/stranding.dart';
import 'package:numlink_app/game/tree_generator.dart';

String sig(TreePuzzle p) => [
      p.tier,
      p.start,
      p.targets.join(','),
      p.par,
      p.optimalPar,
      for (final h in p.hands)
        h.map((o) => '${o.id}:${o.symbol}:${o.n}:${o.tokens}').join('|'),
    ].join('#');

void main() {
  // Port of the prototype `runSelfCheck` (generator-only invariants — the
  // guard false-pos/neg checks land with the controller in phase 3).
  group('buildPuzzle self-check', () {
    const tiers = ['kids', 'easy', 'medium', 'hard'];
    const n = 30;

    for (final tier in tiers) {
      test('$tier: honest, solvable, deterministic', () {
        for (var i = 0; i < n; i++) {
          final seed = 5000000 + i * 97 + tier.length * 31337;
          final p = buildPuzzle(tier, seed);

          // determinism: same seed → identical board
          expect(sig(buildPuzzle(tier, seed)), sig(p), reason: '$tier #$i not deterministic');

          // par is never below the true optimum
          expect(p.par, greaterThanOrEqualTo(p.optimalPar), reason: '$tier #$i par < optimum');

          // the DEALT hand can actually reach every target within the depth cap
          expect(
            solveFrom([(v: p.start, d: 0)], p.targets, p.hands[0], p.branchMax),
            isTrue,
            reason: '$tier #$i unreachable with dealt hand',
          );

          // no value below 1
          expect(p.targets.every((t) => t >= 1), isTrue, reason: '$tier #$i target < 1');
          expect(p.optimalEdges.every((e) => e.$2 >= 1), isTrue, reason: '$tier #$i edge value < 1');

          // structural sanity
          expect(p.targets.length, inInclusiveRange(kTiers[tier]!.targetsMin, kTiers[tier]!.targetsMax));
          expect(p.hands.length, kTiers[tier]!.shuffles + 1);
          expect(p.targets.toSet().length, p.targets.length, reason: '$tier #$i duplicate targets');
        }
      });
    }
  });

  // The regression guard for the null-`kinds` bug: `easy`/`medium`/`hard` used
  // to leave `kinds` unset, and `makeHand`'s fallback then dealt ÷ % Σ to every
  // tier — which is how the "easy" campaign opener came to be anything but.
  test('kids stays kids: one target, one move, + − × only', () {
    for (var i = 0; i < 30; i++) {
      final p = buildPuzzle('kids', 5000 + i * 97);
      expect(p.targets.length, 1, reason: 'kids #$i should have one target');
      expect(p.branchMax, 1, reason: 'kids #$i should be one move deep');
      expect(p.hints, 3, reason: 'kids #$i should deal three hints');
      for (final hand in p.hands) {
        for (final o in hand) {
          expect(['+', '−', '×'], contains(o.symbol),
              reason: 'kids #$i dealt ${o.symbol}');
        }
      }
    }
  });

  test('different seeds generally differ', () {
    final a = buildPuzzle('medium', 111);
    final b = buildPuzzle('medium', 222);
    expect(sig(a), isNot(sig(b)));
  });
}
