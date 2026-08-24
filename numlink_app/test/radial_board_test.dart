import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numlink_app/game/tree_controller.dart';
import 'package:numlink_app/game/tree_generator.dart';
import 'package:numlink_app/models/operation.dart';
import 'package:numlink_app/screens/tree_game_screen.dart';
import 'package:numlink_app/theme/app_theme.dart';
import 'package:numlink_app/theme/tokens.dart';
import 'package:numlink_app/widgets/operation_button.dart';
import 'package:numlink_app/widgets/radial_board.dart';
import 'package:provider/provider.dart';

Operation op(String id, String symbol, int n, {int tokens = 3}) =>
    Operation(id: id, symbol: symbol, n: n, tokens: tokens);

TreePuzzle fixture() => TreePuzzle(
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
      dpValid: false,
    );

/// Match production: the app shell caps the board at 440px wide.
void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget host(TreeController c) => MaterialApp(
      theme: buildTheme(NumTokens.light, Brightness.light),
      home: MediaQuery(
        // disable looping animations so pending timers don't trip teardown
        data: const MediaQueryData(disableAnimations: true),
        child: ChangeNotifierProvider<TreeController>.value(
          value: c,
          child: const Scaffold(body: TreeGameScreen()),
        ),
      ),
    );

void main() {
  group('radial layout', () {
    test('start at origin; children fan out by depth ring', () {
      final nodes = [
        const TreeNode(id: 0, v: 2),
        const TreeNode(id: 1, v: 6, parent: 0),
        const TreeNode(id: 2, v: 18, parent: 1),
      ];
      final pos = radialLayout(nodes);
      expect(pos[0], Offset.zero); // start centred
      expect(pos[1]!.distance, greaterThan(0)); // depth 1 off-centre
      expect(pos[2]!.distance, greaterThan(pos[1]!.distance)); // deeper = farther
    });

    test('siblings get distinct angles', () {
      final nodes = [
        const TreeNode(id: 0, v: 2),
        const TreeNode(id: 1, v: 6, parent: 0),
        const TreeNode(id: 2, v: 5, parent: 0),
      ];
      final pos = radialLayout(nodes);
      expect(pos[1], isNot(pos[2]));
    });
  });

  group('TreeGameScreen', () {
    testWidgets('renders start node, targets bar, and op pad', (tester) async {
      phone(tester);
      final c = TreeController(fixture())..init();
      await tester.pumpWidget(host(c));
      expect(tester.takeException(), isNull);
      expect(find.text('2'), findsWidgets); // start value on the board
      expect(find.textContaining('TARGETS'), findsOneWidget);
      expect(find.text('0/2'), findsOneWidget); // none reached yet
      expect(find.byType(OperationButton), findsNWidgets(2));
    });

    testWidgets('tapping an op places a node and updates reached count',
        (tester) async {
      phone(tester);
      final c = TreeController(fixture())..init();
      await tester.pumpWidget(host(c));
      await tester.tap(find.widgetWithText(OperationButton, '×3'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(c.nodes.map((n) => n.v), [2, 6]);
      expect(find.text('6'), findsWidgets); // new node rendered
      expect(find.text('1/2'), findsOneWidget); // one target reached
    });

    testWidgets('reaching every target shows the win state', (tester) async {
      phone(tester);
      final c = TreeController(fixture())..init();
      await tester.pumpWidget(host(c));
      c.apply(op('m', '×', 3)); // 2 → 6
      c.apply(op('p', '+', 1)); // 6 → 7
      await tester.pumpAndSettle();
      expect(c.solved, isTrue);
      expect(tester.takeException(), isNull);
      expect(find.text('2/2'), findsOneWidget);
    });

    testWidgets('a real generated board renders without exceptions',
        (tester) async {
      phone(tester);
      final c = TreeController(buildPuzzle('hard', 7001234))..init();
      await tester.pumpWidget(host(c));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(RadialBoard), findsOneWidget);
    });
  });
}
