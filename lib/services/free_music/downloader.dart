import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/audio/metadata_writer.dart';
import '../../core/database/app_database.dart';
import 'archive_client.dart';
import 'catalog.dart';

/// Saves a catalog MP3 into the OmniPlayer library.
class FreeMusicDownloader {
  final FreeMusicCatalog catalog;
  final AppDatabase db;

  const FreeMusicDownloader({required this.catalog, required this.db});

  Future<File> fileFor(CatalogTrack track) async {
    final root = await freeMusicRoot();
    final folder = Directory(p.join(root.path, _safeId(track.identifier)));
    return File(p.join(folder.path, localFileName(track.fileName)));
  }

  Future<bool> isSaved(CatalogTrack track) async {
    if (await _rowReady(await fileFor(track))) return true;
    final mapped = await db.catalogFilePath(catalogFileKey(track.identifier, track.fileName));
    if (mapped == null) return false;
    return _rowReady(File(mapped));
  }

  Future<bool> _rowReady(File file) async {
    if (!await file.exists() || await file.length() < 32000) return false;
    return (await db.getTrackByPath(file.path)) != null;
  }

  /// Download when needed, then store the library row with its license.
  Future<Track> save(
    CatalogTrack track, {
    void Function(int received, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final dest = await fileFor(track);
    final already = await dest.exists() && await dest.length() >= 32000 && await _looksLikeExistingMp3(dest);
    if (!already) {
      await catalog.download(track, dest, onProgress: onProgress, isCancelled: isCancelled);
    }
    if (isCancelled?.call() == true) {
      throw const FreeMusicException('cancelled');
    }
    await MetadataWriter.writeTag(
      dest.path,
      title: track.title,
      artist: track.artist,
      album: track.album,
      genre: track.genre,
      trackNumber: track.trackNumber,
      comment: track.license,
    );
    final size = await dest.length();
    final saved = await db.saveDownloadedTrack(
      path: dest.path,
      title: track.title,
      artist: track.artist,
      album: track.album,
      durationMs: track.durationMs,
      size: size,
      licenseName: track.license,
      trackNumber: track.trackNumber,
      genre: track.genre,
    );
    await db.rememberCatalogFile(catalogFileKey(track.identifier, track.fileName), dest.path);
    return saved;
  }
}

Future<bool> _looksLikeExistingMp3(File file) async {
  try {
    final header = await file.openRead(0, 3).fold<List<int>>(<int>[], (bytes, chunk) {
      bytes.addAll(chunk);
      return bytes;
    });
    if (header.length < 3) return false;
    final id3 = header[0] == 0x49 && header[1] == 0x44 && header[2] == 0x33;
    final frame = header[0] == 0xFF && (header[1] & 0xE0) == 0xE0;
    return id3 || frame;
  } catch (_) {
    return false;
  }
}

Future<Directory> freeMusicRoot() async {
  if (Platform.isAndroid || Platform.isIOS) {
    final docs = await getApplicationDocumentsDirectory();
    return Directory(p.join(docs.path, 'OmniPlayer'));
  }
  if (Platform.isLinux || Platform.isMacOS) {
    final home = Platform.environment['HOME'] ?? '';
    final music = await _xdgMusicDir(home) ?? p.join(home, 'Music');
    return Directory(p.join(music, 'OmniPlayer'));
  }
  if (Platform.isWindows) {
    final profile = Platform.environment['USERPROFILE'] ?? '';
    return Directory(p.join(profile, 'Music', 'OmniPlayer'));
  }
  final docs = await getApplicationDocumentsDirectory();
  return Directory(p.join(docs.path, 'OmniPlayer'));
}

String _safeId(String identifier) {
  final cleaned = identifier.replaceAll(RegExp(r'[^A-Za-z0-9._\-]'), '_');
  return cleaned.isEmpty ? 'release' : cleaned;
}

Future<String?> _xdgMusicDir(String home) async {
  try {
    final file = File('$home/.config/user-dirs.dirs');
    if (!await file.exists()) return null;
    for (final line in await file.readAsLines()) {
      if (!line.startsWith('XDG_MUSIC_DIR=')) continue;
      var value = line.substring('XDG_MUSIC_DIR='.length).trim();
      if (value.startsWith('"') && value.endsWith('"')) {
        value = value.substring(1, value.length - 1);
      }
      return value.replaceFirst(r'$HOME', home);
    }
  } catch (_) {}
  return null;
}
