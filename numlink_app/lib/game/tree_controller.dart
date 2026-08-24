import 'package:flutter/foundation.dart' hide compute;

import '../models/operation.dart';
import 'steiner.dart';
import 'stranding.dart';
import 'tree_generator.dart';

/// Outcome of an [TreeController.apply] attempt.
enum ApplyResult { placed, solved, rejected, ignored }

/// One placed value in the branching tree. Depth is derived by walking
/// [parent], never stored.
class TreeNode {
  const TreeNode({
    required this.id,
    required this.v,
    this.parent,
    this.opSig,
    this.opLabel,
  });
  final int id;
  final int v;
  final int? parent;
  final String? opSig;
  final String? opLabel;
}

/// Branching-tree gameplay controller (ported from the prototype `Component`).
/// Pure state + rules; no UI, no persistence. The stranding guard and token
/// economy live here.
class TreeController extends ChangeNotifier {
  TreeController(this.puzzle);

  TreePuzzle puzzle;

  List<TreeNode> nodes = const [];
  int sel = 0;
  int _nextId = 1;
  int handIndex = 0;
  int shufflesLeft = 0;
  bool solved = false;
  bool hintUsed = false;

  /// Last user-facing status line (rejection reason, shuffle result, …).
  String? message;

  /// Op id to flash/shake after an illegal tap; null when nothing pending.
  String? shakeOp;

  /// Op id to glow after a hint; null otherwise.
  String? hintGlow;

  void init() {
    nodes = [TreeNode(id: 0, v: puzzle.start)];
    sel = 0;
    _nextId = 1;
    handIndex = 0;
    shufflesLeft = puzzle.shuffles;
    solved = false;
    hintUsed = false;
    message = null;
    shakeOp = null;
    hintGlow = null;
  }

  int get nextId => _nextId;
  List<Operation> get hand => puzzle.hands[handIndex % puzzle.hands.length];

  /// Value of the currently selected node (what the next op builds from).
  int get selValue => _selNode.v;

  /// Targets already placed on the board.
  int get reached =>
      puzzle.targets.where((t) => nodes.any((n) => n.v == t)).length;

  /// Moves played = every node except the start.
  int get moves => nodes.length - 1;

  /// Moves still allowed on the selected arm before it hits [branchMax].
  int get armLeft =>
      (puzzle.branchMax - depthOf(_selNode)).clamp(0, puzzle.branchMax);

  TreeNode get _selNode => nodes.firstWhere((n) => n.id == sel);

  /// Tokens consumed per op signature across the whole tree.
  Map<String, int> usedMap() {
    final m = <String, int>{};
    for (final n in nodes) {
      if (n.opSig != null) m[n.opSig!] = (m[n.opSig!] ?? 0) + 1;
    }
    return m;
  }

  int remaining(Operation o) => o.tokens - (usedMap()[o.opSig] ?? 0);

  /// Depth of [node] within [list] (defaults to live [nodes]).
  int depthOf(TreeNode node, [List<TreeNode>? list]) {
    final l = list ?? nodes;
    var d = 0;
    var c = node;
    while (c.parent != null) {
      c = l.firstWhere((x) => x.id == c.parent);
      d++;
    }
    return d;
  }

  void select(int id) {
    sel = id;
    notifyListeners();
  }

  /// Enforcement order (prototype 1394–1425): token → depth cap → compute-null →
  /// unchanged → already-on-board → stranding guard → place. Win when every
  /// target has a node.
  ApplyResult apply(Operation o) {
    if (solved) return ApplyResult.ignored;
    final used = usedMap();
    final sig = o.opSig;
    if ((used[sig] ?? 0) >= o.tokens) {
      return _reject(o, 'No ${o.label} tokens left');
    }
    final from = _selNode;
    if (depthOf(from) >= puzzle.branchMax) {
      return _reject(o, 'This arm is at its ${puzzle.branchMax}-move limit');
    }
    final r = compute(from.v, o);
    if (r == null) {
      return _reject(
        o,
        switch (o.symbol) {
          '÷' => "That doesn't divide evenly",
          '√' => 'Not a perfect square',
          _ => 'That goes out of range',
        },
      );
    }
    if (r == from.v) return _reject(o, 'That leaves ${from.v} unchanged');
    if (nodes.any((n) => n.v == r)) {
      return _reject(o, '$r is already on the board');
    }

    final node = TreeNode(
      id: _nextId,
      v: r,
      parent: from.id,
      opSig: sig,
      opLabel: o.label,
    );
    final next = [...nodes, node];
    final nextUsed = {...used, sig: (used[sig] ?? 0) + 1};
    if (_stranded(next, nextUsed)) {
      return _reject(o, 'That would strand a target');
    }

    nodes = next;
    sel = node.id;
    _nextId++;
    hintGlow = null;
    shakeOp = null;
    message = null;
    if (puzzle.targets.every((t) => nodes.any((n) => n.v == t))) {
      solved = true;
      notifyListeners();
      return ApplyResult.solved;
    }
    notifyListeners();
    return ApplyResult.placed;
  }

  ApplyResult _reject(Operation o, String msg) {
    message = msg;
    shakeOp = o.id;
    notifyListeners();
    return ApplyResult.rejected;
  }

  /// Public guard over a hypothetical board (used by tests and [apply]).
  bool stranded(List<TreeNode> ns, Map<String, int> used) =>
      _stranded(ns, used);

  bool _stranded(List<TreeNode> ns, Map<String, int> used) {
    final missing =
        puzzle.targets.where((t) => !ns.any((n) => n.v == t)).toList();
    if (missing.isEmpty) return false;
    final tree = [for (final n in ns) (v: n.v, d: depthOf(n, ns))];
    Map<String, int> leftFor(List<Operation> h) =>
        {for (final o in h) o.opSig: o.tokens - (used[o.opSig] ?? 0)};
    if (solveFrom(tree, missing, hand, puzzle.branchMax, leftFor(hand))) {
      return false;
    }
    if (shufflesLeft <= 0) return true;
    for (final alt in puzzle.hands) {
      if (solveFrom(tree, missing, alt, puzzle.branchMax, leftFor(alt))) {
        return false;
      }
    }
    return true;
  }

  /// Deal the first alternate hand that still solves the live tree; else keep
  /// the current hand. Costs a shuffle either way (prototype 1433–1457).
  void shuffleHand() {
    if (shufflesLeft <= 0) {
      message = 'No shuffles left';
      notifyListeners();
      return;
    }
    final missing =
        puzzle.targets.where((t) => !nodes.any((n) => n.v == t)).toList();
    final used = usedMap();
    final tree = [for (final n in nodes) (v: n.v, d: depthOf(n, nodes))];
    bool works(List<Operation> cand) {
      if (missing.isEmpty) return true;
      final left = {
        for (final o in cand) o.opSig: o.tokens - (used[o.opSig] ?? 0)
      };
      return solveFrom(tree, missing, cand, puzzle.branchMax, left);
    }

    for (var step = 1; step <= puzzle.hands.length; step++) {
      final idx = (handIndex + step) % puzzle.hands.length;
      if (idx == handIndex) continue;
      if (works(puzzle.hands[idx])) {
        handIndex = idx;
        shufflesLeft--;
        message = 'New hand dealt — still solvable';
        notifyListeners();
        return;
      }
    }
    shufflesLeft--;
    message = 'No alternate hand keeps this solvable — kept your current hand';
    notifyListeners();
  }

  /// Glow the available op whose result lands nearest an outstanding target.
  /// One hint per puzzle (prototype 1546–1562).
  void hint() {
    if (hintUsed) {
      message = 'Your hint is spent';
      notifyListeners();
      return;
    }
    final missing =
        puzzle.targets.where((t) => !nodes.any((n) => n.v == t)).toList();
    if (missing.isEmpty) return;
    final from = _selNode;
    final used = usedMap();
    Operation? best;
    var bestD = 1 << 30;
    for (final o in hand) {
      if ((used[o.opSig] ?? 0) >= o.tokens) continue;
      final r = compute(from.v, o);
      if (r == null || r == from.v) continue;
      final d = missing
          .map((t) => (t - r).abs())
          .reduce((a, b) => a < b ? a : b);
      if (d < bestD) {
        bestD = d;
        best = o;
      }
    }
    if (best != null) {
      hintGlow = best.id;
      hintUsed = true;
      notifyListeners();
    }
  }
}
