// ═══════════════════════════════════════════════
// lib/core/database/app_database.dart
// Drift schema — tracks, playlists, queue
// ═══════════════════════════════════════════════

import 'dart:io';
import 'package:drift/drift.dart' hide Type;
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

// ── Tables ───────────────────────────────────────

class Tracks extends Table {
  IntColumn get id       => integer().autoIncrement()();
  TextColumn get path    => text().unique()();
  TextColumn get title   => text()();
  TextColumn get artist  => text().withDefault(const Constant('Unknown Artist'))();
  TextColumn get album   => text().withDefault(const Constant('Unknown Album'))();
  TextColumn get genre   => text().nullable()();
  IntColumn  get duration => integer().withDefault(const Constant(0))(); // milliseconds
  IntColumn  get size    => integer().withDefault(const Constant(0))();  // bytes
  IntColumn  get dateAdded => integer().withDefault(const Constant(0))();
  TextColumn get albumArtPath => text().nullable()();
  IntColumn  get playCount => integer().withDefault(const Constant(0))();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
}

class Playlists extends Table {
  IntColumn get id        => integer().autoIncrement()();
  TextColumn get name     => text().unique()();
  IntColumn  get createdAt => integer()();
}

class PlaylistTracks extends Table {
  IntColumn get id         => integer().autoIncrement()();
  IntColumn get playlistId => integer().references(Playlists, #id, onDelete: KeyAction.cascade)();
  IntColumn get trackId    => integer().references(Tracks, #id, onDelete: KeyAction.cascade)();
  IntColumn get position   => integer()();
}

class QueueEntries extends Table {
  IntColumn get id       => integer().autoIncrement()();
  IntColumn get trackId  => integer().references(Tracks, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();
}

// ── Database ─────────────────────────────────────

@DriftDatabase(tables: [Tracks, Playlists, PlaylistTracks, QueueEntries])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // ── Track queries ──────────────────────────────

  Future<List<Track>> getAllTracks() =>
      (select(tracks)..orderBy([(t) => OrderingTerm(expression: t.title)])).get();

  Stream<List<Track>> watchAllTracks() =>
      (select(tracks)..orderBy([(t) => OrderingTerm(expression: t.title)])).watch();

  Future<int> insertTrack(TracksCompanion entry) =>
      into(tracks).insertOnConflictUpdate(entry);

  Future<int> insertTrackBatch(List<TracksCompanion> entries) async {
    var count = 0;
    await batch((b) {
      for (final entry in entries) {
        b.insert(tracks, entry, mode: InsertMode.insertOrReplace);
        count++;
      }
    });
    return count;
  }

  Future<void> incrementPlayCount(int trackId) => customStatement(
    'UPDATE tracks SET play_count = play_count + 1 WHERE id = ?', [trackId],
  );

  Future<void> toggleFavorite(int trackId) => customStatement(
    'UPDATE tracks SET is_favorite = NOT is_favorite WHERE id = ?', [trackId],
  );

  Stream<List<Track>> watchFavorites() =>
      (select(tracks)..where((t) => t.isFavorite.equals(true))).watch();

  // ── Queue queries ──────────────────────────────

  Future<void> saveQueue(List<int> trackIds) async {
    await delete(queueEntries).go();
    await batch((b) {
      for (var i = 0; i < trackIds.length; i++) {
        b.insert(queueEntries, QueueEntriesCompanion(
          trackId: Value(trackIds[i]),
          position: Value(i),
        ));
      }
    });
  }

  Future<List<Track>> getQueue() async {
    final entries = await (select(queueEntries)
      ..orderBy([(q) => OrderingTerm(expression: q.position)])).get();
    final ids = entries.map((e) => e.trackId).toList();
    if (ids.isEmpty) return [];
    // isIn() returns rows in DB order, not ids order — rebuild by position.
    final fetched = await (select(tracks)..where((t) => t.id.isIn(ids))).get();
    final byId = {for (final t in fetched) t.id: t};
    return ids.map((id) => byId[id]).whereType<Track>().toList();
  }

  // ── Playlist queries ───────────────────────────

  Future<List<Playlist>> getAllPlaylists() => select(playlists).get();

  Future<int> createPlaylist(String name) => into(playlists).insert(
    PlaylistsCompanion(name: Value(name), createdAt: Value(DateTime.now().millisecondsSinceEpoch)),
  );

  Future<void> addTrackToPlaylist(int playlistId, int trackId, int position) =>
      into(playlistTracks).insert(PlaylistTracksCompanion(
        playlistId: Value(playlistId),
        trackId: Value(trackId),
        position: Value(position),
      ));
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'omnix_audio.db'));
    return NativeDatabase.createInBackground(file);
  });
}
