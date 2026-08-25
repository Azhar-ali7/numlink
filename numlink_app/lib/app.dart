import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import 'data/settings_controller.dart';
import 'game/game_controller.dart';
import 'screens/intro_carousel.dart';
import 'screens/welcome_screen.dart';
import 'sheets/archive_sheet.dart';
import 'sheets/how_to_play_sheet.dart';
import 'sheets/leaderboard_sheet.dart';
import 'sheets/notifications_sheet.dart';
import 'sheets/roadmap_sheet.dart';
import 'sheets/settings_sheet.dart';
import 'sheets/stats_sheet.dart';
import 'theme/app_theme.dart';
import 'theme/motion.dart';
import 'theme/tokens.dart';

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
      // Cap EVERY route (home + pushed boards) to a centered phone-width frame,
      // so the game board doesn't sprawl on desktop/macOS. Phones (<440) fill.
      builder: (context, child) => ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ClipRect(child: SizedBox.expand(child: child)),
          ),
        ),
      ),
      home: const _Boot(),
    );
  }
}

/// Shows the launch splash over the app shell for ~2.2s on cold start.
class _Boot extends StatefulWidget {
  const _Boot();

  @override
  State<_Boot> createState() => _BootState();
}

class _BootState extends State<_Boot> {
  bool _booting = true;

  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 2200),
        () => mounted ? setState(() => _booting = false) : null);
  }

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          const _AppShell(),
          if (_booting) const Positioned.fill(child: _BootSplash()),
        ],
      );
}

/// Full-bleed launch splash: hero→accent gradient, NUMLINK wordmark, studio tag.
class _BootSplash extends StatelessWidget {
  const _BootSplash();

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    final on = !reducedMotion(context);
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
                Text('NUMLINK',
                    style: Fonts.display(
                        size: 38, color: Colors.white, weight: 800)),
                const SizedBox(height: 22),
                // Sweeping loader bar (handoff `bootbar`), gated.
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: SizedBox(
                    width: 120,
                    height: 4,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ColoredBox(
                              color: Colors.white.withValues(alpha: 0.25)),
                        ),
                        if (on)
                          Positioned(
                            left: 0,
                            top: 0,
                            bottom: 0,
                            child: Container(
                              width: 44,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            )
                                .animate(onPlay: (c) => c.repeat())
                                .moveX(
                                    begin: -44,
                                    end: 120,
                                    duration:
                                        const Duration(milliseconds: 1100),
                                    curve: Curves.easeInOut),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                // Three bouncing dots (handoff `bootdot`), staggered; gated.
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < 3; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      _bootDot(on, i),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 34,
            child: Text('PARTAGEUR INTERACTIVE',
                textAlign: TextAlign.center,
                style: Fonts.ui(
                    size: 11,
                    color: const Color(0xD1FFFFFF),
                    weight: FontWeight.w800,
                    letterSpacing: 2)),
          ),
        ],
      ),
    );
  }

  Widget _bootDot(bool on, int i) {
    Widget dot = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        shape: BoxShape.circle,
      ),
    );
    if (!on) return dot;
    return dot
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .moveY(
            begin: 0,
            end: -7,
            delay: Duration(milliseconds: i * 160),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut);
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
                    if (g.overlay == SheetOverlay.roadmap)
                      const Positioned.fill(child: RoadmapSheet()),
                    if (g.overlay == SheetOverlay.notifications)
                      const Positioned.fill(child: NotificationsSheet()),
                    if (g.overlay == SheetOverlay.leaderboard)
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
