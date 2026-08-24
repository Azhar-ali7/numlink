import 'dart:collection';
import 'dart:math';

import '../models/operation.dart';

/// A value-to-value edge in the solution tree.
typedef Edge = (int from, int to);

/// Prototype-faithful evaluator for the branching-tree engine.
///
/// Differs from the legacy [Operation.apply] on purpose: `√` is
/// perfect-square-only (not floored) and the value floor is **1** (0 and
/// negatives are illegal). The legacy linear engine keeps [Operation.apply];
/// this is the single evaluator the branching-tree engine uses, and it replaces
/// `apply` once the old engine is retired.
int? compute(int cur, Operation o) {
  final int? r;
  switch (o.symbol) {
    case '×':
      r = cur * o.n;
    case '+':
      r = cur + o.n;
    case '−':
      r = cur - o.n;
    case '%':
      r = o.n > 0 ? cur % o.n : null;
    case '÷':
      r = (o.n != 0 && cur % o.n == 0) ? cur ~/ o.n : null;
    case 'Σ':
      r = _digitSum(cur);
    case '↺':
      r = _reverse(cur);
    case '^': // square (x²)
      r = cur * cur;
    case '⧺': // concat a fixed digit
      r = cur * 10 + o.n;
    case '√': // perfect-square only
      final s = sqrt(cur).round();
      r = (s >= 0 && s * s == cur) ? s : null;
    default:
      r = null;
  }
  if (r == null || r < 1 || r > 999) return null;
  return r;
}

int _digitSum(int v) {
  var x = v.abs(), s = 0;
  while (x > 0) {
    s += x % 10;
    x ~/= 10;
  }
  return s;
}

int _reverse(int v) => int.parse(v.abs().toString().split('').reversed.join());

/// Directed Steiner tree, root = [start], ≤5 targets ⇒ ≤32 subset masks,
/// depth-capped at [branchMax]. Returns the minimum edge count and the winning
/// tree as value-to-value edges (`cost == null` when unsolvable within the cap).
///
/// `D(mask, v, d)` = min edges for a tree rooted at `v` (relative depth 0)
/// spanning the targets in `mask`, with every node's depth-from-`v` ≤ d. Once
/// `v` is unwound back to `start`, relative depth equals true absolute depth, so
/// this enforces the same per-arm cap the board enforces. No relaxation needed:
/// merges look at strictly smaller masks at the same d, edge-steps at the same
/// mask one d lower — both already resolved, so each `(mask, v, d)` fills once.
({int? cost, List<Edge> edges}) steinerSolve(
    int start, List<int> targets, List<Operation> ops, int? branchMax) {
  // Forward reachability graph.
  final seen = <int>{start};
  final adj = <int, Set<int>>{};
  final radj = <int, Set<int>>{};
  final q = Queue<int>()..add(start);
  while (q.isNotEmpty) {
    final v = q.removeFirst();
    final outs = <int>{};
    for (final o in ops) {
      final r = compute(v, o);
      if (r != null && r != v) outs.add(r);
    }
    adj[v] = outs;
    for (final u in outs) {
      (radj[u] ??= <int>{}).add(v);
      if (seen.add(u)) q.add(u);
    }
  }

  // Per-target reverse-BFS hop distances + back-pointers.
  final k = targets.length;
  final distToTarget = <Map<int, int>>[];
  final parentTo = <Map<int, int>>[];
  for (final t in targets) {
    final d = <int, int>{t: 0};
    final par = <int, int>{};
    if (seen.contains(t)) {
      final bq = Queue<int>()..add(t);
      while (bq.isNotEmpty) {
        final u = bq.removeFirst();
        for (final v in radj[u] ?? const <int>{}) {
          if (!d.containsKey(v)) {
            d[v] = d[u]! + 1;
            par[v] = u;
            bq.add(v);
          }
        }
      }
    }
    distToTarget.add(d);
    parentTo.add(par);
  }

  final full = (1 << k) - 1;
  final maxD = max(0, min(branchMax ?? seen.length, seen.length));
  bool isPow2(int m) => (m & (m - 1)) == 0;
  int bitIndex(int mask) {
    var i = 0;
    while ((mask >> i) != 1) {
      i++;
    }
    return i;
  }

  const inf = 1 << 30;
  // dp[mask][d] : {value: cost}; choice[mask][d] : {value: _Choice}
  final dp = List.generate(full + 1, (_) => <Map<int, int>>[]);
  final choice = List.generate(full + 1, (_) => <Map<int, _Choice>>[]);
  for (var mask = 1; mask <= full; mask++) {
    final single = isPow2(mask);
    final ti = single ? bitIndex(mask) : -1;
    for (var d = 0; d <= maxD; d++) {
      final m = <int, int>{};
      final ch = <int, _Choice>{};
      for (final v in seen) {
        var best = inf;
        _Choice? bestCh;
        if (single) {
          final dist = distToTarget[ti][v];
          if (dist != null && dist <= d) {
            best = dist;
            bestCh = const _Choice.base();
          }
        } else {
          for (var sub = (mask - 1) & mask; sub > 0; sub = (sub - 1) & mask) {
            final other = mask ^ sub;
            final a = dp[sub][d][v];
            final b = dp[other][d][v];
            if (a != null && b != null && a + b < best) {
              best = a + b;
              bestCh = _Choice.merge(sub, other);
            }
          }
        }
        if (d > 0) {
          for (final u in adj[v] ?? const <int>{}) {
            final cand = dp[mask][d - 1][u];
            if (cand != null && 1 + cand < best) {
              best = 1 + cand;
              bestCh = _Choice.edge(u);
            }
          }
        }
        if (best < inf) {
          m[v] = best;
          ch[v] = bestCh!;
        }
      }
      dp[mask].add(m);
      choice[mask].add(ch);
    }
  }

  final cost = dp[full][maxD][start];
  final edges = <Edge>[];
  void build(int v, int mask, int d) {
    final c = choice[mask][d][v];
    if (c == null) return;
    switch (c.type) {
      case _ChoiceType.base:
        final i = bitIndex(mask);
        var cur = v;
        while (cur != targets[i]) {
          final nx = parentTo[i][cur];
          if (nx == null) break;
          edges.add((cur, nx));
          cur = nx;
        }
      case _ChoiceType.merge:
        build(v, c.a, d);
        build(v, c.b, d);
      case _ChoiceType.edge:
        edges.add((v, c.a));
        build(c.a, mask, d - 1);
    }
  }

  if (cost != null) build(start, full, maxD);
  return (cost: cost, edges: edges);
}

/// Can this exact [hand] (respecting each tile's real token cap) actually build
/// these [edges]? Backtracking assignment of edges to tiles.
bool validateHandCovers(List<Edge> edges, List<Operation> hand) {
  final caps = {for (final o in hand) o.id: o.tokens};
  final used = <String, int>{};
  bool assign(int i) {
    if (i >= edges.length) return true;
    final e = edges[i];
    for (final o in hand) {
      if (compute(e.$1, o) != e.$2) continue;
      if ((used[o.id] ?? 0) >= caps[o.id]!) continue;
      used[o.id] = (used[o.id] ?? 0) + 1;
      if (assign(i + 1)) return true;
      used[o.id] = used[o.id]! - 1;
    }
    return false;
  }

  return assign(0);
}

/// A valid tree has exactly `edges + 1` distinct values — a repeat means a value
/// the board's own "already on the board" rule would reject.
bool edgesFormUniqueTree(int start, List<Edge> edges) {
  final vals = <int>{start};
  for (final e in edges) {
    vals..add(e.$1)..add(e.$2);
  }
  return vals.length == edges.length + 1;
}

enum _ChoiceType { base, merge, edge }

class _Choice {
  const _Choice.base()
      : type = _ChoiceType.base,
        a = 0,
        b = 0;
  const _Choice.merge(this.a, this.b) : type = _ChoiceType.merge;
  const _Choice.edge(this.a)
      : type = _ChoiceType.edge,
        b = 0;
  final _ChoiceType type;
  final int a;
  final int b;
}
