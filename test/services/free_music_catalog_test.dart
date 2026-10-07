import 'package:flutter_test/flutter_test.dart';
import 'package:omniplayer/services/free_music/catalog.dart';

void main() {
  test('license labels cover commons and public domain', () {
    expect(
      licenseLabel('http://creativecommons.org/licenses/by-nc-sa/4.0/'),
      'CC BY-NC-SA 4.0',
    );
    expect(
      licenseLabel('https://creativecommons.org/licenses/by/4.0/'),
      'CC BY 4.0',
    );
    expect(
      licenseLabel('https://creativecommons.org/publicdomain/zero/1.0/'),
      'CC0',
    );
    expect(
      licenseLabel('http://creativecommons.org/publicdomain/mark/1.0/'),
      'Public domain',
    );
    expect(licenseLabel('https://example.com/all-rights-reserved'), isNull);
    expect(licenseLabel(null), isNull);
  });

  test('search stays inside the netlabel collection', () {
    expect(catalogQuery(''), contains('collection:netlabels'));
    expect(catalogQuery('jazz!'), contains('(jazz)'));
    expect(catalogQuery('jazz!'), isNot(contains('!')));
    expect(catalogQuery('', genre: 'Jazz'), contains('subject:jazz'));
    expect(catalogQuery('', genre: 'Not a genre'), isNot(contains('subject:')));
    expect(catalogQuery('', year: 2012), contains('year:2012'));
    expect(catalogQuery('', decade: 2010), contains('year:[2010 TO 2019]'));
    expect(catalogQuery('piano', genre: 'Ambient', year: 2016), contains('subject:(ambient OR drone OR soundscape)'));
    expect(catalogQuery('piano', genre: 'Ambient', year: 2016), contains('year:2016'));
    final url = catalogSearchUrl('piano', 2, genre: 'Jazz', decade: 2020);
    expect(url, contains('page=2'));
    expect(url, contains('output=json'));
    expect(url, isNot(contains(' ')));
  });

  test('search drops releases with no open license', () {
    const body = '''
    {"response":{"numFound":2,"docs":[
      {"identifier":"ok1","title":"Night","creator":"Ada","licenseurl":"https://creativecommons.org/licenses/by/4.0/","downloads":12,"year":"2014"},
      {"identifier":"nope","title":"Secret","creator":"X","downloads":99}
    ]}}
    ''';
    final page = parseCatalogPage(body, page: 1);
    expect(page.albums, hasLength(1));
    expect(page.albums.single.identifier, 'ok1');
    expect(page.albums.single.license, 'CC BY 4.0');
    expect(page.albums.single.year, 2014);
    expect(page.total, 2);
  });

  test('release parser keeps mp3 songs and the license', () {
    const body = '''
    {"metadata":{"licenseurl":"http://creativecommons.org/licenses/by-nc-sa/4.0/","title":"Day"},
     "files":[
      {"name":"notes.txt","format":"Text"},
      {"name":"01-song.mp3","format":"VBR MP3","title":"Song","artist":"Ada","album":"Day","track":"1/2","length":"90.5","size":"400000","genre":"folk"},
      {"name":"01-song_64kb.mp3","format":"64Kbps MP3","title":"Song","artist":"Ada","length":"90","size":"80000"},
      {"name":"02-other.flac","format":"Flac","title":"Other"}
    ]}
    ''';
    final album = const CatalogAlbum(
      identifier: 'day1',
      title: 'Day',
      creator: 'Ada',
      license: 'CC BY-NC-SA 4.0',
      downloads: 3,
    );
    final release = parseRelease(body, album);
    expect(release.license, 'CC BY-NC-SA 4.0');
    expect(release.tracks, hasLength(1));
    final track = release.tracks.single;
    expect(track.title, 'Song');
    expect(track.artist, 'Ada');
    expect(track.trackNumber, 1);
    expect(track.durationMs, 90500);
    expect(track.downloadUrl, contains('archive.org/download/day1/01-song.mp3'));
    expect(track.genre, 'folk');
  });

  test('a release with no license url is refused', () {
    const album = CatalogAlbum(
      identifier: 'x',
      title: 'X',
      creator: 'Y',
      license: 'CC BY 4.0',
      downloads: 1,
    );
    expect(
      () => parseRelease('{"metadata":{"title":"X"},"files":[]}', album),
      throwsA(isA<FreeMusicException>()),
    );
  });

  test('download urls encode spaces in the file name', () {
    expect(
      archiveDownloadUrl('ab c', 'my song.mp3'),
      'https://archive.org/download/ab%20c/my%20song.mp3',
    );
  });
}
