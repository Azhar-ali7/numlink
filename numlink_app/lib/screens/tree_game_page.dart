import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../game/game_controller.dart' show ScoreLabel, ScoreLabelText;
import '../game/tree_controller.dart';
import '../game/tree_generator.dart';
import '../screens/game_screen.dart' show GameToast;
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/confetti_overlay.dart';
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

/// The board a given past daily served, for Archive replay. ponytail: mirrors
/// PuzzleRepository's epoch (#128 → 2026-08-08); keep the two in sync, or fold
/// into one source when GameController is retired.
TreePuzzle archiveBranchingPuzzle(int no) =>
    dailyBranchingPuzzle(DateTime.utc(2026, 8, 8).add(Duration(days: no - 128)));

/// Self-contained branching-tree game: owns its [TreeController], deals fresh
/// boards, switches difficulty, and shows a win overlay. Launched from home via
/// [Navigator.push]; the linear engine stays untouched around it.
class TreeGamePage extends StatefulWidget {
  const TreeGamePage({super.key, this.tier = 'easy', this.puzzle, this.onWin});

  final String tier;

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
                  _Header(tier: _tier, onNew: _newBoard, onTier: _setTier),
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
  const _Header({required this.tier, required this.onNew, required this.onTier});
  final String tier;
  final VoidCallback onNew;
  final ValueChanged<String> onTier;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: t.text),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Text(tier.toUpperCase(),
              style: Fonts.ui(
                  size: 14,
                  color: t.text,
                  weight: FontWeight.w800,
                  letterSpacing: 2)),
          const Spacer(),
          PopupMenuButton<String>(
            key: const Key('difficulty'),
            icon: Icon(Icons.tune, color: t.muted),
            onSelected: onTier,
            itemBuilder: (_) => [
              for (final k in kTiers.keys)
                PopupMenuItem(value: k, child: Text(k)),
            ],
          ),
          TextButton(
            onPressed: onNew,
            child: Text('New',
                style: Fonts.ui(
                    size: 13, color: t.progress, weight: FontWeight.w700)),
          ),
        ],
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
          Icon(Icons.bolt_rounded, size: 18, color: NumTokens.accentOrange),
          const SizedBox(width: 4),
          Text(clock,
              style: Fonts.mono(
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
              border: Border(top: BorderSide(color: t.success, width: 3)),
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
                      color: tint(NumTokens.hero, 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('+${win!.xpGained} XP  ·  Level ${win!.level}',
                        style: Fonts.ui(
                            size: 13,
                            color: NumTokens.hero,
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
              border: Border(top: BorderSide(color: t.success, width: 3)),
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
                      child: _pill(_boardCharacter(c), NumTokens.hero),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text('${c.moves} moves · par ${c.puzzle.par}',
                    style: Fonts.mono(
                        size: 15,
                        color: over > 0 ? t.progress : t.text,
                        weight: FontWeight.w700)),
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
                    border: Border.all(color: t.border, width: 1.4),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(_shareText(c),
                      style: Fonts.mono(
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
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: Text('Home',
                        style: Fonts.ui(
                            size: 13, color: t.muted, weight: FontWeight.w600)),
                  ),
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
          color: tint(NumTokens.hero, 0.14),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('+${w.xpGained} XP',
                style: Fonts.ui(
                    size: 13, color: NumTokens.hero, weight: FontWeight.w800)),
            const SizedBox(width: 8),
            Text('· Level ${w.level}  ·  🔥 ${w.streak}',
                style: Fonts.ui(
                    size: 13, color: t.muted, weight: FontWeight.w700)),
          ],
        ),
      );

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
