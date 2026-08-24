import 'steiner.dart' show compute;
import '../models/operation.dart';

/// One produced step on a candidate arm. `sig` keys the token budget; `to` is
/// the produced value at depth `d`.
typedef Step = ({String sig, int to, int d});

/// A live tree node: value [v] at depth [d].
typedef Vd = ({int v, int d});

/// All permutations of [arr] (k ≤ 5 ⇒ ≤ 120).
List<List<int>> permute(List<int> arr) {
  if (arr.length <= 1) return [arr.toList()];
  final out = <List<int>>[];
  for (var i = 0; i < arr.length; i++) {
    final rest = [...arr.sublist(0, i), ...arr.sublist(i + 1)];
    for (final p in permute(rest)) {
      out.add([arr[i], ...p]);
    }
  }
  return out;
}

/// Token-aware reachability: can [nodes] still reach every [missing] target with
/// the tokens left? Tries every ordering of the targets (a fixed sample lets a
/// greedy first arm steal a tile a later target needs → false "stranded"). A
/// memo keyed by (target, existing values, remaining tokens) is shared across
/// orders. [tokensLeft] (by op signature) caps the budget; when null, each
/// tile's full `tokens` is used.
bool solveFrom(List<Vd> nodes, List<int> missing, List<Operation> hand,
    int branchMax, [Map<String, int>? tokensLeft]) {
  final caps = <String, int>{};
  for (final o in hand) {
    caps[o.opSig] = tokensLeft != null ? (tokensLeft[o.opSig] ?? 0) : o.tokens;
  }
  final orders = missing.isNotEmpty ? permute(missing) : [<int>[]];
  final memo = <String, List<Step>?>{};
  for (final order in orders) {
    final tree = [for (final n in nodes) (v: n.v, d: n.d)];
    final left = Map<String, int>.from(caps);
    var ok = true;
    for (final t in order) {
      if (tree.any((n) => n.v == t)) continue;
      final arm = _armTo(tree, t, hand, branchMax, left, memo);
      if (arm == null) {
        ok = false;
        break;
      }
      for (final st in arm) {
        left[st.sig] = (left[st.sig] ?? 0) - 1;
        tree.add((v: st.to, d: st.d));
      }
    }
    if (ok) return true;
  }
  return false;
}

/// Shortest token-legal arm from any tree node to [target], never revisiting a
/// value already on the board or produced earlier on this same arm. Layered
/// BFS ≤ [branchMax] steps with a same-step dominance prune (cheapest arm to
/// each value) and a shared [memo].
List<Step>? _armTo(List<Vd> tree, int target, List<Operation> hand,
    int branchMax, Map<String, int> left, Map<String, List<Step>?> memo) {
  final existing = [for (final n in tree) n.v]..sort();
  final leftArr = [for (final o in hand) left[o.opSig] ?? 0];
  final cacheKey = '$target|${existing.join(',')}|${leftArr.join(',')}';
  if (memo.containsKey(cacheKey)) return memo[cacheKey];

  final existingSet = existing.toSet();
  var front = [
    for (final n in tree) _Front(n.v, n.d, List.filled(hand.length, 0), const [])
  ];
  List<Step>? result;
  outer:
  for (var step = 0; step < branchMax; step++) {
    final bestAt = <int, _Front>{};
    final bestTotal = <int, int>{};
    for (final cur in front) {
      if (cur.d >= branchMax) continue;
      for (var hi = 0; hi < hand.length; hi++) {
        if (cur.spent[hi] >= leftArr[hi]) continue;
        final o = hand[hi];
        final r = compute(cur.v, o);
        if (r == null || r == cur.v) continue;
        if (existingSet.contains(r) || cur.path.any((st) => st.to == r)) continue;
        final path = [...cur.path, (sig: o.opSig, to: r, d: cur.d + 1)];
        if (r == target) {
          result = path;
          break outer;
        }
        final spentTotal = cur.spent.fold<int>(0, (a, b) => a + b) + 1;
        final prev = bestTotal[r];
        if (prev != null && prev <= spentTotal) continue;
        final spent = [...cur.spent];
        spent[hi] += 1;
        bestAt[r] = _Front(r, cur.d + 1, spent, path);
        bestTotal[r] = spentTotal;
      }
    }
    front = bestAt.values.toList();
    if (front.isEmpty) break;
  }
  memo[cacheKey] = result;
  return result;
}

class _Front {
  _Front(this.v, this.d, this.spent, this.path);
  final int v;
  final int d;
  final List<int> spent;
  final List<Step> path;
}
