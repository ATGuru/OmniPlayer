// ═══════════════════════════════════════════════
// lib/features/player/widgets/holo_panel.dart
// Reusable holographic glass panel
// ═══════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class HoloPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color glowColor;
  final double borderRadius;

  const HoloPanel({
    super.key,
    required this.child,
    this.padding,
    this.glowColor = OmniXColors.cyan,
    this.borderRadius = 14,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            OmniXColors.cyan.withOpacity(0.04),
            OmniXColors.violet.withOpacity(0.06),
            OmniXColors.magenta.withOpacity(0.04),
          ],
        ),
        border: Border.all(color: OmniXColors.cyan.withOpacity(0.18), width: 1),
        boxShadow: [
          BoxShadow(color: glowColor.withOpacity(0.08), blurRadius: 24, spreadRadius: 0),
          BoxShadow(color: glowColor.withOpacity(0.04), blurRadius: 1, spreadRadius: 0),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Stack(
          children: [
            // Scanline overlay
            Positioned.fill(
              child: CustomPaint(painter: _ScanlinePainter()),
            ),
            // Content
            Padding(
              padding: padding ?? const EdgeInsets.all(20),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = OmniXColors.cyan.withOpacity(0.015)
      ..strokeWidth = 1;

    for (double y = 0; y < size.height; y += 4) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_ScanlinePainter old) => false;
}
