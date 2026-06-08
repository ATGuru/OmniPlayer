// ═══════════════════════════════════════════════
// lib/features/library/screens/library_screen.dart
// Track library with scan + playback
// ═══════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../../../providers/providers.dart';
import '../widgets/track_tile.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracksAsync = ref.watch(tracksProvider);
    final scanState   = ref.watch(scanProvider);
    final scanNotifier = ref.read(scanProvider.notifier);

    return Scaffold(
      backgroundColor: OmniXColors.voidBlack,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('LIBRARY', style: OmniXTextStyles.orbitronLabel.copyWith(fontSize: 13, letterSpacing: 4)),
                  tracksAsync.when(
                    data: (tracks) => Text(
                      '${tracks.length} TRACKS',
                      style: OmniXTextStyles.orbitronMono.copyWith(color: OmniXColors.violet.withOpacity(0.5)),
                    ),
                    loading: () => const SizedBox(),
                    error: (_, __) => const SizedBox(),
                  ),
                ],
              ),
            ),

            // ── Scan button ──────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: _ScanButton(
                isScanning: scanState.isScanning,
                scanned: scanState.scanned,
                total: scanState.total,
                onScan: () => scanNotifier.scan(),
              ),
            ),

            // ── Track list ───────────────────────
            Expanded(
              child: tracksAsync.when(
                data: (tracks) {
                  if (tracks.isEmpty) {
                    return _EmptyState(onScan: () => scanNotifier.scan());
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    itemCount: tracks.length,
                    itemBuilder: (ctx, i) => TrackTile(
                      track: tracks[i],
                      index: i,
                      allTracks: tracks,
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(color: OmniXColors.cyan)),
                error: (e, _) => Center(
                  child: Text('Error: $e', style: OmniXTextStyles.rajdhaniBody.copyWith(color: OmniXColors.errorRed)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Scan button ────────────────────────────────

class _ScanButton extends StatelessWidget {
  final bool isScanning;
  final int scanned;
  final int total;
  final VoidCallback onScan;

  const _ScanButton({required this.isScanning, required this.scanned, required this.total, required this.onScan});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isScanning ? null : onScan,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: OmniXColors.cyan.withOpacity(isScanning ? 0.5 : 0.25)),
          color: OmniXColors.cyan.withOpacity(isScanning ? 0.08 : 0.04),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isScanning) ...[
              SizedBox(
                width: 14, height: 14,
                child: CircularProgressIndicator(
                  value: total > 0 ? scanned / total : null,
                  color: OmniXColors.cyan,
                  strokeWidth: 2,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                total > 0 ? 'SCANNING $scanned / $total' : 'SCANNING...',
                style: OmniXTextStyles.orbitronLabel.copyWith(fontSize: 10),
              ),
            ] else ...[
              const Icon(Icons.radar, color: OmniXColors.cyan, size: 16),
              const SizedBox(width: 8),
              Text('SCAN DEVICE', style: OmniXTextStyles.orbitronLabel.copyWith(fontSize: 10)),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Empty state ────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onScan;
  const _EmptyState({required this.onScan});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.library_music_outlined, size: 64, color: OmniXColors.cyan.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text('NO TRACKS', style: OmniXTextStyles.orbitronLabel.copyWith(fontSize: 12, color: OmniXColors.cyan.withOpacity(0.4))),
          const SizedBox(height: 8),
          Text('Tap SCAN DEVICE to find your music', style: OmniXTextStyles.rajdhaniBody.copyWith(color: OmniXColors.textMuted)),
        ],
      ),
    );
  }
}
