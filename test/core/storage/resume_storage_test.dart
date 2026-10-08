import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:omniplayer/core/storage/resume_storage.dart';

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('omniplayer-resume');
    ResumeStorage.directoryOverride = dir;
  });

  tearDown(() {
    ResumeStorage.directoryOverride = null;
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('save and load resume state', () async {
    const trackId = 123;
    const positionMs = 45000;

    await ResumeStorage.save(trackId: trackId, positionMs: positionMs);
    final loaded = await ResumeStorage.load();

    expect(loaded, isNotNull);
    expect(loaded!.trackId, equals(trackId));
    expect(loaded.positionMs, equals(positionMs));
  });

  test('load returns null when no state saved', () async {
    expect(await ResumeStorage.load(), isNull);
  });

  test('save handles invalid data gracefully', () async {
    await ResumeStorage.save(trackId: -1, positionMs: -1);
    final loaded = await ResumeStorage.load();

    expect(loaded, isNotNull);
    expect(loaded!.trackId, equals(-1));
    expect(loaded.positionMs, equals(-1));
  });
}
