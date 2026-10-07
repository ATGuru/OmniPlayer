import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/providers.dart';

// ═══════════════════════════════════════════════
// FREQUENCY SIMULATOR
// Summed sine oscillators per band — gives organic,
// bass-heavy motion without real FFT data.
// ═══════════════════════════════════════════════

class _Sim {
  static const n = 48;
  final _rng = Random(0xDEAD1337);
  late final List<double> _f, _p, _w;

  _Sim() {
    _f = List.generate(n, (i) => 0.45 + i * 0.14 + _rng.nextDouble() * 0.18);
    _p = List.generate(n, (i) => _rng.nextDouble() * pi * 2);
    // Bass bands (low index) get higher weight
    _w = List.generate(n, (i) => 0.55 + (1.0 - i / n) * 1.1 + _rng.nextDouble() * 0.25);
  }

  double bar(int i, double t) => max(0.0,
      sin(t * _f[i] + _p[i]) * 0.44 +
      sin(t * _f[i] * 2.09 + _p[i] * 1.37) * 0.27 +
      sin(t * _f[i] * 4.87 + _p[i] * 0.83) * 0.16 +
      sin(t * _f[i] * 9.11 + _p[i] * 2.07) * 0.08 +
      sin(t * _f[i] * 15.3 + _p[i] * 1.19) * 0.05) * _w[i];

  double rms(double t) {
    var s = 0.0;
    for (var i = 0; i < n; i++) s += bar(i, t);
    return s / n;
  }
}

// ═══════════════════════════════════════════════
// PARTICLE
// ═══════════════════════════════════════════════

class _Particle {
  Offset pos, vel;
  double life, size;
  final Color color;
  final double _maxLife;

  _Particle({
    required this.pos,
    required this.vel,
    required this.life,
    required this.size,
    required this.color,
  }) : _maxLife = life;

  bool step(double dt) {
    pos += vel * dt;
    vel = Offset(vel.dx * 0.97, vel.dy - 28 * dt);
    life -= dt;
    return life > 0;
  }

  double get alpha => (life / _maxLife).clamp(0.0, 1.0);
}

// ═══════════════════════════════════════════════
// BACKGROUND PAINTER
// Radial gradient that breathes with RMS + beats.
// ═══════════════════════════════════════════════

class _BgPainter extends CustomPainter {
  final double rms, beat;
  _BgPainter(this.rms, this.beat);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = OmniPlayerColors.voidBlack);
    final c = size.center(Offset.zero);
    final r = size.longestSide * (0.55 + rms * 0.22 + beat * 0.12);
    // Cyan bloom
    canvas.drawRect(Offset.zero & size, Paint()
      ..shader = RadialGradient(colors: [
        OmniPlayerColors.cyan.withOpacity(0.07 + rms * 0.18 + beat * 0.1),
        OmniPlayerColors.violet.withOpacity(0.03 + rms * 0.07 + beat * 0.05),
        Colors.transparent,
      ], stops: const [0.0, 0.5, 1.0])
          .createShader(Rect.fromCircle(center: c, radius: r)));
    // Violet halo offset slightly up
    final halo = Offset(c.dx, c.dy * 0.55);
    canvas.drawRect(Offset.zero & size, Paint()
      ..shader = RadialGradient(colors: [
        OmniPlayerColors.violet.withOpacity(0.04 + beat * 0.07),
        Colors.transparent,
      ]).createShader(Rect.fromCircle(center: halo, radius: size.longestSide * 0.35)));
  }

  @override
  bool shouldRepaint(_BgPainter o) => true;
}

// ═══════════════════════════════════════════════
// SPECTRUM PAINTER
// 48 bars mirrored — bass in center, treble at edges.
// ═══════════════════════════════════════════════

class _SpectrumPainter extends CustomPainter {
  final _Sim sim;
  final double t, play;
  _SpectrumPainter(this.sim, this.t, this.play);

  @override
  void paint(Canvas canvas, Size size) {
    const n = _Sim.n;
    final barW = size.width / n;
    final maxH = size.height;
    final gap = (barW * 0.14).clamp(0.6, 2.5);

    for (var i = 0; i < n; i++) {
      // Mirror: bass at center (index n/2-1), treble at edges
      final half = n ~/ 2;
      final simIdx = i < half ? half - 1 - i : i - half;
      final h = sim.bar(simIdx, t) * maxH * play;
      if (h < 1.5) continue;

      final x = i * barW;
      final rect = Rect.fromLTWH(x + gap, size.height - h, barW - gap * 2, h);

      canvas.drawRect(rect, Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            OmniPlayerColors.cyan.withOpacity(0.5),
            OmniPlayerColors.cyan,
            OmniPlayerColors.violet,
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(rect));

      // Glowing cap at bar tip
      canvas.drawRect(
        Rect.fromLTWH(x + gap, size.height - h - 1, barW - gap * 2, 3),
        Paint()
          ..color = OmniPlayerColors.cyan
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }
  }

  @override
  bool shouldRepaint(_SpectrumPainter o) => true;
}

// ═══════════════════════════════════════════════
// RADIAL WAVE PAINTER
// Two counter-rotating morphing rings.
// ═══════════════════════════════════════════════

class _RadialPainter extends CustomPainter {
  final _Sim sim;
  final double t, play, beat;
  _RadialPainter(this.sim, this.t, this.play, this.beat);

  Path _buildRing(Offset c, double baseR, double waveH, double rotOffset) {
    const pts = _Sim.n;
    final path = Path();
    for (var i = 0; i <= pts; i++) {
      final angle = (i % pts) / pts * pi * 2 + rotOffset - pi / 2;
      final r = baseR + sim.bar(i % pts, t) * waveH * play;
      final p = Offset(c.dx + cos(angle) * r, c.dy + sin(angle) * r);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final baseR = size.shortestSide * 0.21 + beat * 14;
    final waveH = size.shortestSide * 0.13;

    // Outer ring
    final outer = _buildRing(c, baseR, waveH, 0);

    // Glow fill
    canvas.drawPath(outer, Paint()
      ..shader = RadialGradient(colors: [
        OmniPlayerColors.cyan.withOpacity(0.15 + beat * 0.18),
        OmniPlayerColors.violet.withOpacity(0.05 + beat * 0.05),
        Colors.transparent,
      ], stops: const [0.0, 0.55, 1.0])
          .createShader(Rect.fromCircle(center: c, radius: baseR + waveH * 2)));

    // Neon stroke with blur
    canvas.drawPath(outer, Paint()
      ..color = OmniPlayerColors.cyan.withOpacity(0.6 + beat * 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));

    // Sharp inner stroke (white core)
    canvas.drawPath(outer, Paint()
      ..color = Colors.white.withOpacity(0.22 + beat * 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7);

    // Inner counter-rotating violet ring
    if (play > 0.05) {
      final inner = _buildRing(c, baseR * 0.64, waveH * 0.5, t * 0.42);
      canvas.drawPath(inner, Paint()
        ..color = OmniPlayerColors.violet.withOpacity(0.45 + beat * 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    }

    // Static ambient ring (visible when paused)
    canvas.drawCircle(c, baseR * 0.34, Paint()
      ..color = OmniPlayerColors.cyan.withOpacity(0.09 + beat * 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6);
  }

  @override
  bool shouldRepaint(_RadialPainter o) => true;
}

// ═══════════════════════════════════════════════
// PARTICLE PAINTER
// ═══════════════════════════════════════════════

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  _ParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      canvas.drawCircle(p.pos, p.size,
          Paint()
            ..color = p.color.withOpacity(p.alpha * 0.8)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.size));
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter o) => true;
}

// ═══════════════════════════════════════════════
// VISUALIZER SCREEN
// ═══════════════════════════════════════════════

class VisualizerScreen extends ConsumerStatefulWidget {
  const VisualizerScreen({super.key});

  @override
  ConsumerState<VisualizerScreen> createState() => _VisualizerScreenState();
}

class _VisualizerScreenState extends ConsumerState<VisualizerScreen>
    with SingleTickerProviderStateMixin {
  final _sim = _Sim();
  final _particles = <_Particle>[];
  final _rng = Random();

  late final Ticker _ticker;
  Duration? _prev;
  double _t = 0;
  double _play = 0;
  double _beat = 0;
  double _lastBeat = 0;
  bool _ccVisible = true;

  static const _colors = [
    OmniPlayerColors.cyan,
    OmniPlayerColors.violet,
    OmniPlayerColors.activeGreen,
    Colors.white,
  ];

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _ticker.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    final rawDt = _prev == null
        ? 0.016
        : (elapsed - _prev!).inMicroseconds / 1e6;
    _prev = elapsed;
    final dt = rawDt.clamp(0.0, 0.05);

    final isPlaying = ref.read(playerProvider).isPlaying;
    _play = isPlaying
        ? min(1.0, _play + dt * 3.0)
        : max(0.0, _play - dt * 1.5);

    _t += dt;

    // Beat: ~130 BPM with slight organic variation
    final beatInterval = 0.44 + sin(_t * 0.17) * 0.05;
    if (_play > 0.1 && _t - _lastBeat >= beatInterval) {
      _beat = 1.0;
      _lastBeat = _t;
      _burst();
    }
    _beat *= exp(-5.5 * dt);

    // Particle lifecycle
    _particles.removeWhere((p) => !p.step(dt));
    if (_play > 0.1 && _particles.length < 80 && _rng.nextDouble() < dt * 18) {
      _spawnOne();
    }

    setState(() {});
  }

  void _spawnOne({double speed = 1.0}) {
    final sz = MediaQuery.of(context).size;
    _particles.add(_Particle(
      pos: Offset(
        sz.width * (0.05 + _rng.nextDouble() * 0.9),
        sz.height * 0.7 + _rng.nextDouble() * sz.height * 0.25,
      ),
      vel: Offset(
        (_rng.nextDouble() - 0.5) * 70 * speed,
        -(35 + _rng.nextDouble() * 130) * speed,
      ),
      life: 1.5 + _rng.nextDouble() * 2.5,
      size: 0.8 + _rng.nextDouble() * 2.5 * speed,
      color: _colors[_rng.nextInt(_colors.length)],
    ));
  }

  void _burst() {
    final count = 5 + _rng.nextInt(7);
    for (var i = 0; i < count; i++) _spawnOne(speed: 1.8);
  }

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerProvider);
    final track  = player.currentTrack;
    final rms    = _sim.rms(_t) * _play;
    final sz     = MediaQuery.of(context).size;
    final top    = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: OmniPlayerColors.voidBlack,
      body: Stack(children: [

        // ── Background bloom ──────────────────────
        Positioned.fill(child: RepaintBoundary(
          child: CustomPaint(painter: _BgPainter(rms, _beat)),
        )),

        // ── Particles ─────────────────────────────
        Positioned.fill(child: RepaintBoundary(
          child: CustomPaint(painter: _ParticlePainter(List.from(_particles))),
        )),

        // ── Radial morphing rings (upper 65%) ─────
        Positioned(
          left: 0, right: 0, top: 0,
          height: sz.height * 0.65,
          child: RepaintBoundary(
            child: CustomPaint(painter: _RadialPainter(_sim, _t, _play, _beat)),
          ),
        ),

        // ── Track info ────────────────────────────
        if (track != null)
          Positioned(
            left: 24, right: 24,
            top: sz.height * 0.56,
            child: Column(children: [
              Text(
                track.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: OmniPlayerTextStyles.orbitronLabel.copyWith(
                  fontSize: 13,
                  letterSpacing: 3,
                  color: Colors.white.withOpacity(0.88),
                  shadows: [
                    Shadow(
                      color: OmniPlayerColors.cyan.withOpacity(0.6),
                      blurRadius: 14,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 5),
              Text(
                track.artist,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: OmniPlayerTextStyles.rajdhaniBody.copyWith(
                  fontSize: 13,
                  color: OmniPlayerColors.cyan.withOpacity(0.6),
                ),
              ),
            ]),
          ),

        // ── Spectrum bars (bottom 30%) ────────────
        Positioned(
          left: 0, right: 0, bottom: 0,
          height: sz.height * 0.30,
          child: RepaintBoundary(
            child: CustomPaint(painter: _SpectrumPainter(_sim, _t, _play)),
          ),
        ),

        // ── CC lyrics strip ───────────────────────
        if (track != null &&
            (track.lyrics?.isNotEmpty ?? false) &&
            _ccVisible)
          Positioned(
            left: 0,
            right: 0,
            bottom: sz.height * 0.30,
            child: _CcStrip(lyrics: track.lyrics!),
          ),

        // ── Close button ──────────────────────────
        Positioned(
          top: top + 14,
          right: 16,
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: OmniPlayerColors.cyan.withOpacity(0.07),
                border: Border.all(
                  color: OmniPlayerColors.cyan.withOpacity(0.25),
                ),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Icon(
                Icons.close,
                color: OmniPlayerColors.cyan.withOpacity(0.55),
                size: 15,
              ),
            ),
          ),
        ),

        // ── CC toggle button ──────────────────────
        if (track != null && (track.lyrics?.isNotEmpty ?? false))
          Positioned(
            top: top + 14,
            right: 58,
            child: GestureDetector(
              onTap: () => setState(() => _ccVisible = !_ccVisible),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: _ccVisible
                      ? OmniPlayerColors.cyan.withOpacity(0.18)
                      : OmniPlayerColors.cyan.withOpacity(0.05),
                  border: Border.all(
                    color: OmniPlayerColors.cyan.withOpacity(
                        _ccVisible ? 0.55 : 0.22),
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  'CC',
                  style: OmniPlayerTextStyles.orbitronMono.copyWith(
                    fontSize: 9,
                    letterSpacing: 1,
                    color: OmniPlayerColors.cyan.withOpacity(
                        _ccVisible ? 0.95 : 0.40),
                  ),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════
// CC STRIP
// Scrollable lyrics overlay above the spectrum.
// ═══════════════════════════════════════════════

class _CcStrip extends StatefulWidget {
  final String lyrics;
  const _CcStrip({required this.lyrics});

  @override
  State<_CcStrip> createState() => _CcStripState();
}

class _CcStripState extends State<_CcStrip> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 130,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withOpacity(0.72),
            Colors.black.withOpacity(0.82),
          ],
          stops: const [0.0, 0.3, 1.0],
        ),
        border: Border(
          top: BorderSide(
            color: OmniPlayerColors.cyan.withOpacity(0.12),
          ),
        ),
      ),
      child: Scrollbar(
        controller: _scroll,
        thumbVisibility: false,
        child: SingleChildScrollView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
          child: Text(
            widget.lyrics,
            textAlign: TextAlign.center,
            style: OmniPlayerTextStyles.rajdhaniBody.copyWith(
              fontSize: 14,
              height: 1.65,
              color: Colors.white.withOpacity(0.82),
              shadows: [
                Shadow(
                  color: OmniPlayerColors.cyan.withOpacity(0.4),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
