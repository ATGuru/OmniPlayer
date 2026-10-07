// ═══════════════════════════════════════════════
// lib/core/database/app_database.dart
// Drift schema — tracks, playlists, queue
// ═══════════════════════════════════════════════

import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
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
  IntColumn  get trackNumber => integer().nullable()();            // ID3 track number; null = unset
  TextColumn get lyrics    => text().nullable()();               // plain-text lyrics; null = none
  IntColumn  get playCount => integer().withDefault(const Constant(0))();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  // User edited tags in the app. A later scan must not overwrite them.
  BoolColumn get tagsEdited => boolean().withDefault(const Constant(false))();
  // Set when the track was saved from the in-app open-music catalog.
  // Creative Commons attribution stays on the song, with no external link.
  TextColumn get licenseName => text().nullable()();
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

class Settings extends Table {
  TextColumn get key   => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

// ── Database ─────────────────────────────────────

@DriftDatabase(tables: [Tracks, Playlists, PlaylistTracks, QueueEntries, Settings])
class AppDatabase extends _$AppDatabase {
  static const onboardingSeenKey = 'onboarding_seen';
  static const excludedPathsKey = 'excluded_paths';
  static const libraryAlbumsKey = 'library_albums';
  static const catalogFilesKey = 'catalog_files';

  AppDatabase({bool inMemoryDatabase = false})
      : super(inMemoryDatabase ? NativeDatabase.memory() : _openConnection());

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(settings);
      }
      if (from < 3) {
        await m.addColumn(tracks, tracks.trackNumber);
      }
      if (from < 4) {
        await m.addColumn(tracks, tracks.lyrics);
      }
      if (from < 5) {
        await m.addColumn(tracks, tracks.tagsEdited);
      }
      if (from < 6) {
        await m.addColumn(tracks, tracks.licenseName);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  // ── Settings queries ───────────────────────────

  Future<String?> getSetting(String key) async {
    final row = await (select(settings)..where((s) => s.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> setSetting(String key, String value) async {
    await into(settings).insertOnConflictUpdate(
      SettingsCompanion(key: Value(key), value: Value(value)),
    );
  }

  Future<List<String>> _stringList(String key) async {
    final raw = await getSetting(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded.whereType<String>().toList();
    } catch (_) {}
    return [];
  }

  Future<Map<String, String>> _stringMap(String key) async {
    final raw = await getSetting(key);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry('$key', '$value'));
      }
    } catch (_) {}
    return {};
  }

  Future<Set<String>> excludedPaths() async => (await _stringList(excludedPathsKey)).toSet();

  Future<void> excludePath(String path) async {
    final paths = await excludedPaths();
    if (!paths.add(path)) return;
    final sorted = paths.toList()..sort();
    await setSetting(excludedPathsKey, jsonEncode(sorted));
  }

  Future<List<String>> rememberedAlbums() => _stringList(libraryAlbumsKey);

  Future<void> rememberAlbum(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final names = await rememberedAlbums();
    if (names.any((item) => item.toLowerCase() == trimmed.toLowerCase())) return;
    names.add(trimmed);
    names.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    await setSetting(libraryAlbumsKey, jsonEncode(names));
  }

  Future<void> forgetAlbum(String name) async {
    final names = await rememberedAlbums();
    names.removeWhere((item) => item.toLowerCase() == name.toLowerCase());
    await setSetting(libraryAlbumsKey, jsonEncode(names));
  }

  Future<void> rememberCatalogFile(String key, String path) async {
    final map = await _stringMap(catalogFilesKey);
    map[key] = path;
    await setSetting(catalogFilesKey, jsonEncode(map));
  }

  Future<String?> catalogFilePath(String key) async => (await _stringMap(catalogFilesKey))[key];

  Future<void> forgetCatalogPath(String path) async {
    final map = await _stringMap(catalogFilesKey);
    final before = map.length;
    map.removeWhere((_, value) => value == path);
    if (map.length != before) await setSetting(catalogFilesKey, jsonEncode(map));
  }

  Future<void> retargetCatalogPath(String from, String to) async {
    if (from == to) return;
    final map = await _stringMap(catalogFilesKey);
    var changed = false;
    for (final entry in map.entries.toList()) {
      if (entry.value == from) {
        map[entry.key] = to;
        changed = true;
      }
    }
    if (changed) await setSetting(catalogFilesKey, jsonEncode(map));
  }

  // ── Track queries ──────────────────────────────

  // Songs of at least a minute, plus anything saved from the open-music catalog.
  // Short notification clips stay hidden. A catalog download the user asked
  // for stays even when the recording is under a minute.
  Expression<bool> _visibleTrack(Tracks t) =>
      t.duration.isBiggerOrEqualValue(60000) | t.licenseName.isNotNull();

  // Returns the MIN(id) per (title, duration) group — used to deduplicate.
  _dedupeSubquery() => selectOnly(tracks)
    ..addColumns([tracks.id.min()])
    ..where(_visibleTrack(tracks))
    ..groupBy([tracks.title, tracks.duration]);

  // Sort: album → track number (nulls sorted last via coalesce) → title.
  // This makes tracks play in disc order when track numbers are set, and
  // falls back to alphabetical within albums when they are not.
  List<OrderingTerm Function(Tracks)> get _trackOrder => [
    (t) => OrderingTerm(expression: t.album),
    (t) => OrderingTerm(
      expression: coalesce([t.trackNumber, const Constant(999999)]),
    ),
    (t) => OrderingTerm(expression: t.title),
  ];

  Future<List<Track>> getAllTracks() =>
      (select(tracks)
        ..where((t) => _visibleTrack(t) & t.id.isInQuery(_dedupeSubquery()))
        ..orderBy(_trackOrder)).get();

  Stream<List<Track>> watchAllTracks() =>
      (select(tracks)
        ..where((t) => _visibleTrack(t) & t.id.isInQuery(_dedupeSubquery()))
        ..orderBy(_trackOrder)).watch();

  Future<int> insertTrack(TracksCompanion entry) =>
      into(tracks).insertOnConflictUpdate(entry);

  /// Insert new files and refresh tags on known paths.
  /// Keeps the row id, favorite flag, and play count. Playlist and queue
  /// rows point at that id, so a rescan must not replace the row.
  /// Rows marked tagsEdited keep the user's title, artist, album, and lyrics.
  Future<int> insertTrackBatch(List<TracksCompanion> entries) async {
    if (entries.isEmpty) return 0;
    final excluded = await excludedPaths();
    var count = 0;
    await transaction(() async {
      for (final entry in entries) {
        if (!entry.path.present || excluded.contains(entry.path.value)) continue;
        final existing = await (select(tracks)
              ..where((t) => t.path.equals(entry.path.value)))
            .getSingleOrNull();
        if (existing == null) {
          await into(tracks).insert(entry);
        } else if (existing.tagsEdited) {
          await (update(tracks)..where((t) => t.id.equals(existing.id))).write(
            TracksCompanion(
              duration: entry.duration.present ? entry.duration : const Value.absent(),
              size: entry.size.present ? entry.size : const Value.absent(),
            ),
          );
        } else {
          await (update(tracks)..where((t) => t.id.equals(existing.id))).write(
            TracksCompanion(
              title: entry.title.present ? entry.title : const Value.absent(),
              artist: entry.artist.present ? entry.artist : const Value.absent(),
              album: entry.album.present ? entry.album : const Value.absent(),
              genre: entry.genre.present ? entry.genre : const Value.absent(),
              duration: entry.duration.present ? entry.duration : const Value.absent(),
              size: entry.size.present ? entry.size : const Value.absent(),
              dateAdded: entry.dateAdded.present ? entry.dateAdded : const Value.absent(),
              trackNumber: entry.trackNumber.present ? entry.trackNumber : const Value.absent(),
              lyrics: entry.lyrics.present && entry.lyrics.value != null
                  ? entry.lyrics
                  : const Value.absent(),
              albumArtPath: entry.albumArtPath.present ? entry.albumArtPath : const Value.absent(),
            ),
          );
        }
        count++;
      }
    });
    return count;
  }

  /// Drop rows whose files are gone. Foreign keys clear playlist and queue links.
  Future<int> removeMissingFiles() async {
    final rows = await select(tracks).get();
    final gone = <int>[];
    for (final row in rows) {
      if (!await File(row.path).exists()) gone.add(row.id);
    }
    if (gone.isEmpty) return 0;
    await (delete(tracks)..where((t) => t.id.isIn(gone))).go();
    return gone.length;
  }

  Future<void> deleteTrack(int id) =>
      (delete(tracks)..where((t) => t.id.equals(id))).go();

  /// Point a library row at a new file and album. tagsEdited keeps a later
  /// scan from putting the old album name back.
  Future<void> relocateTrack(int id, {required String path, required String album}) =>
      (update(tracks)..where((t) => t.id.equals(id))).write(TracksCompanion(
        path: Value(path),
        album: Value(album),
        tagsEdited: const Value(true),
      ));

  Future<void> incrementPlayCount(int trackId) => customStatement(
    'UPDATE tracks SET play_count = play_count + 1 WHERE id = ?', [trackId],
  );

  Future<void> toggleFavorite(int trackId) => customStatement(
    'UPDATE tracks SET is_favorite = NOT is_favorite WHERE id = ?', [trackId],
  );

  Future<Track?> getTrackById(int id) =>
      (select(tracks)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<Track?> getTrackByPath(String path) =>
      (select(tracks)..where((t) => t.path.equals(path))).getSingleOrNull();

  /// Save a catalog download. A second save of the same file keeps favorites,
  /// play counts, and any title the user edited after the first save.
  Future<Track> saveDownloadedTrack({
    required String path,
    required String title,
    required String artist,
    required String album,
    required int durationMs,
    required int size,
    required String licenseName,
    int? trackNumber,
    String? genre,
  }) async {
    final existing = await getTrackByPath(path);
    if (existing == null) {
      final id = await into(tracks).insert(TracksCompanion.insert(
        path: path,
        title: title,
        artist: Value(artist),
        album: Value(album),
        genre: Value(genre),
        duration: Value(durationMs),
        size: Value(size),
        dateAdded: Value(DateTime.now().millisecondsSinceEpoch),
        trackNumber: Value(trackNumber),
        licenseName: Value(licenseName),
        tagsEdited: const Value(true),
      ));
      return (await getTrackById(id))!;
    }
    await (update(tracks)..where((t) => t.id.equals(existing.id))).write(
      TracksCompanion(
        duration: Value(durationMs),
        size: Value(size),
        licenseName: Value(licenseName),
        title: existing.tagsEdited ? const Value.absent() : Value(title),
        artist: existing.tagsEdited ? const Value.absent() : Value(artist),
        album: existing.tagsEdited ? const Value.absent() : Value(album),
        genre: existing.tagsEdited || genre == null ? const Value.absent() : Value(genre),
        trackNumber: existing.tagsEdited ? const Value.absent() : Value(trackNumber),
        tagsEdited: const Value(true),
      ),
    );
    return (await getTrackById(existing.id))!;
  }

  // null fields = keep existing value.  genre="" clears the genre field.
  Future<void> updateTrackMetadata(int id, {
    String? title,
    String? artist,
    String? album,
    String? genre,         // null=no change, ""=clear, non-empty=set
    bool changeGenre = false,
    int? trackNumber,      // null=no change unless changeTrackNumber=true
    bool changeTrackNumber = false,
    String? lyrics,        // null=no change, ""=clear, non-empty=set
    bool changeLyrics = false,
  }) async {
    final Value<String?> genreVal = !changeGenre
        ? const Value.absent()
        : genre == null || genre.isEmpty ? const Value(null) : Value(genre);
    final Value<int?> trackNumVal = !changeTrackNumber
        ? const Value.absent()
        : Value(trackNumber);
    final Value<String?> lyricsVal = !changeLyrics
        ? const Value.absent()
        : lyrics == null || lyrics.isEmpty ? const Value(null) : Value(lyrics);
    await (update(tracks)..where((t) => t.id.equals(id))).write(TracksCompanion(
      title:       title  != null && title.isNotEmpty  ? Value(title)  : const Value.absent(),
      artist:      artist != null && artist.isNotEmpty ? Value(artist) : const Value.absent(),
      album:       album  != null && album.isNotEmpty  ? Value(album)  : const Value.absent(),
      genre:       genreVal,
      trackNumber: trackNumVal,
      lyrics:      lyricsVal,
      tagsEdited:  const Value(true),
    ));
  }

  // Batch update — null fields are not touched.
  Future<void> batchUpdateTracks(List<int> ids, {
    String? artist,
    String? album,
    String? genre,   // null=no change, ""=clear, non-empty=set all
  }) async {
    if (ids.isEmpty) return;
    final Value<String?> genreVal = genre == null
        ? const Value.absent()
        : genre.isEmpty ? const Value(null) : Value(genre);
    await (update(tracks)..where((t) => t.id.isIn(ids))).write(TracksCompanion(
      artist: artist != null && artist.isNotEmpty ? Value(artist) : const Value.absent(),
      album:  album  != null && album.isNotEmpty  ? Value(album)  : const Value.absent(),
      genre:  genreVal,
      tagsEdited: const Value(true),
    ));
  }

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

  Stream<List<Playlist>> watchPlaylists() =>
      (select(playlists)..orderBy([(p) => OrderingTerm(expression: p.name)])).watch();

  Future<void> renamePlaylist(int id, String name) =>
      (update(playlists)..where((p) => p.id.equals(id))).write(
        PlaylistsCompanion(name: Value(name)),
      );

  Future<void> deletePlaylist(int id) =>
      (delete(playlists)..where((p) => p.id.equals(id))).go();

  Future<void> addTrackToPlaylist(int playlistId, int trackId, int position) =>
      into(playlistTracks).insert(PlaylistTracksCompanion(
        playlistId: Value(playlistId),
        trackId: Value(trackId),
        position: Value(position),
      ));

  Future<int> nextPlaylistPosition(int playlistId) async {
    final row = await (select(playlistTracks)
          ..where((t) => t.playlistId.equals(playlistId))
          ..orderBy([(t) => OrderingTerm(expression: t.position, mode: OrderingMode.desc)])
          ..limit(1))
        .getSingleOrNull();
    return (row?.position ?? -1) + 1;
  }

  Future<void> removeTrackFromPlaylist(int playlistId, int trackId) =>
      (delete(playlistTracks)
            ..where((t) => t.playlistId.equals(playlistId) & t.trackId.equals(trackId)))
          .go();

  Stream<List<Track>> watchPlaylistTracks(int playlistId) {
    final query = select(playlistTracks).join([
      innerJoin(tracks, tracks.id.equalsExp(playlistTracks.trackId)),
    ])
      ..where(playlistTracks.playlistId.equals(playlistId))
      ..orderBy([OrderingTerm(expression: playlistTracks.position)]);
    return query.watch().map((rows) => rows.map((row) => row.readTable(tracks)).toList());
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'omniplayer.db'));
    return NativeDatabase.createInBackground(file);
  });
}
