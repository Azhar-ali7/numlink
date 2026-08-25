import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/settings_controller.dart';
import '../game/game_controller.dart';
import '../game/game_mode.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/chunky_button.dart';
import 'tree_game_page.dart';

/// Home hub — the design handoff's Screen 1 (`design-handoff-current`, "Hi
/// Player" home): a single warm scroll of chunky rounded cards.
///   • greeting header (date · "Hi {name}", notification bell, avatar→settings)
///   • gradient DAILY hero card (Play today's puzzle · How to play · level/XP)
///   • streak card
///   • "Game modes" card → the modes screen (Practice/Zen/Timed/Archive)
///   • "Campaign" card → the roadmap trail (SheetOverlay.roadmap)
///
/// The daily/practice/timed launchers and the sheet overlays are unchanged —
/// only the surrounding chrome was rebuilt to the handoff layout.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final g = context.watch<GameController>();
    final t = NumTheme.of(context);

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
              _DailyHeroCard(g: g),
              const SizedBox(height: 14),
              _WeekStripCard(g: g),
              const SizedBox(height: 14),
              _NavCard(
                eyebrow: 'EXPLORE · 4 MODES',
                title: 'Game modes',
                subtitle: 'Practice · Zen · Timed · Archive',
                icon: Icons.sports_esports_rounded,
                gradient: const [NumTokens.heroTwo, NumTokens.hero],
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const _ModesScreen()),
                ),
              ),
              const SizedBox(height: 14),
              _NavCard(
                eyebrow: 'STORY MODE',
                title: 'Campaign',
                subtitle:
                    'Levels · ${g.stats.campaignCleared}/${g.campaignCount} cleared',
                icon: Icons.route_rounded,
                gradient: const [NumTokens.accentOrange, NumTokens.star],
                onTap: () => g.open(SheetOverlay.roadmap),
              ),
              const SizedBox(height: 14),
              _NavCard(
                eyebrow: 'YOUR CIRCLE',
                title: 'Friends',
                subtitle: 'Leaderboard · This week by XP',
                icon: Icons.emoji_events_rounded,
                gradient: const [NumTokens.hero, NumTokens.accent],
                onTap: () => g.open(SheetOverlay.leaderboard),
              ),
              const SizedBox(height: 14),
              _NavCard(
                eyebrow: 'WEEKENDS ONLY',
                title: 'Weekend Co-op',
                subtitle: 'Shared board · resets Monday',
                icon: Icons.groups_rounded,
                gradient: const [NumTokens.heroTwo, NumTokens.hero],
                onTap: () => openCoop(context),
              ),
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
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [NumTokens.heroTwo, NumTokens.hero],
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: t.elevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.border, width: 1.5),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, size: 22, color: t.text),
            if (badge)
              Positioned(
                top: 10,
                right: 11,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: NumTokens.accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: t.elevated, width: 1.5),
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
    final s = g.stats;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [NumTokens.accent, NumTokens.hero],
        ),
        boxShadow: [
          BoxShadow(
            color: NumTokens.hero.withValues(alpha: 0.35),
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
              const _RobotMascot(),
            ],
          ),
          const SizedBox(height: 18),
          ChunkyButton(
            color: Colors.white,
            baseColor: const Color(0xFFE7E1F6),
            radius: 16,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            onTap: () => openDailyBranching(context),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.play_arrow_rounded,
                    size: 20, color: NumTokens.hero),
                const SizedBox(width: 6),
                Text(
                  "Play today's puzzle",
                  style: Fonts.ui(
                    size: 15,
                    color: NumTokens.hero,
                    weight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ],
            ),
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
                style: Fonts.mono(
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
/// (Kept static: a corner glow barely reads as moving; the mascot carries the
/// motion.)
class _Blob extends StatelessWidget {
  const _Blob({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) => IgnorePointer(
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
}

/// Illustrated robot mascot for the daily hero card — a friendly bot (white
/// body, dark screen with cyan eyes, glowing antenna, arms + feet).
/// (Static: the handoff's gentle bob is skipped — decorative, and an infinite
/// controller never lets widget tests settle. Add behind reduced-motion later.)
class _RobotMascot extends StatelessWidget {
  const _RobotMascot();

  @override
  Widget build(BuildContext context) {
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
    final bot = SizedBox(
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
          Positioned(
            left: 27,
            top: 0,
            child: Container(
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
            ),
          ),
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
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [eye, SizedBox(width: 9), eye],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

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
/// solved/today/pending state derived from `streak` + `todaySolved` (no
/// per-day history is persisted). Header chevron → archive; the 🔥·Stats chip →
/// stats overlay. Tapping today launches the daily; past days open the archive.
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.border, width: 1.5),
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
                Expanded(child: _dayCell(context, t, today, idx, streak)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _dayCell(
      BuildContext context, NumTokens t, DateTime today, int idx, int streak) {
    final back = 6 - idx; // 0 = today (rightmost)
    final date = today.subtract(Duration(days: back));
    final isToday = back == 0;
    final done = isToday ? g.todaySolved : back <= streak;

    final Color border, dayColor, markColor;
    final Color bg;
    final String mark;
    if (done) {
      border = markColor = dayColor = t.success;
      bg = tint(t.success, 0.12);
      mark = '✓';
    } else if (isToday) {
      border = markColor = dayColor = NumTokens.accent;
      bg = tint(NumTokens.accent, 0.14);
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
          border: Border.all(color: border, width: 1.5),
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
          border: Border.all(color: t.border, width: 1.5),
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
            Icon(Icons.chevron_right_rounded, size: 26, color: t.muted),
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
    final g = context.read<GameController>();
    final t = NumTheme.of(context);
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
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'PLAY · 4 MODES',
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
              const SizedBox(height: 20),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 1.05,
                children: [
                  _ModeTile(
                    tag: 'PRACTICE',
                    blurb: 'Unlimited puzzles at your pace',
                    icon: Icons.all_inclusive_rounded,
                    color: NumTokens.accentBlue,
                    onTap: () => _showDifficultySheet(context,
                        (d) => _openBranchingMode(context, GameMode.practice, d.name)),
                  ),
                  _ModeTile(
                    tag: 'ZEN',
                    blurb: 'No clock, no par, no streak',
                    icon: Icons.spa_rounded,
                    color: NumTokens.accentPurple,
                    onTap: () => _showDifficultySheet(context,
                        (d) => _openBranchingMode(context, GameMode.zen, d.name)),
                  ),
                  _ModeTile(
                    tag: 'TIMED',
                    blurb: 'Climb the escalating ladder',
                    icon: Icons.bolt_rounded,
                    color: NumTokens.accentOrange,
                    onTap: () => _openBranchingTimed(context),
                  ),
                  _ModeTile(
                    tag: 'ARCHIVE',
                    blurb: 'Replay past daily puzzles',
                    icon: Icons.calendar_month_rounded,
                    color: NumTokens.accentPink,
                    onTap: () => g.open(SheetOverlay.archive),
                  ),
                ],
              ),
              const SizedBox(height: 24),
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

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.tag,
    required this.blurb,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String tag;
  final String blurb;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tint(color, 0.12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: tint(color, 0.35), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 22, color: Colors.white),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tag,
                  style: Fonts.ui(
                    size: 14,
                    color: t.text,
                    weight: FontWeight.w700,
                    letterSpacing: 0.5,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  blurb,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Fonts.ui(size: 11, color: t.muted, height: 1.2),
                ),
              ],
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

/// Practice/Zen run on the branching engine: a chosen-tier board. [mode] decides
/// how the win is recorded.
void _openBranchingMode(BuildContext context, GameMode mode, String tier) {
  final g = context.read<GameController>();
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => TreeGamePage(
        tier: tier,
        onWin: (m, p) {
          g.recordBranchingWin(mode, m, p);
          return WinRecord(
              xpGained: g.lastXpGain,
              level: g.playerLevel,
              streak: g.stats.streak);
        },
      ),
    ),
  );
}

/// Timed on the branching engine: a stopwatch race up the escalating ladder.
void _openBranchingTimed(BuildContext context) {
  final g = context.read<GameController>();
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => TimedTreePage(
        onStageSolved: (stage, runDone) {
          g.recordTimedStage(stage, runDone: runDone);
          return WinRecord(
              xpGained: g.lastXpGain,
              level: g.playerLevel,
              streak: g.stats.streak);
        },
      ),
    ),
  );
}

/// Quick difficulty chooser for Practice/Zen.
void _showDifficultySheet(
  BuildContext context,
  void Function(Difficulty) onStart,
) {
  final t = NumTheme.of(context);
  var selected = Difficulty.medium;
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => StatefulBuilder(
      builder: (sheetCtx, setSheet) => Container(
        decoration: BoxDecoration(
          color: t.elevated,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: t.border, width: 1.4)),
        ),
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          24 + MediaQuery.of(sheetCtx).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Choose difficulty', style: Fonts.display(size: 24, color: t.text)),
            const SizedBox(height: 16),
            _DifficultyPicker(
              selected: selected,
              onSelect: (d) => setSheet(() => selected = d),
            ),
            const SizedBox(height: 18),
            ChunkyButton(
              color: t.success,
              radius: 16,
              padding: const EdgeInsets.symmetric(vertical: 16),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                onStart(selected);
              },
              child: Text(
                'Start ${selected.label}',
                style: Fonts.ui(
                  size: 16,
                  color: Colors.white,
                  weight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Three-way difficulty segmented control.
class _DifficultyPicker extends StatelessWidget {
  const _DifficultyPicker({required this.selected, required this.onSelect});

  final Difficulty selected;
  final ValueChanged<Difficulty> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: tint(t.text, 0.04),
        border: Border.all(color: t.border, width: 1.2),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          for (final d in Difficulty.values)
            Expanded(
              child: GestureDetector(
                onTap: () => onSelect(d),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: d == selected ? tint(t.success, 0.16) : null,
                    border: d == Difficulty.hard
                        ? null
                        : Border(
                            right: BorderSide(color: t.border, width: 1.2),
                          ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    d.label,
                    style: Fonts.ui(
                      size: 13,
                      color: d == selected ? t.success : t.muted,
                      weight: FontWeight.w700,
                      letterSpacing: 0.3,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
