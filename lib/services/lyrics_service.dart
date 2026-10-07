import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class LyricsResult {
  final String? lyrics;
  final String? error;
  const LyricsResult({this.lyrics, this.error});
}

class LyricsService {
  LyricsService._();

  static Future<LyricsResult> transcribeAudio(String audioPath) async {
    if (Platform.isAndroid || Platform.isIOS) {
      return const LyricsResult(error: 'On-device transcription is not in this release.');
    }
    return _transcribeDesktop(audioPath);
  }

  // ── Desktop (Linux / macOS / Windows) ────────────────────────────────────

  static Future<LyricsResult> _transcribeDesktop(String audioPath) async {
    final whisperBin = await _findWhisper();
    if (whisperBin == null) {
      return const LyricsResult(
        error: 'Whisper not found — install with: pip install openai-whisper',
      );
    }

    final tmpDir = '/tmp/omniplayer_whisper_${DateTime.now().millisecondsSinceEpoch}';
    try {
      await Directory(tmpDir).create(recursive: true);

      ProcessResult result;
      try {
        result = await Process.run(whisperBin, [
          audioPath,
          '--model',         'base',
          '--output_format', 'txt',
          '--output_dir',    tmpDir,
          '--task',          'transcribe',
          '--fp16',          'False',
          '--verbose',       'False',
        ]).timeout(
          const Duration(minutes: 10),
          onTimeout: () => ProcessResult(0, -1, '', 'timeout'),
        );
      } catch (e) {
        return LyricsResult(error: 'Transcription failed: $e');
      }

      if (result.exitCode != 0) {
        final stderr = (result.stderr as String? ?? '').trim();
        if (stderr == 'timeout') {
          return const LyricsResult(error: 'Timed out — try a shorter track');
        }
        return LyricsResult(error: 'Whisper error: $stderr');
      }

      final txtPath = p.join(tmpDir, '${p.basenameWithoutExtension(audioPath)}.txt');
      final txtFile = File(txtPath);
      if (!await txtFile.exists()) {
        return const LyricsResult(error: 'No output — transcription may have failed');
      }
      final text = (await txtFile.readAsString()).trim();
      if (text.isEmpty) return const LyricsResult(error: 'No speech detected in audio');
      return LyricsResult(lyrics: text);
    } finally {
      try { await Directory(tmpDir).delete(recursive: true); } catch (e) {
        debugPrint('[LyricsService] cleanup tmpDir delete failed: $e');
      }
    }
  }

  static Future<String?> _findWhisper() async {
    try {
      final r = await Process.run('which', ['whisper'])
          .timeout(const Duration(seconds: 3));
      if (r.exitCode == 0) {
        final path = (r.stdout as String).trim();
        if (path.isNotEmpty) return path;
      }
    } catch (e) {
      debugPrint('[LyricsService] which whisper failed: $e');
    }
    final home  = Platform.environment['HOME'] ?? '';
    final local = '$home/.local/bin/whisper';
    if (await File(local).exists()) return local;
    return null;
  }
}
