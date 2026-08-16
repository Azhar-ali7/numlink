import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../game/campaign.dart';
import '../game/game_controller.dart';
import '../game/game_mode.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'bottom_sheet_shell.dart';

/// The campaign roadmap: a vertical node-path of curated levels. Cleared levels
/// show their earned stars, the next playable level is highlighted, later ones
/// are locked (linear gate). Tapping an unlocked node loads it (closing this).
class RoadmapSheet extends StatelessWidget {
  const RoadmapSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final g = context.watch<GameController>();
    final t = NumTheme.of(context);
    final stats = g.stats;
    final count = g.campaignCount;
    final maxStars = count * 3;

    return BottomSheetShell(
      title: 'Levels',
      onClose: g.close,
      children: [
        Row(
          children: [
            Icon(Icons.star_rounded, size: 18, color: t.progress),
            const SizedBox(width: 5),
            Text('${stats.campaignStars} / $maxStars',
                style: Fonts.mono(
                    size: 15, color: t.text, weight: FontWeight.w700)),
            const SizedBox(width: 10),
            Text('${stats.campaignCleared}/$count cleared',
                style: Fonts.ui(size: 12, color: t.muted, height: 1)),
          ],
        ),
        const SizedBox(height: 18),
        for (var i = 0; i < count; i++) ...[
          if (i > 0) _Connector(color: t.border),
          _LevelNode(
            def: kCampaign[i],
            stars: stats.levelStars[i + 1],
            unlocked: stats.levelUnlocked(i + 1),
            onTap: () => g.startCampaign(i + 1),
          ),
        ],
      ],
    );
  }
}

/// One level in the roadmap path: numbered badge, tier label (+ new-op hint),
/// and either earned stars, a "PLAY" cue, or a lock.
class _LevelNode extends StatelessWidget {
  const _LevelNode({
    required this.def,
    required this.stars,
    required this.unlocked,
    required this.onTap,
  });

  final LevelDef def;
  final int? stars;
  final bool unlocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    final cleared = stars != null;
    final accent = cleared ? t.success : (unlocked ? t.text : t.border);

    return Opacity(
      opacity: unlocked ? 1 : 0.5,
      child: GestureDetector(
        onTap: unlocked ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: cleared ? tint(t.success, 0.12) : t.surface,
            border: Border.all(
                color: cleared || unlocked ? accent : t.border, width: 2),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Text('${def.no}',
                  style: Fonts.mono(
                      size: 22, color: accent, weight: FontWeight.w700)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('LEVEL ${def.no}',
                        style: Fonts.ui(
                            size: 13,
                            color: t.text,
                            weight: FontWeight.w700,
                            letterSpacing: 1,
                            height: 1)),
                    const SizedBox(height: 4),
                    Text(
                        def.unlocks != null
                            ? '${def.tier.label} · new: ${def.unlocks}'
                            : def.tier.label,
                        style: Fonts.ui(size: 11, color: t.muted, height: 1)),
                  ],
                ),
              ),
              if (!unlocked)
                Icon(Icons.lock_outline_rounded, size: 20, color: t.muted)
              else if (cleared)
                _MiniStars(earned: stars!)
              else
                Text('PLAY',
                    style: Fonts.ui(
                        size: 11,
                        color: t.success,
                        weight: FontWeight.w700,
                        letterSpacing: 1,
                        height: 1)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStars extends StatelessWidget {
  const _MiniStars({required this.earned});
  final int earned;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 3; i++)
          Icon(
            i <= earned ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 18,
            color: i <= earned ? t.progress : t.border,
          ),
      ],
    );
  }
}

class _Connector extends StatelessWidget {
  const _Connector({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) => Center(
        child: Container(width: 2, height: 12, color: color),
      );
}
