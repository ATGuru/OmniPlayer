// ═══════════════════════════════════════════════
// lib/features/player/widgets/control_buttons.dart
// Play/pause/skip/shuffle/repeat controls
// ═══════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/providers.dart';

class ControlButtons extends ConsumerWidget {
  const ControlButtons({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final notifier = ref.read(playerProvider.notifier);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Shuffle
        _IconBtn(
          icon: Icons.shuffle,
          active: player.shuffle,
          activeColor: OmniXColors.cyan,
          onTap: () => notifier.toggleShuffle(),
        ),

        const SizedBox(width: 16),

        // Skip previous
        _SkipBtn(
          icon: Icons.skip_previous_rounded,
          onTap: () => notifier.skipPrevious(),
        ),

        const SizedBox(width: 12),

        // Play / Pause
        _PlayPauseBtn(
          isPlaying: player.isPlaying,
          onTap: () => notifier.togglePlayPause(),
        ),

        const SizedBox(width: 12),

        // Skip next
        _SkipBtn(
          icon: Icons.skip_next_rounded,
          onTap: () => notifier.skipNext(),
        ),

        const SizedBox(width: 16),

        // Repeat
        _IconBtn(
          icon: switch (player.repeatMode) {
            AudioServiceRepeatMode.one => Icons.repeat_one,
            _ => Icons.repeat,
          },
          active: player.repeatMode != AudioServiceRepeatMode.none,
          activeColor: OmniXColors.magenta,
          onTap: () => notifier.cycleRepeat(),
        ),
      ],
    );
  }
}

// ── Play/Pause button ──────────────────────────

class _PlayPauseBtn extends StatefulWidget {
  final bool isPlaying;
  final VoidCallback onTap;

  const _PlayPauseBtn({required this.isPlaying, required this.onTap});

  @override
  State<_PlayPauseBtn> createState() => _PlayPauseBtnState();
}

class _PlayPauseBtnState extends State<_PlayPauseBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _onTap() {
    _scaleController.forward().then((_) => _scaleController.reverse());
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (_, child) => Transform.scale(scale: _scaleAnim.value, child: child),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.isPlaying ? OmniXColors.cyan : OmniXColors.violet,
              width: 2,
            ),
            gradient: RadialGradient(
              colors: widget.isPlaying
                  ? [OmniXColors.cyan.withOpacity(0.15), Colors.transparent]
                  : [OmniXColors.violet.withOpacity(0.15), Colors.transparent],
            ),
            boxShadow: [
              BoxShadow(
                color: (widget.isPlaying ? OmniXColors.cyan : OmniXColors.violet)
                    .withOpacity(0.4),
                blurRadius: widget.isPlaying ? 24 : 12,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Icon(
            widget.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: Colors.white,
            size: 32,
          ),
        ),
      ),
    );
  }
}

// ── Skip button ────────────────────────────────

class _SkipBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _SkipBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, color: OmniXColors.cyan.withOpacity(0.75), size: 36),
    );
  }
}

// ── Icon toggle button ─────────────────────────

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  const _IconBtn({
    required this.icon,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(6),
        child: Icon(
          icon,
          size: 20,
          color: active ? activeColor : Colors.white.withOpacity(0.25),
        ),
      ),
    );
  }
}
