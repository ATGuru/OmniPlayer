import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class WaveformBar extends StatefulWidget {
  final bool isPlaying;
  final Stream<Float32List>? fftStream;
  final int barCount;
  final double height;
  final Color color;

  const WaveformBar({
    super.key,
    required this.isPlaying,
    this.fftStream,
    this.barCount = 40,
    this.height = 48,
    this.color = OmniPlayerColors.cyan,
  });

  @override
  State<WaveformBar> createState() => _WaveformBarState();
}

class _WaveformBarState extends State<WaveformBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  StreamSubscription<Float32List>? _sub;
  Float32List? _fft;

  // Map the 40 bars across the first 100 FFT bins (~0–8.6 kHz at 44100 Hz).
  // Bins beyond 100 are mostly high-frequency content with little musical energy.
  static const _fftRange = 100;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _applyStream();
    _applyPlayState();
  }

  @override
  void didUpdateWidget(WaveformBar old) {
    super.didUpdateWidget(old);
    if (old.fftStream != widget.fftStream) _applyStream();
    if (old.isPlaying != widget.isPlaying && _sub == null) _applyPlayState();
  }

  void _applyStream() {
    _sub?.cancel();
    _sub = null;
    _fft = null;
    if (widget.fftStream != null) {
      _controller.stop();
      _controller.value = 0;
      _sub = widget.fftStream!.listen((data) {
        if (mounted) setState(() => _fft = data);
      });
    }
  }

  void _applyPlayState() {
    if (widget.isPlaying && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isPlaying && _controller.isAnimating) {
      _controller.stop();
      _controller.animateTo(0.3, duration: const Duration(milliseconds: 300));
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  double _fftHeight(int i) {
    final fft = _fft!;
    final bin = (i / widget.barCount * _fftRange).toInt().clamp(0, fft.length - 1);
    // Amplify — raw FFT values tend to be small; ×4 fills the widget nicely.
    final amp = (fft[bin] * 4.0).clamp(0.0, 1.0);
    return (amp * widget.height * 0.88 + 3.0).clamp(3.0, widget.height * 0.95);
  }

  double _animHeight(int i) {
    final baseH = 6.0 + sin(i * 0.6) * 10 + cos(i * 0.3) * 6;
    final v = _controller.value;
    return widget.isPlaying
        ? (baseH * (0.4 + v * sin(i * 0.9 + v * pi) * 0.6 + 0.6)).clamp(3.0, widget.height * 0.9)
        : (baseH * 0.25).clamp(3.0, widget.height * 0.9);
  }

  @override
  Widget build(BuildContext context) {
    // FFT path — rebuild driven by stream subscription setState calls
    if (_fft != null) {
      return SizedBox(
        height: widget.height,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(widget.barCount, (i) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Container(
                width: 3,
                height: _fftHeight(i),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: widget.color.withOpacity(0.5 + (i % 3) * 0.15),
                ),
              ),
            );
          }),
        ),
      );
    }

    // Fallback — timer-driven animation (no real FFT data)
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => SizedBox(
        height: widget.height,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(widget.barCount, (i) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Container(
                width: 3,
                height: _animHeight(i),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: widget.color.withOpacity(0.5 + (i % 3) * 0.15),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
