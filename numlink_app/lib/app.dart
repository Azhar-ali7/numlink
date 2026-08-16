import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/settings_controller.dart';
import 'game/game_controller.dart';
import 'screens/game_screen.dart';
import 'screens/intro_carousel.dart';
import 'screens/welcome_screen.dart';
import 'sheets/archive_sheet.dart';
import 'sheets/how_to_play_sheet.dart';
import 'sheets/settings_sheet.dart';
import 'sheets/solution_sheet.dart';
import 'sheets/stats_sheet.dart';
import 'sheets/win_sheet.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';
import 'widgets/confetti_overlay.dart';

class NumlinkApp extends StatelessWidget {
  const NumlinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();

    NumTokens darkTokens = NumTokens.dark;
    NumTokens lightTokens = NumTokens.light;
    if (settings.orangeSuccess) {
      darkTokens = darkTokens.copyWith(success: NumTokens.altSuccessOrange);
      lightTokens = lightTokens.copyWith(success: NumTokens.altSuccessOrange);
    }

    return MaterialApp(
      title: 'NUMLINK',
      debugShowCheckedModeBanner: false,
      themeMode: settings.themeMode,
      theme: buildTheme(lightTokens, Brightness.light),
      darkTheme: buildTheme(darkTokens, Brightness.dark),
      home: const _AppShell(),
    );
  }
}

/// Centered fixed-width column (max 440px) with 2px left/right borders,
/// hosting the game, the welcome overlay, sheets, confetti, and the toast.
class _AppShell extends StatelessWidget {
  const _AppShell();

  @override
  Widget build(BuildContext context) {
    final g = context.watch<GameController>();
    final settings = context.watch<SettingsController>();
    final t = NumTheme.of(context);

    return Scaffold(
      backgroundColor: t.bg,
      body: Center(
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 440),
          decoration: BoxDecoration(
            color: t.bg,
            border: Border(
              left: BorderSide(color: t.border, width: 2),
              right: BorderSide(color: t.border, width: 2),
            ),
          ),
          child: ClipRect(
            child: SafeArea(
              child: Stack(
                children: [
                  const Positioned.fill(child: GameScreen()),

                  // Confetti sits above the board, below the sheets.
                  Positioned.fill(child: ConfettiOverlay(pulse: g.winPulse)),

                  // Toast on illegal taps.
                  if (g.message != null)
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 220,
                      child: GameToast(message: g.message!),
                    ),

                  // Welcome overlay (z-40 equivalent).
                  if (!g.started)
                    const Positioned.fill(child: WelcomeScreen()),

                  // Sheets (z-50 equivalent) render above everything.
                  if (g.overlay == SheetOverlay.win)
                    const Positioned.fill(child: WinSheet()),
                  if (g.overlay == SheetOverlay.stats)
                    const Positioned.fill(child: StatsSheet()),
                  if (g.overlay == SheetOverlay.how)
                    const Positioned.fill(child: HowToPlaySheet()),
                  if (g.overlay == SheetOverlay.settings)
                    const Positioned.fill(child: SettingsSheet()),
                  if (g.overlay == SheetOverlay.archive)
                    const Positioned.fill(child: ArchiveSheet()),
                  if (g.overlay == SheetOverlay.solution)
                    const Positioned.fill(child: SolutionSheet()),

                  // First-run intro carousel — above everything else.
                  if (settings.tutorialOpen)
                    const Positioned.fill(child: IntroCarousel()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
