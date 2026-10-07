import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/providers.dart';
import 'track_actions.dart';

final playlistsProvider = StreamProvider<List<Playlist>>((ref) {
  return ref.watch(databaseProvider).watchPlaylists();
});

class PlaylistPanel extends ConsumerWidget {
  const PlaylistPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistsProvider);
    final db = ref.watch(databaseProvider);
    return playlists.when(
      loading: () => const Center(child: CircularProgressIndicator(color: OmniPlayerColors.cyan)),
      error: (e, _) => Center(child: Text('$e', style: OmniPlayerTextStyles.rajdhaniBody.copyWith(color: OmniPlayerColors.errorRed))),
      data: (items) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: GestureDetector(
              onTap: () => _create(context, db),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: OmniPlayerColors.cyan.withOpacity(0.25)),
                ),
                child: Text('NEW PLAYLIST', style: OmniPlayerTextStyles.orbitronLabel.copyWith(fontSize: 10, letterSpacing: 2)),
              ),
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? Center(child: Text('No playlists yet', style: OmniPlayerTextStyles.rajdhaniBody.copyWith(color: OmniPlayerColors.textMuted)))
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final playlist = items[i];
                      return ListTile(
                        title: Text(playlist.name, style: OmniPlayerTextStyles.rajdhaniSemi.copyWith(color: Colors.white.withOpacity(0.85))),
                        trailing: IconButton(
                          icon: Icon(Icons.delete_outline, size: 18, color: OmniPlayerColors.magenta.withOpacity(0.6)),
                          onPressed: () => db.deletePlaylist(playlist.id),
                        ),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => PlaylistDetailScreen(playlist: playlist),
                        )),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _create(BuildContext context, AppDatabase db) async {
    final name = await askLibraryName(context, 'NEW PLAYLIST');
    if (name == null || name.isEmpty) return;
    try {
      await db.createPlaylist(name);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not create playlist: $e')));
      }
    }
  }
}

class PlaylistDetailScreen extends ConsumerWidget {
  final Playlist playlist;
  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final tracks = ref.watch(_playlistTracksProvider(playlist.id));
    final notifier = ref.read(playerProvider.notifier);
    return Scaffold(
      backgroundColor: OmniPlayerColors.voidBlack,
      appBar: AppBar(
        backgroundColor: OmniPlayerColors.voidBlack,
        foregroundColor: OmniPlayerColors.cyan,
        title: Text(playlist.name, style: OmniPlayerTextStyles.orbitronLabel.copyWith(fontSize: 13)),
      ),
      body: tracks.when(
        loading: () => const Center(child: CircularProgressIndicator(color: OmniPlayerColors.cyan)),
        error: (e, _) => Center(child: Text('$e')),
        data: (items) => items.isEmpty
            ? Center(child: Text('This playlist is empty', style: OmniPlayerTextStyles.rajdhaniBody.copyWith(color: OmniPlayerColors.textMuted)))
            : ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final track = items[i];
                  return ListTile(
                    onTap: () {
                      notifier.playTrack(track, items);
                      Navigator.of(context).pop();
                    },
                    title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: OmniPlayerTextStyles.rajdhaniBody.copyWith(color: Colors.white.withOpacity(0.85))),
                    subtitle: Text(track.artist, style: OmniPlayerTextStyles.rajdhaniBody.copyWith(fontSize: 12, color: OmniPlayerColors.cyan.withOpacity(0.45))),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Song menu',
                          icon: Icon(Icons.more_vert, size: 18, color: OmniPlayerColors.cyan.withOpacity(0.7)),
                          onPressed: () => showTrackActions(context, ref, track),
                        ),
                        IconButton(
                          tooltip: 'Remove from playlist',
                          icon: Icon(Icons.close, size: 16, color: OmniPlayerColors.magenta.withOpacity(0.6)),
                          onPressed: () => db.removeTrackFromPlaylist(playlist.id, track.id),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

final _playlistTracksProvider = StreamProvider.family<List<Track>, int>((ref, id) {
  return ref.watch(databaseProvider).watchPlaylistTracks(id);
});
