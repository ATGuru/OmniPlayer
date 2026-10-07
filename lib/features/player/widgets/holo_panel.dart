// ═══════════════════════════════════════════════
// lib/features/player/widgets/holo_panel.dart
// Holographic glass panel with scanline overlay
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
    this.glowColor = OmniPlayerColors.cyan,
    this.borderRadius = 14,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: glowColor.withOpacity(0.25), width: 1),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            OmniPlayerColors.cyan.withOpacity(0.04),
            OmniPlayerColors.violet.withOpacity(0.06),
            OmniPlayerColors.magenta.withOpacity(0.04),
          ],
        ),
        boxShadow: [
          BoxShadow(color: glowColor.withOpacity(0.08), blurRadius: 24),
          BoxShadow(color: glowColor.withOpacity(0.04), blurRadius: 1),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _ScanlinePainter())),
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

// ═══════════════════════════════════════════════
// SCANLINE PAINTER
// ═══════════════════════════════════════════════

class _ScanlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = OmniPlayerColors.cyan.withOpacity(0.015)
      ..strokeWidth = 1;
    for (double y = 0; y < size.height; y += 4) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_ScanlinePainter old) => false;
}
