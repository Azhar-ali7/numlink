import 'package:flutter/material.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'account/account_service.dart';
import 'app.dart';
import 'data/session_repository.dart';
import 'data/settings_controller.dart';
import 'data/stats_repository.dart';
import 'game/game_controller.dart';
import 'game/puzzle_repository.dart';
import 'services/feedback_service.dart';

Future<void> main() async {
  // Opt-in only (--dart-define=ENABLE_FLUTTER_DRIVER=true) so normal and release
  // builds are untouched; lets the MCP/agent loop drive the running UI.
  if (const bool.fromEnvironment('ENABLE_FLUTTER_DRIVER')) {
    enableFlutterDriverExtension();
  }
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  // Repositories — local-first today; account seam ready for a remote swap.
  final statsRepo = LocalStatsRepository(prefs);
  const puzzleRepo = LocalPuzzleRepository();
  const AccountService account = LocalOnlyAccountService();

  final feedback = FeedbackService();
  final puzzle = await puzzleRepo.today();
  final stats = await statsRepo.load();

  // Resume an in-progress game if the app was killed mid-board.
  final sessionRepo = LocalSessionRepository(prefs);
  final saved = await sessionRepo.load();

  runApp(
    MultiProvider(
      providers: [
        Provider<AccountService>.value(value: account),
        ChangeNotifierProvider(
          create: (_) => SettingsController(
            prefs: prefs,
            feedback: feedback,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) {
            final g = GameController(
              puzzle: puzzle,
              statsRepo: statsRepo,
              feedback: feedback,
              initialStats: stats,
              sessionRepo: sessionRepo,
            );
            return saved != null ? g.resumeFrom(saved) : g.init();
          },
        ),
      ],
      child: const NumlinkApp(),
    ),
  );
}
