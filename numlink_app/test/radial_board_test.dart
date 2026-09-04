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
    [op('m', '×', 3), op('p', '+', 1)],
  ],
  hints: 1,
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
      expect(
        pos[2]!.distance,
        greaterThan(pos[1]!.distance),
      ); // deeper = farther
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

  group('ghostLayout — targets never stack on a node or each other', () {
    // Minimum centre-to-centre gap we require between any two markers. Node
    // chips are ~100px wide but don't fill the slot; 88 catches true stacks
    // (~0px) without disturbing the natural ~100px fan.
    const minGap = 88.0;

    void assertNoOverlap(List<Offset> markers) {
      for (var i = 0; i < markers.length; i++) {
        for (var j = i + 1; j < markers.length; j++) {
          expect(
            (markers[i] - markers[j]).distance,
            greaterThanOrEqualTo(minGap),
            reason: 'markers $i and $j overlap',
          );
        }
      }
    }

    test('after first move (×3 on 6→18): ghost 9 does not land on node 18', () {
      // The reported bug: nodes {6, 18}, remaining targets {13, 9}. Target 9
      // is nearest node 6 (the root, whose ray is now occupied by the 18 arm),
      // so it used to be placed straight down — on top of node 18.
      final nodes = [
        const TreeNode(id: 0, v: 6),
        const TreeNode(id: 1, v: 18, parent: 0),
      ];
      final pos = radialLayout(nodes);
      final g = ghostLayout(
        missing: const [13, 9],
        nodes: nodes,
        nodePos: pos,
        gap: 120,
      );
      assertNoOverlap([...pos.values, ...g.pos.values]);
    });

    test('initial board (no moves): two targets fan without overlapping', () {
      final nodes = [const TreeNode(id: 0, v: 6)];
      final pos = radialLayout(nodes);
      final g = ghostLayout(
        missing: const [13, 9],
        nodes: nodes,
        nodePos: pos,
        gap: 120,
      );
      assertNoOverlap([...pos.values, ...g.pos.values]);
    });

    test('several ghosts on one occupied anchor all stay clear', () {
      final nodes = [
        const TreeNode(id: 0, v: 6),
        const TreeNode(id: 1, v: 12, parent: 0),
      ];
      final pos = radialLayout(nodes);
      final g = ghostLayout(
        missing: const [7, 8, 9, 10],
        nodes: nodes,
        nodePos: pos,
        gap: 120,
      );
      assertNoOverlap([...pos.values, ...g.pos.values]);
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

    testWidgets('tapping an op places a node and updates reached count', (
      tester,
    ) async {
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

    testWidgets('a node far outside the viewport is still tappable', (
      tester,
    ) async {
      phone(tester);
      // A deep chain makes the canvas taller than the viewport. The board used
      // to be silently clamped to the viewport by its parent Stack, so chips
      // past that rect painted but never hit-tested.
      final c = TreeController(
        TreePuzzle(
          tier: 'test',
          start: 2,
          targets: const [11],
          hands: [
            [op('p', '+', 1, tokens: 12)],
          ],
          hints: 0,
          shuffles: 0,
          branchMax: 12,
          par: 12,
          optimalPar: 12,
          optimalEdges: const [],
          dpValid: false,
        ),
      )..init();
      for (var i = 0; i < 8; i++) {
        c.apply(op('p', '+', 1, tokens: 12));
      }
      await tester.pumpWidget(host(c));
      await tester.pumpAndSettle();
      expect(c.nodes.last.v, 10);
      c.select(0); // so the tap below is what moves the selection
      await tester.tap(find.text('10'));
      expect(c.sel, c.nodes.last.id, reason: 'the tap selects immediately');
      await tester.pump(const Duration(seconds: 3)); // drain controller timers
    });

    testWidgets('a real generated board renders without exceptions', (
      tester,
    ) async {
      phone(tester);
      final c = TreeController(buildPuzzle('hard', 7001234))..init();
      await tester.pumpWidget(host(c));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(RadialBoard), findsOneWidget);
    });
  });
}
