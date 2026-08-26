import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'data/settings_controller.dart';
import 'flags.dart';
import 'game/game_controller.dart';
import 'screens/intro_carousel.dart';
import 'screens/welcome_screen.dart';
import 'sheets/archive_sheet.dart';
import 'sheets/how_to_play_sheet.dart';
import 'sheets/leaderboard_sheet.dart';
import 'sheets/notifications_sheet.dart';
import 'sheets/settings_sheet.dart';
import 'sheets/stats_sheet.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';

class NumlinkApp extends StatefulWidget {
  const NumlinkApp({super.key});

  @override
  State<NumlinkApp> createState() => _NumlinkAppState();
}

class _NumlinkAppState extends State<NumlinkApp> {
  /// Splash lives here, not under `home:`, so it sits OUTSIDE the 440px phone
  /// frame — inside it, launch showed cream gutters either side of the splash.
  bool _booting = true;

  @override
  void initState() {
    super.initState();
    Timer(
      const Duration(milliseconds: 2200),
      () => mounted ? setState(() => _booting = false) : null,
    );
  }

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
      // Cap EVERY route (home + pushed boards) to a centered phone-width frame,
      // so the game board doesn't sprawl on desktop/macOS. Phones (<440) fill.
      // Material(transparency) wraps everything the builder places outside a
      // route: Text with no Material ancestor renders with Flutter's yellow
      // debug double-underline, which is what showed under the splash wordmark.
      builder: (context, child) => Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            ColoredBox(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: ClipRect(child: SizedBox.expand(child: child)),
                ),
              ),
            ),
            if (_booting) const Positioned.fill(child: _BootSplash()),
          ],
        ),
      ),
      home: const _AppShell(),
    );
  }
}

/// Full-bleed launch splash: hero→accent gradient, NUMLINK wordmark, studio tag.
class _BootSplash extends StatelessWidget {
  const _BootSplash();

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [t.hero, t.accent],
        ),
      ),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Wordmark only. No progress bar or dots: boot is a few
                // frames, and a loader that flashes reads as a stall.
                Text(
                  'NUMLINK',
                  style: Fonts.display(
                    size: 38,
                    color: Colors.white,
                    weight: 800,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 34,
            child: Text(
              'PARTAGEUR INTERACTIVE',
              textAlign: TextAlign.center,
              style: Fonts.ui(
                size: 11,
                color: const Color(0xD1FFFFFF),
                weight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Centered fixed-width column (max 440px) with 2px left/right borders,
/// hosting the Home hub, sheets, and the first-run intro. Boards play as
/// pushed routes on the branching engine (`TreeGamePage` / `TimedTreePage`).
class _AppShell extends StatelessWidget {
  const _AppShell();

  @override
  Widget build(BuildContext context) {
    final g = context.watch<GameController>();
    final settings = context.watch<SettingsController>();
    final t = NumTheme.of(context);

    // Android back: unwind our in-app layers (sheet → intro) before letting the
    // system pop the route and exit. Only the bare Home hub pops.
    final atHome = g.overlay == null && !settings.tutorialOpen;

    final dark = Theme.of(context).brightness == Brightness.dark;
    final bars = dark ? Brightness.light : Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: bars,
        statusBarBrightness: dark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: bars,
        systemNavigationBarContrastEnforced: false,
      ),
      child: PopScope(
        canPop: atHome,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (g.overlay != null) {
            g.close();
          } else if (settings.tutorialOpen) {
            settings.dismissTutorial();
          }
        },
        child: Scaffold(
          backgroundColor: t.bg,
          body: Center(
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 440),
              // Handoff: the fixed puzzle column has 2px left/right borders.
              decoration: BoxDecoration(
                color: t.bg,
                border: Border.symmetric(
                  vertical: BorderSide(color: t.border, width: 2),
                ),
              ),
              child: ClipRect(
                child: SafeArea(
                  child: Stack(
                    children: [
                      // The Home hub is the base layer; boards open as routes.
                      const Positioned.fill(child: WelcomeScreen()),

                      // Sheets (z-50 equivalent) render above the hub.
                      if (g.overlay == SheetOverlay.stats)
                        const Positioned.fill(child: StatsSheet()),
                      if (g.overlay == SheetOverlay.how)
                        const Positioned.fill(child: HowToPlaySheet()),
                      if (g.overlay == SheetOverlay.settings)
                        const Positioned.fill(child: SettingsSheet()),
                      if (g.overlay == SheetOverlay.archive)
                        const Positioned.fill(child: ArchiveSheet()),
                      if (g.overlay == SheetOverlay.notifications)
                        const Positioned.fill(child: NotificationsSheet()),
                      if (kSocialEnabled &&
                          g.overlay == SheetOverlay.leaderboard)
                        const Positioned.fill(child: LeaderboardSheet()),

                      // First-run intro carousel — above everything else.
                      if (settings.tutorialOpen)
                        const Positioned.fill(child: IntroCarousel()),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
