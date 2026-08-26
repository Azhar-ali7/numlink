import 'package:flutter_test/flutter_test.dart';
import 'package:numlink_app/game/rng.dart';

void main() {
  group('minstd (Park–Miller)', () {
    test('matches the known seed-1 stream (cross-platform reproducibility)', () {
      final rnd = minstd(1);
      // Classic MINSTD state sequence for seed 1.
      expect((rnd() * 2147483647).round(), 16807);
      expect((rnd() * 2147483647).round(), 282475249);
      expect((rnd() * 2147483647).round(), 1622650073);
    });

    test('same seed → identical sequence; different seed → different', () {
      final a = minstd(42), b = minstd(42), c = minstd(43);
      final sa = [for (var i = 0; i < 5; i++) a()];
      final sb = [for (var i = 0; i < 5; i++) b()];
      final sc = [for (var i = 0; i < 5; i++) c()];
      expect(sa, sb);
      expect(sa, isNot(sc));
    });

    test('outputs are in [0,1)', () {
      final rnd = minstd(7);
      for (var i = 0; i < 1000; i++) {
        final x = rnd();
        expect(x, greaterThanOrEqualTo(0));
        expect(x, lessThan(1));
      }
    });
  });

  group('shuffleInPlace (Fisher–Yates)', () {
    test('is deterministic for a given seed', () {
      final l1 = [for (var i = 0; i < 10; i++) i];
      final l2 = [for (var i = 0; i < 10; i++) i];
      shuffleInPlace(l1, minstd(99));
      shuffleInPlace(l2, minstd(99));
      expect(l1, l2);
    });

    test('is a permutation (no loss/dup)', () {
      final l = [for (var i = 0; i < 20; i++) i];
      shuffleInPlace(l, minstd(5));
      expect(l.toSet(), {for (var i = 0; i < 20; i++) i});
      expect(l.length, 20);
    });
  });
}
