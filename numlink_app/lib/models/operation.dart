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

  /// Display label, e.g. `×3`. Unary ops (√ Σ ↺) and square drop the operand;
  /// binary ops (incl. concat ⧺) keep it.
  String get label => switch (symbol) {
        '√' => '√',
        'Σ' => 'Σ',
        '↺' => '↺',
        '^' => 'x²',
        _ => '$symbol$n',
      };

  /// Unary ops ignore their operand: √ Σ ↺ and square (`^`). Everything else —
  /// including concat (`⧺`) — is binary and keeps its operand.
  bool get isUnary => symbol == '√' || symbol == 'Σ' || symbol == '↺' || symbol == '^';

  /// Token-accounting identity, ported from the prototype `sig`: unary ops key
  /// by kind (`u`-prefixed), binary ops by kind+operand. Signatures collide
  /// across shuffled hands on purpose, so a spent token stays spent.
  String get opSig => isUnary ? 'u$symbol' : '$symbol$n';

  Map<String, dynamic> toJson() =>
      {'id': id, 'symbol': symbol, 'n': n, 'tokens': tokens};

  factory Operation.fromJson(Map<String, dynamic> j) => Operation(
        id: j['id'] as String,
        symbol: j['symbol'] as String,
        n: j['n'] as int,
        tokens: j['tokens'] as int,
      );
}
