import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/database/app_database.dart';
import 'free_music/downloader.dart';

/// True when [filePath] is stored inside [rootPath]. A sibling directory
/// such as OmniPlayerExtra does not count.
bool fileIsInside(String rootPath, String filePath) {
  final root = p.normalize(rootPath);
  final file = p.normalize(filePath);
  final prefix = root.endsWith(p.separator) ? root : '$root${p.separator}';
  return file.startsWith(prefix);
}

/// Folder name safe for a filesystem. The album label stored on the song
/// can still contain the name the user typed.
String albumDirectoryName(String name) {
  var cleaned = name.replaceAll(RegExp(r'[\\/:*?"<>|\n\r]'), ' ').trim();
  cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
  if (cleaned.isEmpty || cleaned == '.' || cleaned == '..') return 'Album';
  if (cleaned.length > 80) cleaned = cleaned.substring(0, 80).trim();
  return cleaned.isEmpty ? 'Album' : cleaned;
}

/// Album labels to show. Remembered names stay even when they have no songs.
List<String> collectAlbumNames(Iterable<String> remembered, Iterable<String> trackAlbums) {
  final byKey = <String, String>{};
  void add(String raw) {
    final name = raw.trim();
    if (name.isEmpty) return;
    byKey.putIfAbsent(name.toLowerCase(), () => name);
  }

  for (final name in remembered) {
    add(name);
  }
  for (final name in trackAlbums) {
    add(name);
  }
  final list = byKey.values.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return list;
}

/// Moves downloads between album folders and deletes songs the app saved.
class LibraryOrganizer {
  final AppDatabase db;
  final Directory? rootOverride;

  const LibraryOrganizer(this.db, {this.rootOverride});

  Future<Directory> _root() async => rootOverride ?? await freeMusicRoot();

  Future<bool> owns(String path) async => fileIsInside((await _root()).path, path);

  /// Removes the library row. A file this app saved is deleted. A scanned
  /// file stays on disk and is left out of later scans.
  Future<bool> deleteTrack(Track track) async {
    final owned = await owns(track.path);
    if (owned) {
      final file = File(track.path);
      if (await file.exists()) await file.delete();
      await _pruneEmptyParents(file.parent, await _root());
    } else {
      await db.excludePath(track.path);
    }
    await db.forgetCatalogPath(track.path);
    await db.deleteTrack(track.id);
    return owned;
  }

  /// Puts [track] in [albumName]. Downloads move into that album's folder.
  /// Other files only change the album label.
  Future<Track> moveToAlbum(Track track, String albumName) async {
    final album = albumName.trim();
    if (album.isEmpty) {
      throw const FormatException('Album name is empty');
    }
    await db.rememberAlbum(album);
    final root = await _root();
    if (!fileIsInside(root.path, track.path)) {
      await db.updateTrackMetadata(track.id, album: album);
      return (await db.getTrackById(track.id))!;
    }

    final folder = Directory(p.join(root.path, 'Albums', albumDirectoryName(album)));
    await folder.create(recursive: true);
    final destPath = await _uniqueDestination(folder.path, p.basename(track.path), track.path);
    if (p.normalize(destPath) != p.normalize(track.path)) {
      await _moveFile(File(track.path), File(destPath));
      await _pruneEmptyParents(File(track.path).parent, root);
      await db.retargetCatalogPath(track.path, destPath);
      await _rememberLegacyCatalog(track.path, destPath, root);
    }
    await db.relocateTrack(track.id, path: destPath, album: album);
    return (await db.getTrackById(track.id))!;
  }

  Future<String> _uniqueDestination(String folder, String baseName, String currentPath) async {
    var candidate = p.join(folder, baseName);
    if (await _pathFree(candidate, currentPath)) return candidate;
    final stem = p.basenameWithoutExtension(baseName);
    final ext = p.extension(baseName);
    for (var i = 2; i < 1000; i++) {
      candidate = p.join(folder, '$stem $i$ext');
      if (await _pathFree(candidate, currentPath)) return candidate;
    }
    return p.join(folder, '${DateTime.now().millisecondsSinceEpoch}_$baseName');
  }

  Future<bool> _pathFree(String candidate, String currentPath) async {
    if (p.normalize(candidate) == p.normalize(currentPath)) return true;
    if (await File(candidate).exists()) return false;
    return (await db.getTrackByPath(candidate)) == null;
  }

  /// Downloads saved before catalog keys existed live in OmniPlayer/<id>/<file>.
  Future<void> _rememberLegacyCatalog(String oldPath, String newPath, Directory root) async {
    if (!fileIsInside(root.path, oldPath)) return;
    final relative = p.split(p.relative(oldPath, from: root.path));
    if (relative.length != 2 || relative.first == 'Albums' || relative.first == '.' || relative.first == '..') {
      return;
    }
    await db.rememberCatalogFile('${relative.first}/${relative.last}', newPath);
  }

  Future<void> _moveFile(File source, File dest) async {
    await dest.parent.create(recursive: true);
    try {
      await source.rename(dest.path);
    } catch (_) {
      await source.copy(dest.path);
      if (await source.exists()) await source.delete();
    }
  }

  Future<void> _pruneEmptyParents(Directory start, Directory root) async {
    final rootPath = p.normalize(root.path);
    var current = start;
    while (fileIsInside(rootPath, current.path)) {
      if (!await current.exists()) {
        current = current.parent;
        continue;
      }
      if (!await current.list().isEmpty) return;
      await current.delete();
      current = current.parent;
    }
  }
}
