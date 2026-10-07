import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class SpectrumRing extends StatefulWidget {
  final bool isPlaying;
  final double size;
  final Stream<Float32List>? fftStream;

  const SpectrumRing({
    super.key,
    required this.isPlaying,
    this.size = 200,
    this.fftStream,
  });

  @override
  State<SpectrumRing> createState() => _SpectrumRingState();
}

class _SpectrumRingState extends State<SpectrumRing>
    with TickerProviderStateMixin {
  late AnimationController _spinController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  StreamSubscription<Float32List>? _sub;
  Float32List? _fft;

  @override
  void initState() {
    super.initState();

    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _applyStream();
    _applySpinState();
  }

  @override
  void didUpdateWidget(SpectrumRing old) {
    super.didUpdateWidget(old);
    if (old.fftStream != widget.fftStream) _applyStream();
    if (old.isPlaying != widget.isPlaying) _applySpinState();
  }

  void _applyStream() {
    _sub?.cancel();
    _sub = null;
    _fft = null;
    if (widget.fftStream != null) {
      _sub = widget.fftStream!.listen((data) {
        if (mounted) setState(() => _fft = data);
      });
    }
  }

  void _applySpinState() {
    if (widget.isPlaying && !_spinController.isAnimating) {
      _spinController.repeat();
    } else if (!widget.isPlaying && _spinController.isAnimating) {
      _spinController.stop();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _spinController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Spectrum bars ring — FFT-driven or pulse-animated fallback
          if (_fft != null)
            CustomPaint(
              size: Size(widget.size, widget.size),
              painter: _SpectrumPainter.fft(fft: _fft!),
            )
          else
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _SpectrumPainter.pulse(
                  isPlaying: widget.isPlaying,
                  pulse: _pulseAnim.value,
                ),
              ),
            ),

          // Spinning vinyl disc — always uses animation
          AnimatedBuilder(
            animation: _spinController,
            builder: (_, child) => Transform.rotate(
              angle: _spinController.value * 2 * pi,
              child: child,
            ),
            child: _buildVinylDisc(),
          ),

          // Center dot
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: OmniPlayerColors.cyan,
              boxShadow: [
                BoxShadow(
                  color: OmniPlayerColors.cyan.withOpacity(0.8),
                  blurRadius: 12,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVinylDisc() {
    final inner = widget.size * 0.55;
    return Container(
      width: inner,
      height: inner,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const SweepGradient(
          colors: [
            OmniPlayerColors.violet,
            OmniPlayerColors.cyan,
            OmniPlayerColors.magenta,
            OmniPlayerColors.violet,
          ],
        ),
      ),
      padding: const EdgeInsets.all(3),
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [Color(0xFF0A0F1E), Color(0xFF050A12)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '⟁',
              style: TextStyle(fontSize: 28, color: OmniPlayerColors.cyan),
            ),
            const SizedBox(height: 2),
            Text(
              'ATGURU',
              style: OmniPlayerTextStyles.orbitronMono.copyWith(
                fontSize: 7,
                color: OmniPlayerColors.cyan.withOpacity(0.6),
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Spectrum painter ────────────────────────────────────────────────────────────

class _SpectrumPainter extends CustomPainter {
  final Float32List? fft;
  final bool isPlaying;
  final double pulse;

  static const int _segments = 48;
  // Spread 48 segments across the first 100 FFT bins (musically relevant range)
  static const int _fftRange = 100;

  // FFT-driven constructor
  const _SpectrumPainter.fft({required Float32List this.fft})
      : isPlaying = true,
        pulse = 1.0;

  // Pulse-animation fallback constructor
  const _SpectrumPainter.pulse({required this.isPlaying, required this.pulse})
      : fft = null;

  double _barLength(int i) {
    if (fft != null) {
      final bin = (i / _segments * _fftRange).toInt().clamp(0, fft!.length - 1);
      final amp = (fft![bin] * 4.0).clamp(0.0, 1.0);
      return 4.0 + amp * 24.0;
    }
    final base = 6 + sin(i * 0.8) * 8 * (isPlaying ? 1.0 : 0.3);
    return isPlaying ? base * (0.5 + pulse * 0.5) : 4.0;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2 - 10;

    final paint = Paint()
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < _segments; i++) {
      final angle = (i / _segments) * 2 * pi - pi / 2;
      final barLen = _barLength(i);

      final x1 = cx + cos(angle) * (r - 2);
      final y1 = cy + sin(angle) * (r - 2);
      final x2 = cx + cos(angle) * (r - 2 + barLen);
      final y2 = cy + sin(angle) * (r - 2 + barLen);

      final hue = (i / _segments) * 120 + 180; // cyan → magenta sweep
      final brightness = fft != null ? 0.75 : 0.65 + pulse * 0.35;
      paint.color = HSVColor.fromAHSV(1.0, hue, 1.0, brightness).toColor();

      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
    }
  }

  @override
  bool shouldRepaint(_SpectrumPainter old) =>
      old.fft != fft || old.pulse != pulse || old.isPlaying != isPlaying;
}
