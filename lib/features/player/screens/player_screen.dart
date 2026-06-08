import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/providers.dart';
import '../widgets/holo_panel.dart';
import '../widgets/spectrum_ring.dart';
import '../widgets/waveform_bar.dart';
import '../widgets/control_buttons.dart';
import '../../library/screens/library_screen.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  bool _libraryOpen = false;

  void _toggleLibrary() => setState(() => _libraryOpen = !_libraryOpen);
  void _closeLibrary()  => setState(() => _libraryOpen = false);

  @override
  Widget build(BuildContext context) {
    final player   = ref.watch(playerProvider);
    final notifier = ref.read(playerProvider.notifier);
    final track    = player.currentTrack;
    final panelW   = MediaQuery.of(context).size.width * 0.85;

    return Scaffold(
      backgroundColor: OmniXColors.voidBlack,
      body: Stack(
        children: [
          // ── Ambient background ──────────────────
          const _AmbientBackground(),

          // ── Player content ──────────────────────
          SafeArea(
            child: SingleChildScrollView(
              padding: OmniXSpacing.screenPadding,
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  _HeaderBar(onLibraryToggle: _toggleLibrary),
                  const SizedBox(height: 20),
                  HoloPanel(
                    child: Column(
                      children: [
                        Center(child: SpectrumRing(isPlaying: player.isPlaying, size: 200)),
                        const SizedBox(height: 24),
                        _TrackInfo(track: track),
                        const SizedBox(height: 16),
                        WaveformBar(isPlaying: player.isPlaying),
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
                  if (player.error != null) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        player.error!,
                        textAlign: TextAlign.center,
                        style: OmniXTextStyles.orbitronMono.copyWith(
                          color: OmniXColors.errorRed,
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
                  left: BorderSide(color: OmniXColors.cyan.withOpacity(0.2), width: 1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: OmniXColors.cyan.withOpacity(0.06),
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
  const _HeaderBar({required this.onLibraryToggle});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'OMNIX AUDIO',
          style: OmniXTextStyles.orbitronLabel.copyWith(
            fontSize: 11,
            letterSpacing: 4,
            color: OmniXColors.cyan.withOpacity(0.7),
          ),
        ),
        Row(children: [
          _dot(OmniXColors.cyan),
          const SizedBox(width: 5),
          _dot(OmniXColors.violet),
          const SizedBox(width: 5),
          _dot(OmniXColors.magenta),
        ]),
        GestureDetector(
          onTap: onLibraryToggle,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(
              Icons.library_music_outlined,
              color: OmniXColors.cyan.withOpacity(0.7),
              size: 20,
            ),
          ),
        ),
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
          style: OmniXTextStyles.orbitronTitle.copyWith(
            fontSize: 17,
            shadows: [Shadow(color: OmniXColors.cyan.withOpacity(0.5), blurRadius: 20)],
          ),
        ),
        const SizedBox(height: 4),
        Text(artist, style: OmniXTextStyles.rajdhaniSemi.copyWith(color: OmniXColors.cyan.withOpacity(0.6), letterSpacing: 2)),
        const SizedBox(height: 2),
        Text(album, style: OmniXTextStyles.rajdhaniBody.copyWith(color: OmniXColors.violet.withOpacity(0.5), fontSize: 12)),
        if (track != null) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_badge(track!), style: OmniXTextStyles.orbitronMono.copyWith(color: OmniXColors.cyan.withOpacity(0.5))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text('◆', style: TextStyle(color: Colors.white.withOpacity(0.1), fontSize: 8)),
              ),
              Text('LOCAL', style: OmniXTextStyles.orbitronMono.copyWith(color: OmniXColors.magenta.withOpacity(0.5))),
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
            activeTrackColor: OmniXColors.cyan,
            inactiveTrackColor: OmniXColors.cyan.withOpacity(0.12),
            thumbColor: OmniXColors.cyan,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayColor: OmniXColors.cyan.withOpacity(0.15),
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
              Text(_fmt(position), style: OmniXTextStyles.orbitronMono.copyWith(color: OmniXColors.cyan.withOpacity(0.5))),
              Text(_fmt(duration), style: OmniXTextStyles.orbitronMono.copyWith(color: OmniXColors.cyan.withOpacity(0.3))),
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
        Icon(Icons.volume_down, color: OmniXColors.cyan.withOpacity(0.4), size: 18),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              activeTrackColor: OmniXColors.magenta.withOpacity(0.8),
              inactiveTrackColor: OmniXColors.cyan.withOpacity(0.1),
              thumbColor: OmniXColors.magenta,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayColor: OmniXColors.magenta.withOpacity(0.15),
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
        Icon(Icons.volume_up, color: OmniXColors.magenta.withOpacity(0.5), size: 18),
        const SizedBox(width: 6),
        Text(
          '${(_volume * 100).round()}%',
          style: OmniXTextStyles.orbitronMono.copyWith(color: OmniXColors.violet.withOpacity(0.5), fontSize: 9),
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
        Text('LOCAL LIBRARY', style: OmniXTextStyles.orbitronMono.copyWith(color: OmniXColors.cyan.withOpacity(0.3))),
        Row(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 7, height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isPlaying ? OmniXColors.activeGreen : Colors.white.withOpacity(0.2),
              boxShadow: isPlaying
                  ? [BoxShadow(color: OmniXColors.activeGreen.withOpacity(0.8), blurRadius: 8)]
                  : [],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isPlaying ? 'PLAYING' : 'STANDBY',
            style: OmniXTextStyles.orbitronMono.copyWith(
              color: isPlaying ? OmniXColors.activeGreen : Colors.white.withOpacity(0.2),
            ),
          ),
        ]),
        Text(
          '$trackCount TRACKS',
          style: OmniXTextStyles.orbitronMono.copyWith(color: OmniXColors.violet.withOpacity(0.3)),
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
      (Offset(size.width * 0.1, size.height * 0.1), OmniXColors.cyan, 160.0),
      (Offset(size.width * 0.85, size.height * 0.25), OmniXColors.violet, 120.0),
      (Offset(size.width * 0.4, size.height * 0.7), OmniXColors.magenta, 100.0),
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
