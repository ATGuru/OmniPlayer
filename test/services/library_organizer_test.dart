import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:omniplayer/core/database/app_database.dart';
import 'package:omniplayer/services/library_organizer.dart';

void main() {
  late AppDatabase db;
  late Directory root;
  late LibraryOrganizer organizer;

  setUp(() async {
    db = AppDatabase(inMemoryDatabase: true);
    root = await Directory.systemTemp.createTemp('omniplayer_org_');
    organizer = LibraryOrganizer(db, rootOverride: root);
  });

  tearDown(() async {
    await db.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('album folder names drop characters a filesystem rejects', () {
    expect(albumDirectoryName('Road/Trip: Live'), 'Road Trip Live');
    expect(albumDirectoryName('..'), 'Album');
    expect(albumDirectoryName('   '), 'Album');
  });

  test('a sibling directory is not inside the download root', () {
    expect(fileIsInside('/music/OmniPlayer', '/music/OmniPlayer/Albums/a.mp3'), isTrue);
    expect(fileIsInside('/music/OmniPlayer', '/music/OmniPlayerExtra/a.mp3'), isFalse);
  });

  test('album names keep an empty album the user created', () {
    expect(
      collectAlbumNames(['Night Drive'], ['Unknown Album', 'Night Drive']),
      ['Night Drive', 'Unknown Album'],
    );
  });

  test('moving a download puts the file in the album folder', () async {
    final sourceDir = Directory('${root.path}/NS050');
    await sourceDir.create(recursive: true);
    final source = File('${sourceDir.path}/sketch.mp3');
    await source.writeAsBytes(List<int>.filled(40, 1));
    final id = await db.insertTrack(TracksCompanion.insert(
      path: source.path,
      title: 'Sketch',
      artist: const Value('Ada'),
      album: const Value('Sketches'),
      licenseName: const Value('CC BY 4.0'),
    ));
    await db.toggleFavorite(id);
    await db.rememberCatalogFile('NS050/sketch.mp3', source.path);

    final track = (await db.getTrackById(id))!;
    final moved = await organizer.moveToAlbum(track, 'Night/Drive');

    expect(moved.id, id);
    expect(moved.album, 'Night/Drive');
    expect(moved.isFavorite, isTrue);
    expect(moved.tagsEdited, isTrue);
    expect(moved.path, '${root.path}/Albums/Night Drive/sketch.mp3');
    expect(await File(moved.path).exists(), isTrue);
    expect(await source.exists(), isFalse);
    expect(await db.catalogFilePath('NS050/sketch.mp3'), moved.path);
    expect(await db.rememberedAlbums(), contains('Night/Drive'));
  });

  test('deleting a download removes the file', () async {
    final source = File('${root.path}/keep.mp3');
    await source.writeAsBytes(const [1, 2, 3]);
    final id = await db.insertTrack(TracksCompanion.insert(
      path: source.path,
      title: 'Keep',
    ));
    await db.rememberCatalogFile('rel/keep.mp3', source.path);
    final removedFile = await organizer.deleteTrack((await db.getTrackById(id))!);

    expect(removedFile, isTrue);
    expect(await source.exists(), isFalse);
    expect(await db.getTrackById(id), isNull);
    expect(await db.catalogFilePath('rel/keep.mp3'), isNull);
  });

  test('removing a scanned song leaves the file and blocks the next scan', () async {
    final outside = await Directory.systemTemp.createTemp('omniplayer_scanned_');
    try {
      final file = File('${outside.path}/radio.mp3');
      await file.writeAsBytes(const [1, 2, 3, 4]);
      final id = await db.insertTrack(TracksCompanion.insert(
        path: file.path,
        title: 'Radio',
      ));
      final removedFile = await organizer.deleteTrack((await db.getTrackById(id))!);

      expect(removedFile, isFalse);
      expect(await file.exists(), isTrue);
      expect(await db.getTrackById(id), isNull);
      await db.insertTrackBatch([
        TracksCompanion.insert(path: file.path, title: 'Radio again'),
      ]);
      expect(await db.getTrackByPath(file.path), isNull);
    } finally {
      await outside.delete(recursive: true);
    }
  });
}
