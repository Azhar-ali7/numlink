import 'package:flutter_test/flutter_test.dart';
import 'package:numlink_app/data/stats_repository.dart';
import 'package:numlink_app/game/game_controller.dart';
import 'package:numlink_app/game/game_mode.dart';
import 'package:numlink_app/game/puzzle_repository.dart';
import 'package:numlink_app/game/solver.dart';
import 'package:numlink_app/models/game_stats.dart';
import 'package:numlink_app/models/operation.dart';
import 'package:numlink_app/models/puzzle.dart';
import 'package:numlink_app/services/feedback_service.dart';

/// In-memory stats repo for tests.
class FakeStatsRepository implements StatsRepository {
  GameStats saved = GameStats.empty;
  @override
  Future<GameStats> load() async => saved;
  @override
  Future<void> save(GameStats stats) async => saved = stats;
}

/// Repo that hands out trivial 1-move puzzles (1 +1→ 2), so timed-ladder
/// progression is deterministic without knowing generated solutions.
class FakePuzzleRepository implements PuzzleRepository {
  Puzzle _trivial(int no) => Puzzle(
        no: no,
        dateLabel: '',
        start: 1,
        target: 2,
        par: 1,
        ops: const [Operation(id: 'p1', symbol: '+', n: 1, tokens: 1)],
      );
  @override
  Future<Puzzle> today() async => _trivial(1);
  @override
  Future<Puzzle> daily(DateTime date) async => _trivial(1);
  @override
  Future<Puzzle> generate(Difficulty d, {int? seed}) async => _trivial(1);
  @override
  Future<Puzzle> archive(int puzzleNo) async => _trivial(puzzleNo);
  @override
  List<Puzzle> ladder(int count, {required int runSeed}) =>
      [for (var i = 0; i < count; i++) _trivial(i + 1)];
}

/// Fixed reference puzzle (the handoff #128) so tests don't depend on the
/// live generated daily. Par-3: 2 ×3→6 +7→13 ×2→26.
const Puzzle kReferencePuzzle = Puzzle(
  no: 128,
  dateLabel: 'AUG 8 2026',
  start: 2,
  target: 26,
  par: 3,
  ops: [
    Operation(id: 'm3', symbol: '×', n: 3, tokens: 2),
    Operation(id: 'p7', symbol: '+', n: 7, tokens: 2),
    Operation(id: 'm2', symbol: '×', n: 2, tokens: 3),
    Operation(id: 's1', symbol: '−', n: 1, tokens: 3),
    Operation(id: 'd2', symbol: '÷', n: 2, tokens: 2),
    Operation(id: 'p5', symbol: '+', n: 5, tokens: 2),
  ],
);

Future<GameController> _controller() async {
  return GameController(
    puzzle: kReferencePuzzle,
    statsRepo: FakeStatsRepository(),
    feedback: FeedbackService(),
    initialStats: GameStats.empty,
  ).init();
}

Operation _op(GameController g, String id) =>
    g.puzzle.ops.firstWhere((o) => o.id == id);

void main() {
  group('compute legality', () {
    test('÷ rejects non-integer results', () async {
      final g = await _controller();
      // start = 2; ÷2 -> 1 legal, but +7 first -> 9, ÷2 illegal.
      g.apply(_op(g, 'p7')); // 2 -> 9
      expect(g.current, 9);
      final before = g.chain.length;
      g.apply(_op(g, 'd2')); // 9 ÷ 2 -> illegal
      expect(g.chain.length, before, reason: 'illegal op must not change chain');
      expect(g.message, isNotNull);
    });

    test('operations cannot exceed range 0..999', () async {
      final g = await _controller();
      // Force a large value via ×3 twice then ×2 thrice would exceed; but token
      // caps limit us. Simpler: −1 below zero from start 2 twice is fine (0),
      // a third −1 would go negative and be rejected.
      g.apply(_op(g, 's1')); // 2 -> 1
      g.apply(_op(g, 's1')); // 1 -> 0
      final before = g.chain.length;
      g.apply(_op(g, 's1')); // 0 -> -1 illegal
      expect(g.chain.length, before);
    });
  });

  group('tokens', () {
    test('apply decrements and undo refunds', () async {
      final g = await _controller();
      final m3 = _op(g, 'm3');
      expect(g.remaining(m3), 2);
      g.apply(m3); // 2 -> 6
      expect(g.remaining(m3), 1);
      g.undo();
      expect(g.remaining(m3), 2);
      expect(g.current, 2);
    });

    test('running out of tokens disables the op', () async {
      final g = await _controller();
      final d2 = _op(g, 'd2'); // 2 tokens
      g.apply(d2); // 2 -> 1
      // reset value path: 1 ÷2 illegal, so build a divisible chain instead.
      g.reset();
      // 2 ×3 -> 6, ÷2 -> 3, ... use two ÷2 to exhaust tokens.
      g.apply(_op(g, 'm2')); // 2 -> 4
      g.apply(d2); // 4 -> 2  (token 1 used)
      g.apply(_op(g, 'm2')); // 2 -> 4
      g.apply(d2); // 4 -> 2  (token 2 used)
      expect(g.remaining(d2), 0);
      expect(g.isDisabled(d2), isTrue);
    });
  });

  group('solve', () {
    test('par-3 solution solves and records a win', () async {
      final g = await _controller();
      g.apply(_op(g, 'm3')); // 2 -> 6
      g.apply(_op(g, 'p7')); // 6 -> 13
      g.apply(_op(g, 'm2')); // 13 -> 26 == target
      expect(g.solved, isTrue);
      expect(g.moves, 3);
      expect(g.overlay, SheetOverlay.win);
      expect(g.stats.wins, 1);
      expect(g.stats.streak, 1);
      expect(g.scoreLabel, ScoreLabel.par);
      expect(g.currentBucket, 'par');
    });

    test('applying ops after solve is a no-op', () async {
      final g = await _controller();
      g.apply(_op(g, 'm3'));
      g.apply(_op(g, 'p7'));
      g.apply(_op(g, 'm2')); // solved
      final moves = g.moves;
      g.apply(_op(g, 'm2'));
      expect(g.moves, moves);
    });
  });

  group('heat + share', () {
    test('heat reaches 100 and onTarget when solved', () async {
      final g = await _controller();
      g.apply(_op(g, 'm3'));
      g.apply(_op(g, 'p7'));
      g.apply(_op(g, 'm2'));
      expect(g.heat, Heat.onTarget);
      expect(g.heatPercent, 100);
    });

    test('share grid is spoiler-free', () async {
      final g = await _controller();
      g.apply(_op(g, 'm3'));
      g.apply(_op(g, 'p7'));
      g.apply(_op(g, 'm2'));
      final txt = g.shareText();
      expect(txt, contains('NUMLINK #128'));
      expect(txt, contains('3 moves · par 3'));
      expect(txt, contains('🟦🟦🟦'));
      expect(txt, contains('🎯'));
    });
  });

  test('solver reports honest par of 3', () async {
    expect(minMoves(kReferencePuzzle), 3);
  });

  group('practice mode', () {
    test('startPractice loads a solvable puzzle at the chosen tier', () async {
      final g = await _controller();
      await g.startPractice(Difficulty.easy);
      expect(g.mode, GameMode.practice);
      expect(g.difficulty, Difficulty.easy);
      expect(g.moves, 0);
      expect(g.solved, isFalse);
      final min = minMoves(g.puzzle);
      expect(min, equals(g.puzzle.par)); // honest par
      expect(g.puzzle.par, inInclusiveRange(2, 3)); // easy band
    });

    test('newPuzzle swaps the board and keeps difficulty', () async {
      final g = await _controller();
      await g.startPractice(Difficulty.hard);
      final first = g.puzzle;
      await g.newPuzzle();
      expect(g.difficulty, Difficulty.hard);
      expect(g.moves, 0);
      // Overwhelmingly likely to differ (random seed); at minimum board reset.
      expect(identical(g.puzzle, first), isFalse);
    });

    test('practice wins do not touch the daily streak', () async {
      final g = await _controller();
      final streakBefore = g.stats.streak;
      final winsBefore = g.stats.wins;
      // Handcrafted 1-move puzzle so the solve is deterministic.
      g.load(
        const Puzzle(
          no: 0,
          dateLabel: '',
          start: 1,
          target: 2,
          par: 1,
          ops: [Operation(id: 'p1', symbol: '+', n: 1, tokens: 1)],
        ),
        mode: GameMode.practice,
        difficulty: Difficulty.easy,
      );
      g.apply(_op(g, 'p1')); // 1 -> 2 == target, solved
      expect(g.solved, isTrue);
      expect(g.stats.streak, streakBefore);
      expect(g.stats.wins, winsBefore);
    });
  });

  group('zen mode', () {
    test('startZen tags the session zen with no par pressure', () async {
      final g = await _controller();
      await g.startZen(Difficulty.easy);
      expect(g.mode, GameMode.zen);
      expect(g.isZen, isTrue);
      expect(g.solved, isFalse);
    });

    test('zen wins skip the streak and the summary omits par', () async {
      final g = await _controller();
      final streakBefore = g.stats.streak;
      g.load(
        const Puzzle(
          no: 0,
          dateLabel: '',
          start: 1,
          target: 2,
          par: 1,
          ops: [Operation(id: 'p1', symbol: '+', n: 1, tokens: 1)],
        ),
        mode: GameMode.zen,
        difficulty: Difficulty.easy,
      );
      g.apply(_op(g, 'p1')); // solved
      expect(g.solved, isTrue);
      expect(g.stats.streak, streakBefore);
      expect(g.stats.wins, 0);
      expect(g.winSummary, contains('moves'));
      expect(g.winSummary, isNot(contains('par')));
    });
  });

  group('timed ladder', () {
    Future<GameController> timedController(FakeStatsRepository stats) async {
      return GameController(
        puzzle: kReferencePuzzle,
        statsRepo: stats,
        feedback: FeedbackService(),
        initialStats: GameStats.empty,
        puzzleRepo: FakePuzzleRepository(),
      ).init();
    }

    test('each solve advances a stage, last solve finishes the run', () async {
      final g = await timedController(FakeStatsRepository());
      await g.startTimed();
      expect(g.mode, GameMode.timed);
      expect(g.stage, 1);
      final n = g.stageCount;
      expect(n, greaterThan(1));

      for (var i = 1; i < n; i++) {
        g.apply(_op(g, 'p1')); // solve stage i
        expect(g.solved, isFalse, reason: 'mid-ladder should not finish');
        expect(g.stage, i + 1, reason: 'should advance to next stage');
      }
      g.apply(_op(g, 'p1')); // solve final stage
      expect(g.solved, isTrue);
      expect(g.overlay, SheetOverlay.win);
      expect(g.bestStage, n);
      expect(g.winSummary, contains('stages'));
    });

    test('timed wins do not touch the daily streak', () async {
      final stats = FakeStatsRepository();
      final g = await timedController(stats);
      final streakBefore = g.stats.streak;
      await g.startTimed();
      for (var i = 0; i < g.stageCount; i++) {
        g.apply(_op(g, 'p1'));
      }
      expect(g.stats.streak, streakBefore);
      expect(g.stats.wins, 0);
    });
  });
}
