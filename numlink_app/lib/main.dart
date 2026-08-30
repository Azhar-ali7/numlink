import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'account/account_service.dart';
import 'app.dart';
import 'data/settings_controller.dart';
import 'data/stats_repository.dart';
import 'game/game_controller.dart';
import 'services/feedback_service.dart';
import 'services/reminder_service.dart';

Future<void> main() async {
  // Opt-in only (--dart-define=ENABLE_FLUTTER_DRIVER=true) so normal and release
  // builds are untouched; lets the MCP/agent loop drive the running UI.
  if (const bool.fromEnvironment('ENABLE_FLUTTER_DRIVER')) {
    enableFlutterDriverExtension();
  }
  WidgetsFlutterBinding.ensureInitialized();

  // Use only the fonts bundled in assets/fonts/ — never fetch at runtime. The
  // fetch throws unhandled exceptions offline (macOS sandbox, no-DNS device).
  GoogleFonts.config.allowRuntimeFetching = false;

  // Draw under the status + system-nav bars so the app's own background shows
  // through them (no default OS bar strip clashing with the dark neon theme).
  // AnnotatedRegion in _AppShell sets the transparent bars + icon brightness.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final prefs = await SharedPreferences.getInstance();

  // Repositories — local-first today; account seam ready for a remote swap.
  final statsRepo = LocalStatsRepository(prefs);
  const AccountService account = LocalOnlyAccountService();

  final feedback = FeedbackService();
  final reminders = ReminderService();
  final stats = await statsRepo.load();

  runApp(
    MultiProvider(
      providers: [
        Provider<AccountService>.value(value: account),
        ChangeNotifierProvider(
          create: (_) => SettingsController(
            prefs: prefs,
            feedback: feedback,
            reminders: reminders,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              GameController(statsRepo: statsRepo, initialStats: stats),
        ),
      ],
      child: const NumlinkApp(),
    ),
  );
}
