import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/audio/metadata_writer.dart';
import '../core/database/app_database.dart';
import 'package:drift/drift.dart';

class LibraryScanner {
  final OnAudioQuery _query = OnAudioQuery();
  final AppDatabase _db;

  LibraryScanner(this._db);

  static const _supportedFormats = [
    '.mp3', '.wav', '.flac', '.aac', '.ogg', '.m4a', '.opus', '.wma',
  ];

  static bool _isSupportedFormat(String path) {
    final lower = path.toLowerCase();
    return _supportedFormats.any((ext) => lower.endsWith(ext));
  }

  // Directory NAME segments that cause the entire subtree to be skipped.
  // Hidden directories (name starts with '.') are also skipped unconditionally.
  static const _excludedDirNames = {
    'Downloads', 'snap',
    'proc', 'sys', 'dev', 'run',
    'node_modules', 'vendor', '__pycache__',
  };

  static bool _skipDir(String name) =>
      name.startsWith('.') || _excludedDirNames.contains(name);

  Future<bool> requestPermission() async {
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) return true;
    final status = await Permission.audio.request();
    if (status.isGranted) return true;
    return (await Permission.storage.request()).isGranted;
  }

  Future<ScanResult> scanLibrary({
    void Function(int scanned, int total)? onProgress,
  }) async {
    final hasPermission = await requestPermission();
    if (!hasPermission) {
      return const ScanResult(success: false, tracksFound: 0, error: 'Permission denied');
    }
    if (Platform.isAndroid || Platform.isIOS) {
      return _scanMobile(onProgress: onProgress);
    } else {
      return _scanDesktop(onProgress: onProgress);
    }
  }

  // ── Mobile ────────────────────────────────────────────────────────────────

  Future<ScanResult> _scanMobile({void Function(int, int)? onProgress}) async {
    try {
      final songs = await _query.querySongs(
        sortType: SongSortType.TITLE,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );
      final valid = songs.where((s) =>
        (s.duration ?? 0) > 30000 &&
        s.data.isNotEmpty &&
        _isSupportedFormat(s.data),
      ).toList();

      final total = valid.length;
      int scanned = 0;
      const chunkSize = 10;

      for (int i = 0; i < valid.length; i += chunkSize) {
        final chunk = valid.sublist(i, (i + chunkSize).clamp(0, valid.length));
        await _db.insertTrackBatch(chunk.map((s) => TracksCompanion(
          path:      Value(s.data),
          title:     Value(s.title),
          artist:    Value(s.artist ?? 'Unknown Artist'),
          album:     Value(s.album ?? 'Unknown Album'),
          genre:     Value(s.genre),
          duration:  Value(s.duration ?? 0),
          size:      Value(s.size),
          dateAdded: Value(s.dateAdded ?? 0),
        )).toList());
        scanned += chunk.length;
        onProgress?.call(scanned, total);
        await Future.delayed(Duration.zero);
      }
      await _db.removeMissingFiles();
      return ScanResult(success: true, tracksFound: scanned);
    } catch (e) {
      return ScanResult(success: false, tracksFound: 0, error: e.toString());
    }
  }

  // ── Desktop ───────────────────────────────────────────────────────────────

  static Future<bool> _ffprobeAvailable() async {
    try {
      final r = await Process.run('ffprobe', ['-version'])
          .timeout(const Duration(seconds: 5), onTimeout: () => ProcessResult(0, -1, '', ''));
      return r.exitCode == 0;
    } catch (e) {
      debugPrint('[LibraryScanner] ffprobe check failed: $e');
      return false;
    }
  }

  Future<ScanResult> _scanDesktop({void Function(int, int)? onProgress}) async {
    final useFfprobe = await _ffprobeAvailable();
    debugPrint('[LibraryScanner] ffprobe available: $useFfprobe');

    final seenDirs  = <String>{}; // real paths of visited directories (cycle detection)
    final seenFiles = <String>{}; // real paths of accepted audio files (dedup)
    const chunkSize = 10;
    final chunk     = <File>[];
    int scanned     = 0;

    // Insert the current chunk and update progress; clears chunk when done.
    Future<void> flushChunk() async {
      if (chunk.isEmpty) return;

      // Concurrent when ffprobe is available (fast subprocess, no resource clash).
      // Sequential when falling back to just_audio so mpv instances don't contend.
      final List<FileTag> tags;
      if (useFfprobe) {
        tags = await Future.wait(chunk.map((f) => MetadataWriter.readTag(f.path)));
      } else {
        tags = [];
        for (final f in chunk) {
          tags.add(await MetadataWriter.readTag(f.path));
        }
      }

      final companions = <TracksCompanion>[];
      for (var j = 0; j < chunk.length; j++) {
        FileStat stat;
        try {
          stat = await chunk[j].stat();
        } catch (e) {
          debugPrint('[LibraryScanner] stat failed for ${chunk[j].path}: $e');
          continue;
        }
        final name      = chunk[j].uri.pathSegments.last;
        final fileTitle = name.replaceAll(RegExp(r'\.[^.]+$'), '');
        final tag       = tags[j];
        // If duration probing failed (0), estimate from file size at 128 kbps.
        // Any file > 100 KB at 128 kbps is at least ~6 s, but we already
        // filtered below 100 KB by size, so this floor lets large files through
        // the watchAllTracks duration filter even when probing is unavailable.
        final durMs = tag.durationMs > 0
            ? tag.durationMs
            : ((stat.size * 8) ~/ 128).clamp(0, 9999999);

        companions.add(TracksCompanion(
          path:        Value(chunk[j].path),
          title:       Value(tag.title  ?? fileTitle),
          artist:      Value(tag.artist ?? 'Unknown Artist'),
          album:       Value(tag.album  ?? 'Unknown Album'),
          genre:       Value(tag.genre),
          trackNumber: Value(tag.trackNumber),
          lyrics:      Value(tag.lyrics),
          duration:    Value(durMs),
          size:        Value(stat.size),
          dateAdded:   Value(stat.modified.millisecondsSinceEpoch),
        ));
      }

      if (companions.isNotEmpty) {
        await _db.insertTrackBatch(companions);
        scanned += companions.length;
        // total=0 → UI shows "FOUND X FILES" (denominator unknown while scanning)
        onProgress?.call(scanned, 0);
      }
      chunk.clear();
      await Future.delayed(Duration.zero);
    }

    // Recursive directory walk that prunes excluded subtrees at the dir level.
    Future<void> walk(Directory dir) async {
      // Resolve the real path for cycle detection (handles symlinked dirs).
      String realDir;
      try {
        realDir = await dir.resolveSymbolicLinks();
      } catch (e) {
        debugPrint('[LibraryScanner] resolveSymbolicLinks failed for ${dir.path}: $e');
        return;
      }
      if (!seenDirs.add(realDir)) return; // already visited

      await for (final entity in dir.list(followLinks: true).handleError((_) {})) {
        try {
          if (entity is Directory) {
            final name = entity.path.split('/').last;
            if (!_skipDir(name)) await walk(entity);
          } else if (entity is File) {
            if (!_isSupportedFormat(entity.path)) continue;

            String realFile;
            try {
              realFile = await entity.resolveSymbolicLinks();
            } catch (e) {
              debugPrint('[LibraryScanner] file resolveSymbolicLinks failed for ${entity.path}: $e');
              realFile = entity.path;
            }
            if (!seenFiles.add(realFile)) continue;

            FileStat stat;
            try {
              stat = await entity.stat();
            } catch (e) {
              debugPrint('[LibraryScanner] file stat failed for ${entity.path}: $e');
              continue;
            }
            // Skip tiny files — UI sounds, notification clips, etc.
            if (stat.size <= 102400) continue;

            chunk.add(entity);
            if (chunk.length >= chunkSize) {
              try {
                await flushChunk();
              } catch (e) {
                debugPrint('[LibraryScanner] flushChunk error: $e');
                chunk.clear(); // discard the failed chunk and keep scanning
              }
            }
          }
        } catch (e) {
          debugPrint('[LibraryScanner] walk entity error: $e');
        }
      }
    }

    try {
      for (final dir in await _getDesktopScanDirs()) {
        if (await dir.exists()) await walk(dir);
      }
      try { await flushChunk(); } catch (e) {
        debugPrint('[LibraryScanner] final flushChunk error: $e');
      }
      await _db.removeMissingFiles();
      return ScanResult(success: true, tracksFound: scanned);
    } catch (e) {
      debugPrint('[LibraryScanner] scanDesktop error: $e');
      return ScanResult(success: false, tracksFound: 0, error: e.toString());
    }
  }

  Future<List<Directory>> _getDesktopScanDirs() async {
    if (Platform.isLinux || Platform.isMacOS) {
      final home = Platform.environment['HOME'] ?? '';
      final user = Platform.environment['USER'] ?? '';
      // Read the real XDG music dir; fall back to ~/Music.
      final musicDir = await _xdgMusicDir(home) ?? '$home/Music';
      return [
        Directory(musicDir),
        Directory('/mnt'),
        Directory('/media/$user'),
      ];
    }
    if (Platform.isWindows) {
      final profile = Platform.environment['USERPROFILE'] ?? '';
      return [
        Directory('$profile\\Music'),
        Directory('$profile\\Desktop'),
        Directory('$profile\\Documents'),
      ];
    }
    return [];
  }

  // Parse XDG_MUSIC_DIR from ~/.config/user-dirs.dirs.
  static Future<String?> _xdgMusicDir(String home) async {
    try {
      final file = File('$home/.config/user-dirs.dirs');
      if (!await file.exists()) return null;
      for (final line in await file.readAsLines()) {
        if (!line.startsWith('XDG_MUSIC_DIR=')) continue;
        var val = line.substring('XDG_MUSIC_DIR='.length).trim();
        if (val.startsWith('"') && val.endsWith('"')) {
          val = val.substring(1, val.length - 1);
        }
        return val.replaceFirst(r'$HOME', home);
      }
    } catch (e) {
      debugPrint('[LibraryScanner] _xdgMusicDir error: $e');
    }
    return null;
  }
}

class ScanResult {
  final bool success;
  final int tracksFound;
  final String? error;
  const ScanResult({required this.success, required this.tracksFound, this.error});
}
