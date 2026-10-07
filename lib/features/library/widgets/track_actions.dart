import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/providers.dart';
import '../../../services/library_organizer.dart';

final albumRevisionProvider = StateProvider<int>((ref) => 0);

Future<String?> askLibraryName(BuildContext context, String title) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: OmniPlayerColors.deepVoid,
      title: Text(title, style: OmniPlayerTextStyles.orbitronLabel.copyWith(fontSize: 12)),
      content: TextField(
        controller: controller,
        autofocus: true,
        style: OmniPlayerTextStyles.rajdhaniBody.copyWith(color: Colors.white),
        decoration: const InputDecoration(hintText: 'Name'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('CANCEL')),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
          child: const Text('SAVE'),
        ),
      ],
    ),
  );
}

Future<void> showTrackActions(BuildContext context, WidgetRef ref, Track track) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: OmniPlayerColors.deepVoid,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              track.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: OmniPlayerTextStyles.orbitronLabel.copyWith(fontSize: 11, letterSpacing: 1),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.playlist_add, color: OmniPlayerColors.cyan),
            title: Text('Add to playlist', style: OmniPlayerTextStyles.rajdhaniBody.copyWith(color: Colors.white)),
            onTap: () async {
              Navigator.of(sheetContext).pop();
              await showAddToPlaylist(context, ref.read(databaseProvider), track);
            },
          ),
          ListTile(
            leading: const Icon(Icons.folder_outlined, color: OmniPlayerColors.cyan),
            title: Text('Move to album', style: OmniPlayerTextStyles.rajdhaniBody.copyWith(color: Colors.white)),
            onTap: () async {
              Navigator.of(sheetContext).pop();
              await showMoveTracksToAlbum(context, ref, [track]);
            },
          ),
          ListTile(
            leading: Icon(Icons.delete_outline, color: OmniPlayerColors.magenta.withOpacity(0.9)),
            title: Text('Delete', style: OmniPlayerTextStyles.rajdhaniBody.copyWith(color: Colors.white)),
            onTap: () async {
              Navigator.of(sheetContext).pop();
              await deleteTracks(context, ref, [track]);
            },
          ),
        ],
      ),
    ),
  );
}

Future<void> showAddToPlaylist(BuildContext context, AppDatabase db, Track track) async {
  final playlists = await db.getAllPlaylists();
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: OmniPlayerColors.deepVoid,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('ADD TO PLAYLIST', style: OmniPlayerTextStyles.orbitronLabel.copyWith(fontSize: 11, letterSpacing: 2)),
            ),
            for (final playlist in playlists)
              ListTile(
                title: Text(playlist.name, style: OmniPlayerTextStyles.rajdhaniBody.copyWith(color: Colors.white)),
                onTap: () async {
                  final position = await db.nextPlaylistPosition(playlist.id);
                  await db.addTrackToPlaylist(playlist.id, track.id, position);
                  if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                },
              ),
            ListTile(
              leading: const Icon(Icons.add, color: OmniPlayerColors.cyan),
              title: Text('New playlist', style: OmniPlayerTextStyles.rajdhaniSemi.copyWith(color: OmniPlayerColors.cyan)),
              onTap: () async {
                final name = await askLibraryName(sheetContext, 'NEW PLAYLIST');
                if (name == null || name.isEmpty) return;
                final id = await db.createPlaylist(name);
                await db.addTrackToPlaylist(id, track.id, 0);
                if (sheetContext.mounted) Navigator.of(sheetContext).pop();
              },
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> showMoveTracksToAlbum(BuildContext context, WidgetRef ref, List<Track> tracks) async {
  if (tracks.isEmpty || !context.mounted) return;
  final db = ref.read(databaseProvider);
  final names = collectAlbumNames(
    await db.rememberedAlbums(),
    (await db.getAllTracks()).map((track) => track.album),
  );
  if (!context.mounted) return;
  final chosen = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: OmniPlayerColors.deepVoid,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('MOVE TO ALBUM', style: OmniPlayerTextStyles.orbitronLabel.copyWith(fontSize: 11, letterSpacing: 2)),
            ),
            for (final name in names)
              ListTile(
                title: Text(name, style: OmniPlayerTextStyles.rajdhaniBody.copyWith(color: Colors.white)),
                onTap: () => Navigator.of(sheetContext).pop(name),
              ),
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined, color: OmniPlayerColors.cyan),
              title: Text('New album', style: OmniPlayerTextStyles.rajdhaniSemi.copyWith(color: OmniPlayerColors.cyan)),
              onTap: () async {
                final name = await askLibraryName(sheetContext, 'NEW ALBUM');
                if (name == null || name.isEmpty || !sheetContext.mounted) return;
                Navigator.of(sheetContext).pop(name);
              },
            ),
          ],
        ),
      ),
    ),
  );
  if (chosen == null || chosen.isEmpty || !context.mounted) return;
  await _moveAll(context, ref, tracks, chosen);
}

Future<void> deleteTracks(BuildContext context, WidgetRef ref, List<Track> tracks) async {
  if (tracks.isEmpty || !context.mounted) return;
  final organizer = LibraryOrganizer(ref.read(databaseProvider));
  var ownedCount = 0;
  for (final track in tracks) {
    if (await organizer.owns(track.path)) ownedCount++;
  }
  if (!context.mounted) return;
  final message = ownedCount == tracks.length
      ? tracks.length == 1
          ? 'Delete this song and remove the file from this phone?'
          : 'Delete ${tracks.length} songs and remove the files from this phone?'
      : ownedCount == 0
          ? tracks.length == 1
              ? 'Remove this song from the library? The file stays on this device and will not come back on the next scan.'
              : 'Remove ${tracks.length} songs from the library? The files stay on this device and will not come back on the next scan.'
          : 'Remove ${tracks.length} songs from the library? Downloaded files are deleted. Other files stay on this device.';
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: OmniPlayerColors.deepVoid,
      title: Text('DELETE', style: OmniPlayerTextStyles.orbitronLabel.copyWith(fontSize: 12)),
      content: Text(message, style: OmniPlayerTextStyles.rajdhaniBody.copyWith(color: Colors.white)),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('CANCEL')),
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('DELETE')),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  final notifier = ref.read(playerProvider.notifier);
  try {
    for (final track in tracks) {
      await notifier.dropTrack(track.id);
      await organizer.deleteTrack(track);
    }
    ref.read(albumRevisionProvider.notifier).state++;
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Removed from the library.')),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not delete: $e')));
  }
}

Future<void> _moveAll(BuildContext context, WidgetRef ref, List<Track> tracks, String album) async {
  final organizer = LibraryOrganizer(ref.read(databaseProvider));
  final notifier = ref.read(playerProvider.notifier);
  try {
    for (final track in tracks) {
      await notifier.releaseFile(track.id);
      final updated = await organizer.moveToAlbum(track, album);
      await notifier.replaceTrack(updated);
    }
    ref.read(albumRevisionProvider.notifier).state++;
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Moved to $album.')));
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not move: $e')));
  }
}
