import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
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

  // Paths that should never be scanned
  static const _excludedPaths = [
    '/Downloads',
    '/.local',
    '/snap',
    '/proc',
    '/sys',
  ];

  static bool _isExcluded(String path) {
    final home = Platform.environment['HOME'] ?? '';
    for (final ex in _excludedPaths) {
      if (path.startsWith('$home$ex/') || path.startsWith('$ex/')) return true;
    }
    return false;
  }

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
      return ScanResult(success: false, tracksFound: 0, error: 'Permission denied');
    }
    if (Platform.isAndroid || Platform.isIOS) {
      return _scanMobile(onProgress: onProgress);
    } else {
      return _scanDesktop(onProgress: onProgress);
    }
  }

  Future<ScanResult> _scanMobile({void Function(int, int)? onProgress}) async {
    try {
      final songs = await _query.querySongs(
        sortType: SongSortType.TITLE,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );
      final valid = songs.where((s) =>
        s.duration != null && s.duration! > 30000 &&
        s.data != null && s.data!.isNotEmpty &&
        _isSupportedFormat(s.data!),
      ).toList();

      final total = valid.length;
      int scanned = 0;
      const chunkSize = 10;

      for (int i = 0; i < valid.length; i += chunkSize) {
        final chunk = valid.sublist(i, (i + chunkSize).clamp(0, valid.length));
        await _db.insertTrackBatch(chunk.map((s) => TracksCompanion(
          path:      Value(s.data ?? ''),
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
      return ScanResult(success: true, tracksFound: scanned);
    } catch (e) {
      return ScanResult(success: false, tracksFound: 0, error: e.toString());
    }
  }

  Future<ScanResult> _scanDesktop({void Function(int, int)? onProgress}) async {
    final player = AudioPlayer();
    try {
      final scanDirs = await _getDesktopScanDirs();
      final allFiles = <File>[];

      for (final dir in scanDirs) {
        if (!await dir.exists()) continue;
        await for (final entity in dir.list(recursive: true, followLinks: false)) {
          if (entity is File &&
              _isSupportedFormat(entity.path) &&
              !_isExcluded(entity.path)) {
            final stat = await entity.stat();
            // Skip anything under 100KB — UI sounds, alerts, etc.
            if (stat.size > 102400) {
              allFiles.add(entity);
            }
          }
        }
      }

      final total = allFiles.length;
      int scanned = 0;
      const chunkSize = 10;

      for (int i = 0; i < allFiles.length; i += chunkSize) {
        final chunk = allFiles.sublist(i, (i + chunkSize).clamp(0, allFiles.length));
        final companions = <TracksCompanion>[];

        for (final file in chunk) {
          final stat = await file.stat();
          final name = file.uri.pathSegments.last;
          final title = name.replaceAll(RegExp(r'\.[^.]+$'), '');
          final duration = await _getFileDuration(player, file.path);

          companions.add(TracksCompanion(
            path:      Value(file.path),
            title:     Value(title),
            artist:    const Value('Unknown Artist'),
            album:     const Value('Unknown Album'),
            duration:  Value(duration),
            size:      Value(stat.size),
            dateAdded: Value(stat.modified.millisecondsSinceEpoch),
          ));
        }

        await _db.insertTrackBatch(companions);
        scanned += chunk.length;
        onProgress?.call(scanned, total);
        await Future.delayed(Duration.zero);
      }

      return ScanResult(success: true, tracksFound: scanned);
    } catch (e) {
      return ScanResult(success: false, tracksFound: 0, error: e.toString());
    } finally {
      await player.dispose();
    }
  }

  Future<int> _getFileDuration(AudioPlayer player, String path) async {
    try {
      final duration = await player.setFilePath(path);
      return duration?.inMilliseconds ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<List<Directory>> _getDesktopScanDirs() async {
    final home = Platform.environment['HOME'] ?? '';
    if (Platform.isLinux || Platform.isMacOS) {
      return [
        Directory('$home/Music'),
      ];
    } else if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'] ?? '';
      return [Directory('$userProfile\\Music')];
    }
    return [];
  }
}

class ScanResult {
  final bool success;
  final int tracksFound;
  final String? error;
  const ScanResult({required this.success, required this.tracksFound, this.error});
}
