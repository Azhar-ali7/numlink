import 'dart:math' show sqrt;

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

  /// Display label, e.g. `×3`. Unary ops (√ Σ) and square drop the operand.
  String get label => switch (symbol) {
        '√' => '√',
        'Σ' => 'Σ',
        '^' => 'x²',
        _ => '$symbol$n',
      };

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
      case '%': // modulo — remainder of cur ÷ n
        if (n <= 0) return null;
        r = cur % n;
      case '^': // square (operand ignored; label x²)
        r = cur * cur;
      case '√': // integer (floored) square root — unary
        r = sqrt(cur).floor();
      case 'Σ': // digit sum — unary
        r = _digitSum(cur);
      default:
        return null;
    }
    if (r != r.roundToDouble() || r < 0 || r > cap) return null;
    return r.toInt();
  }

  static int _digitSum(int v) {
    var x = v.abs(), s = 0;
    while (x > 0) {
      s += x % 10;
      x ~/= 10;
    }
    return s;
  }

  Map<String, dynamic> toJson() =>
      {'id': id, 'symbol': symbol, 'n': n, 'tokens': tokens};

  factory Operation.fromJson(Map<String, dynamic> j) => Operation(
        id: j['id'] as String,
        symbol: j['symbol'] as String,
        n: j['n'] as int,
        tokens: j['tokens'] as int,
      );
}
