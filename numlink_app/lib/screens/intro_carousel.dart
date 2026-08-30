import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/settings_controller.dart';
import '../game/campaign.dart';
import '../game/game_controller.dart';
import '../game/tree_generator.dart';
import '../sheets/bottom_sheet_shell.dart';
import 'tree_game_page.dart';
import 'welcome_screen.dart' show RobotMascot;
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../theme/tokens.dart';

/// First-run walkthrough: 3 swipeable slides with a dot indicator, a Skip
/// affordance, and a Next → Get-started button. Shown once on first launch and
/// replayable from Settings; both exits call [SettingsController.dismissTutorial].
class IntroCarousel extends StatefulWidget {
  const IntroCarousel({super.key});

  @override
  State<IntroCarousel> createState() => _IntroCarouselState();
}

class _IntroCarouselState extends State<IntroCarousel> {
  final _pages = PageController();
  int _page = 0;

  /// Slide 1 is the mascot the home hub already uses; 2 and 3 carry a glyph.
  /// Each rides the same gradient hero panel as the daily card, so the intro
  /// reads as this app rather than a stock walkthrough.
  static const _slides = [
    (
      icon: null,
      kicker: 'WELCOME',
      title: 'Welcome to NUMLINK',
      body:
          'Chain operations to turn the start number into the target — '
          'in as few moves as you can.',
    ),
    (
      icon: Icons.touch_app_rounded,
      kicker: 'HOW IT WORKS',
      title: 'Tap to build the chain',
      body:
          'Tap an operation like ×3 or +7 to apply it. The chain grows '
          'downward, and the orange node is where you are now.',
    ),
    // The arm limit is the one rule players hit without ever being told it
    // exists — the board just refuses the tap. Explain it before that happens.
    (
      icon: Icons.account_tree_rounded,
      kicker: 'ARMS',
      title: 'Every branch has a limit',
      body:
          'Each number you reach can sprout its own branch — an "arm". An arm '
          'only holds a few moves before it fills up, so tap back to an '
          'earlier number and grow a new one.',
    ),
    (
      icon: Icons.flag_rounded,
      kicker: 'THE GOAL',
      title: 'Reach the target',
      body:
          'Land exactly on the target to close the chain. Start with '
          'Level 1 — the roadmap eases you in and unlocks new operators as '
          'you climb.',
    ),
  ];

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _dismiss() => context.read<SettingsController>().dismissTutorial();

  /// Finish the intro. On a genuine first launch (not a Settings replay), drop
  /// the player straight into (branching) Level 1 — a guaranteed easy first win
  /// — instead of the medium daily.
  void _finish() {
    final firstRun = !context.read<SettingsController>().tutorialSeen;
    final g = context.read<GameController>();
    _dismiss();
    if (!firstRun) return;
    final def = kCampaign[0];
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TreeGamePage(
          tier: def.tier.name,
          puzzle: buildPuzzle(def.tier.name, def.seed),
          onWin: (m, p) {
            g.recordCampaignWin(def.no, m, p);
            return WinRecord(
              xpGained: g.lastXpGain,
              level: g.playerLevel,
              streak: g.stats.streak,
            );
          },
        ),
      ),
    );
  }

  void _next() {
    if (_page >= _slides.length - 1) {
      _finish();
      return;
    }
    final target = _page + 1;
    if (reducedMotion(context)) {
      _pages.jumpToPage(target);
    } else {
      _pages.animateToPage(
        target,
        duration: Motion.standard,
        curve: Motion.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    final last = _page == _slides.length - 1;
    final firstRun = !context.read<SettingsController>().tutorialSeen;

    // The gradient is the screen, not a card on it: the cream page behind a
    // vivid panel read as two apps. Animated so swiping shifts the whole field.
    final (from, to) = _gradient(t, _page);
    return AnimatedContainer(
      duration: Motion.standard,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [from, to],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 12, 0),
                child: TextButton(
                  onPressed: _dismiss,
                  child: Text(
                    'Skip',
                    style: Fonts.ui(
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.85),
                      weight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: _slides.length,
                itemBuilder: (_, i) => _Slide(slide: _slides[i]),
              ),
            ),
            _Dots(count: _slides.length, active: _page),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
              child: PrimaryButton(
                label: last
                    ? (firstRun ? 'Start Level 1' : 'Get started')
                    : 'Next',
                center: true,
                fill: Colors.white,
                fg: t.text,
                onTap: _next,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One theme accent pair per slide, straight off the tokens the hub cards use.
(Color, Color) _gradient(NumTokens t, int index) => switch (index) {
      0 => (t.accent, t.hero),
      1 => (t.hero, t.success),
      _ => (t.tileOrange, t.accent),
    };

class _Slide extends StatelessWidget {
  const _Slide({required this.slide});

  final ({IconData? icon, String kicker, String title, String body}) slide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Art floats on the gradient — the panel that used to hold it now IS
          // the page, so a second bordered box would just re-draw the edge.
          SizedBox(
            height: 200,
            child: Center(
              child: slide.icon == null
                  ? Transform.scale(scale: 1.6, child: const RobotMascot())
                  : Container(
                      width: 116,
                      height: 116,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.55),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: Icon(slide.icon, size: 54, color: Colors.white),
                    ),
            ),
          ),
          const SizedBox(height: 34),
          Text(
            slide.kicker,
            style: Fonts.ui(
              size: 11,
              color: Colors.white.withValues(alpha: 0.7),
              weight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: Fonts.display(size: 30, color: Colors.white, height: 1.05),
          ),
          const SizedBox(height: 12),
          Text(
            slide.body,
            textAlign: TextAlign.center,
            style: Fonts.ui(
              size: 15,
              color: Colors.white.withValues(alpha: 0.82),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: Motion.micro,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == active ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.white
                  .withValues(alpha: i == active ? 1 : 0.35),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
      ],
    );
  }
}
