import 'package:flutter_test/flutter_test.dart';
import 'package:numlink_app/models/operation.dart';

Operation op(String symbol, int n) =>
    Operation(id: 'x', symbol: symbol, n: n, tokens: 1);

void main() {
  group('new operators', () {
    test('modulo', () {
      expect(op('%', 7).apply(20), 6);
      expect(op('%', 5).apply(12), 2);
      expect(op('%', 0).apply(9), isNull); // guard against n<=0
      expect(op('%', 4).apply(4), 0); // divisible → 0 is legal
    });

    test('square (x²) self-limits at the cap', () {
      expect(op('^', 2).apply(6), 36);
      expect(op('^', 2).apply(40), isNull); // 1600 > 999 cap
      expect(op('^', 2).apply(31), 961);
    });

    test('integer (floored) root', () {
      expect(op('√', 0).apply(81), 9);
      expect(op('√', 0).apply(82), 9); // floor(9.05…)
      expect(op('√', 0).apply(80), 8);
    });

    test('digit sum', () {
      expect(op('Σ', 0).apply(256), 13);
      expect(op('Σ', 0).apply(9), 9);
      expect(op('Σ', 0).apply(100), 1);
    });

    test('labels drop the operand for unary ops', () {
      expect(op('%', 7).label, '%7');
      expect(op('^', 2).label, 'x²');
      expect(op('√', 0).label, '√');
      expect(op('Σ', 0).label, 'Σ');
      expect(op('×', 3).label, '×3'); // unchanged
    });
  });

  // Phase 1 of the branching-tree migration: the prototype's alchemy operators
  // and the operator-signature identity used for token accounting.
  group('branching-tree operators', () {
    test('digit-reverse (↺)', () {
      expect(op('↺', 0).apply(250), 52); // "250" → "052" → 52
      expect(op('↺', 0).apply(19), 91);
      expect(op('↺', 0).apply(100), 1); // "100" → "001" → 1
      expect(op('↺', 0).apply(9), 9);
    });

    test('concat-digit (⧺) = cur*10 + n', () {
      expect(op('⧺', 3).apply(5), 53);
      expect(op('⧺', 0).apply(12), 120);
      expect(op('⧺', 9).apply(99), 999); // == cap, legal
      expect(op('⧺', 1).apply(100), isNull); // 1001 > 999 cap
    });

    test('isUnary: alchemy unaries drop their operand, others keep it', () {
      for (final s in ['√', 'Σ', '^', '↺']) {
        expect(op(s, 0).isUnary, isTrue, reason: '$s should be unary');
      }
      for (final s in ['×', '+', '−', '÷', '%', '⧺']) {
        expect(op(s, 3).isUnary, isFalse, reason: '$s should be binary');
      }
    });

    test('opSig: unary keys by kind (u-prefixed), binary by kind+operand', () {
      expect(op('×', 3).opSig, '×3');
      expect(op('÷', 2).opSig, '÷2');
      expect(op('⧺', 3).opSig, '⧺3'); // binary — operand kept
      expect(op('√', 0).opSig, 'u√');
      expect(op('Σ', 0).opSig, 'uΣ');
      expect(op('^', 2).opSig, 'u^');
      expect(op('↺', 0).opSig, 'u↺');
    });

    test('⧺ label keeps its operand', () {
      expect(op('⧺', 3).label, '⧺3');
      expect(op('↺', 0).label, '↺');
    });
  });
}
