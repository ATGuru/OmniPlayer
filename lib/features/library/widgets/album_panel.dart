import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/providers.dart';
import '../../../services/library_organizer.dart';
import 'track_actions.dart';

final albumNamesProvider = FutureProvider<List<String>>((ref) async {
  ref.watch(albumRevisionProvider);
  final db = ref.watch(databaseProvider);
  final tracks = await ref.watch(tracksProvider.future);
  return collectAlbumNames(await db.rememberedAlbums(), tracks.map((track) => track.album));
});

class AlbumPanel extends ConsumerWidget {
  const AlbumPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albums = ref.watch(albumNamesProvider);
    final tracks = ref.watch(tracksProvider);
    final db = ref.watch(databaseProvider);
    return albums.when(
      loading: () => const Center(child: CircularProgressIndicator(color: OmniPlayerColors.cyan)),
      error: (error, _) => Center(
        child: Text('$error', style: OmniPlayerTextStyles.rajdhaniBody.copyWith(color: OmniPlayerColors.errorRed)),
      ),
      data: (names) {
        final songs = tracks.asData?.value ?? const <Track>[];
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: GestureDetector(
                onTap: () => _create(context, ref, db),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: OmniPlayerColors.cyan.withOpacity(0.25)),
                  ),
                  child: Text('NEW ALBUM', style: OmniPlayerTextStyles.orbitronLabel.copyWith(fontSize: 10, letterSpacing: 2)),
                ),
              ),
            ),
            Expanded(
              child: names.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No albums yet. Create one, then move songs into it from a song menu.',
                          textAlign: TextAlign.center,
                          style: OmniPlayerTextStyles.rajdhaniBody.copyWith(color: OmniPlayerColors.textMuted),
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: names.length,
                      itemBuilder: (context, index) {
                        final name = names[index];
                        final count = songs.where((track) => track.album.toLowerCase() == name.toLowerCase()).length;
                        return ListTile(
                          title: Text(name, style: OmniPlayerTextStyles.rajdhaniSemi.copyWith(color: Colors.white.withOpacity(0.85))),
                          subtitle: Text(
                            count == 1 ? '1 song' : '$count songs',
                            style: OmniPlayerTextStyles.rajdhaniBody.copyWith(fontSize: 12, color: OmniPlayerColors.textMuted),
                          ),
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => AlbumDetailScreen(albumName: name),
                          )),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref, AppDatabase db) async {
    final name = await askLibraryName(context, 'NEW ALBUM');
    if (name == null || name.isEmpty) return;
    await db.rememberAlbum(name);
    ref.read(albumRevisionProvider.notifier).state++;
  }
}

class AlbumDetailScreen extends ConsumerWidget {
  final String albumName;
  const AlbumDetailScreen({super.key, required this.albumName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = ref.watch(tracksProvider);
    final db = ref.watch(databaseProvider);
    final notifier = ref.read(playerProvider.notifier);
    return Scaffold(
      backgroundColor: OmniPlayerColors.voidBlack,
      appBar: AppBar(
        backgroundColor: OmniPlayerColors.voidBlack,
        foregroundColor: OmniPlayerColors.cyan,
        title: Text(albumName, style: OmniPlayerTextStyles.orbitronLabel.copyWith(fontSize: 13)),
        actions: [
          IconButton(
            tooltip: 'Delete album',
            onPressed: () => _deleteAlbum(context, ref, db),
            icon: Icon(Icons.delete_outline, color: OmniPlayerColors.magenta.withOpacity(0.8)),
          ),
        ],
      ),
      body: tracks.when(
        loading: () => const Center(child: CircularProgressIndicator(color: OmniPlayerColors.cyan)),
        error: (error, _) => Center(child: Text('$error')),
        data: (all) {
          final items = all.where((track) => track.album.toLowerCase() == albumName.toLowerCase()).toList();
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'This album is empty. Open a song menu and choose Move to album.',
                  textAlign: TextAlign.center,
                  style: OmniPlayerTextStyles.rajdhaniBody.copyWith(color: OmniPlayerColors.textMuted),
                ),
              ),
            );
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final track = items[index];
              return ListTile(
                onTap: () => notifier.playTrack(track, items),
                title: Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: OmniPlayerTextStyles.rajdhaniBody.copyWith(color: Colors.white.withOpacity(0.85)),
                ),
                subtitle: Text(
                  track.artist,
                  style: OmniPlayerTextStyles.rajdhaniBody.copyWith(fontSize: 12, color: OmniPlayerColors.cyan.withOpacity(0.45)),
                ),
                trailing: IconButton(
                  tooltip: 'Song menu',
                  icon: Icon(Icons.more_vert, size: 18, color: OmniPlayerColors.cyan.withOpacity(0.7)),
                  onPressed: () => showTrackActions(context, ref, track),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _deleteAlbum(BuildContext context, WidgetRef ref, AppDatabase db) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: OmniPlayerColors.deepVoid,
        title: Text('DELETE ALBUM', style: OmniPlayerTextStyles.orbitronLabel.copyWith(fontSize: 12)),
        content: Text(
          'Remove this album? Songs stay in the library. Downloaded files stay where they are.',
          style: OmniPlayerTextStyles.rajdhaniBody.copyWith(color: Colors.white),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('DELETE')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final songs = await db.getAllTracks();
    final ids = [
      for (final track in songs)
        if (track.album.toLowerCase() == albumName.toLowerCase()) track.id,
    ];
    await db.batchUpdateTracks(ids, album: 'Unknown Album');
    await db.forgetAlbum(albumName);
    ref.read(albumRevisionProvider.notifier).state++;
    if (context.mounted) Navigator.of(context).pop();
  }
}
