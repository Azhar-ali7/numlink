import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/stats_repository.dart';
import '../models/chain_node.dart';
import '../models/game_stats.dart';
import '../models/operation.dart';
import '../models/puzzle.dart';
import '../services/feedback_service.dart';
import 'game_mode.dart';
import 'puzzle_repository.dart';

/// Which overlay sheet is showing.
enum SheetOverlay { how, stats, settings, win }

/// Golf-style score verdicts.
enum ScoreLabel { eagle, birdie, par, bogey, doubleBogey, over }

extension ScoreLabelText on ScoreLabel {
  String text(int over) => switch (this) {
        ScoreLabel.eagle => 'Eagle',
        ScoreLabel.birdie => 'Birdie',
        ScoreLabel.par => 'Par',
        ScoreLabel.bogey => 'Bogey',
        ScoreLabel.doubleBogey => 'Double bogey',
        ScoreLabel.over => '+$over',
      };
}

/// Proximity heat state, mapped to a themed color by the UI.
enum Heat { onTarget, near, far }

/// The core play loop. Logic is ported 1:1 from the design prototype's
/// `Component` class (see `NUMLINK.dc.html`).
class GameController extends ChangeNotifier {
  GameController({
    required Puzzle puzzle,
    required StatsRepository statsRepo,
    required this.feedback,
    required GameStats initialStats,
    this.puzzleRepo = const LocalPuzzleRepository(),
  })  : _puzzle = puzzle,
        _statsRepo = statsRepo,
        _stats = initialStats;

  Puzzle _puzzle;
  final StatsRepository _statsRepo;
  final FeedbackService feedback;

  /// Source for generated puzzles (Practice/Zen "new puzzle", ladder).
  final PuzzleRepository puzzleRepo;

  GameMode _mode = GameMode.daily;
  Difficulty _difficulty = Difficulty.medium;

  Puzzle get puzzle => _puzzle;
  GameMode get mode => _mode;
  Difficulty get difficulty => _difficulty;

  List<ChainNode> _chain = [];
  final Map<String, int> _used = {};
  bool _solved = false;
  bool _recorded = false;
  bool _started = false;
  SheetOverlay? _overlay;
  GameStats _stats;
  String? _message;
  String? _shakeOpId;
  bool _copied = false;

  /// Bumped whenever a solve happens, so the UI can fire a confetti burst.
  int _winPulse = 0;

  Timer? _messageTimer;
  Timer? _shakeTimer;
  Timer? _copyTimer;

  GameController init() {
    _chain = [ChainNode(puzzle.start)];
    return this;
  }

  // ---- Read-only view of state -------------------------------------------

  List<ChainNode> get chain => List.unmodifiable(_chain);
  Map<String, int> get used => Map.unmodifiable(_used);
  bool get solved => _solved;
  bool get started => _started;
  SheetOverlay? get overlay => _overlay;
  GameStats get stats => _stats;
  String? get message => _message;
  String? get shakeOpId => _shakeOpId;
  bool get copied => _copied;
  int get winPulse => _winPulse;

  int get current => _chain.last.value;
  int get moves => _chain.length - 1;
  int get par => puzzle.par;
  int get target => puzzle.target;

  int get distance => (puzzle.target - current).abs();
  int get _initialDistance =>
      (puzzle.target - puzzle.start).abs() == 0
          ? 1
          : (puzzle.target - puzzle.start).abs();

  /// Heat bar fill percentage (min 6, max 100).
  double get heatPercent {
    final pct = 100 * (1 - distance / _initialDistance);
    return pct.clamp(6, 100).toDouble();
  }

  Heat get heat =>
      distance == 0 ? Heat.onTarget : (distance <= 3 ? Heat.near : Heat.far);

  String get proximityText =>
      _solved ? 'On target' : '$distance away from target';

  /// Tokens remaining for [o].
  int remaining(Operation o) => o.tokens - (_used[o.id] ?? 0);

  /// Preview result of applying [o] to the current value, or null if illegal.
  int? preview(Operation o) => o.apply(current, cap: puzzle.cap);

  bool isDisabled(Operation o) =>
      _solved || preview(o) == null || remaining(o) <= 0;

  int get scoreOver => moves - par;

  ScoreLabel get scoreLabel {
    final over = scoreOver;
    if (over <= -2) return ScoreLabel.eagle;
    if (over == -1) return ScoreLabel.birdie;
    if (over == 0) return ScoreLabel.par;
    if (over == 1) return ScoreLabel.bogey;
    if (over == 2) return ScoreLabel.doubleBogey;
    return ScoreLabel.over;
  }

  bool get showTargetPlaceholder => !_solved;

  // ---- Actions ------------------------------------------------------------

  void apply(Operation o) {
    if (_solved) return;
    if (remaining(o) <= 0) {
      _flash('No ${o.label} tokens left');
      _shake(o.id);
      feedback.onIllegal();
      return;
    }
    final r = o.apply(current, cap: puzzle.cap);
    if (r == null) {
      _flash(o.symbol == '÷'
          ? "That doesn't divide evenly"
          : 'That goes out of range');
      _shake(o.id);
      feedback.onIllegal();
      return;
    }
    _chain = [..._chain, ChainNode(r, o.label)];
    _used[o.id] = (_used[o.id] ?? 0) + 1;
    if (r == puzzle.target) {
      _solved = true;
      _overlay = SheetOverlay.win;
      _winPulse++;
      if (_mode == GameMode.daily) _recordWin(moves);
      feedback.onSolve();
    } else {
      feedback.onTap();
    }
    notifyListeners();
  }

  void undo() {
    if (_solved || _chain.length <= 1) return;
    final lastLabel = _chain.last.opLabel;
    final hit = puzzle.ops.where((o) => o.label == lastLabel);
    if (hit.isNotEmpty) {
      final id = hit.first.id;
      if ((_used[id] ?? 0) > 0) _used[id] = _used[id]! - 1;
    }
    _chain = _chain.sublist(0, _chain.length - 1);
    feedback.onTap();
    notifyListeners();
  }

  void reset() {
    _resetBoard();
    notifyListeners();
  }

  void _resetBoard() {
    _chain = [ChainNode(_puzzle.start)];
    _used.clear();
    _solved = false;
    _recorded = false;
  }

  /// Swaps in a new puzzle and clears the board — the seam for Practice/Zen/
  /// Timed and Archive. [mode]/[difficulty] tag the session for stat routing
  /// and mode-aware UI.
  void load(Puzzle p, {GameMode mode = GameMode.daily, Difficulty? difficulty}) {
    _puzzle = p;
    _mode = mode;
    if (difficulty != null) _difficulty = difficulty;
    _resetBoard();
    _overlay = null;
    _copied = false;
    _message = null;
    notifyListeners();
  }

  /// Practice: generate a fresh puzzle at tier [d] and start it.
  Future<void> startPractice(Difficulty d) async {
    final p = await puzzleRepo.generate(d);
    load(p, mode: GameMode.practice, difficulty: d);
  }

  /// Practice/Zen "New puzzle": regenerate at the current difficulty and mode.
  Future<void> newPuzzle() async {
    final p = await puzzleRepo.generate(_difficulty);
    load(p, mode: _mode, difficulty: _difficulty);
  }

  void playAgain() {
    reset();
    _overlay = null;
    _copied = false;
    notifyListeners();
  }

  void startGame() {
    _started = true;
    _overlay = null;
    notifyListeners();
  }

  void open(SheetOverlay o) {
    _overlay = o;
    notifyListeners();
  }

  void close() {
    _overlay = null;
    notifyListeners();
  }

  // ---- Stats --------------------------------------------------------------

  Future<void> _recordWin(int moves) async {
    if (_recorded) return;
    _recorded = true;
    _stats = _stats.recordWin(moves, par);
    await _statsRepo.save(_stats);
    notifyListeners();
  }

  /// Bucket key for the just-finished game (for histogram highlighting).
  String get currentBucket => GameStats.bucketFor(moves, par);

  // ---- Share --------------------------------------------------------------

  String shareText() {
    final within = moves < par ? moves : par;
    final over = (moves - par) > 0 ? moves - par : 0;
    var grid = '🟦' * within + '🟧' * over;
    if (_solved) grid += ' 🎯';
    return 'NUMLINK #${puzzle.no}\n$moves moves · par $par\n$grid';
  }

  void markCopied() {
    _copied = true;
    notifyListeners();
    _copyTimer?.cancel();
    _copyTimer = Timer(const Duration(milliseconds: 1800), () {
      _copied = false;
      notifyListeners();
    });
  }

  // ---- Transient feedback -------------------------------------------------

  void _flash(String msg) {
    _message = msg;
    notifyListeners();
    _messageTimer?.cancel();
    _messageTimer = Timer(const Duration(milliseconds: 1600), () {
      _message = null;
      notifyListeners();
    });
  }

  void _shake(String id) {
    _shakeOpId = id;
    notifyListeners();
    _shakeTimer?.cancel();
    _shakeTimer = Timer(const Duration(milliseconds: 340), () {
      _shakeOpId = null;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    _shakeTimer?.cancel();
    _copyTimer?.cancel();
    super.dispose();
  }
}
