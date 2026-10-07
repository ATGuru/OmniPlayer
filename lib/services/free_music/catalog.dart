import 'dart:convert';

// Open-music catalog models and parsers.
// The bytes come from the Internet Archive netlabel collection. The app
// never sends the user to that site. A release is kept only when its
// license URL is Creative Commons or public domain.

class FreeMusicException implements Exception {
  final String message;
  const FreeMusicException(this.message);
  @override
  String toString() => message;
}

class CatalogAlbum {
  final String identifier;
  final String title;
  final String creator;
  final String license;
  final int downloads;
  final int? year;

  const CatalogAlbum({
    required this.identifier,
    required this.title,
    required this.creator,
    required this.license,
    required this.downloads,
    this.year,
  });
}

/// A browse genre. The clause is a fixed subject search, not free text.
class MusicGenre {
  final String label;
  final String clause;
  const MusicGenre(this.label, this.clause);
}

const musicGenres = <MusicGenre>[
  MusicGenre('Ambient', 'subject:(ambient OR drone OR soundscape)'),
  MusicGenre('Electronic', 'subject:(electronic OR electronica OR techno OR electro OR idm)'),
  MusicGenre('Experimental', 'subject:experimental'),
  MusicGenre('Noise', 'subject:(noise OR industrial)'),
  MusicGenre('Downtempo', 'subject:(downtempo OR chillout OR "lo-fi" OR lofi)'),
  MusicGenre('Rock', 'subject:(rock OR indie OR punk)'),
  MusicGenre('Hip-hop', 'subject:("hip hop" OR "hip-hop" OR rap)'),
  MusicGenre('Jazz', 'subject:jazz'),
  MusicGenre('Folk', 'subject:(folk OR acoustic)'),
  MusicGenre('Metal', 'subject:metal'),
  MusicGenre('Pop', 'subject:pop'),
  MusicGenre('Classical', 'subject:(classical OR piano)'),
];

const musicDecades = <int>[2020, 2010, 2000];

class CatalogPage {
  final List<CatalogAlbum> albums;
  final int total;
  final int page;

  const CatalogPage({required this.albums, required this.total, required this.page});

  bool get hasMore => albums.isNotEmpty && page * 20 < total;
}

class CatalogTrack {
  final String identifier;
  final String fileName;
  final String title;
  final String artist;
  final String album;
  final String license;
  final int durationMs;
  final int sizeBytes;
  final int? trackNumber;
  final String? genre;

  const CatalogTrack({
    required this.identifier,
    required this.fileName,
    required this.title,
    required this.artist,
    required this.album,
    required this.license,
    required this.durationMs,
    required this.sizeBytes,
    this.trackNumber,
    this.genre,
  });

  String get downloadUrl => archiveDownloadUrl(identifier, fileName);
}

const catalogUserAgent = 'OmniPlayer/1.0 (netlabel catalog)';

/// Stable id for a catalog file after the download has been moved.
String catalogFileKey(String identifier, String fileName) => '$identifier/$fileName';

/// Search string locked to netlabel audio that declares an open license.
/// [genre] must be one of [musicGenres]. [year] is a single year.
/// [decade] is 2000, 2010, or 2020 and is used only when [year] is null.
String catalogQuery(String raw, {String? genre, int? year, int? decade}) {
  const base = 'collection:netlabels AND mediatype:audio AND format:MP3 '
      'AND (licenseurl:*creativecommons* OR licenseurl:*publicdomain*)';
  final parts = <String>[base];
  for (final item in musicGenres) {
    if (item.label == genre) {
      parts.add(item.clause);
      break;
    }
  }
  final range = _yearClause(year: year, decade: decade);
  if (range != null) parts.add(range);
  final words = raw
      .replaceAll(RegExp(r'[^A-Za-z0-9 \-]'), ' ')
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .take(6);
  final extra = words.map((word) => '($word)').join(' AND ');
  if (extra.isNotEmpty) parts.add('($extra)');
  return parts.join(' AND ');
}

String? _yearClause({int? year, int? decade}) {
  if (year != null && year >= 1990 && year <= 2035) return 'year:$year';
  if (decade == 2000 || decade == 2010 || decade == 2020) {
    final start = decade!;
    return 'year:[$start TO ${start + 9}]';
  }
  return null;
}

String catalogSearchUrl(String query, int page, {String? genre, int? year, int? decade}) {
  final q = Uri.encodeQueryComponent(catalogQuery(query, genre: genre, year: year, decade: decade));
  final sort = Uri.encodeQueryComponent('downloads desc');
  return 'https://archive.org/advancedsearch.php?q=$q'
      '&fl[]=identifier&fl[]=title&fl[]=creator&fl[]=licenseurl&fl[]=downloads&fl[]=year'
      '&sort[]=$sort&rows=20&page=$page&output=json';
}

String archiveDownloadUrl(String identifier, String fileName) {
  final id = Uri.encodeComponent(identifier);
  final path = fileName.split('/').map(Uri.encodeComponent).join('/');
  return 'https://archive.org/download/$id/$path';
}

/// Short label for a Creative Commons or public-domain license URL.
/// Returns null when the URL is missing or is some other license.
String? licenseLabel(String? url) {
  if (url == null || url.trim().isEmpty) return null;
  final u = url.toLowerCase();
  final open = u.contains('creativecommons.org') || u.contains('publicdomain');
  if (!open) return null;
  if (u.contains('publicdomain/zero') || u.contains('/publicdomain/zero')) {
    return 'CC0';
  }
  if (u.contains('publicdomain')) return 'Public domain';
  final match = RegExp(r'licenses/([a-z0-9-]+)/(\d+\.\d+)').firstMatch(u);
  if (match != null) {
    return 'CC ${match.group(1)!.toUpperCase()} ${match.group(2)}';
  }
  return 'Creative Commons';
}

String localFileName(String archiveName) {
  var base = archiveName.split(RegExp(r'[/\\]')).last.trim();
  if (base.isEmpty || base == '.' || base == '..') return 'track.mp3';
  return base;
}

CatalogPage parseCatalogPage(String body, {required int page}) {
  final json = _decodeMap(body);
  final response = json['response'];
  if (response is! Map) {
    throw const FreeMusicException('The catalog returned an unexpected response.');
  }
  final docs = response['docs'];
  final total = response['numFound'];
  final albums = <CatalogAlbum>[];
  if (docs is List) {
    for (final doc in docs) {
      if (doc is! Map) continue;
      final album = _albumFromDoc(doc);
      if (album != null) albums.add(album);
    }
  }
  return CatalogPage(
    albums: albums,
    total: total is int ? total : int.tryParse('$total') ?? albums.length,
    page: page,
  );
}

class ParsedRelease {
  final String license;
  final List<CatalogTrack> tracks;
  const ParsedRelease({required this.license, required this.tracks});
}

/// Throws [FreeMusicException] when the release has no open license.
ParsedRelease parseRelease(String body, CatalogAlbum album) {
  final json = _decodeMap(body);
  final meta = json['metadata'];
  final resolved = licenseLabel(meta is Map ? _asString(meta['licenseurl']) : null);
  if (resolved == null) {
    throw const FreeMusicException('This release has no open license.');
  }
  final files = json['files'];
  if (files is! List) {
    return ParsedRelease(license: resolved, tracks: const []);
  }
  final parsed = <_FileRow>[];
  for (final file in files) {
    if (file is! Map) continue;
    final name = _asString(file['name']);
    if (!name.toLowerCase().endsWith('.mp3')) continue;
    final format = _asString(file['format']);
    final title = _firstNonEmpty([
      _asString(file['title']),
      _titleFromFileName(name),
    ]);
    final artist = _firstNonEmpty([
      _asString(file['artist']),
      _asString(file['creator']),
      album.creator,
    ]);
    final albumName = _firstNonEmpty([
      _asString(file['album']),
      album.title,
    ]);
    parsed.add(_FileRow(
      name: name,
      title: title,
      artist: artist,
      album: albumName,
      durationMs: _durationMs(file['length']),
      sizeBytes: int.tryParse(_asString(file['size'])) ?? 0,
      trackNumber: _trackNumber(file['track']),
      genre: _emptyToNull(_asString(file['genre'])),
      lowBitrate: _lowBitrate(name, format),
    ));
  }
  final titlesWithFull = parsed.where((row) => !row.lowBitrate).map((row) => row.title.toLowerCase()).toSet();
  final tracks = parsed
      .where((row) => !row.lowBitrate || !titlesWithFull.contains(row.title.toLowerCase()))
      .map((row) => CatalogTrack(
            identifier: album.identifier,
            fileName: row.name,
            title: row.title,
            artist: row.artist,
            album: row.album,
            license: resolved,
            durationMs: row.durationMs,
            sizeBytes: row.sizeBytes,
            trackNumber: row.trackNumber,
            genre: row.genre,
          ))
      .toList();
  tracks.sort((a, b) {
    final an = a.trackNumber ?? 9999;
    final bn = b.trackNumber ?? 9999;
    if (an != bn) return an.compareTo(bn);
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  });
  return ParsedRelease(license: resolved, tracks: tracks);
}

class _FileRow {
  final String name;
  final String title;
  final String artist;
  final String album;
  final int durationMs;
  final int sizeBytes;
  final int? trackNumber;
  final String? genre;
  final bool lowBitrate;
  const _FileRow({
    required this.name,
    required this.title,
    required this.artist,
    required this.album,
    required this.durationMs,
    required this.sizeBytes,
    required this.trackNumber,
    required this.genre,
    required this.lowBitrate,
  });
}

CatalogAlbum? _albumFromDoc(Map doc) {
  final id = _asString(doc['identifier']);
  final title = _asString(doc['title']);
  final license = licenseLabel(_asString(doc['licenseurl']));
  if (id.isEmpty || title.isEmpty || license == null) return null;
  final downloads = doc['downloads'];
  return CatalogAlbum(
    identifier: id,
    title: title,
    creator: _firstNonEmpty([_asString(doc['creator']), 'Unknown artist']),
    license: license,
    downloads: downloads is int ? downloads : int.tryParse('$downloads') ?? 0,
    year: _catalogYear(doc['year']),
  );
}

int? _catalogYear(dynamic value) {
  final match = RegExp(r'(?:19|20)\d{2}').firstMatch(_asString(value));
  if (match == null) return null;
  final year = int.parse(match.group(0)!);
  if (year < 1990 || year > 2035) return null;
  return year;
}

Map<String, dynamic> _decodeMap(String body) {
  final decoded = _jsonDecode(body);
  if (decoded is! Map) {
    throw const FreeMusicException('The catalog returned an unexpected response.');
  }
  return decoded.map((key, value) => MapEntry(key.toString(), value));
}

dynamic _jsonDecode(String body) {
  try {
    return _decode(body);
  } on FormatException {
    throw const FreeMusicException('The catalog returned an unexpected response.');
  }
}

dynamic _decode(String body) => jsonDecode(body);

String _asString(dynamic value) {
  if (value == null) return '';
  if (value is String) return value.trim();
  if (value is num) return value.toString();
  if (value is List && value.isNotEmpty) return _asString(value.first);
  return value.toString().trim();
}

String _firstNonEmpty(List<String> values) {
  for (final value in values) {
    if (value.trim().isNotEmpty) return value.trim();
  }
  return 'Unknown';
}

String? _emptyToNull(String value) => value.trim().isEmpty ? null : value.trim();

String _titleFromFileName(String name) {
  final base = localFileName(name);
  final dot = base.lastIndexOf('.');
  final stem = dot > 0 ? base.substring(0, dot) : base;
  return stem.replaceAll('_', ' ').trim();
}

int _durationMs(dynamic length) {
  final seconds = double.tryParse(_asString(length));
  if (seconds == null || seconds <= 0) return 0;
  return (seconds * 1000).round();
}

int? _trackNumber(dynamic raw) {
  final text = _asString(raw);
  if (text.isEmpty) return null;
  return int.tryParse(text.split('/').first.trim());
}

bool _lowBitrate(String name, String format) {
  final blob = '${name.toLowerCase()} ${format.toLowerCase()}';
  return blob.contains('64kbps') || blob.contains('64 kbps') || blob.contains('_64kb');
}
