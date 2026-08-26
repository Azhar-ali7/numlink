import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../data/settings_controller.dart';
import '../flags.dart';
import '../game/game_controller.dart';
import '../game/game_mode.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../theme/tokens.dart';
import '../sheets/archive_sheet.dart';
import '../sheets/roadmap_sheet.dart';
import '../widgets/chunky_button.dart';
import '../widgets/ui.dart';
import 'tree_game_page.dart';

/// Home hub — the design handoff's Screen 1 (`design-handoff-current`, "Hi
/// Player" home): a single warm scroll of chunky rounded cards.
///   • greeting header (date · "Hi {name}", notification bell, avatar→settings)
///   • gradient DAILY hero card (Play today's puzzle · How to play · level/XP)
///   • streak card
///   • "Game modes" card → the modes screen (Daily / Archive / Weekend Co-op)
///   • "Campaign" card → the roadmap trail (CampaignPage, pushed full-screen)
///
/// The daily/co-op launchers and the sheet overlays are unchanged — only the
/// surrounding chrome was rebuilt to the handoff layout.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final g = context.watch<GameController>();
    final t = NumTheme.of(context);
    final on = !reducedMotion(context);

    return ColoredBox(
      color: t.bg,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(g: g),
              const SizedBox(height: 18),
              entrance(_DailyHeroCard(g: g), on: on, index: 0),
              const SizedBox(height: 14),
              entrance(_WeekStripCard(g: g), on: on, index: 1),
              const SizedBox(height: 14),
              entrance(
                _NavCard(
                  eyebrow: 'EXPLORE · ${kSocialEnabled ? 4 : 3} MODES',
                  title: 'Game modes',
                  subtitle: kSocialEnabled
                      ? 'Daily · Archive · Free Play · Co-op'
                      : 'Daily · Archive · Free Play',
                  icon: Icons.sports_esports_rounded,
                  gradient: [t.heroTwo, t.hero],
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const _ModesScreen()),
                  ),
                ),
                on: on,
                index: 2,
              ),
              const SizedBox(height: 14),
              entrance(
                _NavCard(
                  eyebrow: 'STORY MODE',
                  title: 'Campaign',
                  subtitle:
                      'Levels · ${g.stats.campaignCleared}/${g.campaignCount} cleared',
                  icon: Icons.route_rounded,
                  gradient: [t.tileOrange, t.star],
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const CampaignPage()),
                  ),
                ),
                on: on,
                index: 3,
              ),
              if (kSocialEnabled) ...[
                const SizedBox(height: 14),
                entrance(
                  _NavCard(
                    eyebrow: 'YOUR CIRCLE',
                    title: 'Friends',
                    subtitle: 'Leaderboard · This week by XP',
                    icon: Icons.emoji_events_rounded,
                    gradient: [t.hero, t.accent],
                    onTap: () => g.open(SheetOverlay.leaderboard),
                  ),
                  on: on,
                  index: 4,
                ),
                const SizedBox(height: 14),
                entrance(
                  _NavCard(
                    eyebrow: 'WEEKENDS ONLY',
                    title: 'Weekend Co-op',
                    subtitle: 'Shared board · resets Monday',
                    icon: Icons.groups_rounded,
                    gradient: [t.heroTwo, t.hero],
                    onTap: () => openCoop(context),
                  ),
                  on: on,
                  index: 5,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.g});
  final GameController g;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const mo = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final now = DateTime.now();
    final dateLabel = '${wd[(now.weekday - 1) % 7]}, ${now.day} ${mo[now.month - 1]}';
    final name = context.watch<SettingsController>().playerName;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dateLabel,
                style: Fonts.ui(
                  size: 12,
                  color: t.muted,
                  weight: FontWeight.w700,
                  letterSpacing: 0.5,
                  height: 1,
                ),
              ),
              const SizedBox(height: 5),
              Text('Hi $name', style: Fonts.display(size: 28, color: t.text)),
            ],
          ),
        ),
        _IconButton(
          icon: Icons.notifications_none_rounded,
          onTap: () => g.open(SheetOverlay.notifications),
          badge: true,
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => g.open(SheetOverlay.settings),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [t.heroTwo, t.hero],
              ),
            ),
            alignment: Alignment.center,
            child: Text(name.characters.first.toUpperCase(),
                style: Fonts.display(size: 18, color: Colors.white)),
          ),
        ),
      ],
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, required this.onTap, this.badge = false});
  final IconData icon;
  final VoidCallback onTap;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    // The notification bell rings periodically (handoff `bellring`), gated.
    Widget glyph = Icon(icon, size: 22, color: t.text);
    if (badge && !reducedMotion(context)) {
      glyph = glyph
          .animate(onPlay: (c) => c.repeat())
          .shake(
              duration: const Duration(milliseconds: 700),
              hz: 4,
              rotation: 0.08)
          .then(delay: const Duration(milliseconds: 2600));
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: t.elevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.border, width: 2),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            glyph,
            if (badge)
              Positioned(
                top: 10,
                right: 11,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: t.accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: t.elevated, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Daily hero card ──────────────────────────────────────────────────────────

class _DailyHeroCard extends StatelessWidget {
  const _DailyHeroCard({required this.g});
  final GameController g;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    final s = g.stats;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [t.accent, t.hero],
        ),
        boxShadow: [
          BoxShadow(
            color: t.hero.withValues(alpha: 0.35),
            blurRadius: 26,
            spreadRadius: -6,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Drifting light blob bleeding off the top-right corner.
          const Positioned(top: -50, right: -44, child: _Blob(size: 170)),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DAILY PUZZLE · #${g.dailyPuzzle.no}',
                      style: Fonts.ui(
                        size: 12,
                        color: Colors.white.withValues(alpha: 0.85),
                        weight: FontWeight.w800,
                        letterSpacing: 1,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Today's number chain",
                      style: Fonts.display(size: 26, color: Colors.white, height: 1.1),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const RobotMascot(),
            ],
          ),
          const SizedBox(height: 18),
          Stack(
            alignment: Alignment.center,
            children: [
              // Expanding ring pulse behind the CTA (handoff `playpulse`), gated.
              if (!reducedMotion(context))
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.6),
                            width: 2),
                      ),
                    )
                        .animate(onPlay: (c) => c.repeat())
                        .scaleXY(
                            begin: 1,
                            end: 1.16,
                            duration: const Duration(milliseconds: 2400),
                            curve: Curves.easeOut)
                        .fadeOut(duration: const Duration(milliseconds: 2400)),
                  ),
                ),
              ChunkyButton(
                color: Colors.white,
                baseColor: const Color(0xFFE7E1F6),
                radius: 16,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                onTap: () => openDailyBranching(context),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_arrow_rounded, size: 20, color: t.hero),
                    const SizedBox(width: 6),
                    Text(
                      "Play today's puzzle",
                      style: Fonts.ui(
                        size: 15,
                        color: t.hero,
                        weight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => g.open(SheetOverlay.how),
              child: Text(
                'How to play',
                style: Fonts.ui(
                  size: 14,
                  color: Colors.white,
                  weight: FontWeight.w700,
                  height: 1,
                ).copyWith(decoration: TextDecoration.underline),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Divider(color: Colors.white.withValues(alpha: 0.28), height: 1),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Level ${s.playerLevel}',
                style: Fonts.ui(
                  size: 14,
                  color: Colors.white,
                  weight: FontWeight.w800,
                  height: 1,
                ),
              ),
              Text(
                '${s.xpIntoLevel} / ${s.xpLevelSpan} XP',
                style: Fonts.numeric(
                  size: 12,
                  color: Colors.white.withValues(alpha: 0.85),
                  height: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: s.levelProgress.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Soft radial glow bleeding off a card corner — the handoff's drifting blob.
/// Behind reduced-motion it slowly drifts and breathes (the `drift` keyframe);
/// gated so tests see a static glow.
class _Blob extends StatelessWidget {
  const _Blob({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    Widget blob = IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [Color(0x4DFFFFFF), Color(0x00FFFFFF)],
            stops: [0.0, 0.7],
          ),
        ),
      ),
    );
    if (reducedMotion(context)) return blob;
    return blob
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .moveX(
            begin: 0,
            end: -14,
            duration: const Duration(milliseconds: 8000),
            curve: Curves.easeInOut)
        .moveY(
            begin: 0,
            end: 10,
            duration: const Duration(milliseconds: 8000),
            curve: Curves.easeInOut)
        .scaleXY(
            begin: 1,
            end: 1.08,
            duration: const Duration(milliseconds: 8000),
            curve: Curves.easeInOut);
  }
}

/// Illustrated robot mascot for the daily hero card — a friendly bot (white
/// body, dark screen with cyan eyes, glowing antenna, arms + feet). Behind
/// reduced-motion the whole bot bobs (translate + a hair of rotate), the
/// antenna tip pulses, and the eyes blink on a slow cycle — the handoff's
/// `bob` / `antenna` / `blink` keyframes. All loops are gated so widget tests
/// (which force reduced motion) never see an unsettling controller.
class RobotMascot extends StatelessWidget {
  const RobotMascot({super.key});

  @override
  Widget build(BuildContext context) {
    final on = !reducedMotion(context);
    const eye = SizedBox(
      width: 9,
      height: 11,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color(0xFF8BD3FF),
          borderRadius: BorderRadius.all(Radius.circular(5)),
        ),
      ),
    );
    Widget eyes = const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [eye, SizedBox(width: 9), eye],
    );
    if (on) {
      // Slow blink: hold ~3s, snap the eyes shut and back open.
      eyes = eyes
          .animate(onPlay: (c) => c.repeat())
          .scaleY(
              begin: 1,
              end: 0.1,
              duration: const Duration(milliseconds: 80),
              delay: const Duration(milliseconds: 3000),
              alignment: Alignment.center)
          .then()
          .scaleY(
              begin: 0.1, end: 1, duration: const Duration(milliseconds: 80));
    }

    Widget tip = Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFFFD166),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFFFFD166).withValues(alpha: 0.9),
              blurRadius: 8),
        ],
      ),
    );
    if (on) {
      tip = tip
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scaleXY(
              begin: 1,
              end: 1.35,
              duration: const Duration(milliseconds: 1600),
              curve: Curves.easeInOut)
          .fade(
              begin: 1,
              end: 0.7,
              duration: const Duration(milliseconds: 1600));
    }

    Widget bot = SizedBox(
      width: 64,
      height: 82,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // antenna stalk + glowing tip
          Positioned(
            left: 30.5,
            top: 8,
            child: Container(width: 3, height: 12, color: const Color(0xD9FFFFFF)),
          ),
          Positioned(left: 27, top: 0, child: tip),
          // arms
          Positioned(
              left: 0,
              top: 44,
              child: _bar(6, 14, const Color(0xFFE3E6FF))),
          Positioned(
              left: 58,
              top: 44,
              child: _bar(6, 14, const Color(0xFFE3E6FF))),
          // feet
          Positioned(left: 16, top: 74, child: _foot()),
          Positioned(left: 42, top: 74, child: _foot()),
          // body
          Positioned(
            left: 2,
            top: 18,
            child: Container(
              width: 60,
              height: 58,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.white, Color(0xFFEEF0FF)],
                ),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      blurRadius: 18,
                      offset: const Offset(0, 8)),
                ],
              ),
              child: Center(
                child: Container(
                  width: 42,
                  height: 34,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF2B2350), Color(0xFF3A2F66)],
                    ),
                  ),
                  child: eyes,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (on) {
      bot = bot
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .moveY(
              begin: 0,
              end: -7,
              duration: const Duration(milliseconds: 4500),
              curve: Curves.easeInOut)
          .rotate(
              begin: -0.008,
              end: 0.008,
              duration: const Duration(milliseconds: 4500),
              curve: Curves.easeInOut);
    }
    return bot;
  }

  Widget _bar(double w, double h, Color c) => Container(
        width: w,
        height: h,
        decoration:
            BoxDecoration(color: c, borderRadius: BorderRadius.circular(4)),
      );

  Widget _foot() => Container(
        width: 14,
        height: 8,
        decoration: const BoxDecoration(
          color: Color(0xFFD7CBFF),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(6)),
        ),
      );
}

// ── Streak card ──────────────────────────────────────────────────────────────

/// "This week" daily calendar strip (handoff): 7 day cells ending today, each
/// solved/today/pending state read from the persisted `dailySolvedDays` set —
/// a cell is green only if that day's daily was actually solved. Header chevron
/// → archive; the 🔥·Stats chip → stats overlay. Tapping today launches the
/// daily; past days open the archive.
class _WeekStripCard extends StatelessWidget {
  const _WeekStripCard({required this.g});
  final GameController g;

  static const _wd = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    final streak = g.stats.streak;
    final today = DateTime.now();

    return Container(
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 16),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: t.border, width: 2),
        boxShadow: t.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => g.open(SheetOverlay.archive),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('DAILY CALENDAR',
                        style: Fonts.ui(
                            size: 10,
                            color: t.muted,
                            weight: FontWeight.w800,
                            letterSpacing: 1.4,
                            height: 1)),
                    const SizedBox(height: 3),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('This week',
                          style: Fonts.display(size: 20, color: t.text, height: 1)),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right_rounded, size: 18, color: t.muted),
                    ]),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => g.open(SheetOverlay.stats),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                  decoration: BoxDecoration(
                    color: tint(t.text, 0.05),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Text('🔥', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 5),
                    Text('$streak',
                        style: Fonts.ui(
                            size: 12, color: t.text, weight: FontWeight.w800)),
                    const SizedBox(width: 8),
                    Container(width: 1, height: 12, color: t.border),
                    const SizedBox(width: 8),
                    Text('Stats',
                        style: Fonts.ui(
                            size: 12, color: t.text, weight: FontWeight.w800)),
                  ]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              for (var idx = 0; idx < 7; idx++) ...[
                if (idx > 0) const SizedBox(width: 6),
                Expanded(child: _dayCell(context, t, today, idx)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _dayCell(BuildContext context, NumTokens t, DateTime today, int idx) {
    final back = 6 - idx; // 0 = today (rightmost)
    final date = today.subtract(Duration(days: back));
    final isToday = back == 0;
    final done = isToday
        ? g.todaySolved
        : g.stats.dailySolvedDays.contains(GameController.dayIndexOf(date));

    final Color border, dayColor, markColor;
    final Color bg;
    final String mark;
    if (done) {
      border = markColor = dayColor = t.success;
      bg = tint(t.success, 0.12);
      mark = '✓';
    } else if (isToday) {
      border = markColor = dayColor = t.accent;
      bg = tint(t.accent, 0.14);
      mark = '▸';
    } else {
      border = t.border;
      bg = Colors.transparent;
      dayColor = t.text;
      markColor = t.muted;
      mark = '·';
    }

    return GestureDetector(
      onTap: () => isToday
          ? openDailyBranching(context)
          : g.open(SheetOverlay.archive),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border, width: 2),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_wd[(date.weekday - 1) % 7],
                style: Fonts.ui(
                    size: 10,
                    color: t.muted,
                    weight: FontWeight.w800,
                    height: 1)),
            const SizedBox(height: 6),
            Text('${date.day}',
                style: Fonts.display(size: 16, color: dayColor, height: 1)),
            const SizedBox(height: 5),
            Text(mark,
                style: TextStyle(
                    fontSize: 11, color: markColor, height: 1)),
          ],
        ),
      ),
    );
  }
}

// ── Nav cards (Game modes / Campaign) ────────────────────────────────────────

/// Gentle "go here" horizontal nudge for a launch arrow (handoff `arrownudge`),
/// gated behind reduced-motion.
Widget _arrowNudge(bool on, Widget child) => on
    ? child
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .moveX(
            begin: 0,
            end: 4,
            duration: const Duration(milliseconds: 1800),
            curve: Curves.easeInOut)
    : child;

class _NavCard extends StatelessWidget {
  const _NavCard({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: t.elevated,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: t.border, width: 2),
          boxShadow: t.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradient,
                ),
              ),
              child: Icon(icon, size: 26, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    eyebrow,
                    style: Fonts.ui(
                      size: 11,
                      color: t.muted,
                      weight: FontWeight.w800,
                      letterSpacing: 1,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(title, style: Fonts.display(size: 20, color: t.text)),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: Fonts.ui(size: 12.5, color: t.muted, height: 1.2),
                  ),
                ],
              ),
            ),
            _arrowNudge(!reducedMotion(context),
                Icon(Icons.chevron_right_rounded, size: 26, color: t.muted)),
          ],
        ),
      ),
    );
  }
}

// ── Modes screen (pushed from the "Game modes" card) ─────────────────────────

class _ModesScreen extends StatelessWidget {
  const _ModesScreen();

  @override
  Widget build(BuildContext context) {
    final g = context.watch<GameController>();
    final t = NumTheme.of(context);
    final on = !reducedMotion(context);
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _IconButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 10),
                  _IconButton(
                    icon: Icons.home_rounded,
                    onTap: () =>
                        Navigator.of(context).popUntil((r) => r.isFirst),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'PLAY · ${kSocialEnabled ? 4 : 3} MODES',
                style: Fonts.ui(
                  size: 12,
                  color: t.muted,
                  weight: FontWeight.w800,
                  letterSpacing: 1,
                  height: 1,
                ),
              ),
              const SizedBox(height: 6),
              Text('Game modes', style: Fonts.display(size: 30, color: t.text)),
              const SizedBox(height: 14),
              Row(
                children: [
                  _ModeChip(emoji: '🎮', label: '${kSocialEnabled ? 4 : 3} Modes'),
                  const SizedBox(width: 8),
                  _ModeChip(emoji: '🗺️', label: '${g.campaignCount} Levels'),
                ],
              ),
              const SizedBox(height: 20),
              // Daily + Archive sit side-by-side (handoff 2-col grid); Weekend
              // Co-op spans full width below.
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: entrance(
                        _ModeCard(
                          icon: Icons.today_rounded,
                          color: t.accent,
                          badge: 'DAILY',
                          kicker: "TODAY'S CHAIN",
                          title: 'Daily Puzzle',
                          avatars: const ['K', 'F', 'C'],
                          extra: 43,
                          onTap: () => openDailyBranching(context),
                        ),
                        on: on,
                        index: 0,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: entrance(
                        _ModeCard(
                          icon: Icons.calendar_month_rounded,
                          color: t.hero,
                          badge: 'DAILY',
                          kicker: 'PAST PUZZLES',
                          title: 'The Archive',
                          avatars: const ['F', 'K', 'P'],
                          extra: 12,
                          onTap: () => openArchive(context),
                        ),
                        on: on,
                        index: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              entrance(
                _ModeCard(
                  icon: Icons.tune_rounded,
                  color: t.success,
                  badge: 'ANY TIME',
                  kicker: 'PICK YOUR LEVEL',
                  title: 'Free Play',
                  onTap: () => openFreePlay(context),
                ),
                on: on,
                index: 2,
              ),
              if (kSocialEnabled) ...[
                const SizedBox(height: 14),
                entrance(
                  _ModeCard(
                    icon: Icons.groups_rounded,
                    color: t.heroTwo,
                    badge: 'CHALLENGE',
                    kicker: 'WEEKENDS ONLY',
                    title: 'Weekend Co-op',
                    avatars: const ['K', 'P', 'U'],
                    extra: 3,
                    onTap: () => openCoop(context),
                  ),
                  on: on,
                  index: 3,
                ),
              ],
              const SizedBox(height: 20),
              entrance(_CampaignCard(g: g), on: on, index: 4),
              const SizedBox(height: 20),
              Center(
                child: GestureDetector(
                  onTap: () => g.open(SheetOverlay.how),
                  child: Text(
                    'How to play',
                    style: Fonts.ui(
                      size: 14,
                      color: t.muted,
                      weight: FontWeight.w700,
                      height: 1,
                    ).copyWith(decoration: TextDecoration.underline),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small pill in the modes header ("🎮 3 Modes" / "🗺️ N Levels").
class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.emoji, required this.label});
  final String emoji;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: t.border, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 13, height: 1)),
          const SizedBox(width: 6),
          Text(label,
              style: Fonts.ui(
                  size: 12,
                  color: t.text,
                  weight: FontWeight.w700,
                  letterSpacing: 0.3,
                  height: 1)),
        ],
      ),
    );
  }
}

/// A handoff-style mode card: colored icon tile + badge pill, a category kicker
/// over the title, a friends avatar stack, and a circular arrow launch button.
class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.color,
    required this.badge,
    required this.kicker,
    required this.title,
    required this.onTap,
    this.avatars = const [],
    this.extra = 0,
  });

  final IconData icon;
  final Color color;
  final String badge;
  final String kicker;
  final String title;
  final List<String> avatars;
  final int extra;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: t.border, width: 2),
          boxShadow: t.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, size: 20, color: Colors.white),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: tint(color, 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(badge,
                      style: Fonts.ui(
                          size: 10,
                          color: color,
                          weight: FontWeight.w800,
                          letterSpacing: 0.8,
                          height: 1)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(kicker,
                style: Fonts.ui(
                    size: 10,
                    color: t.muted,
                    weight: FontWeight.w800,
                    letterSpacing: 1,
                    height: 1)),
            const SizedBox(height: 5),
            Text(title, style: Fonts.display(size: 19, color: t.text)),
            const SizedBox(height: 12),
            Row(
              children: [
                // Fake "43 friends played this" social proof — nothing backs it
                // until accounts exist, so the row is just spacer without it.
                Expanded(
                  child: kSocialEnabled && avatars.isNotEmpty
                      ? _AvatarStack(initials: avatars, extra: extra)
                      : const SizedBox.shrink(),
                ),
                const SizedBox(width: 8),
                _arrowNudge(
                  !reducedMotion(context),
                  Container(
                    width: 38,
                    height: 38,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                    child: const Icon(Icons.arrow_forward_rounded,
                        size: 19, color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Overlapping friend-avatar discs with a "+N" tail — the handoff's social
/// proof on the mode cards. Purely cosmetic (mock cohort).
class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.initials, required this.extra});
  final List<String> initials;
  final int extra;

  static const _hues = [
    Color(0xFFEC6A8D),
    Color(0xFF6B61E6),
    Color(0xFFEFA42F),
    Color(0xFF237E72),
  ];

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    const d = 24.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: d,
          width: d + (initials.length - 1) * 16,
          child: Stack(
            children: [
              for (var i = 0; i < initials.length; i++)
                Positioned(
                  left: i * 16.0,
                  child: Container(
                    width: d,
                    height: d,
                    decoration: BoxDecoration(
                      color: _hues[i % _hues.length],
                      shape: BoxShape.circle,
                      border: Border.all(color: t.surface, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Text(initials[i],
                        style: Fonts.ui(
                            size: 10,
                            color: Colors.white,
                            weight: FontWeight.w800,
                            height: 1)),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text('+$extra',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Fonts.ui(
                  size: 11, color: t.muted, weight: FontWeight.w700, height: 1)),
        ),
      ],
    );
  }
}

/// The campaign-progress card at the foot of the modes screen: cleared count,
/// a star-progress bar, and a Continue arrow into the roadmap.
class _CampaignCard extends StatelessWidget {
  const _CampaignCard({required this.g});
  final GameController g;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    final stats = g.stats;
    final count = g.campaignCount;
    final maxStars = count * 3;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const CampaignPage()),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tint(t.tileOrange, 0.12),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: tint(t.tileOrange, 0.35), width: 2),
          boxShadow: t.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('CAMPAIGN',
                    style: Fonts.ui(
                        size: 11,
                        color: t.muted,
                        weight: FontWeight.w800,
                        letterSpacing: 1,
                        height: 1)),
                const Spacer(),
                Icon(Icons.star_rounded, size: 15, color: t.progress),
                const SizedBox(width: 4),
                Text('${stats.campaignStars} / $maxStars',
                    style: Fonts.numeric(
                        size: 13, color: t.text, weight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                      '${stats.campaignCleared} of $count levels cleared',
                      style: Fonts.ui(
                          size: 14, color: t.text, weight: FontWeight.w700)),
                ),
                Container(
                  width: 42,
                  height: 42,
                  decoration:
                      BoxDecoration(color: t.tileOrange, shape: BoxShape.circle),
                  child: const Icon(Icons.arrow_forward_rounded,
                      size: 20, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: maxStars == 0 ? 0 : stats.campaignStars / maxStars,
                minHeight: 8,
                backgroundColor: tint(t.text, 0.08),
                valueColor: AlwaysStoppedAnimation<Color>(t.success),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Launchers (unchanged) ────────────────────────────────────────────────────

/// The daily CTA opens today's board on the branching engine.
void openDailyBranching(BuildContext context) {
  final g = context.read<GameController>();
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => TreeGamePage(
        tier: 'medium',
        puzzle: dailyBranchingPuzzle(),
        onWin: (m, p) {
          g.recordDailyWin(m, p);
          return WinRecord(
              xpGained: g.lastXpGain,
              level: g.playerLevel,
              streak: g.stats.streak);
        },
      ),
    ),
  );
}

/// Weekend Co-op: this week's shared board, with the teammates banner. Wins
/// count like practice (mock social board — no dedicated mode/counter).
/// Opens the Archive calendar as a transparent pushed route (it draws its own
/// scrim). Used from the pushed Game-modes screen, where the app-shell overlay
/// would render *behind* the route. Home opens it as an overlay instead.
void openArchive(BuildContext context) {
  final nav = Navigator.of(context);
  // Defer to the next frame: on web the opening tap's synthesized pointer-up
  // would otherwise bleed onto the sheet's freshly-mounted scrim and dismiss it.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    nav.push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.transparent,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, __, ___) => const ArchiveSheet(asRoute: true),
      ),
    );
  });
}

void openCoop(BuildContext context) {
  final g = context.read<GameController>();
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => TreeGamePage(
        tier: 'medium',
        title: 'WEEKEND CO-OP',
        coop: true,
        puzzle: weekendCoopPuzzle(),
        onWin: (m, p) {
          g.recordBranchingWin(GameMode.practice, m, p);
          return WinRecord(
              xpGained: g.lastXpGain,
              level: g.playerLevel,
              streak: g.stats.streak);
        },
      ),
    ),
  );
}

/// Free Play: ask which tier, then hand [TreeGamePage] the key and let it deal
/// an endless stream of boards at that difficulty ("New board" re-rolls in
/// tier). This is the launcher [GameMode.practice] never had.
void openFreePlay(BuildContext context) {
  final g = context.read<GameController>();
  final t = NumTheme.of(context);
  showModalBottomSheet<Difficulty>(
    context: context,
    backgroundColor: t.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 14),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: t.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
            child: Text('Choose a difficulty',
                style: Fonts.display(size: 22, color: t.text)),
          ),
          for (final d in Difficulty.values)
            InkWell(
              key: ValueKey('freeplay_${d.name}'),
              onTap: () => Navigator.of(sheet).pop(d),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(children: [
                  Text(d.emoji, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.label,
                            style: Fonts.ui(
                                size: 16,
                                color: t.text,
                                weight: FontWeight.w800,
                                height: 1.2)),
                        Text(d.blurb,
                            style: Fonts.ui(
                                size: 12,
                                color: t.muted,
                                weight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: t.muted),
                ]),
              ),
            ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  ).then((d) {
    if (d == null || !context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TreeGamePage(
          tier: d.name,
          onWin: (m, p) {
            g.recordBranchingWin(GameMode.practice, m, p);
            return WinRecord(
                xpGained: g.lastXpGain,
                level: g.playerLevel,
                streak: g.stats.streak);
          },
        ),
      ),
    );
  });
}
