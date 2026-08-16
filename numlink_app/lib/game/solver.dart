import '../models/operation.dart';
import '../models/puzzle.dart';

/// BFS solver over the op set. [solvePath] returns the op-id sequence of a
/// shortest solution (the puzzle's honest answer path); [minMoves] is just its
/// length. Used at generation time to guarantee solvability + honest par, and
/// at play time to power hints ("next best move from here") and the reveal.
///
/// Returns the sequence of [Operation.id]s of a shortest path from [from]
/// (default [Puzzle.start]) to [Puzzle.target], respecting token caps and any
/// tokens already spent in [used]. Null if unreachable.
List<String>? solvePath(Puzzle p,
    {int? from, Map<String, int>? used, int fromMilestone = 0}) {
  final caps = {for (final o in p.ops) o.id: o.tokens};
  final ms = p.milestones;

  // State: current value + tokens consumed per op + count of milestones passed.
  String key(int value, Map<String, int> u, int idx) {
    final parts = p.ops.map((o) => u[o.id] ?? 0).join(',');
    return '$value|$parts|$idx';
  }

  final startVal = from ?? p.start;
  final startUsed = <String, int>{if (used != null) ...used};
  final startIdx = fromMilestone.clamp(0, ms.length);
  // Goal: land on target with every milestone already passed, in order.
  bool done(int v, int idx) => v == p.target && idx == ms.length;
  final seen = <String>{key(startVal, startUsed, startIdx)};
  var frontier = <_State>[_State(startVal, startUsed, const [], startIdx)];
  var depth = 0;

  while (frontier.isNotEmpty) {
    // Level-order BFS: the first frontier state at the goal carries a shortest
    // path (checked here so the already-solved case returns an empty path).
    for (final s in frontier) {
      if (done(s.value, s.idx)) return s.path;
    }
    final next = <_State>[];
    for (final s in frontier) {
      for (final Operation o in p.ops) {
        final usedN = s.used[o.id] ?? 0;
        if (usedN >= caps[o.id]!) continue;
        final r = o.apply(s.value, cap: p.cap);
        if (r == null) continue;
        // Consume the next milestone only when we land exactly on it.
        final nextIdx =
            (s.idx < ms.length && r == ms[s.idx]) ? s.idx + 1 : s.idx;
        final nextUsed = Map<String, int>.from(s.used)..[o.id] = usedN + 1;
        final k = key(r, nextUsed, nextIdx);
        if (seen.add(k)) {
          next.add(_State(r, nextUsed, [...s.path, o.id], nextIdx));
        }
      }
    }
    frontier = next;
    depth++;
    if (depth > 20) break; // safety bound
  }
  return null;
}

/// Minimum number of moves to reach [Puzzle.target] from [Puzzle.start]
/// respecting token caps, or null if unsolvable.
int? minMoves(Puzzle p) => solvePath(p)?.length;

class _State {
  const _State(this.value, this.used, this.path, this.idx);
  final int value;
  final Map<String, int> used;
  final List<String> path;
  final int idx;
}
