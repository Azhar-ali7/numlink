import 'package:flutter_test/flutter_test.dart';
import 'package:numlink_app/app.dart';
import 'package:numlink_app/data/settings_controller.dart';
import 'package:numlink_app/game/game_controller.dart';
import 'package:numlink_app/models/game_stats.dart';
import 'package:numlink_app/services/feedback_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game_controller_test.dart' show FakeStatsRepository;

void main() {
  testWidgets('home hub shows the daily CTA on load', (tester) async {
    SharedPreferences.setMockInitialValues({'tutorialSeen': true});
    final prefs = await SharedPreferences.getInstance();
    final feedback = FeedbackService();

    final game = GameController(
      statsRepo: FakeStatsRepository(),
      initialStats: GameStats.seed,
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
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 3)); // clear the boot splash

    expect(find.text("Play today's puzzle"), findsOneWidget,
        reason: 'the Home hub must be visible on load');
  });
}
