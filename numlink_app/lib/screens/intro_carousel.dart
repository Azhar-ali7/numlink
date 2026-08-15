import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/settings_controller.dart';
import '../sheets/bottom_sheet_shell.dart';
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

  static const _slides = [
    (
      icon: Icons.link_rounded,
      title: 'Welcome to NUMLINK',
      body: 'Chain operations to turn the start number into the target — '
          'in as few moves as you can.',
    ),
    (
      icon: Icons.touch_app_rounded,
      title: 'Tap to build the chain',
      body: 'Tap an operation like ×3 or +7 to apply it. The chain grows '
          'downward, and the orange node is where you are now.',
    ),
    (
      icon: Icons.flag_rounded,
      title: 'Reach the target',
      body: 'Land exactly on the target to close the chain. A fresh daily '
          'puzzle drops every day — keep your streak alive.',
    ),
  ];

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _dismiss() => context.read<SettingsController>().dismissTutorial();

  void _next() {
    if (_page >= _slides.length - 1) {
      _dismiss();
      return;
    }
    final target = _page + 1;
    if (reducedMotion(context)) {
      _pages.jumpToPage(target);
    } else {
      _pages.animateToPage(target,
          duration: Motion.standard, curve: Motion.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    final last = _page == _slides.length - 1;

    return ColoredBox(
      color: t.bg,
      child: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 12, 0),
                child: TextButton(
                  onPressed: _dismiss,
                  child: Text('Skip',
                      style: Fonts.ui(
                          size: 14,
                          color: t.muted,
                          weight: FontWeight.w700,
                          height: 1)),
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
                label: last ? 'Get started' : 'Next',
                center: true,
                onTap: _next,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  const _Slide({required this.slide});

  final ({IconData icon, String title, String body}) slide;

  @override
  Widget build(BuildContext context) {
    final t = NumTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: tint(t.success, 0.12),
              border: Border.all(color: t.success, width: 2),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Icon(slide.icon, size: 44, color: t.success),
          ),
          const SizedBox(height: 32),
          Text(slide.title,
              textAlign: TextAlign.center,
              style: Fonts.display(size: 30, color: t.text, height: 1.05)),
          const SizedBox(height: 14),
          Text(slide.body,
              textAlign: TextAlign.center,
              style: Fonts.ui(size: 16, color: t.muted, height: 1.5)),
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
    final t = NumTheme.of(context);
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
              color: i == active ? t.success : t.border,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
      ],
    );
  }
}
