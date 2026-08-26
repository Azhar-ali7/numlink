import 'dart:async';

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

  /// Hints still available this board — per-tier (`kTiers`), not a flat one.
  int hintsLeft = 0;

  /// Last user-facing status line (rejection reason, shuffle result, …).
  String? message;

  /// Op id to flash/shake after an illegal tap; null when nothing pending.
  String? shakeOp;

  /// Op id to glow after a hint; null otherwise.
  String? hintGlow;

  Timer? _msgTimer;
  Timer? _glowTimer;

  /// Show a transient status line that auto-clears after 1.6s, cancelling any
  /// prior auto-clear (prototype `flash`). Non-transient states (solved) set
  /// [message] directly.
  void _flash(String msg) {
    message = msg;
    _msgTimer?.cancel();
    _msgTimer = Timer(const Duration(milliseconds: 1600), () {
      message = null;
      notifyListeners();
    });
    notifyListeners();
  }

  @override
  void dispose() {
    _msgTimer?.cancel();
    _glowTimer?.cancel();
    super.dispose();
  }

  void init() {
    _msgTimer?.cancel();
    _glowTimer?.cancel();
    nodes = [TreeNode(id: 0, v: puzzle.start)];
    sel = 0;
    _nextId = 1;
    handIndex = 0;
    shufflesLeft = puzzle.shuffles;
    solved = false;
    hintsLeft = puzzle.hints;
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
    // The glow was computed against the old selection — it may be illegal here.
    _clearGlow();
    notifyListeners();
  }

  /// The cheap half of the legality rules — everything [apply] checks before
  /// the expensive stranding guard. Returns the resulting value, or null with
  /// [why] set to the player-facing reason.
  ///
  /// Shared with [hint] so a hint can never glow a move [apply] would reject:
  /// duplicating these conditions in [hint] is exactly how it ended up
  /// suggesting values already on the board.
  ({int? r, String? why}) _legality(
      TreeNode from, Operation o, Map<String, int> used) {
    if ((used[o.opSig] ?? 0) >= o.tokens) {
      return (r: null, why: 'No ${o.label} tokens left');
    }
    if (depthOf(from) >= puzzle.branchMax) {
      return (
        r: null,
        why: 'This arm is at its ${puzzle.branchMax}-move limit'
      );
    }
    final r = compute(from.v, o);
    if (r == null) {
      return (
        r: null,
        why: switch (o.symbol) {
          '÷' => "That doesn't divide evenly",
          '√' => 'Not a perfect square',
          _ => 'That goes out of range',
        }
      );
    }
    if (r == from.v) return (r: null, why: 'That leaves ${from.v} unchanged');
    if (nodes.any((n) => n.v == r)) {
      return (r: null, why: '$r is already on the board');
    }
    return (r: r, why: null);
  }

  /// The board [from] + [o] would produce, paired with the token map after it.
  (List<TreeNode>, Map<String, int>) _boardAfter(
      TreeNode from, Operation o, int r, Map<String, int> used) {
    final node = TreeNode(
      id: _nextId,
      v: r,
      parent: from.id,
      opSig: o.opSig,
      opLabel: o.label,
    );
    return ([...nodes, node], {...used, o.opSig: (used[o.opSig] ?? 0) + 1});
  }

  /// Enforcement order (prototype 1394–1425): token → depth cap → compute-null →
  /// unchanged → already-on-board → stranding guard → place. Win when every
  /// target has a node.
  ApplyResult apply(Operation o) {
    if (solved) return ApplyResult.ignored;
    final used = usedMap();
    final from = _selNode;
    final check = _legality(from, o, used);
    if (check.r == null) return _reject(o, check.why!);

    final (next, nextUsed) = _boardAfter(from, o, check.r!, used);
    if (_stranded(next, nextUsed)) {
      return _reject(o, 'That would strand a target');
    }

    nodes = next;
    final node = next.last;
    sel = node.id;
    _nextId++;
    _clearGlow();
    shakeOp = null;
    message = null;
    _msgTimer?.cancel();
    if (puzzle.targets.every((t) => nodes.any((n) => n.v == t))) {
      solved = true;
      notifyListeners();
      return ApplyResult.solved;
    }
    notifyListeners();
    return ApplyResult.placed;
  }

  ApplyResult _reject(Operation o, String msg) {
    shakeOp = o.id;
    _flash(msg);
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
      _flash('No shuffles left');
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
        _clearGlow(); // the glowed op may not be in the new hand (proto 1451)
        _flash('New hand dealt — still solvable');
        return;
      }
    }
    shufflesLeft--;
    _flash('No alternate hand keeps this solvable — kept your current hand');
  }

  /// Glow the available op whose result lands nearest an outstanding target.
  /// [hintsLeft] per puzzle, dealt by the tier (prototype 1546–1562, which
  /// had a flat one).
  ///
  /// Every candidate must survive the same rules [apply] enforces — including
  /// the stranding guard, which is run only on candidates in nearest-first
  /// order so the expensive `solveFrom` sweep usually happens once, not once
  /// per op.
  void hint() {
    if (solved) return;
    if (hintsLeft == 0) {
      _flash('No hints left');
      return;
    }
    final missing =
        puzzle.targets.where((t) => !nodes.any((n) => n.v == t)).toList();
    if (missing.isEmpty) return;
    final from = _selNode;
    final used = usedMap();

    final ranked = <({Operation o, int r, int d})>[];
    for (final o in hand) {
      final r = _legality(from, o, used).r;
      if (r == null) continue;
      final d =
          missing.map((t) => (t - r).abs()).reduce((a, b) => a < b ? a : b);
      ranked.add((o: o, r: r, d: d));
    }
    ranked.sort((a, b) => a.d.compareTo(b.d));

    hintsLeft--; // spent either way, like the prototype
    for (final c in ranked) {
      final (next, nextUsed) = _boardAfter(from, c.o, c.r, used);
      if (_stranded(next, nextUsed)) continue;
      _glow(c.o.id);
      return;
    }
    _flash('No legal move from here — pick another node');
  }

  /// Light an op for 2.5s (prototype 1561). Cleared early by [apply],
  /// [shuffleHand] and [select], any of which invalidate the suggestion.
  void _glow(String opId) {
    hintGlow = opId;
    _glowTimer?.cancel();
    _glowTimer = Timer(const Duration(milliseconds: 2500), () {
      hintGlow = null;
      notifyListeners();
    });
    notifyListeners();
  }

  void _clearGlow() {
    _glowTimer?.cancel();
    hintGlow = null;
  }
}
