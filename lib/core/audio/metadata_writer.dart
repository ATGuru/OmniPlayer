import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;

/// Metadata read from an audio file.
class FileTag {
  final String? title;
  final String? artist;
  final String? album;
  final String? genre;
  final int? trackNumber; // null = tag absent in file
  final String? lyrics;
  final int durationMs;

  const FileTag({
    this.title,
    this.artist,
    this.album,
    this.genre,
    this.trackNumber,
    this.lyrics,
    this.durationMs = 0,
  });
}

class MetadataWriter {
  MetadataWriter._();

  // ── Read ──────────────────────────────────────────────────────────────────

  /// Read tags and duration from [path] using ffprobe.
  /// Falls back to just_audio for duration only when ffprobe is unavailable.
  static Future<FileTag> readTag(String path) async {
    try {
      final result = await Process.run('ffprobe', [
        '-v', 'quiet',
        '-print_format', 'json',
        '-show_format',
        path,
      ]).timeout(
        const Duration(seconds: 20),
        onTimeout: () => ProcessResult(0, -1, '', 'timeout'),
      );
      if (result.exitCode == 0) {
        final json   = jsonDecode(result.stdout as String) as Map<String, dynamic>;
        final format = json['format'] as Map<String, dynamic>? ?? {};
        // Normalise to lowercase so MP3 (mixed-case) and FLAC (uppercase) both work.
        final rawTags = format['tags'] as Map<String, dynamic>? ?? {};
        final tags    = rawTags.map((k, v) => MapEntry(k.toLowerCase(), v?.toString()));
        final durSec  = double.tryParse(format['duration']?.toString() ?? '') ?? 0;
        // Track tag is often "1/10" — take only the part before the slash.
        final trackStr = _pick(tags, ['track', 'tracknumber']);
        int? trackNum;
        if (trackStr != null) {
          trackNum = int.tryParse(trackStr.split('/').first.trim());
        }
        return FileTag(
          title:       _pick(tags, ['title']),
          artist:      _pick(tags, ['artist', 'album_artist']),
          album:       _pick(tags, ['album']),
          genre:       _pick(tags, ['genre']),
          trackNumber: trackNum,
          lyrics:      _pick(tags, ['lyrics', 'lyrics-eng', 'unsyncedlyrics']),
          durationMs:  (durSec * 1000).round(),
        );
      }
    } catch (e) {
      debugPrint('[MetadataWriter] ffprobe readTag error: $e');
      // ffprobe not installed — fall through
    }

    // just_audio fallback: duration only, no tag reading
    try {
      return FileTag(durationMs: await _durationViaPlayer(path));
    } catch (e) {
      debugPrint('[MetadataWriter] just_audio fallback error: $e');
      return const FileTag();
    }
  }

  // ── Write ─────────────────────────────────────────────────────────────────

  /// Write metadata to [path] in-place using ffmpeg (-codec copy, no re-encode).
  /// Existing tags not listed here are preserved via -map_metadata 0.
  /// Returns false (never throws) if ffmpeg is unavailable or fails.
  static Future<bool> writeTag(
    String path, {
    String? title,
    String? artist,
    String? album,
    String? genre,
    int? trackNumber,
    String? lyrics,
    String? comment,
  }) async {
    final meta = <String>[];
    if (title       != null) meta.addAll(['-metadata', 'title=$title']);
    if (artist      != null) meta.addAll(['-metadata', 'artist=$artist']);
    if (album       != null) meta.addAll(['-metadata', 'album=$album']);
    if (genre       != null) meta.addAll(['-metadata', 'genre=$genre']);
    if (trackNumber != null) meta.addAll(['-metadata', 'track=$trackNumber']);
    if (lyrics      != null) meta.addAll(['-metadata', 'lyrics=$lyrics']);
    if (comment     != null) meta.addAll(['-metadata', 'comment=$comment']);
    if (meta.isEmpty)   return true;

    // Write to /tmp so there's no scan-collision and no cross-dir rename issue.
    final ext     = p.extension(path);
    final tmpPath = p.join(
      Platform.isWindows
          ? (Platform.environment['TEMP'] ?? 'C:\\Temp')
          : '/tmp',
      'omniplayer_${DateTime.now().millisecondsSinceEpoch}$ext',
    );

    try {
      final result = await Process.run('ffmpeg', [
        '-i', path,
        '-map_metadata', '0', // carry forward all existing tags
        ...meta,              // then override the ones we're changing
        '-codec', 'copy',
        '-y',
        tmpPath,
      ]);

      if (result.exitCode != 0) {
        debugPrint('[MetadataWriter] ffmpeg error: ${result.stderr}');
        return false;
      }

      // Replace original. rename() is atomic on the same FS; fallback copies.
      try {
        await File(tmpPath).rename(path);
      } catch (e) {
        debugPrint('[MetadataWriter] rename failed, trying copy: $e');
        await File(tmpPath).copy(path);
        await File(tmpPath).delete();
      }
      return true;
    } catch (e) {
      debugPrint('[MetadataWriter] writeTag failed: $e');
      return false;
    } finally {
      // Safety cleanup in case rename threw after creating tmpPath
      try { await File(tmpPath).delete(); } catch (e) {
        debugPrint('[MetadataWriter] cleanup delete failed: $e');
      }
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String? _pick(Map<String, String?> tags, List<String> keys) {
    for (final k in keys) {
      final v = tags[k];
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }

  static Future<int> _durationViaPlayer(String path) async {
    AudioPlayer? player;
    try {
      player = AudioPlayer(); // inside try so constructor failures are caught
      await player.setFilePath(path);
      final d = await player.durationStream
          .where((d) => d != null && d.inDays < 364)
          .first
          .timeout(const Duration(seconds: 8));
      return d?.inMilliseconds ?? 0;
    } catch (e) {
      debugPrint('[MetadataWriter] _durationViaPlayer error: $e');
      return 0;
    } finally {
      try { await player?.dispose(); } catch (e) {
        debugPrint('[MetadataWriter] dispose error: $e');
      }
    }
  }
}
