// ═══════════════════════════════════════════════
// lib/features/player/widgets/waveform_bar.dart
// Animated waveform visualizer bars
// ═══════════════════════════════════════════════

import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class WaveformBar extends StatefulWidget {
  final bool isPlaying;
  final int barCount;
  final double height;
  final Color color;

  const WaveformBar({
    super.key,
    required this.isPlaying,
    this.barCount = 40,
    this.height = 48,
    this.color = OmniXColors.cyan,
  });

  @override
  State<WaveformBar> createState() => _WaveformBarState();
}

class _WaveformBarState extends State<WaveformBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    if (widget.isPlaying) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(WaveformBar old) {
    super.didUpdateWidget(old);
    if (widget.isPlaying && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isPlaying && _controller.isAnimating) {
      _controller.stop();
      _controller.animateTo(0.3, duration: const Duration(milliseconds: 300));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return SizedBox(
          height: widget.height,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(widget.barCount, (i) {
              final baseH = 6.0 + sin(i * 0.6) * 10 + cos(i * 0.3) * 6;
              final animH = widget.isPlaying
                  ? baseH * (0.4 + _controller.value * sin(i * 0.9 + _controller.value * pi) * 0.6 + 0.6)
                  : baseH * 0.25;
              final clampedH = animH.clamp(3.0, widget.height * 0.9);

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Container(
                  width: 3,
                  height: clampedH,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: widget.color.withOpacity(0.5 + (i % 3) * 0.15),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
