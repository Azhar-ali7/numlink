import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numlink_app/app.dart';
import 'package:numlink_app/data/settings_controller.dart';
import 'package:numlink_app/game/game_controller.dart';
import 'package:numlink_app/game/game_mode.dart';
import 'package:numlink_app/models/game_stats.dart';
import 'package:numlink_app/services/feedback_service.dart';
import 'package:numlink_app/widgets/operation_button.dart';
import 'package:numlink_app/widgets/radial_board.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game_controller_test.dart' show FakeStatsRepository, kReferencePuzzle;

Future<GameController> _pumpApp(WidgetTester tester) async {
  // Flow tests exercise the game, not onboarding: mark the intro seen so the
  // first-run carousel doesn't cover the hub. Carousel behavior is covered in
  // settings_controller_test.dart.
  SharedPreferences.setMockInitialValues({'tutorialSeen': true});
  final prefs = await SharedPreferences.getInstance();
  final feedback = FeedbackService();
  final game = GameController(
    puzzle: kReferencePuzzle,
    statsRepo: FakeStatsRepository(),
    feedback: feedback,
    initialStats: GameStats.seed,
  ).init();

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SettingsController(
            prefs: prefs,
            feedback: feedback,
          ),
        ),
        ChangeNotifierProvider<GameController>.value(value: game),
      ],
      child: const NumlinkApp(),
    ),
  );
  await tester.pump(const Duration(milliseconds: 600));
  return game;
}

/// Advances the clock enough to fire one-shot timers (gesture recognizers, the
/// toast/flash timers) so the test doesn't finish with timers pending. Repeat
/// animations are tickers, not timers, so they don't need draining.
Future<void> _drain(WidgetTester tester) =>
    tester.pump(const Duration(seconds: 2));

void main() {
  testWidgets('daily CTA opens the branching board, no exceptions',
      (tester) async {
    // The branching pad wants phone width (the shell's 440 cap doesn't apply to
    // this pushed route); the board also breathes (a repeat animation), so
    // disable animations to keep timers from pending at teardown.
    tester.view.physicalSize = const Size(440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await _pumpApp(tester);

    // Welcome overlay is visible (verifies the Positioned.fill overlay wiring).
    expect(find.text("Play today's puzzle"), findsOneWidget);

    // Tap the daily CTA → it now pushes today's board on the branching engine.
    await tester.ensureVisible(find.text("Play today's puzzle"));
    await tester.tap(find.text("Play today's puzzle"));
    await tester.pumpAndSettle(); // route push + board build (anims disabled)
    expect(find.byType(RadialBoard), findsOneWidget);
    expect(find.byType(OperationButton), findsWidgets);

    await _drain(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stats & settings sheets render with their content',
      (tester) async {
    final game = await _pumpApp(tester);
    game.startGame();
    await tester.pump(const Duration(milliseconds: 300));

    game.open(SheetOverlay.settings);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('High-contrast cues'), findsOneWidget);
    expect(find.text('Sound effects'), findsOneWidget);
    expect(find.text('Haptics'), findsOneWidget);

    game.open(SheetOverlay.stats);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Statistics'), findsOneWidget);
    expect(find.text('MOVES vs PAR'), findsOneWidget);

    await _drain(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hub → practice → back to home', (tester) async {
    final game = await _pumpApp(tester);

    // Hub opens on the Play tab; switch to the Modes tab to reach the tiles.
    await tester.tap(find.text('Modes'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('PRACTICE'), findsOneWidget);
    await tester.ensureVisible(find.text('PRACTICE'));
    await tester.pump();
    await tester.tap(find.text('PRACTICE'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Choose difficulty'), findsOneWidget);
    expect(find.text('Start Medium'), findsOneWidget);

    // The popup's Start button does exactly this (pop + startPractice); the
    // headless surface renders it below the root bounds, so drive it directly.
    Navigator.of(tester.element(find.text('Choose difficulty'))).pop();
    await game.startPractice(Difficulty.medium);
    await tester.pump(); // resolve the async generate() future
    await tester.pump(const Duration(milliseconds: 400));
    expect(game.started, isTrue);
    expect(game.mode.name, 'practice');
    // Board target bar rendered. Use 'MOVES' (always shown), not 'GET TO':
    // a random practice puzzle may have checkpoints, flipping that label.
    expect(find.text('MOVES'), findsOneWidget);
    expect(find.text('Practice'), findsOneWidget); // header title

    // Back to Home via the header button.
    game.goHome();
    await tester.pump(const Duration(milliseconds: 400));
    expect(game.started, isFalse);
    expect(find.text("Play today's puzzle"), findsOneWidget);

    await _drain(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('illegal op shows a toast and does not change the chain',
      (tester) async {
    final game = await _pumpApp(tester);
    game.startGame();
    await tester.pump(const Duration(milliseconds: 300));

    // start=2; +7 -> 9, then ÷2 is illegal (odd).
    await tester.tap(find.text('+7').first);
    await tester.pump(const Duration(milliseconds: 300));
    final before = game.moves;
    await tester.tap(find.text('÷2').first);
    await tester.pump(const Duration(milliseconds: 300));
    expect(game.moves, before);
    expect(find.textContaining("doesn't divide evenly"), findsOneWidget);

    await _drain(tester);
    expect(tester.takeException(), isNull);
  });
}
