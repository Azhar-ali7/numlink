import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numlink_app/game/tree_generator.dart';
import 'package:numlink_app/models/operation.dart';
import 'package:numlink_app/screens/tree_game_page.dart';
import 'package:numlink_app/theme/app_theme.dart';
import 'package:numlink_app/theme/tokens.dart';
import 'package:numlink_app/widgets/operation_button.dart';
import 'package:numlink_app/widgets/radial_board.dart';

Operation op(String id, String symbol, int n, {int tokens = 3}) =>
    Operation(id: id, symbol: symbol, n: n, tokens: tokens);

/// Solvable in two taps: 2 →×3→ 6 →+1→ 7 (selection auto-follows each move).
TreePuzzle winnable() => TreePuzzle(
      tier: 'test',
      start: 2,
      targets: const [6, 7],
      hands: [
        [op('m', '×', 3), op('p', '+', 1)]
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
        [op('d', '÷', 2)]
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

  testWidgets('solving the board shows the win sheet with Play again',
      (tester) async {
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

  testWidgets('Play again dismisses the win sheet and deals a fresh board',
      (tester) async {
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

  testWidgets('the win sheet swipes down to reveal the board, and back',
      (tester) async {
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
    expect(find.text('Play again'), findsNothing, reason: 'collapsed to a pill');
    expect(find.textContaining('2 moves'), findsOneWidget);

    await tester.tap(find.textContaining('2 moves'));
    await tester.pumpAndSettle();
    expect(find.text('Play again'), findsOneWidget);
  });

  testWidgets('onWin fires once with (moves, par) on solve', (tester) async {
    phone(tester);
    var calls = 0;
    int? gotMoves;
    int? gotPar;
    await tester.pumpWidget(host(TreeGamePage(
      puzzle: winnable(),
      onWin: (m, p) {
        calls++;
        gotMoves = m;
        gotPar = p;
        return null;
      },
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OperationButton, '×3'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OperationButton, '+1'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(gotMoves, 2);
    expect(gotPar, 3);
  });

  testWidgets('timed page renders stage 1 of the ladder with a live board',
      (tester) async {
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

  testWidgets('a kids board is one target, one move, + − × only',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(host(const TreeGamePage(tier: 'kids')));
    await tester.pumpAndSettle();
    expect(find.text('Kids'), findsOneWidget);
    expect(find.text('0/1'), findsOneWidget, reason: 'exactly one target');
    for (final b in tester.widgetList<OperationButton>(
        find.byType(OperationButton))) {
      expect(['+', '−', '×'], contains(b.op.symbol),
          reason: 'kids dealt ${b.op.symbol}');
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
  testWidgets('Reveal solution appears only after two restarts',
      (tester) async {
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

  testWidgets('changing difficulty deals a board of the new tier',
      (tester) async {
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
}
