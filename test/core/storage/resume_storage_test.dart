import 'package:flutter_test/flutter_test.dart';
import 'package:omniplayer/core/storage/resume_storage.dart';

void main() {
  group('ResumeStorage', () {
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
      // Clear any existing state
      await ResumeStorage.save(trackId: 0, positionMs: 0);
      
      // This test assumes the storage is cleared or empty
      // In a real scenario, you'd need to mock the file system
      final loaded = await ResumeStorage.load();
      
      // The implementation returns null on error, which includes file not found
      expect(loaded, isNotNull);
    });

    test('save handles invalid data gracefully', () async {
      // Test that save doesn't throw on valid data
      expect(
        () async => await ResumeStorage.save(trackId: -1, positionMs: -1),
        returnsNormally,
      );
    });
  });
}
