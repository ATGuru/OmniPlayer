// ═══════════════════════════════════════════════
// lib/features/player/widgets/spectrum_ring.dart
// Rotating vinyl ring + animated spectrum bars
// ═══════════════════════════════════════════════

import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class SpectrumRing extends StatefulWidget {
  final bool isPlaying;
  final double size;

  const SpectrumRing({super.key, required this.isPlaying, this.size = 200});

  @override
  State<SpectrumRing> createState() => _SpectrumRingState();
}

class _SpectrumRingState extends State<SpectrumRing>
    with TickerProviderStateMixin {
  late AnimationController _spinController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

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

    if (widget.isPlaying) _spinController.repeat();
  }

  @override
  void didUpdateWidget(SpectrumRing old) {
    super.didUpdateWidget(old);
    if (widget.isPlaying && !_spinController.isAnimating) {
      _spinController.repeat();
    } else if (!widget.isPlaying && _spinController.isAnimating) {
      _spinController.stop();
    }
  }

  @override
  void dispose() {
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
          // Spectrum bars ring
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) => CustomPaint(
              size: Size(widget.size, widget.size),
              painter: _SpectrumPainter(
                isPlaying: widget.isPlaying,
                pulse: _pulseAnim.value,
              ),
            ),
          ),

          // Spinning vinyl disc
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
              color: OmniXColors.cyan,
              boxShadow: [
                BoxShadow(color: OmniXColors.cyan.withOpacity(0.8), blurRadius: 12),
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
            OmniXColors.violet,
            OmniXColors.cyan,
            OmniXColors.magenta,
            OmniXColors.violet,
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
            const Text('⟁', style: TextStyle(fontSize: 28, color: OmniXColors.cyan)),
            const SizedBox(height: 2),
            Text(
              'ATGURU',
              style: OmniXTextStyles.orbitronMono.copyWith(
                fontSize: 7,
                color: OmniXColors.cyan.withOpacity(0.6),
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpectrumPainter extends CustomPainter {
  final bool isPlaying;
  final double pulse;
  static const int segments = 48;
  final List<double> _heights;

  _SpectrumPainter({required this.isPlaying, required this.pulse})
      : _heights = List.generate(segments, (i) =>
          6 + sin(i * 0.8) * 8 * (isPlaying ? 1.0 : 0.3));

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2 - 10;

    final paint = Paint()
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < segments; i++) {
      final angle = (i / segments) * 2 * pi - pi / 2;
      final barLen = isPlaying
          ? _heights[i] * (0.5 + pulse * 0.5)
          : 4.0;

      final x1 = cx + cos(angle) * (r - 2);
      final y1 = cy + sin(angle) * (r - 2);
      final x2 = cx + cos(angle) * (r - 2 + barLen);
      final y2 = cy + sin(angle) * (r - 2 + barLen);

      final hue = (i / segments) * 120 + 180; // cyan → magenta sweep
      paint.color = HSVColor.fromAHSV(1.0, hue, 1.0, 0.65 + pulse * 0.35).toColor();

      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
    }
  }

  @override
  bool shouldRepaint(_SpectrumPainter old) =>
      old.pulse != pulse || old.isPlaying != isPlaying;
}
