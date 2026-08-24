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

  testWidgets('solving the board shows the win overlay with New board',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(host(TreeGamePage(puzzle: winnable())));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OperationButton, '×3'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OperationButton, '+1'));
    await tester.pumpAndSettle();
    expect(find.textContaining('SOLVED'), findsOneWidget);
    expect(find.text('New board'), findsOneWidget);
  });

  testWidgets('New board dismisses the win overlay and deals a fresh board',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(host(TreeGamePage(puzzle: winnable())));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OperationButton, '×3'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OperationButton, '+1'));
    await tester.pumpAndSettle();
    expect(find.textContaining('SOLVED'), findsOneWidget);
    await tester.tap(find.text('New board'));
    await tester.pumpAndSettle();
    expect(find.textContaining('SOLVED'), findsNothing); // overlay gone
    expect(find.text('0/2'), findsOneWidget); // fresh: nothing reached
  });

  testWidgets('an illegal tap surfaces the reject toast', (tester) async {
    phone(tester);
    await tester.pumpWidget(host(TreeGamePage(puzzle: rejecting())));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OperationButton, '÷2'));
    await tester.pumpAndSettle();
    expect(find.textContaining("doesn't divide"), findsOneWidget);
  });

  testWidgets('changing difficulty deals a board of the new tier',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(host(const TreeGamePage(tier: 'easy')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('difficulty')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('hard').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('HARD'), findsOneWidget); // header reflects the new tier
  });
}
