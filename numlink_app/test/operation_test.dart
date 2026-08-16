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
}
