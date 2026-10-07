import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class _GuidePage {
  final String title;
  final String body;
  const _GuidePage(this.title, this.body);
}

const _pages = [
  _GuidePage(
    'YOUR MUSIC',
    'Open Library and tap Scan Device. Tap a song to play it. Playback keeps going when you leave this screen.',
  ),
  _GuidePage(
    'FREE MUSIC',
    'Free Music lists songs you can listen to legally. Tap a song to preview it. Nothing is saved until you tap download.',
  ),
  _GuidePage(
    'ALBUMS AND PLAYLISTS',
    'Open a song menu to move a download into an album, add it to a playlist, or delete it. Create albums and playlists from the Library tabs.',
  ),
  _GuidePage(
    'MAKE A SONG',
    'Create New Song opens lyricsintosong.com in the browser. About tells you who made OmniPlayer. Replay these tips from the question mark.',
  ),
];

/// Returns true when the guide is finished or skipped.
Future<bool> showOnboarding(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withOpacity(0.72),
    builder: (_) => const OnboardingDialog(),
  );
  return result == true;
}

class OnboardingDialog extends StatefulWidget {
  const OnboardingDialog({super.key});

  @override
  State<OnboardingDialog> createState() => _OnboardingDialogState();
}

class _OnboardingDialogState extends State<OnboardingDialog> {
  final _controller = PageController();
  var _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page >= _pages.length - 1) {
      Navigator.of(context).pop(true);
      return;
    }
    _controller.nextPage(duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _pages.length - 1;
    return Dialog(
      backgroundColor: OmniPlayerColors.deepVoid,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: OmniPlayerColors.cyan.withOpacity(0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 210,
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (index) => setState(() => _page = index),
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Column(
                    children: [
                      Text(
                        page.title,
                        textAlign: TextAlign.center,
                        style: OmniPlayerTextStyles.orbitronLabel.copyWith(fontSize: 13, letterSpacing: 2),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        page.body,
                        textAlign: TextAlign.center,
                        style: OmniPlayerTextStyles.rajdhaniBody.copyWith(color: Colors.white.withOpacity(0.9), fontSize: 16, height: 1.35),
                      ),
                    ],
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _pages.length; i++)
                  Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _page ? OmniPlayerColors.cyan : OmniPlayerColors.cyan.withOpacity(0.25),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text('SKIP', style: OmniPlayerTextStyles.orbitronLabel.copyWith(fontSize: 10, color: OmniPlayerColors.textMuted)),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _next,
                  child: Text(
                    last ? 'DONE' : 'NEXT',
                    style: OmniPlayerTextStyles.orbitronLabel.copyWith(fontSize: 12),
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
