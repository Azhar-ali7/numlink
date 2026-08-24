import '../models/operation.dart';
import 'rng.dart';
import 'steiner.dart';
import 'stranding.dart';

/// A difficulty tier for the branching-tree generator. `kinds`/`unaries` null →
/// `makeHand` defaults. A `null` entry in [unaries] is the "standard extra"
/// slot that resolves to a random ↺ / x² / ⧺ tile.
class Tier {
  const Tier({
    required this.targetsMin,
    required this.targetsMax,
    required this.branch,
    required this.shuffles,
    required this.pool,
    this.kinds,
    this.unaries,
  });
  final int targetsMin, targetsMax, branch, shuffles;
  final List<int> pool;
  final List<String>? kinds;
  final List<String?>? unaries;
}

/// Tier table ported from the prototype `TIERS`.
const kTiers = <String, Tier>{
  'sprouts': Tier(targetsMin: 1, targetsMax: 2, branch: 1, shuffles: 2, pool: [2, 3], kinds: ['×', '+', '−'], unaries: []),
  'junior': Tier(targetsMin: 2, targetsMax: 3, branch: 2, shuffles: 3, pool: [2, 3, 4, 5], kinds: ['×', '+', '−', '÷'], unaries: []),
  'easy': Tier(targetsMin: 2, targetsMax: 2, branch: 3, shuffles: 3, pool: [2, 3, 5, 7]),
  'medium': Tier(targetsMin: 3, targetsMax: 3, branch: 3, shuffles: 4, pool: [2, 3, 4, 5, 7, 9], unaries: ['Σ', null]),
  'hard': Tier(targetsMin: 4, targetsMax: 5, branch: 4, shuffles: 5, pool: [2, 3, 4, 5, 6, 7, 8, 9], unaries: ['Σ', '√']),
};

/// A generated branching-tree board. Solution-first, so solvability is a
/// guarantee, not a guess.
class TreePuzzle {
  const TreePuzzle({
    required this.tier,
    required this.start,
    required this.targets,
    required this.hands,
    required this.shuffles,
    required this.branchMax,
    required this.par,
    required this.optimalPar,
    required this.optimalEdges,
    required this.dpValid,
  });
  final String tier;
  final int start;
  final List<int> targets;
  final List<List<Operation>> hands;
  final int shuffles, branchMax, par, optimalPar;
  final List<Edge> optimalEdges;
  final bool dpValid;
}

/// Builds a 5-binary-op hand plus tier unaries. `forceMul` makes the first two
/// tiles ×,+ (so a solution always exists). No duplicate tiles in one hand.
List<Operation> makeHand(Rng rnd, Tier t, int h, bool forceMul) {
  X pick<X>(List<X> a) => a[(rnd() * a.length).floor()];
  final kinds = t.kinds ?? const ['×', '+', '+', '−', '÷', '%'];
  final unaries = t.unaries ?? const ['Σ'];
  final hand = <Operation>[];
  final seen = <String>{};
  var guard = 0;
  while (hand.length < 5 && guard++ < 80) {
    final k = forceMul && hand.length < 2 ? (hand.isNotEmpty ? '+' : '×') : pick(kinds);
    final n = pick(t.pool);
    if (!seen.add('$k$n')) continue; // no duplicate tiles
    hand.add(Operation(id: 'o$h${hand.length}', symbol: k, n: n, tokens: 3));
  }
  for (var i = 0; i < unaries.length; i++) {
    final u = unaries[i];
    final (String sym, int n) = u == null
        ? pick(const [('↺', 0), ('^', 0), ('⧺', -1)]) // -1 → random concat digit
        : (u, 0);
    final operand = (sym == '⧺') ? 1 + (rnd() * 9).floor() : n;
    hand.add(Operation(id: 'o${h}u$i', symbol: sym, n: operand, tokens: 3));
  }
  return hand;
}

/// Constructs a board from a real solution (grow a legal tree → pick targets →
/// prune to the minimal covering subtree → assign signature tokens → verify
/// shuffle alternates → compute Steiner-DP par). Ported from the prototype
/// `buildPuzzle`; deterministic for a given [seed].
TreePuzzle buildPuzzle(String tierName, int seed) {
  final t = kTiers[tierName] ?? kTiers['medium']!;
  final rnd = minstd(seed);
  final count = t.targetsMin + (rnd() * (t.targetsMax - t.targetsMin + 1)).floor();

  for (var attempt = 0; attempt < 160; attempt++) {
    final start = 2 + (rnd() * 6).floor();
    final hand0 = makeHand(rnd, t, 0, true);
    final cap = {for (final o in hand0) o.id: 1 + (rnd() * 2).floor()};

    // grow a random legal tree honouring caps + the per-arm ceiling
    final nodes = <_GNode>[_GNode(0, start, 0, null, null)];
    final used = <String, int>{};
    final wanted = 3 + count;
    for (var step = 0; step < wanted * 5 && nodes.length < wanted + 1; step++) {
      final open = nodes.where((n) => n.d < t.branch).toList();
      if (open.isEmpty) break;
      final from = open[(rnd() * open.length).floor()];
      final legal = hand0.where((o) {
        final r = compute(from.v, o);
        return (used[o.id] ?? 0) < cap[o.id]! && r != null && r != from.v;
      }).toList();
      if (legal.isEmpty) continue;
      final o = legal[(rnd() * legal.length).floor()];
      final v = compute(from.v, o)!;
      if (nodes.any((n) => n.v == v)) continue;
      used[o.id] = (used[o.id] ?? 0) + 1;
      nodes.add(_GNode(nodes.length, v, from.d + 1, from.i, o.id));
    }

    final cands = nodes.where((n) => n.d >= 1 && n.v > 5).toList();
    if (cands.length < count) continue;
    // spread targets across arms (Fisher–Yates — not sort, for RNG determinism)
    final shuffled = cands.toList();
    shuffleInPlace(shuffled, rnd);
    final chosen = <_GNode>[];
    for (final n in shuffled) {
      if (chosen.length < count && !chosen.any((c) => c.v == n.v)) chosen.add(n);
    }
    if (chosen.length < count) continue;

    // prune to the minimal subtree covering the chosen targets — that IS the solution
    final keep = <int, _GNode>{};
    for (final n0 in chosen) {
      var c = n0;
      while (c.parent != null) {
        keep[c.i] = c;
        c = nodes.firstWhere((x) => x.i == c.parent);
      }
    }
    final kept = keep.values.toList();
    final need = <String, int>{};
    for (final n in kept) {
      need[n.op!] = (need[n.op!] ?? 0) + 1;
    }
    final targets = [for (final n in chosen) n.v];

    // tokens = solution need + slack; unused ops stay in the pad at 1 token
    final hand = [
      for (final o in hand0)
        Operation(
          id: o.id,
          symbol: o.symbol,
          n: o.n,
          tokens: (need[o.id] ?? 0) +
              ((need[o.id] ?? 0) > 0 ? (rnd() < 0.5 ? 1 : 0) : 1),
        )
    ];

    // shuffle deck: t.shuffles verified alternates, or re-roll the whole board
    final hands = <List<Operation>>[hand];
    for (var h = 1; h < 60 && hands.length < t.shuffles + 1; h++) {
      final alt = [
        for (final o in makeHand(rnd, t, h, false))
          Operation(id: o.id, symbol: o.symbol, n: o.n, tokens: 1 + (rnd() * 2).floor())
      ];
      if (solveFrom([(v: start, d: 0)], targets, alt, t.branch)) hands.add(alt);
    }
    if (hands.length < t.shuffles + 1) continue;

    // true par: Steiner optimum over only the op types the DEALT hand has,
    // validated against real token counts + the no-repeat rule, else fall back
    // to the constructed solution's move count.
    final dealtOps = <String, Operation>{};
    for (final o in hand) {
      dealtOps.putIfAbsent(o.opSig, () => o);
    }
    final solved = steinerSolve(start, targets, dealtOps.values.toList(), t.branch);
    final dpValid = solved.cost != null &&
        validateHandCovers(solved.edges, hand) &&
        edgesFormUniqueTree(start, solved.edges);
    final fallbackEdges = [
      for (final n in kept) (nodes.firstWhere((x) => x.i == n.parent).v, n.v)
    ];
    final trueOptimum = dpValid ? solved.cost! : kept.length;
    final optimalEdges = dpValid ? solved.edges : fallbackEdges;
    return TreePuzzle(
      tier: tierName,
      start: start,
      targets: targets,
      hands: hands,
      shuffles: t.shuffles,
      branchMax: t.branch,
      par: trueOptimum + 2, // flat +2 slack, all tiers
      optimalPar: trueOptimum,
      optimalEdges: optimalEdges,
      dpValid: dpValid,
    );
  }

  // deterministic fallback: 4 →(×3)12 →(+7)19. Enough hands so shuffle is never dead.
  List<Operation> fb(int h, int mul, int add) => [
        Operation(id: 'f${h}0', symbol: '×', n: mul, tokens: 2),
        Operation(id: 'f${h}1', symbol: '+', n: add, tokens: 2),
        Operation(id: 'f${h}2', symbol: '×', n: 2, tokens: 1),
        Operation(id: 'f${h}3', symbol: '+', n: 1, tokens: 2),
        Operation(id: 'f${h}4', symbol: '−', n: 3, tokens: 1),
        Operation(id: 'f${h}5', symbol: 'Σ', n: 0, tokens: 1),
      ];
  return TreePuzzle(
    tier: tierName,
    start: 4,
    targets: const [12, 19],
    hands: [fb(0, 3, 7), fb(1, 3, 7), fb(2, 3, 7), fb(3, 3, 7)],
    shuffles: 3,
    branchMax: 3,
    par: 3,
    optimalPar: 2,
    optimalEdges: const [(4, 12), (12, 19)],
    dpValid: false,
  );
}

class _GNode {
  const _GNode(this.i, this.v, this.d, this.parent, this.op);
  final int i, v, d;
  final int? parent;
  final String? op;
}
