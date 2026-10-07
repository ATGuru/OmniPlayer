import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:omniplayer/core/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(inMemoryDatabase: true);
  });

  tearDown(() async {
    await db.close();
  });

  TracksCompanion track({
    required String path,
    required String title,
    String artist = 'Test Artist',
    String album = 'Test Album',
    int duration = 180000,
    int? size,
    String? lyrics,
  }) {
    return TracksCompanion(
      path: Value(path),
      title: Value(title),
      artist: Value(artist),
      album: Value(album),
      duration: Value(duration),
      size: size == null ? const Value.absent() : Value(size),
      lyrics: lyrics == null ? const Value.absent() : Value(lyrics),
    );
  }

  group('Database Operations', () {
    test('insert and retrieve track', () async {
      final id = await db.insertTrack(track(
        path: '/test/path.mp3',
        title: 'Test Track',
      ));
      final retrieved = await db.getTrackById(id);

      expect(retrieved, isNotNull);
      expect(retrieved!.title, equals('Test Track'));
      expect(retrieved.artist, equals('Test Artist'));
      expect(retrieved.tagsEdited, isFalse);
    });

    test('increment play count', () async {
      final id = await db.insertTrack(track(
        path: '/test/path2.mp3',
        title: 'Test Track 2',
      ));
      await db.incrementPlayCount(id);
      final retrieved = await db.getTrackById(id);

      expect(retrieved!.playCount, equals(1));
    });

    test('toggle favorite', () async {
      final id = await db.insertTrack(track(
        path: '/test/path3.mp3',
        title: 'Test Track 3',
      ));
      await db.toggleFavorite(id);
      final retrieved = await db.getTrackById(id);

      expect(retrieved!.isFavorite, isTrue);
    });

    test('get all tracks hides clips under a minute', () async {
      await db.insertTrack(track(path: '/test/track1.mp3', title: 'Track 1'));
      await db.insertTrack(track(path: '/test/track2.mp3', title: 'Track 2'));
      await db.insertTrack(track(
        path: '/test/short.mp3',
        title: 'Short',
        duration: 1000,
      ));

      final tracks = await db.getAllTracks();
      expect(tracks.map((t) => t.title), containsAll(['Track 1', 'Track 2']));
      expect(tracks.map((t) => t.title), isNot(contains('Short')));
    });

    test('rescan keeps id, favorite, and play count', () async {
      final id = await db.insertTrack(track(
        path: '/music/keep.mp3',
        title: 'Keep',
        artist: 'Old Artist',
      ));
      await db.toggleFavorite(id);
      await db.incrementPlayCount(id);
      await db.incrementPlayCount(id);

      final written = await db.insertTrackBatch([
        track(
          path: '/music/keep.mp3',
          title: 'Keep',
          artist: 'New Artist',
          duration: 181000,
          size: 4096,
        ),
      ]);

      final row = await db.getTrackById(id);
      expect(written, 1);
      expect(row!.id, id);
      expect(row.artist, 'New Artist');
      expect(row.duration, 181000);
      expect(row.isFavorite, isTrue);
      expect(row.playCount, 2);
      expect(row.tagsEdited, isFalse);
    });

    test('edited tags survive a rescan', () async {
      final id = await db.insertTrack(track(
        path: '/music/edited.mp3',
        title: 'File Title',
        artist: 'File Artist',
        lyrics: 'file lyrics',
      ));
      await db.updateTrackMetadata(id, title: 'My Title', artist: 'My Artist');

      await db.insertTrackBatch([
        track(
          path: '/music/edited.mp3',
          title: 'File Title',
          artist: 'File Artist',
          duration: 200000,
          size: 99,
          lyrics: 'file lyrics',
        ),
      ]);

      final row = await db.getTrackById(id);
      expect(row!.tagsEdited, isTrue);
      expect(row.title, 'My Title');
      expect(row.artist, 'My Artist');
      expect(row.lyrics, 'file lyrics');
      expect(row.duration, 200000);
      expect(row.size, 99);
    });

    test('rescan does not clear lyrics when the scan has none', () async {
      final id = await db.insertTrack(track(
        path: '/music/words.mp3',
        title: 'Words',
        lyrics: 'keep me',
      ));

      await db.insertTrackBatch([
        TracksCompanion(
          path: const Value('/music/words.mp3'),
          title: const Value('Words'),
          lyrics: const Value(null),
        ),
      ]);

      final row = await db.getTrackById(id);
      expect(row!.lyrics, 'keep me');
      expect(row.title, 'Words');
    });

    test('playlist membership survives a rescan', () async {
      final id = await db.insertTrack(track(
        path: '/music/listed.mp3',
        title: 'Listed',
      ));
      final playlistId = await db.createPlaylist('Night');
      await db.addTrackToPlaylist(playlistId, id, 0);

      await db.insertTrackBatch([
        track(
          path: '/music/listed.mp3',
          title: 'Listed',
          artist: 'After Scan',
        ),
      ]);

      final members = await db.watchPlaylistTracks(playlistId).first;
      expect(members, hasLength(1));
      expect(members.single.id, id);
      expect(members.single.artist, 'After Scan');
    });

    test('a short catalog download stays in the library', () async {
      final saved = await db.saveDownloadedTrack(
        path: '/music/sketch.mp3',
        title: 'Sketch',
        artist: 'Ada',
        album: 'Sketches',
        durationMs: 15000,
        size: 200000,
        licenseName: 'CC BY 4.0',
      );
      await db.toggleFavorite(saved.id);
      final again = await db.saveDownloadedTrack(
        path: '/music/sketch.mp3',
        title: 'Replaced',
        artist: 'Someone else',
        album: 'Sketches',
        durationMs: 15000,
        size: 200000,
        licenseName: 'CC BY 4.0',
      );

      final visible = await db.getAllTracks();
      expect(visible.map((t) => t.id), contains(saved.id));
      expect(again.id, saved.id);
      expect(again.title, 'Sketch');
      expect(again.isFavorite, isTrue);
      expect(again.licenseName, 'CC BY 4.0');
    });

    test('removeMissingFiles drops dead paths and their playlist rows', () async {
      final dir = await Directory.systemTemp.createTemp('omniplayer_db_');
      try {
        final live = File('${dir.path}/live.mp3');
        await live.writeAsBytes(const [0]);
        final liveId = await db.insertTrack(track(
          path: live.path,
          title: 'Live',
        ));
        final deadId = await db.insertTrack(track(
          path: '${dir.path}/gone.mp3',
          title: 'Gone',
        ));
        final playlistId = await db.createPlaylist('Mix');
        await db.addTrackToPlaylist(playlistId, liveId, 0);
        await db.addTrackToPlaylist(playlistId, deadId, 1);

        expect(await db.removeMissingFiles(), 1);
        expect(await db.getTrackById(liveId), isNotNull);
        expect(await db.getTrackById(deadId), isNull);

        final members = await db.watchPlaylistTracks(playlistId).first;
        expect(members.map((t) => t.id), [liveId]);
      } finally {
        await dir.delete(recursive: true);
      }
    });
  });
}
