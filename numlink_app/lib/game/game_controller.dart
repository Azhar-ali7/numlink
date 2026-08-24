import 'package:flutter/foundation.dart';

import '../data/stats_repository.dart';
import '../models/achievement.dart';
import '../models/game_stats.dart';
import 'campaign.dart';
import 'game_mode.dart';
import 'puzzle_repository.dart';

/// Which overlay sheet is showing.
enum SheetOverlay { how, stats, settings, archive, roadmap, notifications }

/// Engine-agnostic stats + progression store. The branching engine
/// (`TreeController` / `TreeGamePage` / `TimedTreePage`) plays the boards as
/// pushed routes; when one is won it calls a `record*Win` bridge here to fold
/// the result into the shared [GameStats] (streak, distribution, XP, badges,
/// campaign stars). This class holds no board state of its own.
class GameController extends ChangeNotifier {
  GameController({
    required StatsRepository statsRepo,
    required GameStats initialStats,
    this.calendar = const PuzzleCalendar(),
  })  : _statsRepo = statsRepo,
        _stats = initialStats,
        _daily = calendar.today();

  final StatsRepository _statsRepo;
  final PuzzleCalendar calendar;
  final DailyInfo _daily;

  GameStats _stats;
  SheetOverlay? _overlay;
  int _lastXpGain = 0;

  // ---- Read-only view -----------------------------------------------------

  GameStats get stats => _stats;
  SheetOverlay? get overlay => _overlay;

  /// Daily identity for the Home hub / settings credits.
  DailyInfo get dailyPuzzle => _daily;

  List<int> get archiveNumbers => calendar.archiveNumbers();
  int get campaignCount => calendar.campaignCount;

  /// XP awarded by the most recent recorded win (shown on the win sheet).
  int get lastXpGain => _lastXpGain;

  /// Current player level (from lifetime XP).
  int get playerLevel => _stats.playerLevel;

  // ---- Overlay routing ----------------------------------------------------

  void open(SheetOverlay o) {
    _overlay = o;
    notifyListeners();
  }

  void close() {
    _overlay = null;
    notifyListeners();
  }

  // ---- Win bridges (called by the branching routes on solve) --------------

  /// Records a daily win into the shared stats (streak + distribution + XP +
  /// achievements). Idempotent per day.
  void recordDailyWin(int moves, int par) {
    final today = _todayIndex();
    if (_stats.lastDailyDay == today) return; // already logged today
    _stats = _stats.recordWin(moves, par, today: today);
    final under = par - moves;
    _awardXp(10 + (under > 0 ? under * 5 : 0));
    _finishWin(moves - par);
  }

  /// Folds a branching win for a non-daily mode into the shared stats
  /// (practice/zen counters, archive-solved set). Never touches the streak.
  void recordBranchingWin(GameMode mode, int moves, int par,
      {int archiveNo = 0}) {
    switch (mode) {
      case GameMode.practice:
        _stats = _stats.bumpCounter('practice');
      case GameMode.zen:
        _stats = _stats.bumpCounter('zen');
      case GameMode.archive:
        _stats = _stats.markArchive(archiveNo);
      default:
        break; // daily → recordDailyWin; campaign → recordCampaignWin
    }
    final under = par - moves;
    _awardXp(mode == GameMode.zen ? 10 : 10 + (under > 0 ? under * 5 : 0));
    _finishWin(moves - par);
  }

  /// Folds a branching campaign-level win into the shared stats: stars from
  /// moves-vs-par (kept as a per-level max), plus XP with the per-star bonus.
  /// Clearing a level unlocks the next.
  void recordCampaignWin(int no, int moves, int par) {
    final stars = starsFor(moves, par);
    _stats = _stats.recordLevel(no, stars);
    final under = par - moves;
    _awardXp(10 + (under > 0 ? under * 5 : 0) + (stars - 1) * 5);
    _finishWin(moves - par);
  }

  /// Banks one cleared stage of a branching timed run: every stage lifts the
  /// best-stage counter; the final stage ([runDone]) bumps the run count and
  /// awards whole-run XP (5 per stage).
  void recordTimedStage(int stageCompleted, {bool runDone = false}) {
    _stats = _stats.setCounterMax('timedBestStage', stageCompleted);
    if (runDone) {
      _stats = _stats.bumpCounter('timedRuns');
      _awardXp(stageCompleted * 5);
    }
    _finishWin(0);
  }

  /// Shared tail for every bridge: re-evaluate achievements, persist, notify.
  void _finishWin(int scoreOver) {
    _stats = _stats.withUnlocked(earnedAchievements(
        _stats, SolveContext(scoreOver: scoreOver, usedDivision: false)));
    _statsRepo.save(_stats);
    notifyListeners();
  }

  /// Grant [amount] XP and remember it for the win sheet.
  void _awardXp(int amount) {
    _lastXpGain = amount;
    _stats = _stats.bumpCounter('xp', amount);
  }

  /// Whether today's daily has already been solved (drives the home week strip).
  bool get todaySolved => _stats.lastDailyDay == _todayIndex();

  /// Local-date day index (days since epoch) for streak-gap math. Only day-to-
  /// day *differences* matter, so a constant tz offset is harmless.
  int _todayIndex() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay;
  }
}
