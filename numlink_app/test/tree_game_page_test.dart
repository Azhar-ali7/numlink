import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numlink_app/data/settings_controller.dart';
import 'package:numlink_app/game/tree_generator.dart';
import 'package:numlink_app/models/operation.dart';
import 'package:numlink_app/screens/tree_game_page.dart';
import 'package:numlink_app/services/feedback_service.dart';
import 'package:numlink_app/theme/app_theme.dart';
import 'package:numlink_app/theme/tokens.dart';
import 'package:numlink_app/widgets/coach_marks.dart';
import 'package:numlink_app/widgets/operation_button.dart';
import 'package:numlink_app/widgets/radial_board.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Operation op(String id, String symbol, int n, {int tokens = 3}) =>
    Operation(id: id, symbol: symbol, n: n, tokens: tokens);

/// Solvable in two taps: 2 →×3→ 6 →+1→ 7 (selection auto-follows each move).
TreePuzzle winnable() => TreePuzzle(
  tier: 'test',
  start: 2,
  targets: const [6, 7],
  hands: [
    [op('m', '×', 3), op('p', '+', 1)],
  ],
  hints: 1,
  shuffles: 1,
  branchMax: 3,
  par: 3,
  optimalPar: 2,
  optimalEdges: const [(2, 6), (6, 7)],
  dpValid: true,
);

/// One illegal op so the reject toast fires: 5 ÷ 2 is not integer.
TreePuzzle rejecting() => TreePuzzle(
  tier: 'test',
  start: 5,
  targets: const [1],
  hands: [
    [op('d', '÷', 2)],
  ],
  hints: 1,
  shuffles: 0,
  branchMax: 3,
  par: 3,
  optimalPar: 1,
  optimalEdges: const [],
  dpValid: true,
);

/// The app shell caps the board at 440px wide; match it so the pad never
/// overflows the default 800px test window.
void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget host(Widget child) => MaterialApp(
  theme: buildTheme(NumTokens.light, Brightness.light),
  home: MediaQuery(
    // kill looping animations so pending timers don't trip teardown
    data: const MediaQueryData(disableAnimations: true),
    child: child,
  ),
);

void main() {
  testWidgets('a real generated board renders playable', (tester) async {
    phone(tester);
    await tester.pumpWidget(host(const TreeGamePage(tier: 'easy')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(RadialBoard), findsOneWidget);
    expect(find.byType(OperationButton), findsWidgets);
  });

  testWidgets('solving the board shows the win sheet with Play again', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(host(TreeGamePage(puzzle: winnable())));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OperationButton, '×3'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OperationButton, '+1'));
    await tester.pumpAndSettle();
    expect(find.textContaining('CHAIN COMPLETE'), findsOneWidget);
    expect(find.text('Play again'), findsOneWidget);
  });

  testWidgets('Play again dismisses the win sheet and deals a fresh board', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(host(TreeGamePage(puzzle: winnable())));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OperationButton, '×3'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OperationButton, '+1'));
    await tester.pumpAndSettle();
    expect(find.textContaining('CHAIN COMPLETE'), findsOneWidget);
    await tester.tap(find.text('Play again'));
    await tester.pumpAndSettle();
    expect(find.textContaining('CHAIN COMPLETE'), findsNothing); // sheet gone
    expect(find.text('0/2'), findsOneWidget); // fresh: nothing reached
  });

  testWidgets('the win sheet swipes down to reveal the board, and back', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(host(TreeGamePage(puzzle: winnable())));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OperationButton, '×3'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OperationButton, '+1'));
    await tester.pumpAndSettle();
    expect(find.text('Play again'), findsOneWidget);

    await tester.fling(find.text('Play again'), const Offset(0, 300), 1000);
    await tester.pumpAndSettle();
    expect(
      find.text('Play again'),
      findsNothing,
      reason: 'collapsed to a pill',
    );
    expect(find.textContaining('2 moves'), findsOneWidget);

    await tester.tap(find.textContaining('2 moves'));
    await tester.pumpAndSettle();
    expect(find.text('Play again'), findsOneWidget);
  });

  // Campaign only: clearing a level should lead into the next one, not send
  // the player back through the roadmap.
  testWidgets('onNext takes the primary slot and demotes Play again', (
    tester,
  ) async {
    phone(tester);
    var next = 0;
    await tester.pumpWidget(
      host(TreeGamePage(puzzle: winnable(), onNext: () => next++)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OperationButton, '×3'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OperationButton, '+1'));
    await tester.pumpAndSettle();

    expect(find.text('Next level'), findsOneWidget);
    expect(
      find.text('Play again'),
      findsOneWidget,
      reason: 'demoted, not gone',
    );
    await tester.tap(find.text('Next level'));
    expect(next, 1);
  });

  testWidgets('a timed board counts down and ends in the Time\'s up sheet', (
    tester,
  ) async {
    phone(tester);
    final p = winnable();
    await tester.pumpWidget(
      host(TreeGamePage(puzzle: p, timed: true, onWin: null)),
    );
    await tester.pump();
    expect(find.text(clockText(budgetFor(p))), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text(clockText(budgetFor(p) - 1)), findsOneWidget);

    // Run the budget out. No win is recorded; the board just freezes.
    await tester.pump(Duration(seconds: budgetFor(p)));
    await tester.pump();
    expect(find.text("Time's up"), findsOneWidget);
    expect(find.text('0:00'), findsOneWidget);

    // Try again re-arms a full budget.
    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(find.text("Time's up"), findsNothing);
    expect(find.text(clockText(budgetFor(p))), findsOneWidget);
  });

  testWidgets('onWin fires once with (moves, par) on solve', (tester) async {
    phone(tester);
    var calls = 0;
    int? gotMoves;
    int? gotPar;
    await tester.pumpWidget(
      host(
        TreeGamePage(
          puzzle: winnable(),
          onWin: (m, p, div) {
            calls++;
            gotMoves = m;
            gotPar = p;
            return null;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OperationButton, '×3'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OperationButton, '+1'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(gotMoves, 2);
    expect(gotPar, 3);
  });

  testWidgets('timed page renders stage 1 of the ladder with a live board', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(host(const TimedTreePage()));
    await tester.pump();
    expect(find.textContaining('STAGE 1/8'), findsOneWidget);
    expect(find.byType(RadialBoard), findsOneWidget);
    // Unmount to cancel the stopwatch Timer.periodic (else teardown flags it).
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an illegal tap surfaces the reject toast', (tester) async {
    phone(tester);
    await tester.pumpWidget(host(TreeGamePage(puzzle: rejecting())));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OperationButton, '÷2'));
    await tester.pumpAndSettle();
    expect(find.textContaining("doesn't divide"), findsOneWidget);
  });

  testWidgets('a kids board is one target, one move, + − × only', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(host(const TreeGamePage(tier: 'kids')));
    await tester.pumpAndSettle();
    expect(find.text('Kids'), findsOneWidget);
    expect(find.text('0/1'), findsOneWidget, reason: 'exactly one target');
    for (final b in tester.widgetList<OperationButton>(
      find.byType(OperationButton),
    )) {
      expect(
        ['+', '−', '×'],
        contains(b.op.symbol),
        reason: 'kids dealt ${b.op.symbol}',
      );
    }
  });

  // A fixed board (daily / campaign / archive / co-op) has no tier to switch:
  // picking one would silently throw today's shared board away.
  testWidgets('a fixed board hides the difficulty picker', (tester) async {
    phone(tester);
    await tester.pumpWidget(host(TreeGamePage(puzzle: winnable())));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('difficulty')));
    await tester.pumpAndSettle();
    expect(find.text('Difficulty'), findsNothing);
    expect(find.byKey(const ValueKey('tier_kids')), findsNothing);
  });

  // Handing over the answer on the first look is a spoiler; after two
  // restarts of the same board it's a rescue.
  testWidgets('Reveal solution appears only after two restarts', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(host(TreeGamePage(puzzle: winnable())));
    await tester.pumpAndSettle();

    Future<void> openMenu() async {
      await tester.tap(find.byKey(const Key('difficulty')));
      await tester.pumpAndSettle();
    }

    await openMenu();
    expect(find.text('Reveal solution'), findsNothing);
    await tester.tap(find.text('Restart')); // 1st
    await tester.pumpAndSettle();

    await openMenu();
    expect(find.text('Reveal solution'), findsNothing, reason: 'one restart');
    await tester.tap(find.text('Restart')); // 2nd
    await tester.pumpAndSettle();

    await openMenu();
    expect(find.text('Reveal solution'), findsOneWidget);
    await tester.tap(find.text('New board')); // fresh puzzle resets the count
    await tester.pumpAndSettle();

    await openMenu();
    expect(find.text('Reveal solution'), findsNothing);
  });

  testWidgets('changing difficulty deals a board of the new tier', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(host(const TreeGamePage(tier: 'easy')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('difficulty')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tier_hard')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // header reflects the new tier, under its player-facing name
    expect(find.text('Expert'), findsOneWidget);
  });

  group('first-board coach marks', () {
    /// The page under a real SettingsController — the tour only mounts when
    /// one is in scope (isolated board tests have no provider, so no overlay).
    Future<SettingsController> pumpBoard(
      WidgetTester tester, {
      bool seen = false,
    }) async {
      SharedPreferences.setMockInitialValues(
        seen ? {'coachSeen': true} : <String, Object>{},
      );
      final s = SettingsController(
        prefs: await SharedPreferences.getInstance(),
        feedback: FeedbackService(),
      );
      phone(tester);
      await tester.pumpWidget(
        host(
          ChangeNotifierProvider.value(
            value: s,
            child: TreeGamePage(puzzle: winnable()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return s;
    }

    testWidgets('play through all six steps, then it never comes back', (
      tester,
    ) async {
      final s = await pumpBoard(tester);
      expect(find.byType(CoachOverlay), findsOneWidget);
      for (var i = 0; i < 5; i++) {
        expect(find.text('Next'), findsOneWidget, reason: 'step ${i + 1} of 6');
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }
      expect(find.text('Got it'), findsOneWidget);
      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();
      expect(find.byType(CoachOverlay), findsNothing);
      expect(s.coachSeen, isTrue);
    });

    testWidgets('the spotlighted control still works mid-tour', (tester) async {
      await pumpBoard(tester);
      // Step 3 spotlights the op pad and says "tap an operation" -- so the tap
      // has to reach it. The scrim used to swallow it.
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }
      expect(find.text('Apply an operation'), findsOneWidget);
      await tester.tap(find.widgetWithText(OperationButton, '×3'));
      await tester.pumpAndSettle();
      expect(find.text('1/2'), findsOneWidget);
      expect(find.byType(CoachOverlay), findsOneWidget, reason: 'tour stays');
    });

    testWidgets('Skip ends it too', (tester) async {
      final s = await pumpBoard(tester);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(find.byType(CoachOverlay), findsNothing);
      expect(s.coachSeen, isTrue);
    });

    testWidgets('once seen, the board is immediately playable', (tester) async {
      await pumpBoard(tester, seen: true);
      expect(find.byType(CoachOverlay), findsNothing);
      await tester.tap(find.widgetWithText(OperationButton, '×3'));
      await tester.pumpAndSettle();
      expect(find.text('1/2'), findsOneWidget); // the tap landed on the board
    });
  });
}
