import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'account/account_service.dart';
import 'app.dart';
import 'data/settings_controller.dart';
import 'data/stats_repository.dart';
import 'game/game_controller.dart';
import 'game/puzzle_repository.dart';
import 'services/feedback_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  // Repositories — local-first today; account seam ready for a remote swap.
  final statsRepo = LocalStatsRepository(prefs);
  const puzzleRepo = LocalPuzzleRepository();
  const AccountService account = LocalOnlyAccountService();

  final feedback = FeedbackService();
  final puzzle = await puzzleRepo.today();
  final stats = await statsRepo.load();

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
          create: (_) => GameController(
            puzzle: puzzle,
            statsRepo: statsRepo,
            feedback: feedback,
            initialStats: stats,
          ).init(),
        ),
      ],
      child: const NumlinkApp(),
    ),
  );
}
