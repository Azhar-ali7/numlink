import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/settings_controller.dart';
import '../game/campaign.dart' show starsFor;
import '../game/score.dart';
import '../game/steiner.dart' show compute;
import '../game/tree_controller.dart';
import '../game/tree_generator.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/confetti_overlay.dart';
import '../widgets/game_toast.dart';
import 'tree_game_screen.dart';

/// What a recorded win reports back, for the win sheet's XP pill.
class WinRecord {
  const WinRecord(
      {required this.xpGained, required this.level, required this.streak});
  final int xpGained;
  final int level;
  final int streak;
}

/// Today's deterministic daily branching board (medium tier, date-seeded so
/// everyone gets the same puzzle on a given day).
TreePuzzle dailyBranchingPuzzle([DateTime? day]) {
  final d = day ?? DateTime.now();
  return buildPuzzle('medium', d.year * 10000 + d.month * 100 + d.day);
}

/// This weekend's shared co-op board — week-seeded medium, so everyone on the
/// same ISO week gets the same chain. (Handoff ships a hardcoded co-op puzzle,
/// but its unary ops aren't in this engine; a week-seeded board is the same
/// "shared board, resets Monday" experience per docs §11 mock allowance.)
TreePuzzle weekendCoopPuzzle([DateTime? day]) {
  final d = day ?? DateTime.now();
  // Days since a fixed Monday epoch ÷ 7 → a stable per-week seed.
  final week = DateTime(d.year, d.month, d.day)
          .difference(DateTime(2026, 1, 5))
          .inDays ~/
      7;
  return buildPuzzle('medium', 0x00C0FFEE ^ week);
}

/// The board a given past daily served, for Archive replay. ponytail: mirrors
/// PuzzleRepository's epoch (#128 → 2026-08-08); keep the two in sync, or fold
/// into one source when GameController is retired.
TreePuzzle archiveBranchingPuzzle(int no) =>
    dailyBranchingPuzzle(DateTime.utc(2026, 8, 8).add(Duration(days: no - 128)));

/// Self-contained branching-tree game: owns its [TreeController], deals fresh
/// boards, switches difficulty, and shows a win overlay. Launched from home via
/// [Navigator.push]; the linear engine stays untouched around it.
class TreeGamePage extends StatefulWidget {
  const TreeGamePage({
    super.key,
    this.tier = 'easy',
    this.puzzle,
    this.onWin,
    this.title,
    this.coop = false,
  });

  final String tier;

  /// Header label override (e.g. 'WEEKEND CO-OP'); defaults to the tier name.
  final String? title;

  /// Co-op board: shows the "teammates already started" banner.
  final bool coop;

  /// Injected board (daily/tests); when set, "New board" re-deals it.
  final TreePuzzle? puzzle;

  /// Fired once per board when solved, with (moves, par) — lets the daily entry
  /// record the win into the shared stats and hand back XP/level/streak for the
  /// win sheet. Null (or a null return) for standalone/free play: no XP pill.
  final WinRecord? Function(int moves, int par)? onWin;

  @override
  State<TreeGamePage> createState() => _TreeGamePageState();
}

class _TreeGamePageState extends State<TreeGamePage> {
  late String _tier = widget.tier;
  int _seed = DateTime.now().millisecondsSinceEpoch & 0x7fffffff;
  bool _winReported = false;
  WinRecord? _win;
  int _confetti = 0;
  late TreeController _c = _make();

  TreeController _make() {
    final c = TreeController(widget.puzzle ?? buildPuzzle(_tier, _seed))..init();
    c.addListener(_onChange);
    return c;
  }

  void _onChange() {
    if (_c.solved && !_winReported) {
      _winReported = true;
      setState(() {
        _win = widget.onWin?.call(_c.moves, _c.puzzle.par);
        _confetti++;
      });
    }
  }

  void _swap(TreeController next) {
    setState(() {
      _c.removeListener(_onChange);
      _c.dispose();
      _winReported = false;
      _win = null;
      _c = next;
    });
  }

  void _newBoard() {
    _seed = _seed * 1103515245 + 12345 & 0x7fffffff;
    _swap(_make());
  }

  void _restart() {
    _swap(TreeController(_c.puzzle)..init()..addListener(_onChange));
  }

  void _setTier(String tier) {
    if (tier == _tier && widget.puzzle == null) return;
    _tier = tier;
    _seed = _seed * 1103515245 + 12345 & 0x7fffffff;
    _swap(TreeController(buildPuzzle(_tier, _seed))..init()..addListener(_onChange));
  }

  @override
  void dispose() {
    _c.removeListener(_onChange);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    return ChangeNotifierProvider<TreeController>.value(
      value: _c,
      child: Scaffold(
        backgroundColor: t.bg,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _Header(
                      tier: _tier,
                      title: widget.title,
                      onNew: _newBoard,
                      onTier: _setTier,
                      onRestart: _restart),
                  if (widget.coop) const _CoopBanner(),
                  const Expanded(child: TreeGameScreen()),
                ],
              ),
              // reject / shuffle status line, floated above the pad
              Positioned(
                left: 0,
                right: 0,
                bottom: 172,
                child: Consumer<TreeController>(
                  builder: (_, c, __) => (c.message != null && !c.solved)
                      ? Center(child: GameToast(message: c.message!))
                      : const SizedBox.shrink(),
                ),
              ),
              // confetti sits above the board, below the sheet
              Positioned.fill(child: ConfettiOverlay(pulse: _confetti)),
              Consumer<TreeController>(
                builder: (_, c, __) => c.solved
                    ? _WinSheet(controller: c, win: _win, onPlayAgain: _newBoard)
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.tier,
    required this.onNew,
    required this.onTier,
    required this.onRestart,
    this.title,
  });
  final String tier;
  final String? title;
  final VoidCallback onNew;
  final ValueChanged<String> onTier;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    final c = context.watch<TreeController>();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          _RoundIconBtn(
            icon: Icons.arrow_back,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title ?? tier.toUpperCase(),
                  style: Fonts.ui(
                      size: 14,
                      color: t.text,
                      weight: FontWeight.w800,
                      letterSpacing: 2,
                      height: 1)),
              const SizedBox(height: 2),
              Text('${c.puzzle.targets.length} targets · par ${c.puzzle.par}',
                  style: Fonts.ui(
                      size: 11, color: t.muted, weight: FontWeight.w700)),
            ],
          ),
          const Spacer(),
          const _BoardActions(),
          _RoundIconBtn(
            key: const Key('difficulty'),
            icon: Icons.more_horiz_rounded,
            onTap: () => _showOverflow(context, c.puzzle),
          ),
        ],
      ),
    );
  }

  void _showOverflow(BuildContext context, TreePuzzle puzzle) {
    final t = NumTheme.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: t.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _OverflowMenu(
        tier: tier,
        onNew: onNew,
        onTier: onTier,
        onRestart: onRestart,
        // Defer past the overflow's pop frame so the two modal transitions
        // don't clobber each other.
        onSolution: () => WidgetsBinding.instance
            .addPostFrameCallback((_) => showSolutionSheet(context, puzzle)),
      ),
    );
  }
}

/// Co-op board banner: overlapping teammate avatars + shared-board nudge.
class _CoopBanner extends StatelessWidget {
  const _CoopBanner();

  // Fixed mock cohort — matches the Friends leaderboard roster.
  static const _team = [
    ('I', Color(0xFFEC6A8D)),
    ('M', Color(0xFF2F9184)),
    ('P', Color(0xFF7A6CD6)),
  ];

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          SizedBox(
            width: 26 + (_team.length - 1) * 18,
            height: 26,
            child: Stack(
              children: [
                for (var i = 0; i < _team.length; i++)
                  Positioned(
                    left: i * 18,
                    child: Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _team[i].$2.withValues(alpha: 0.2),
                        border: Border.all(color: t.bg, width: 2),
                      ),
                      child: Text(_team[i].$1,
                          style: Fonts.ui(
                              size: 11,
                              color: _team[i].$2,
                              weight: FontWeight.w800)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
                'Teammates already started this chain — finish it together',
                style: Fonts.ui(
                    size: 11, color: t.muted, weight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

/// Board overflow (⋯) menu — ports the handoff's board menu: THIS PUZZLE
/// (Restart / How to play), DIFFICULTY (tier picker), QUICK SETTINGS (Sound /
/// Haptics). Each action pops the sheet first.
class _OverflowMenu extends StatelessWidget {
  const _OverflowMenu({
    required this.tier,
    required this.onNew,
    required this.onTier,
    required this.onRestart,
    required this.onSolution,
  });

  final String tier;
  final VoidCallback onNew;
  final ValueChanged<String> onTier;
  final VoidCallback onRestart;
  final VoidCallback onSolution;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    // Settings is always present in-app; absent in isolated widget tests.
    SettingsController? s;
    try {
      s = context.watch<SettingsController>();
    } on ProviderNotFoundException {
      s = null;
    }
    Widget label(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
          child: Text(text.toUpperCase(),
              style: Fonts.ui(
                  size: 11,
                  color: t.muted,
                  weight: FontWeight.w800,
                  letterSpacing: 1.5)),
        );
    Widget action(IconData icon, String text, VoidCallback onTap, {Key? key}) =>
        InkWell(
          key: key,
          onTap: () {
            Navigator.of(context).pop();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
            child: Row(children: [
              Icon(icon, size: 20, color: t.text),
              const SizedBox(width: 14),
              Text(text,
                  style: Fonts.ui(
                      size: 15, color: t.text, weight: FontWeight.w700)),
            ]),
          ),
        );
    Widget toggle(String text, bool value, VoidCallback onTap) => InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
            child: Row(children: [
              Expanded(
                child: Text(text,
                    style: Fonts.ui(
                        size: 15, color: t.text, weight: FontWeight.w700)),
              ),
              Icon(value ? Icons.toggle_on : Icons.toggle_off,
                  size: 34, color: value ? t.success : t.border),
            ]),
          ),
        );

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: t.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          label('This puzzle'),
          action(Icons.refresh_rounded, 'Restart', onRestart),
          action(Icons.add_circle_outline, 'New board', onNew),
          action(Icons.lightbulb_outline_rounded, 'Reveal solution', onSolution),
          if (s != null)
            action(Icons.school_outlined, 'How to play', s.openTutorial),
          label('Difficulty'),
          for (final k in kTiers.keys)
            action(
              k == tier ? Icons.radio_button_checked : Icons.radio_button_off,
              k,
              () => onTier(k),
              key: ValueKey('tier_$k'),
            ),
          if (s case final st?) ...[
            label('Quick settings'),
            toggle('Sound', st.sound, () => st.setSound(!st.sound)),
            toggle('Haptics', st.haptics, () => st.setHaptics(!st.haptics)),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Shuffle + hint round icon buttons with remaining-count badges. Reads the
/// board [TreeController], so it drops into either game header.
class _BoardActions extends StatelessWidget {
  const _BoardActions();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<TreeController>();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RoundIconBtn(
          icon: Icons.shuffle_rounded,
          badge: c.shufflesLeft,
          onTap: c.shuffleHand,
        ),
        _RoundIconBtn(
          icon: Icons.lightbulb_outline_rounded,
          badge: c.hintUsed ? 0 : 1,
          onTap: c.hint,
        ),
      ],
    );
  }
}

/// A round tappable icon tile with an optional count badge (top-right).
class _RoundIconBtn extends StatelessWidget {
  const _RoundIconBtn(
      {super.key, required this.icon, required this.onTap, this.badge});
  final IconData icon;
  final VoidCallback onTap;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                border: Border.all(color: t.border, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 19, color: t.text),
            ),
            if (badge != null)
              Positioned(
                top: -3,
                right: -3,
                child: Container(
                  width: 17,
                  height: 17,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: badge! > 0 ? t.progress : t.muted,
                    shape: BoxShape.circle,
                    border: Border.all(color: t.bg, width: 2),
                  ),
                  child: Text('$badge',
                      style: Fonts.numeric(
                          size: 9,
                          color: Colors.white,
                          weight: FontWeight.w800,
                          height: 1)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Eight escalating stages for one branching timed run (sprouts → hard).
const _timedLadder = <String>[
  'sprouts', 'junior', 'junior', 'easy', 'easy', 'medium', 'medium', 'hard',
];

/// Timed ladder on the branching engine: a stopwatch race through
/// [_timedLadder]. Each solve auto-advances to the next stage; clearing the
/// last one stops the clock and shows the run summary. [onStageSolved] banks
/// each cleared stage into the shared stats and hands back XP/level for the
/// summary. Launched from the Timed tile via [Navigator.push].
class TimedTreePage extends StatefulWidget {
  const TimedTreePage({super.key, this.onStageSolved});

  /// (stageCompleted 1-based, runDone) → optional WinRecord for the summary.
  final WinRecord? Function(int stageCompleted, bool runDone)? onStageSolved;

  @override
  State<TimedTreePage> createState() => _TimedTreePageState();
}

class _TimedTreePageState extends State<TimedTreePage> {
  int _stage = 0; // 0-based index into _timedLadder
  int _seed = DateTime.now().millisecondsSinceEpoch & 0x7fffffff;
  int _elapsed = 0; // seconds
  bool _done = false;
  WinRecord? _win;
  int _confetti = 0;
  Timer? _tick;
  late TreeController _c = _make();

  TreeController _make() {
    final c = TreeController(buildPuzzle(_timedLadder[_stage], _seed))..init();
    c.addListener(_onChange);
    return c;
  }

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_done) setState(() => _elapsed++);
    });
  }

  void _onChange() {
    if (!_c.solved || _done) return;
    final completed = _stage + 1;
    final runDone = completed >= _timedLadder.length;
    final record = widget.onStageSolved?.call(completed, runDone);
    setState(() {
      _confetti++;
      if (runDone) {
        _done = true;
        _win = record;
        _tick?.cancel();
      } else {
        _stage = completed;
        _seed = _seed * 1103515245 + 12345 & 0x7fffffff;
        _c.removeListener(_onChange);
        _c.dispose();
        _c = _make();
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _c.removeListener(_onChange);
    _c.dispose();
    super.dispose();
  }

  String get _clock {
    final m = _elapsed ~/ 60, s = _elapsed % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void _restart() => Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => TimedTreePage(onStageSolved: widget.onStageSolved),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    return ChangeNotifierProvider<TreeController>.value(
      value: _c,
      child: Scaffold(
        backgroundColor: t.bg,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _TimedHeader(
                      stage: _stage + 1,
                      total: _timedLadder.length,
                      clock: _clock),
                  const Expanded(child: TreeGameScreen()),
                ],
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 172,
                child: Consumer<TreeController>(
                  builder: (_, c, __) => (c.message != null && !c.solved)
                      ? Center(child: GameToast(message: c.message!))
                      : const SizedBox.shrink(),
                ),
              ),
              Positioned.fill(child: ConfettiOverlay(pulse: _confetti)),
              if (_done)
                _RunCompleteSheet(
                    stages: _timedLadder.length,
                    clock: _clock,
                    win: _win,
                    onPlayAgain: _restart),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimedHeader extends StatelessWidget {
  const _TimedHeader(
      {required this.stage, required this.total, required this.clock});
  final int stage;
  final int total;
  final String clock;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 20, 6),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: t.text),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Text('STAGE $stage/$total',
              style: Fonts.ui(
                  size: 14,
                  color: t.text,
                  weight: FontWeight.w800,
                  letterSpacing: 2)),
          const Spacer(),
          const _BoardActions(),
          const SizedBox(width: 8),
          Icon(Icons.bolt_rounded, size: 18, color: t.tileOrange),
          const SizedBox(width: 4),
          Text(clock,
              style: Fonts.numeric(
                  size: 16, color: t.text, weight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Run summary shown when the last stage falls: total stages, elapsed clock,
/// optional +XP pill, Play again / Home.
class _RunCompleteSheet extends StatelessWidget {
  const _RunCompleteSheet(
      {required this.stages,
      required this.clock,
      required this.win,
      required this.onPlayAgain});
  final int stages;
  final String clock;
  final WinRecord? win;
  final VoidCallback onPlayAgain;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black54,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 28),
            decoration: BoxDecoration(
              color: t.elevated,
              border: Border(top: BorderSide(color: t.success, width: 2)),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('RUN COMPLETE',
                    style: Fonts.ui(
                        size: 11,
                        color: t.success,
                        weight: FontWeight.w700,
                        letterSpacing: 2)),
                const SizedBox(height: 4),
                Text('$stages stages · $clock',
                    style: Fonts.display(size: 34, color: t.text, height: 1)),
                if (win != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: tint(t.hero, 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('+${win!.xpGained} XP  ·  Level ${win!.level}',
                        style: Fonts.ui(
                            size: 13,
                            color: t.hero,
                            weight: FontWeight.w800)),
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _action(
                        label: 'Play again',
                        bg: t.success,
                        fg: Colors.white,
                        onTap: onPlayAgain,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _action(
                        label: 'Home',
                        bg: tint(t.text, 0.06),
                        fg: t.text,
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Golf score label from moves-over-par (prototype 2016).
ScoreLabel _labelFor(int over) => over <= -2
    ? ScoreLabel.eagle
    : over == -1
        ? ScoreLabel.birdie
        : over == 0
            ? ScoreLabel.par
            : over == 1
                ? ScoreLabel.bogey
                : over == 2
                    ? ScoreLabel.doubleBogey
                    : ScoreLabel.over;

/// A light read on how this solve was built (prototype 2018–2024).
String _boardCharacter(TreeController c) {
  final sigma = c.nodes.where((n) => n.opLabel == 'Σ').length;
  final rootBranches = c.nodes.where((n) => n.parent == 0).length;
  final moves = c.moves, par = c.puzzle.par;
  if (sigma >= 2) return 'Alchemist';
  if (moves <= par && rootBranches <= 1) return 'Minimalist';
  if (rootBranches >= 3 || moves >= par + 2) return 'Sprawl';
  return 'Balanced';
}

/// Spoiler-free share preview: a blue-per-move / orange-per-over-par grid.
String _shareText(TreeController c) {
  final moves = c.moves, par = c.puzzle.par;
  final within = moves < par ? moves : par;
  final over = moves - par > 0 ? moves - par : 0;
  final grid = '🟦' * within + '🟧' * over;
  return 'NUMLINK — ${c.puzzle.targets.length} targets in $moves (par $par)\n$grid';
}

/// Win sheet (handoff Screen 3): CHAIN COMPLETE kicker, golf score label,
/// board-character read, moves-vs-par, an XP·Level pill when a win was
/// recorded, a spoiler-free share preview, and Play-again / Home actions.
class _WinSheet extends StatelessWidget {
  const _WinSheet(
      {required this.controller, required this.win, required this.onPlayAgain});
  final TreeController controller;
  final WinRecord? win;
  final VoidCallback onPlayAgain;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    final c = controller;
    final over = c.moves - c.puzzle.par;
    final label = _labelFor(over).text(over);
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black54,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 28),
            decoration: BoxDecoration(
              color: t.elevated,
              border: Border(top: BorderSide(color: t.success, width: 2)),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CHAIN COMPLETE',
                    style: Fonts.ui(
                        size: 11,
                        color: t.success,
                        weight: FontWeight.w700,
                        letterSpacing: 2)),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('$label!',
                        style: Fonts.display(
                            size: 38, color: t.text, height: 1)),
                    const SizedBox(width: 12),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _pill(_boardCharacter(c), t.hero),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text('${c.moves} moves · par ${c.puzzle.par}',
                    style: Fonts.numeric(
                        size: 15,
                        color: over > 0 ? t.progress : t.text,
                        weight: FontWeight.w700)),
                const SizedBox(height: 14),
                _StarRow(stars: starsFor(c.moves, c.puzzle.par)),
                if (win != null) ...[
                  const SizedBox(height: 14),
                  _xpPill(t, win!),
                ],
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: tint(t.text, 0.04),
                    border: Border.all(color: t.border, width: 2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(_shareText(c),
                      style: Fonts.numeric(
                          size: 14, color: t.text, height: 1.5)),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _action(
                        label: 'Play again',
                        bg: t.success,
                        fg: Colors.white,
                        onTap: onPlayAgain,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _action(
                        label: 'Copy',
                        bg: tint(t.text, 0.06),
                        fg: t.text,
                        onTap: () => Clipboard.setData(
                            ClipboardData(text: _shareText(c))),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => showSolutionSheet(context, c.puzzle),
                      child: Text('See solution',
                          style: Fonts.ui(
                              size: 13,
                              color: t.muted,
                              weight: FontWeight.w600)),
                    ),
                    Text('·',
                        style: Fonts.ui(size: 13, color: t.muted)),
                    TextButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: Text('Home',
                          style: Fonts.ui(
                              size: 13,
                              color: t.muted,
                              weight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pill(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(text,
            style: Fonts.ui(
                size: 11, color: color, weight: FontWeight.w800)),
      );

  Widget _xpPill(NumTokens t, WinRecord w) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: tint(t.hero, 0.14),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('+${w.xpGained} XP',
                style: Fonts.ui(
                    size: 13, color: t.hero, weight: FontWeight.w800)),
            const SizedBox(width: 8),
            Text('· Level ${w.level}  ·  🔥 ${w.streak}',
                style: Fonts.ui(
                    size: 13, color: t.muted, weight: FontWeight.w700)),
          ],
        ),
      );

}

/// The handoff win-sheet star rating: three big stars, [stars] of them filled
/// (amber), the rest outlined in the border tone.
class _StarRow extends StatelessWidget {
  const _StarRow({required this.stars});
  final int stars;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    return Row(
      children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Icon(
              i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 34,
              color: i < stars ? t.star : t.border,
            ),
          ),
      ],
    );
  }
}

/// One optimal-line step: `from` (op) → `to`.
typedef SolutionStep = ({int n, int from, String op, int to});

/// Orders [puzzle.optimalEdges] start-outward (each step's source is already
/// reached) and labels each edge with the op that produces it. Used by the
/// Solution reveal.
List<SolutionStep> solutionSteps(TreePuzzle puzzle) {
  final ops = [for (final hand in puzzle.hands) ...hand];
  String labelFor(int from, int to) {
    for (final o in ops) {
      if (compute(from, o) == to) return o.label;
    }
    return '?';
  }

  final reached = <int>{puzzle.start};
  final remaining = [...puzzle.optimalEdges];
  final steps = <SolutionStep>[];
  while (remaining.isNotEmpty) {
    final i = remaining.indexWhere((e) => reached.contains(e.$1));
    if (i < 0) break; // disconnected (shouldn't happen for a valid tree)
    final e = remaining.removeAt(i);
    steps.add((n: steps.length + 1, from: e.$1, op: labelFor(e.$1, e.$2), to: e.$2));
    reached.add(e.$2);
  }
  return steps;
}

/// Opens the Solution reveal (handoff spoiler sheet) for [puzzle]: the optimal
/// line as numbered `from op → to` steps. Shown from the win sheet and the board
/// overflow menu.
void showSolutionSheet(BuildContext context, TreePuzzle puzzle) {
  final t = NumTheme.of(context);
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: t.elevated,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _SolutionSheet(puzzle: puzzle),
  );
}

class _SolutionSheet extends StatelessWidget {
  const _SolutionSheet({required this.puzzle});
  final TreePuzzle puzzle;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    final steps = solutionSteps(puzzle);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('Solution',
                    style: Fonts.display(size: 28, color: t.text, weight: 700)),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close, color: t.text),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Text('Optimal line · ${puzzle.optimalPar} moves',
                style: Fonts.ui(
                    size: 12, color: t.muted, weight: FontWeight.w700)),
            const SizedBox(height: 16),
            for (final st in steps) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: t.border, width: 2),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      child: Text('${st.n}',
                          style: Fonts.numeric(size: 12, color: t.muted)),
                    ),
                    const SizedBox(width: 8),
                    Text('${st.from}',
                        style: Fonts.numeric(
                            size: 18, color: t.text, weight: FontWeight.w700)),
                    const SizedBox(width: 12),
                    Text(st.op,
                        style: Fonts.numeric(
                            size: 14,
                            color: t.progress,
                            weight: FontWeight.w700)),
                    const SizedBox(width: 12),
                    Text('→', style: Fonts.numeric(size: 14, color: t.muted)),
                    const SizedBox(width: 12),
                    Text('${st.to}',
                        style: Fonts.numeric(
                            size: 18,
                            color: t.success,
                            weight: FontWeight.w700)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 12),
            _action(
              label: 'Back to puzzle',
              bg: t.accent,
              fg: Colors.white,
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

/// A flat rounded action button shared by the win / run-complete sheets.
Widget _action({
  required String label,
  required Color bg,
  required Color fg,
  required VoidCallback onTap,
}) =>
    Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          child: Text(label,
              style: Fonts.ui(size: 14, color: fg, weight: FontWeight.w800)),
        ),
      ),
    );
