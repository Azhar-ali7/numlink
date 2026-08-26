import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numlink_app/app.dart';
import 'package:numlink_app/data/settings_controller.dart';
import 'package:numlink_app/game/game_controller.dart';
import 'package:numlink_app/models/game_stats.dart';
import 'package:numlink_app/services/feedback_service.dart';
import 'package:numlink_app/widgets/operation_button.dart';
import 'package:numlink_app/widgets/radial_board.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game_controller_test.dart' show FakeStatsRepository;

Future<GameController> _pumpApp(WidgetTester tester) async {
  // Flow tests exercise the hub, not onboarding: mark the intro seen so the
  // first-run carousel doesn't cover it. Carousel behavior is covered in
  // settings_controller_test.dart.
  SharedPreferences.setMockInitialValues({'tutorialSeen': true});
  final prefs = await SharedPreferences.getInstance();
  final feedback = FeedbackService();
  final game = GameController(
    statsRepo: FakeStatsRepository(),
    initialStats: GameStats.empty,
  );

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
  await tester.pump(const Duration(seconds: 3)); // clear the boot splash
  return game;
}

/// Advances the clock enough to fire one-shot timers (gesture recognizers, the
/// toast/flash timers) so the test doesn't finish with timers pending.
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

    // Home hub is visible (verifies the Positioned.fill base layer wiring).
    expect(find.text("Play today's puzzle"), findsOneWidget);

    // Tap the daily CTA → it pushes today's board on the branching engine.
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

    game.open(SheetOverlay.settings);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('High-contrast cues'), findsOneWidget);
    expect(find.text('Sound effects'), findsOneWidget);
    expect(find.text('Haptics'), findsOneWidget);
    expect(find.text('Reduce motion'), findsOneWidget);
    // Gated behind kSocialEnabled (lib/flags.dart) until accounts exist.
    expect(find.text('Social nudges'), findsNothing);

    game.open(SheetOverlay.stats);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Statistics'), findsOneWidget);
    expect(find.text('MOVES vs PAR'), findsOneWidget);

    game.open(SheetOverlay.notifications);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text("Today's board is ready"), findsOneWidget);

    await _drain(tester);
    expect(tester.takeException(), isNull);
  });
}
