import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/providers.dart';
import '../widgets/album_art.dart';
import '../widgets/holo_panel.dart';
import '../widgets/spectrum_ring.dart';
import '../widgets/waveform_bar.dart';
import '../widgets/control_buttons.dart';
import '../widgets/queue_sheet.dart';
import '../../free_music/free_music_screen.dart';
import '../../about/about_screen.dart';
import '../../library/screens/library_screen.dart';
import '../../onboarding/onboarding_dialog.dart';
import '../../visualizer/visualizer_screen.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  bool _libraryOpen = false;
  var _guideScheduled = false;

  void _toggleLibrary() => setState(() => _libraryOpen = !_libraryOpen);
  void _closeLibrary()  => setState(() => _libraryOpen = false);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openGuideIfNeeded());
  }

  Future<void> _openGuideIfNeeded() async {
    if (_guideScheduled || !mounted) return;
    _guideScheduled = true;
    final seen = await ref.read(databaseProvider).getSetting(AppDatabase.onboardingSeenKey);
    if (seen == '1' || !mounted) return;
    final finished = await showOnboarding(context);
    if (finished && mounted) {
      await ref.read(databaseProvider).setSetting(AppDatabase.onboardingSeenKey, '1');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(playerProvider.select((s) => s.error), (prev, next) {
      if (next != null && next != prev) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(next, style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 13)),
          backgroundColor: OmniPlayerColors.errorRed.withOpacity(0.92),
          duration: const Duration(seconds: 6),
          behavior: SnackBarBehavior.floating,
        ));
      }
    });

    final player   = ref.watch(playerProvider);
    final notifier = ref.read(playerProvider.notifier);
    final track    = player.currentTrack;
    final panelW   = MediaQuery.of(context).size.width * 0.85;

    return Scaffold(
      backgroundColor: OmniPlayerColors.voidBlack,
      body: Stack(
        children: [
          // ── Ambient background ──────────────────
          const _AmbientBackground(),

          // ── Player content ──────────────────────
          SafeArea(
            child: SingleChildScrollView(
              padding: OmniPlayerSpacing.screenPadding,
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  _HeaderBar(
                    onLibraryToggle: _toggleLibrary,
                    onQueue: () => showQueueSheet(context),
                    onHelp: () => showOnboarding(context),
                  ),
                  const SizedBox(height: 20),
                  HoloPanel(
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SpectrumRing(
                              isPlaying: player.isPlaying,
                              size: 200,
                            ),
                            AlbumArt(track: track, size: 112),
                            if (player.isLoading)
                              const SizedBox(
                                width: 36, height: 36,
                                child: CircularProgressIndicator(color: OmniPlayerColors.cyan, strokeWidth: 2),
                              ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _TrackInfo(track: track),
                        const SizedBox(height: 16),
                        WaveformBar(
                          isPlaying: player.isPlaying,
                        ),
                        const SizedBox(height: 16),
                        _ProgressBar(
                          progress: player.progressFraction,
                          position: player.position,
                          duration: player.duration,
                          onSeek: notifier.seek,
                        ),
                        const SizedBox(height: 20),
                        const ControlButtons(),
                        const SizedBox(height: 20),
                        _VolumeRow(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _StatusBar(isPlaying: player.isPlaying, trackCount: player.queue.length),
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      _ScreenButton(
                        label: 'FREE MUSIC',
                        color: OmniPlayerColors.cyan,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const FreeMusicScreen()),
                        ),
                      ),
                      _ScreenButton(
                        label: 'CREATE NEW SONG',
                        color: OmniPlayerColors.magenta,
                        onTap: () => launchUrl(
                          Uri.parse('https://lyricsintosong.com'),
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                      _ScreenButton(
                        label: 'ABOUT',
                        color: OmniPlayerColors.violet,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const AboutScreen()),
                        ),
                      ),
                    ],
                  ),
                  if (player.error != null) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        player.error!,
                        textAlign: TextAlign.center,
                        style: OmniPlayerTextStyles.orbitronMono.copyWith(
                          color: OmniPlayerColors.errorRed,
                          fontSize: 8,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // ── Scrim — tap outside to close library ─
          if (_libraryOpen)
            GestureDetector(
              onTap: _closeLibrary,
              child: Container(color: Colors.black.withOpacity(0.45)),
            ),

          // ── Library panel — slides in from right ─
          AnimatedPositioned(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
            top: 0,
            bottom: 0,
            right: _libraryOpen ? 0 : -panelW,
            width: panelW,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: OmniPlayerColors.cyan.withOpacity(0.2), width: 1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: OmniPlayerColors.cyan.withOpacity(0.06),
                    blurRadius: 32,
                    offset: const Offset(-8, 0),
                  ),
                ],
              ),
              child: LibraryContent(onClose: _closeLibrary),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header ─────────────────────────────────────

class _HeaderBar extends StatelessWidget {
  final VoidCallback onLibraryToggle;
  final VoidCallback onQueue;
  final VoidCallback onHelp;
  const _HeaderBar({required this.onLibraryToggle, required this.onQueue, required this.onHelp});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'OMNIPLAYER',
          style: OmniPlayerTextStyles.orbitronLabel.copyWith(
            fontSize: 11,
            letterSpacing: 4,
            color: OmniPlayerColors.cyan.withOpacity(0.7),
          ),
        ),
        Row(children: [
          _dot(OmniPlayerColors.cyan),
          const SizedBox(width: 5),
          _dot(OmniPlayerColors.violet),
          const SizedBox(width: 5),
          _dot(OmniPlayerColors.magenta),
        ]),
        Row(children: [
          GestureDetector(
            onTap: onHelp,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.help_outline,
                color: OmniPlayerColors.cyan.withOpacity(0.7),
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onQueue,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.queue_music,
                color: OmniPlayerColors.cyan.withOpacity(0.7),
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              PageRouteBuilder(
                opaque: false,
                pageBuilder: (_, __, ___) => const VisualizerScreen(),
                transitionsBuilder: (_, anim, __, child) =>
                    FadeTransition(opacity: anim, child: child),
                transitionDuration: const Duration(milliseconds: 400),
              ),
            ),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.graphic_eq,
                color: OmniPlayerColors.cyan.withOpacity(0.7),
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onLibraryToggle,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.library_music_outlined,
                color: OmniPlayerColors.cyan.withOpacity(0.7),
                size: 20,
              ),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _dot(Color c) => Container(
    width: 7, height: 7,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: c,
      boxShadow: [BoxShadow(color: c.withOpacity(0.8), blurRadius: 6)],
    ),
  );
}

class _ScreenButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ScreenButton({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: OmniPlayerTextStyles.orbitronMono.copyWith(
            color: color.withOpacity(0.75),
            fontSize: 10,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}

// ── Track info ─────────────────────────────────

class _TrackInfo extends StatelessWidget {
  final Track? track;
  const _TrackInfo({this.track});

  // Derives "FLAC · 1024K" style label from path extension + size/duration.
  String _badge(Track t) {
    final dot = t.path.lastIndexOf('.');
    final ext = dot >= 0 ? t.path.substring(dot + 1).toUpperCase() : 'AUDIO';
    if (t.duration <= 0 || t.size <= 0) return ext;
    final kbps = (t.size * 8) / (t.duration / 1000) / 1000;
    return '$ext · ${kbps.round()}K';
  }

  @override
  Widget build(BuildContext context) {
    final title  = track?.title  ?? 'NO TRACK LOADED';
    final artist = track?.artist ?? '—';
    final album  = track?.album  ?? '—';

    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: OmniPlayerTextStyles.orbitronTitle.copyWith(
            fontSize: 17,
            shadows: [Shadow(color: OmniPlayerColors.cyan.withOpacity(0.5), blurRadius: 20)],
          ),
        ),
        const SizedBox(height: 4),
        Text(artist, style: OmniPlayerTextStyles.rajdhaniSemi.copyWith(color: OmniPlayerColors.cyan.withOpacity(0.6), letterSpacing: 2)),
        const SizedBox(height: 2),
        Text(album, style: OmniPlayerTextStyles.rajdhaniBody.copyWith(color: OmniPlayerColors.violet.withOpacity(0.5), fontSize: 12)),
        if (track != null) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_badge(track!), style: OmniPlayerTextStyles.orbitronMono.copyWith(color: OmniPlayerColors.cyan.withOpacity(0.5))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text('◆', style: TextStyle(color: Colors.white.withOpacity(0.1), fontSize: 8)),
              ),
              Text(
                track!.licenseName ?? 'LOCAL',
                style: OmniPlayerTextStyles.orbitronMono.copyWith(color: OmniPlayerColors.magenta.withOpacity(0.5)),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ── Progress bar ───────────────────────────────

class _ProgressBar extends StatelessWidget {
  final double progress;
  final Duration position;
  final Duration duration;
  final ValueChanged<double> onSeek;

  const _ProgressBar({
    required this.progress,
    required this.position,
    required this.duration,
    required this.onSeek,
  });

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            activeTrackColor: OmniPlayerColors.cyan,
            inactiveTrackColor: OmniPlayerColors.cyan.withOpacity(0.12),
            thumbColor: OmniPlayerColors.cyan,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayColor: OmniPlayerColors.cyan.withOpacity(0.15),
          ),
          child: Slider(
            value: progress.clamp(0.0, 1.0),
            onChanged: onSeek,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_fmt(position), style: OmniPlayerTextStyles.orbitronMono.copyWith(color: OmniPlayerColors.cyan.withOpacity(0.5))),
              Text(_fmt(duration), style: OmniPlayerTextStyles.orbitronMono.copyWith(color: OmniPlayerColors.cyan.withOpacity(0.3))),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Volume row ─────────────────────────────────

class _VolumeRow extends ConsumerStatefulWidget {
  @override
  ConsumerState<_VolumeRow> createState() => _VolumeRowState();
}

class _VolumeRowState extends ConsumerState<_VolumeRow> {
  late double _volume;

  @override
  void initState() {
    super.initState();
    _volume = ref.read(playerProvider).volume;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.volume_down, color: OmniPlayerColors.cyan.withOpacity(0.4), size: 18),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              activeTrackColor: OmniPlayerColors.magenta.withOpacity(0.8),
              inactiveTrackColor: OmniPlayerColors.cyan.withOpacity(0.1),
              thumbColor: OmniPlayerColors.magenta,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayColor: OmniPlayerColors.magenta.withOpacity(0.15),
            ),
            child: Slider(
              value: _volume,
              onChanged: (v) {
                setState(() => _volume = v);
                ref.read(playerProvider.notifier).setVolume(v);
              },
            ),
          ),
        ),
        Icon(Icons.volume_up, color: OmniPlayerColors.magenta.withOpacity(0.5), size: 18),
        const SizedBox(width: 6),
        Text(
          '${(_volume * 100).round()}%',
          style: OmniPlayerTextStyles.orbitronMono.copyWith(color: OmniPlayerColors.violet.withOpacity(0.5), fontSize: 9),
        ),
      ],
    );
  }
}

// ── Status bar ─────────────────────────────────

class _StatusBar extends StatelessWidget {
  final bool isPlaying;
  final int trackCount;

  const _StatusBar({required this.isPlaying, required this.trackCount});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('LOCAL LIBRARY', style: OmniPlayerTextStyles.orbitronMono.copyWith(color: OmniPlayerColors.cyan.withOpacity(0.3))),
        Row(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 7, height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isPlaying ? OmniPlayerColors.activeGreen : Colors.white.withOpacity(0.2),
              boxShadow: isPlaying
                  ? [BoxShadow(color: OmniPlayerColors.activeGreen.withOpacity(0.8), blurRadius: 8)]
                  : [],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isPlaying ? 'PLAYING' : 'STANDBY',
            style: OmniPlayerTextStyles.orbitronMono.copyWith(
              color: isPlaying ? OmniPlayerColors.activeGreen : Colors.white.withOpacity(0.2),
            ),
          ),
        ]),
        Text(
          '$trackCount TRACKS',
          style: OmniPlayerTextStyles.orbitronMono.copyWith(color: OmniPlayerColors.violet.withOpacity(0.3)),
        ),
      ],
    );
  }
}

// ── Ambient background ─────────────────────────

class _AmbientBackground extends StatelessWidget {
  const _AmbientBackground();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: CustomPaint(painter: _AmbientPainter()),
    );
  }
}

class _AmbientPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final orbs = [
      (Offset(size.width * 0.1, size.height * 0.1), OmniPlayerColors.cyan, 160.0),
      (Offset(size.width * 0.85, size.height * 0.25), OmniPlayerColors.violet, 120.0),
      (Offset(size.width * 0.4, size.height * 0.7), OmniPlayerColors.magenta, 100.0),
    ];

    for (final (center, color, radius) in orbs) {
      canvas.drawCircle(
        center,
        radius,
        Paint()..shader = RadialGradient(
          colors: [color.withOpacity(0.06), Colors.transparent],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }
  }

  @override
  bool shouldRepaint(_AmbientPainter old) => false;
}
