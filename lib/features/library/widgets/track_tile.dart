// ═══════════════════════════════════════════════
// lib/features/library/widgets/track_tile.dart
// Single track row in library list
// ═══════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../../../providers/providers.dart';
import 'track_actions.dart';

class TrackTile extends ConsumerWidget {
  final Track track;
  final int index;
  final List<Track> allTracks;
  final VoidCallback? onSelected;

  const TrackTile({
    super.key,
    required this.track,
    required this.index,
    required this.allTracks,
    this.onSelected,
  });

  String _fmtDuration(int ms) {
    if (ms <= 0) return '—';
    final d = Duration(milliseconds: ms);
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player  = ref.watch(playerProvider);
    final notifier = ref.read(playerProvider.notifier);
    final isActive = player.currentTrack?.id == track.id;

    return GestureDetector(
      onTap: () {
        notifier.playTrack(track, allTracks);
        onSelected?.call();
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: isActive ? OmniPlayerColors.cyan.withOpacity(0.08) : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isActive ? OmniPlayerColors.cyan : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          children: [
            // Index / playing indicator
            SizedBox(
              width: 28,
              child: Text(
                isActive && player.isPlaying ? '▶' : '${index + 1}'.padLeft(2, '0'),
                textAlign: TextAlign.center,
                style: OmniPlayerTextStyles.orbitronMono.copyWith(
                  color: isActive ? OmniPlayerColors.cyan : Colors.white.withOpacity(0.2),
                  fontSize: isActive ? 10 : 9,
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Track info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: OmniPlayerTextStyles.rajdhaniSemi.copyWith(
                      color: isActive ? Colors.white : Colors.white.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: OmniPlayerTextStyles.rajdhaniBody.copyWith(
                      color: OmniPlayerColors.cyan.withOpacity(0.4),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            // Duration
            Text(
              _fmtDuration(track.duration),
              style: OmniPlayerTextStyles.orbitronMono.copyWith(
                color: OmniPlayerColors.cyan.withOpacity(0.3),
                fontSize: 9,
              ),
            ),

            const SizedBox(width: 8),

            GestureDetector(
              onTap: () => showTrackActions(context, ref, track),
              child: Icon(Icons.more_vert, size: 16, color: OmniPlayerColors.cyan.withOpacity(0.45)),
            ),
            const SizedBox(width: 6),

            // Favorite
            GestureDetector(
              onTap: () => ref.read(databaseProvider).toggleFavorite(track.id),
              child: Icon(
                track.isFavorite ? Icons.favorite : Icons.favorite_border,
                size: 16,
                color: track.isFavorite ? OmniPlayerColors.magenta : Colors.white.withOpacity(0.15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
