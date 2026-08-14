import '../models/operation.dart';
import '../models/puzzle.dart';

// ponytail: intentional YAGNI — only a test calls this today. Kept as the
// production seam for server-generated puzzles with honest, BFS-verified par.
/// BFS solver over the op set — the seam for the production path, where the
/// daily puzzle is generated server-side and par must be honest (the true
/// minimum move count) and solvability guaranteed.
///
/// Returns the minimum number of moves to reach [Puzzle.target] from
/// [Puzzle.start] respecting token caps, or null if unsolvable.
int? minMoves(Puzzle p) {
  final caps = {for (final o in p.ops) o.id: o.tokens};

  // State: current value + tokens consumed per op. Encode used-counts as a key.
  String key(int value, Map<String, int> used) {
    final parts = p.ops.map((o) => used[o.id] ?? 0).join(',');
    return '$value|$parts';
  }

  final start = <String, int>{};
  final seen = <String>{key(p.start, start)};
  var frontier = <_State>[_State(p.start, start)];
  var depth = 0;

  while (frontier.isNotEmpty) {
    if (frontier.any((s) => s.value == p.target)) return depth;
    final next = <_State>[];
    for (final s in frontier) {
      for (final Operation o in p.ops) {
        final usedN = s.used[o.id] ?? 0;
        if (usedN >= caps[o.id]!) continue;
        final r = o.apply(s.value, cap: p.cap);
        if (r == null) continue;
        final nextUsed = Map<String, int>.from(s.used)..[o.id] = usedN + 1;
        final k = key(r, nextUsed);
        if (seen.add(k)) next.add(_State(r, nextUsed));
      }
    }
    frontier = next;
    depth++;
    if (depth > 20) break; // safety bound
  }
  return null;
}

class _State {
  const _State(this.value, this.used);
  final int value;
  final Map<String, int> used;
}
