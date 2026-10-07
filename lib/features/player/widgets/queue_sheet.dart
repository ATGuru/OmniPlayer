import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../providers/providers.dart';

Future<void> showQueueSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: OmniPlayerColors.deepVoid,
    isScrollControlled: true,
    builder: (_) => const _QueueSheet(),
  );
}

class _QueueSheet extends ConsumerWidget {
  const _QueueSheet();

  String _fmt(int ms) {
    if (ms <= 0) return '';
    final d = Duration(milliseconds: ms);
    return '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final notifier = ref.read(playerProvider.notifier);
    final queue = player.queue;
    final height = MediaQuery.of(context).size.height * 0.62;

    return SafeArea(
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36, height: 3,
              decoration: BoxDecoration(
                color: OmniPlayerColors.cyan.withOpacity(0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(
                children: [
                  Text('QUEUE', style: OmniPlayerTextStyles.orbitronLabel.copyWith(fontSize: 12, letterSpacing: 3)),
                  const Spacer(),
                  Text(
                    '${queue.length}  ${player.shuffle ? 'SHUFFLE' : 'IN ORDER'}',
                    style: OmniPlayerTextStyles.orbitronMono.copyWith(
                      fontSize: 8,
                      color: OmniPlayerColors.violet.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: OmniPlayerColors.cyan.withOpacity(0.08)),
            Expanded(
              child: queue.isEmpty
                  ? Center(
                      child: Text(
                        'Nothing queued',
                        style: OmniPlayerTextStyles.rajdhaniBody.copyWith(color: OmniPlayerColors.textMuted),
                      ),
                    )
                  : ListView.builder(
                      itemCount: queue.length,
                      itemBuilder: (context, i) {
                        final track = queue[i];
                        final active = i == player.currentIndex;
                        return ListTile(
                          dense: true,
                          onTap: () => notifier.playQueueIndex(i),
                          leading: Text(
                            active && player.isPlaying ? '▶' : '${i + 1}'.padLeft(2, '0'),
                            style: OmniPlayerTextStyles.orbitronMono.copyWith(
                              fontSize: 9,
                              color: active ? OmniPlayerColors.cyan : Colors.white.withOpacity(0.3),
                            ),
                          ),
                          title: Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: OmniPlayerTextStyles.rajdhaniBody.copyWith(
                              color: active ? Colors.white : Colors.white.withOpacity(0.7),
                            ),
                          ),
                          subtitle: Text(
                            track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: OmniPlayerTextStyles.rajdhaniBody.copyWith(
                              fontSize: 12,
                              color: OmniPlayerColors.cyan.withOpacity(0.45),
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _fmt(track.duration),
                                style: OmniPlayerTextStyles.orbitronMono.copyWith(
                                  fontSize: 8,
                                  color: OmniPlayerColors.cyan.withOpacity(0.35),
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.close, size: 16, color: OmniPlayerColors.magenta.withOpacity(0.6)),
                                onPressed: () => notifier.removeFromQueue(i),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
