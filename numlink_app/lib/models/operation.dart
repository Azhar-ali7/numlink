/// A single arithmetic operation the player can chain, with a token cap.
class Operation {
  const Operation({
    required this.id,
    required this.symbol,
    required this.n,
    required this.tokens,
  });

  /// Stable id, e.g. `m3`.
  final String id;

  /// One of `×`, `+`, `−`, `÷`.
  final String symbol;

  /// The operand.
  final int n;

  /// How many times this op may be used in a puzzle.
  final int tokens;

  /// Display label, e.g. `×3`.
  String get label => '$symbol$n';

  /// Applies the op to [cur]; returns null if the result is illegal
  /// (non-integer, `< 0`, or `> cap`).
  int? apply(int cur, {int cap = 999}) {
    final num r;
    switch (symbol) {
      case '×':
        r = cur * n;
      case '+':
        r = cur + n;
      case '−':
        r = cur - n;
      case '÷':
        if (cur % n != 0) return null;
        r = cur ~/ n;
      default:
        return null;
    }
    if (r != r.roundToDouble() || r < 0 || r > cap) return null;
    return r.toInt();
  }
}
