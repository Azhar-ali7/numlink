import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/session_repository.dart';
import '../data/stats_repository.dart';
import '../models/achievement.dart';
import '../models/chain_node.dart';
import '../models/game_stats.dart';
import '../models/operation.dart';
import '../models/puzzle.dart';
import '../services/feedback_service.dart';
import 'campaign.dart';
import 'game_mode.dart';
import 'puzzle_repository.dart';
import 'solver.dart';

/// Which overlay sheet is showing.
enum SheetOverlay { how, stats, settings, win, archive, solution, roadmap }

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
    this.sessionRepo,
  }) : _puzzle = puzzle,
       _dailyPuzzle = puzzle,
       _statsRepo = statsRepo,
       _stats = initialStats;

  Puzzle _puzzle;

  /// The daily puzzle (captured at construction), for Home-hub display even
  /// while another mode's board is loaded.
  final Puzzle _dailyPuzzle;
  Puzzle get dailyPuzzle => _dailyPuzzle;
  final StatsRepository _statsRepo;
  final FeedbackService feedback;

  /// Source for generated puzzles (Practice/Zen "new puzzle", ladder).
  final PuzzleRepository puzzleRepo;

  /// Persists the in-progress game so it survives an app kill. Null in tests.
  final SessionRepository? sessionRepo;

  GameMode _mode = GameMode.daily;
  Difficulty _difficulty = Difficulty.medium;

  Puzzle get puzzle => _puzzle;
  GameMode get mode => _mode;
  Difficulty get difficulty => _difficulty;

  /// Header title/subtitle for the active mode.
  String get modeTitle => switch (_mode) {
    GameMode.daily => 'NUMLINK',
    GameMode.practice => 'Practice',
    GameMode.zen => 'Zen',
    GameMode.timed => 'Timed',
    GameMode.archive => 'Archive',
    GameMode.campaign => 'Level $levelNo',
  };

  String get modeSubtitle => switch (_mode) {
    GameMode.daily => '#${_puzzle.no} · ${_puzzle.dateLabel}',
    GameMode.practice => '${_difficulty.label} · par ${_puzzle.par}',
    GameMode.zen => 'Free play · ${_difficulty.label}',
    GameMode.timed => 'Stage $stage / $stageCount',
    GameMode.archive => '#${_puzzle.no} · ${_puzzle.dateLabel}',
    GameMode.campaign => '${_difficulty.label} · par ${_puzzle.par}',
  };

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

  // Hints / reveal-on-fail (per-puzzle; reset in [load]).
  int _hintsUsed = 0;
  int _resets = 0;
  bool _revealed = false;
  String? _hintOpId; // op the current hint is pointing at (highlighted)
  Timer? _hintTimer;

  // Milestones: count of ordered checkpoints already passed (reset in [load]).
  int _nextMilestone = 0;

  /// Bumped whenever a solve happens, so the UI can fire a confetti burst.
  int _winPulse = 0;

  /// XP granted by the most recent solve (shown on the win sheet).
  int _lastXpGain = 0;

  Timer? _messageTimer;
  Timer? _shakeTimer;
  Timer? _copyTimer;

  // ---- Timed ladder state -------------------------------------------------

  /// Number of stages in one timed run.
  static const int _ladderLength = 8;

  List<Puzzle> _ladder = [];
  int _stage = 0; // 0-based index of the stage currently being played
  int _elapsedSeconds = 0;
  int _bestStage = 0;
  int _bestTime = 0; // seconds of the fastest full run (0 = none yet)
  Timer? _tickTimer;

  /// 1-based current stage for display.
  int get stage => _stage + 1;
  int get stageCount => _ladder.length;
  int get elapsedSeconds => _elapsedSeconds;
  int get bestStage => _bestStage;
  int get bestTime => _bestTime;
  bool get isTimed => _mode == GameMode.timed;
  bool get isZen => _mode == GameMode.zen;

  /// m:ss elapsed clock for the timed bar.
  String get elapsedLabel {
    final m = _elapsedSeconds ~/ 60;
    final s = _elapsedSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// Mode-aware win-sheet summary — Zen drops par/score language entirely.
  String get winSummary => switch (_mode) {
    GameMode.zen => '$moves moves',
    GameMode.timed => '$stageCount stages · $elapsedLabel',
    _ => '$moves moves · par $par · ${scoreLabel.text(scoreOver)}',
  };

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

  // ---- Hints / reveal -----------------------------------------------------

  DifficultySpec get _spec => DifficultySpec.of(_difficulty);

  /// Hints remaining for this puzzle.
  int get hintsLeft => (_spec.hints - _hintsUsed).clamp(0, _spec.hints);

  /// Op id the active hint is pointing at (for button highlight), or null.
  String? get hintOpId => _hintOpId;

  bool get revealed => _revealed;

  /// "Show solution" unlocks after enough failed attempts — [DifficultySpec]
  /// scales the threshold. 3 resets OR all hints used, per the design.
  bool get canReveal =>
      !_solved && (_resets >= _spec.revealAfter || _hintsUsed >= _spec.hints);

  /// The full canonical answer path from the puzzle's start — what the reveal
  /// shows. Uses the stored solution; falls back to a live solve for legacy
  /// puzzles that predate [Puzzle.solution].
  List<Operation> get answerPath {
    final ids = _puzzle.solution.isNotEmpty
        ? _puzzle.solution
        : (solvePath(_puzzle) ?? const <String>[]);
    return [
      for (final id in ids)
        _puzzle.ops.firstWhere(
          (o) => o.id == id,
          orElse: () => Operation(id: id, symbol: '?', n: 0, tokens: 0),
        ),
    ];
  }

  int get current => _chain.last.value;
  int get moves => _chain.length - 1;
  int get par => puzzle.par;
  int get target => puzzle.target;

  // ---- Milestones ---------------------------------------------------------

  List<int> get milestones => _puzzle.milestones;
  int get milestonesPassed => _nextMilestone;

  /// The value the player is currently aiming for: the next unmet checkpoint,
  /// or the final target once all checkpoints are banked.
  int get activeTarget => _nextMilestone < _puzzle.milestones.length
      ? _puzzle.milestones[_nextMilestone]
      : puzzle.target;

  /// Where the current segment started (previous checkpoint, or start) — so the
  /// heat bar refills at each checkpoint instead of spanning the whole puzzle.
  int get _segmentStart => _nextMilestone == 0
      ? puzzle.start
      : _puzzle.milestones[_nextMilestone - 1];

  int get distance => (activeTarget - current).abs();
  int get _initialDistance {
    final d = (activeTarget - _segmentStart).abs();
    return d == 0 ? 1 : d;
  }

  /// Heat bar fill percentage (min 6, max 100).
  double get heatPercent {
    final pct = 100 * (1 - distance / _initialDistance);
    return pct.clamp(6, 100).toDouble();
  }

  Heat get heat =>
      distance == 0 ? Heat.onTarget : (distance <= 3 ? Heat.near : Heat.far);

  String get proximityText => _solved
      ? 'On target'
      : '$distance away from '
            '${_nextMilestone < _puzzle.milestones.length ? 'checkpoint' : 'target'}';

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
      _flash(
        o.symbol == '÷'
            ? "That doesn't divide evenly"
            : 'That goes out of range',
      );
      _shake(o.id);
      feedback.onIllegal();
      return;
    }
    _chain = [..._chain, ChainNode(r, o.label)];
    _used[o.id] = (_used[o.id] ?? 0) + 1;

    // Required, in-order milestones: bank a checkpoint and advance the sub-goal
    // before the final-target check. Reuses the win pulse/haptic for feedback.
    final ms = _puzzle.milestones;
    if (_nextMilestone < ms.length && r == ms[_nextMilestone]) {
      _nextMilestone++;
      _winPulse++;
      feedback.onSolve();
      _flash(
        _nextMilestone < ms.length
            ? 'Checkpoint! Next: ${ms[_nextMilestone]}'
            : 'Checkpoint! Now reach ${puzzle.target}',
      );
      _persist();
      notifyListeners();
      return;
    }

    if (r == puzzle.target && _nextMilestone == ms.length) {
      if (_mode == GameMode.timed) {
        _solveTimed(); // advances the ladder or finishes the run (self-notifies)
        return;
      }
      _solved = true;
      _overlay = SheetOverlay.win;
      _winPulse++;
      _recordSolve();
      feedback.onSolve();
      _clearSession();
    } else {
      feedback.onTap();
      _persist();
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
    // A reset of a started-but-unsolved board counts as a failed attempt.
    if (moves > 0 && !_solved) _resets++;
    _resetBoard();
    notifyListeners();
    _persist();
  }

  void _resetBoard() {
    _chain = [ChainNode(_puzzle.start)];
    _used.clear();
    _solved = false;
    _recorded = false;
    _nextMilestone = 0;
    _hintOpId = null;
    _hintTimer?.cancel();
  }

  /// Point the player at the next best move from where they are. Costs a hint;
  /// re-solves live so it's always valid even after they've diverged.
  void hint() {
    if (_solved) return;
    if (hintsLeft <= 0) {
      _flash('No hints left');
      notifyListeners();
      return;
    }
    final ids = solvePath(
      _puzzle,
      from: current,
      used: _used,
      fromMilestone: _nextMilestone,
    );
    if (ids == null || ids.isEmpty) {
      _flash('No hint available');
      notifyListeners();
      return;
    }
    _hintsUsed++;
    _hintOpId = ids.first;
    feedback.onTap();
    notifyListeners();
    _hintTimer?.cancel();
    _hintTimer = Timer(const Duration(milliseconds: 2500), () {
      _hintOpId = null;
      notifyListeners();
    });
    _persist();
  }

  /// Give up and show the full remaining answer path. Only meaningful once
  /// [canReveal] is true (the UI gates the button on it).
  void revealSolution() {
    _revealed = true;
    _overlay = SheetOverlay.solution;
    notifyListeners();
  }

  /// Swaps in a new puzzle and clears the board — the seam for Practice/Zen/
  /// Timed and Archive. [mode]/[difficulty] tag the session for stat routing
  /// and mode-aware UI.
  void load(
    Puzzle p, {
    GameMode mode = GameMode.daily,
    Difficulty? difficulty,
  }) {
    _puzzle = p;
    _mode = mode;
    if (difficulty != null) _difficulty = difficulty;
    _resetBoard();
    // Fresh puzzle → fresh hint/reveal allowance.
    _hintsUsed = 0;
    _resets = 0;
    _revealed = false;
    _overlay = null;
    _copied = false;
    _message = null;
    _started = true;
    notifyListeners();
    _persist();
  }

  /// Daily tile from the Home hub: resume in-progress daily, or (re)load it
  /// after a detour through another mode.
  Future<void> startDaily() async {
    if (_mode == GameMode.daily) {
      _started = true;
      _overlay = null;
      notifyListeners();
      return;
    }
    load(await puzzleRepo.today(), mode: GameMode.daily);
  }

  /// Return to the Home hub without discarding the current board. Also stops
  /// the timed clock — leaving a run ends it.
  void goHome() {
    _tickTimer?.cancel();
    _started = false;
    _overlay = null;
    notifyListeners();
    _persist(); // durability if the app is killed from the hub
  }

  /// True when the current in-memory board is mode [m] (matching [no]/[d] when
  /// given) and still mid-solve — so re-entering that mode from the hub resumes
  /// it instead of loading a fresh puzzle.
  bool _canResume(GameMode m, {int? no, Difficulty? d}) =>
      _mode == m &&
      !_solved &&
      moves > 0 &&
      (no == null || _puzzle.no == no) &&
      (d == null || _difficulty == d);

  /// Re-show the preserved board without touching it.
  void _resumeBoard() {
    _started = true;
    _overlay = null;
    notifyListeners();
  }

  /// Practice: resume an in-progress board at tier [d], else generate a fresh
  /// puzzle and start it.
  Future<void> startPractice(Difficulty d) async {
    if (_canResume(GameMode.practice, d: d)) return _resumeBoard();
    final p = await puzzleRepo.generate(d);
    load(p, mode: GameMode.practice, difficulty: d);
  }

  /// Zen: like Practice but pressure-free — no par/score/streak (win recording
  /// is already gated to daily; the UI hides par/heat for this mode).
  Future<void> startZen(Difficulty d) async {
    if (_canResume(GameMode.zen, d: d)) return _resumeBoard();
    final p = await puzzleRepo.generate(d);
    load(p, mode: GameMode.zen, difficulty: d);
  }

  /// Timed: build a fresh escalating ladder and start the clock.
  Future<void> startTimed() async {
    _tickTimer?.cancel();
    final runSeed = DateTime.now().millisecondsSinceEpoch % 100000;
    _ladder = puzzleRepo.ladder(_ladderLength, runSeed: runSeed);
    _stage = 0;
    _elapsedSeconds = 0;
    load(_ladder[0], mode: GameMode.timed);
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedSeconds++;
      notifyListeners();
    });
  }

  /// A timed stage was solved: bank progress, then advance or finish the run.
  void _solveTimed() {
    final completed = _stage + 1;
    if (completed > _bestStage) _bestStage = completed;
    _winPulse++; // confetti pulse between stages
    feedback.onSolve();
    // Persist best stage (drives the Ladder Climber badge); best time stays
    // session-only. ponytail: best-time is a min, not a max — no min-counter
    // helper yet; add one if it needs to survive restarts.
    _stats = _stats.setCounterMax('timedBestStage', completed);
    final done = completed >= _ladder.length;
    if (done) {
      _tickTimer?.cancel();
      _solved = true;
      _overlay = SheetOverlay.win;
      _clearSession();
      if (_bestTime == 0 || _elapsedSeconds < _bestTime) {
        _bestTime = _elapsedSeconds;
      }
      _stats = _stats.bumpCounter('timedRuns');
      _awardXp(completed * 5); // whole-run XP: 5 per stage cleared
    }
    _stats = _stats.withUnlocked(
      earnedAchievements(
        _stats,
        const SolveContext(scoreOver: 0, usedDivision: false),
      ),
    );
    _statsRepo.save(_stats);
    if (done) {
      notifyListeners();
    } else {
      _stage = completed;
      load(_ladder[_stage], mode: GameMode.timed); // self-notifies
    }
  }

  /// Archive: replay a past daily by number. Never affects the streak; a solve
  /// is banked in the archive-completion set instead.
  Future<void> startArchive(int no) async {
    if (_canResume(GameMode.archive, no: no)) return _resumeBoard();
    load(await puzzleRepo.archive(no), mode: GameMode.archive);
  }

  /// Past daily numbers available to replay (newest first, excluding today).
  List<int> get archiveNumbers => puzzleRepo.archiveNumbers();

  /// Campaign: start (or replay) level [n] from the roadmap. The generated
  /// puzzle carries `no == n`, so [levelNo] recovers it (resume-safe).
  Future<void> startCampaign(int n) async {
    if (_canResume(GameMode.campaign, no: n)) return _resumeBoard();
    load(
      await puzzleRepo.campaign(n),
      mode: GameMode.campaign,
      difficulty: kCampaign[n - 1].tier,
    );
  }

  /// Active campaign level number (only meaningful in campaign mode).
  int get levelNo => _puzzle.no;
  int get campaignCount => puzzleRepo.campaignCount;

  /// Stars (1–3) the just-finished run earned for this level.
  int get earnedStars => starsFor(moves, par);

  /// Whether a next campaign level exists after the current one.
  bool get hasNextLevel => levelNo < campaignCount;

  /// Advance to the next campaign level (used by the win sheet).
  Future<void> nextLevel() => startCampaign(levelNo + 1);

  /// Practice/Zen "New puzzle": regenerate at the current difficulty and mode.
  Future<void> newPuzzle() async {
    final p = await puzzleRepo.generate(_difficulty);
    load(p, mode: _mode, difficulty: _difficulty);
  }

  void playAgain() {
    // Timed restarts the whole run; Zen serves a fresh puzzle; others retry the
    // same board.
    if (_mode == GameMode.timed) {
      startTimed();
      return;
    }
    if (_mode == GameMode.zen) {
      newPuzzle();
      return;
    }
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

  // ---- Resume persistence -------------------------------------------------

  /// Re-seed the board from a saved snapshot (called once at startup). Keeps
  /// the freshly-loaded [dailyPuzzle] for the hub; swaps the *active* board to
  /// the in-progress puzzle and lands the player back on it.
  GameController resumeFrom(GameSession s) {
    _puzzle = s.puzzle;
    _mode = s.mode;
    _difficulty = s.difficulty;
    _chain = s.chain.isEmpty ? [ChainNode(s.puzzle.start)] : List.of(s.chain);
    _used
      ..clear()
      ..addAll(s.used);
    _hintsUsed = s.hintsUsed;
    _resets = s.resets;
    _nextMilestone = s.nextMilestone;
    _solved = false;
    _started = true;
    return this;
  }

  /// Save the in-progress board (fire-and-forget). Skips solved boards and
  /// untouched ones (nothing worth resuming).
  void _persist() {
    if (sessionRepo == null || _solved) return;
    if (moves == 0 && _hintsUsed == 0 && _resets == 0) return;
    sessionRepo!.save(
      GameSession(
        mode: _mode,
        difficulty: _difficulty,
        puzzle: _puzzle,
        chain: _chain,
        used: _used,
        hintsUsed: _hintsUsed,
        resets: _resets,
        nextMilestone: _nextMilestone,
      ),
    );
  }

  void _clearSession() => sessionRepo?.clear();

  // ---- Stats --------------------------------------------------------------

  /// Whether the current chain used a `÷` op (for the Purist achievement).
  bool get _usedDivision =>
      puzzle.ops.any((o) => o.symbol == '÷' && (_used[o.id] ?? 0) > 0);

  /// Records a solve for the active mode. Only Daily touches the streak/dist;
  /// other modes bump their own counters or the archive-completion set. Every
  /// mode re-evaluates achievements. (Timed records per-stage in [_solveTimed].)
  void _recordSolve() {
    final ctx = SolveContext(scoreOver: scoreOver, usedDivision: _usedDivision);
    switch (_mode) {
      case GameMode.daily:
        if (_recorded) return;
        _recorded = true;
        _stats = _stats.recordWin(moves, par, today: _todayIndex());
      case GameMode.practice:
        _stats = _stats.bumpCounter('practice');
      case GameMode.zen:
        _stats = _stats.bumpCounter('zen');
      case GameMode.archive:
        _stats = _stats.markArchive(_puzzle.no);
      case GameMode.campaign:
        _stats = _stats.recordLevel(_puzzle.no, starsFor(moves, par));
      case GameMode.timed:
        return; // recorded per-stage in _solveTimed
    }
    _awardXp(_xpForSolve());
    _stats = _stats.withUnlocked(earnedAchievements(_stats, ctx));
    _statsRepo.save(_stats);
  }

  /// Local-date day index (days since epoch) for streak-gap math. Only day-to-
  /// day *differences* matter, so a constant tz offset is harmless.
  /// ponytail: naive local-midnight index; good enough for daily streaks.
  int _todayIndex() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay;
  }

  /// XP for one puzzle solve. Base + a bonus for beating par; zen (no par) is
  /// flat; campaign adds a per-star bonus. ponytail: tunable reward knobs.
  int _xpForSolve() {
    if (isZen) return 10;
    final under = par - moves;
    var xp = 10 + (under > 0 ? under * 5 : 0);
    if (_mode == GameMode.campaign) xp += (starsFor(moves, par) - 1) * 5;
    return xp;
  }

  /// Grant [amount] XP and remember it for the win sheet. Level-up is surfaced
  /// by the home XP bar advancing (the win sheet shows the gain + new level).
  void _awardXp(int amount) {
    _lastXpGain = amount;
    _stats = _stats.bumpCounter('xp', amount);
  }

  /// XP awarded by the most recent solve.
  int get lastXpGain => _lastXpGain;

  /// Current player level (from lifetime XP).
  int get playerLevel => _stats.playerLevel;

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
    _tickTimer?.cancel();
    _hintTimer?.cancel();
    super.dispose();
  }
}
