import 'dart:convert';
import 'dart:io';

import 'catalog.dart';

/// Fetches the netlabel catalog. Callers stay inside the app.
class FreeMusicCatalog {
  const FreeMusicCatalog();

  Future<CatalogPage> search(
    String query, {
    int page = 1,
    String? genre,
    int? year,
    int? decade,
  }) async {
    final body = await _getString(Uri.parse(
      catalogSearchUrl(query, page, genre: genre, year: year, decade: decade),
    ));
    return parseCatalogPage(body, page: page);
  }

  Future<ParsedRelease> release(CatalogAlbum album) async {
    final body = await _getString(
      Uri.parse('https://archive.org/metadata/${Uri.encodeComponent(album.identifier)}'),
    );
    return parseRelease(body, album);
  }

  Future<void> download(
    CatalogTrack track,
    File dest, {
    void Function(int received, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final part = File('${dest.path}.part');
    final client = HttpClient();
    IOSink? sink;
    try {
      final request = await client.getUrl(Uri.parse(track.downloadUrl)).timeout(const Duration(seconds: 20));
      request.headers.set(HttpHeaders.userAgentHeader, catalogUserAgent);
      final response = await request.close().timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw FreeMusicException('Download failed (${response.statusCode}).');
      }
      final total = response.contentLength;
      await dest.parent.create(recursive: true);
      sink = part.openWrite();
      var received = 0;
      await for (final chunk in response) {
        if (isCancelled?.call() == true) {
          throw const FreeMusicException('cancelled');
        }
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
      await sink.flush();
      await sink.close();
      sink = null;
      if (received < 32000) {
        throw const FreeMusicException('That file was too small to be a song.');
      }
      if (!await _looksLikeMp3(part)) {
        throw const FreeMusicException('The download was not an MP3.');
      }
      if (await dest.exists()) await dest.delete();
      await part.rename(dest.path);
    } on FreeMusicException {
      await _drop(part);
      rethrow;
    } catch (_) {
      await _drop(part);
      throw const FreeMusicException('Download failed. Check your connection.');
    } finally {
      try {
        await sink?.close();
      } catch (_) {}
      client.close(force: true);
    }
  }

  Future<String> _getString(Uri uri) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri).timeout(const Duration(seconds: 20));
      request.headers.set(HttpHeaders.userAgentHeader, catalogUserAgent);
      final response = await request.close().timeout(const Duration(seconds: 25));
      if (response.statusCode != 200) {
        throw FreeMusicException('The catalog did not respond (${response.statusCode}).');
      }
      return await response.transform(utf8.decoder).join();
    } on FreeMusicException {
      rethrow;
    } catch (_) {
      throw const FreeMusicException('Could not reach the music catalog. Check your connection.');
    } finally {
      client.close(force: true);
    }
  }
}

Future<bool> _looksLikeMp3(File file) async {
  final header = await file.openRead(0, 3).fold<List<int>>(<int>[], (bytes, chunk) {
    bytes.addAll(chunk);
    return bytes;
  });
  if (header.length < 3) return false;
  final id3 = header[0] == 0x49 && header[1] == 0x44 && header[2] == 0x33;
  final frame = header[0] == 0xFF && (header[1] & 0xE0) == 0xE0;
  return id3 || frame;
}

Future<void> _drop(File part) async {
  try {
    if (await part.exists()) await part.delete();
  } catch (_) {}
}
