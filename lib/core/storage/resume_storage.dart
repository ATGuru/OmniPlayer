import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class ResumeStorage {
  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/resume.json');
  }

  static Future<void> save({required int trackId, required int positionMs}) async {
    try {
      final f = await _file();
      await f.writeAsString(jsonEncode({'track_id': trackId, 'position_ms': positionMs}));
    } catch (e) {
      debugPrint('[ResumeStorage] save error: $e');
    }
  }

  static Future<({int trackId, int positionMs})?> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return null;
      final map = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      return (trackId: map['track_id'] as int, positionMs: map['position_ms'] as int);
    } catch (e) {
      debugPrint('[ResumeStorage] load error: $e');
      return null;
    }
  }
}
