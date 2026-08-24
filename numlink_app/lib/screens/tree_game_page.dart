import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../game/tree_controller.dart';
import '../game/tree_generator.dart';
import '../screens/game_screen.dart' show GameToast;
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'tree_game_screen.dart';

/// Self-contained branching-tree game: owns its [TreeController], deals fresh
/// boards, switches difficulty, and shows a win overlay. Launched from home via
/// [Navigator.push]; the linear engine stays untouched around it.
class TreeGamePage extends StatefulWidget {
  const TreeGamePage({super.key, this.tier = 'easy', this.puzzle});

  final String tier;

  /// Injected board (daily/tests); when set, "New board" re-deals it.
  final TreePuzzle? puzzle;

  @override
  State<TreeGamePage> createState() => _TreeGamePageState();
}

class _TreeGamePageState extends State<TreeGamePage> {
  late String _tier = widget.tier;
  int _seed = DateTime.now().millisecondsSinceEpoch & 0x7fffffff;
  late TreeController _c = _make();

  TreeController _make() =>
      TreeController(widget.puzzle ?? buildPuzzle(_tier, _seed))..init();

  void _newBoard() {
    setState(() {
      _seed = _seed * 1103515245 + 12345 & 0x7fffffff;
      _c.dispose();
      _c = _make();
    });
  }

  void _setTier(String tier) {
    if (tier == _tier && widget.puzzle == null) return;
    setState(() {
      _tier = tier;
      _seed = _seed * 1103515245 + 12345 & 0x7fffffff;
      _c.dispose();
      _c = TreeController(buildPuzzle(_tier, _seed))..init();
    });
  }

  @override
  void dispose() {
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
              Consumer<TreeController>(
                builder: (_, c, __) => c.solved
                    ? _WinOverlay(controller: c, onNew: _newBoard)
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

class _WinOverlay extends StatelessWidget {
  const _WinOverlay({required this.controller, required this.onNew});
  final TreeController controller;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    final par = controller.puzzle.par;
    final over = controller.moves > par;
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black54,
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(32),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            decoration: BoxDecoration(
              color: t.elevated,
              border: Border.all(color: t.success, width: 2.4),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('SOLVED',
                    style: Fonts.ui(
                        size: 20,
                        color: t.success,
                        weight: FontWeight.w800,
                        letterSpacing: 4)),
                const SizedBox(height: 12),
                Text('${controller.moves} moves · par $par',
                    style: Fonts.mono(
                        size: 16,
                        color: over ? t.progress : t.text,
                        weight: FontWeight.w700)),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: onNew,
                  style: FilledButton.styleFrom(backgroundColor: t.success),
                  child: const Text('New board'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: Text('Home',
                      style: Fonts.ui(
                          size: 13, color: t.muted, weight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
