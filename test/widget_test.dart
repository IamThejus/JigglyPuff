// Unit tests for the API model parsers. These exercise the "never fails when a
// subsystem is down" contract: degraded flags parse into plain fields, not
// exceptions.
import 'package:flutter_test/flutter_test.dart';
import 'package:jigglypuff/api/models.dart';
import 'package:jigglypuff/config.dart';
import 'package:jigglypuff/utils/format.dart';
import 'package:jigglypuff/utils/media_title.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Movie search/torrents', () {
    test('MovieSearchResult parses the documented shape', () {
      final r = MovieSearchResult.fromJson(const {
        'id': 10033,
        'title': 'Just Friends',
        'year': '2005',
        'language': 'en',
        'rating': 6.204,
        'overview': 'A comedy…',
        'thumbnail': 'https://image.tmdb.org/t/p/w342/x.jpg',
      });
      expect(r.id, 10033);
      expect(r.title, 'Just Friends');
      expect(r.year, '2005');
      expect(r.rating, closeTo(6.204, 0.001));
    });

    test('MovieTorrentsResponse sorts highest-seeds-first + infers quality/size', () {
      final res = MovieTorrentsResponse.fromJson(const {
        'success': true,
        'results': [
          {'title': 'Just Friends (2005) 720p BrRip x264', 'seeds': 23, 'peers': 1, 'bytes': 629795717, 'magnetUrl': 'magnet:a'},
          {'title': 'Just Friends 2005 1080p BluRay', 'seeds': 90, 'peers': 4, 'bytes': 1610612736, 'magnetUrl': 'magnet:b'},
        ],
      });
      expect(res.results.first.seeds, 90); // sorted desc
      expect(res.results.first.qualityTags, containsAll(['1080p', 'BluRay']));
      expect(res.results.last.qualityTags, containsAll(['720p', 'BRRip']));
      expect(res.results[1].sizeHuman, '600.6 MB'); // 629795717 bytes
    });

    test('Fmt.bytes formats sizes', () {
      expect(Fmt.bytes(0), '0 B');
      expect(Fmt.bytes(1610612736), '1.5 GB');
      expect(Fmt.bytes(512), '512 B');
    });

    test('inferQualityTags normalises 4K and de-dupes', () {
      expect(inferQualityTags('Movie 2160p WEB-DL HDR'), containsAll(['2160p', 'WEB-DL', 'HDR']));
      expect(inferQualityTags('Movie 4K UHD BluRay'), contains('2160p'));
    });
  });

  group('MediaTitle', () {
    test('parses a dotted release name', () {
      final m = MediaTitle.parse('The.Dark.Knight.Rises.2012.2160p.HDR.BluRay.x265');
      expect(m.title, 'The Dark Knight Rises');
      expect(m.year, 2012);
      expect(m.quality, '2160p');
      expect(m.hdr, isTrue);
      expect(m.tags, ['2160p', 'HDR']);
    });

    test('parses a "Title (Year) …" name and normalises 4K', () {
      final m = MediaTitle.parse('Inception (2010) 4K BluRay x265');
      expect(m.title, 'Inception');
      expect(m.year, 2010);
      expect(m.quality, '2160p'); // 4K → 2160p
      expect(m.hdr, isFalse);
    });

    test('backend fields win over parsing', () {
      final m = MediaTitle.of(rawName: 'Whatever.2001.720p', year: 1999, quality: '1080p', hdr: true);
      expect(m.year, 1999);
      expect(m.quality, '1080p');
      expect(m.hdr, isTrue);
    });

    test('falls back gracefully with no metadata', () {
      final m = MediaTitle.parse('Home Videos');
      expect(m.title, 'Home Videos');
      expect(m.year, isNull);
      expect(m.quality, isNull);
      expect(m.tags, isEmpty);
    });
  });

  test('Dashboard parses the documented shape', () {
    final d = Dashboard.fromJson(const {
      'hostname': 'dell-server',
      'server_name': 'Dell Media Server',
      'uptime_seconds': 3589,
      'uptime_human': '59m',
      'cpu_percent': 4.2,
      'memory_percent': 35.1,
      'disk_percent_used': 61.0,
      'storage': {
        'primary_path': '/srv/storage',
        'total_human': '3.6 TB',
        'used_human': '2.2 TB',
        'free_human': '1.4 TB',
        'percent_used': 61.0,
      },
      'torrents_active': 3,
      'torrents_downloading': 1,
      'torrents_seeding': 2,
      'torrents_reachable': true,
      'movies_count': 214,
      'shows_count': 37,
      'services': [
        {'name': 'jellyfin', 'active': true, 'state': 'active', 'sub_state': 'running', 'enabled': true}
      ],
      'generated_at_iso': '2026-07-09T16:04:11+00:00',
    });

    expect(d.hostname, 'dell-server');
    expect(d.storage.percentUsed, 61.0);
    expect(d.services.single.name, 'jellyfin');
    expect(d.torrentsReachable, isTrue);
  });

  test('TorrentsSummary treats an offline client as a flag, not an error', () {
    final s = TorrentsSummary.fromJson(const {
      'reachable': false,
      'message': 'qBittorrent connection refused',
    });
    expect(s.reachable, isFalse);
    expect(s.message, contains('qBittorrent'));
    expect(s.total, 0); // missing numbers default gracefully
  });

  test('SmartInfo.available=false parses without throwing', () {
    final smart = SmartInfo.fromJson(const {'available': false, 'message': 'no root'});
    expect(smart.available, isFalse);
    expect(smart.temperatureCelsius, isNull);
  });

  test('LibraryItem parses the new artwork/metadata fields', () {
    final item = LibraryItem.fromJson(const {
      'name': 'Interstellar (2014)',
      'path': '/srv/storage/media/movies/Interstellar (2014)',
      'is_dir': true,
      'poster_url': '/api/v1/library/artwork?id=a1b2c3d4&size=poster',
      'thumb_url': '/api/v1/library/artwork?id=a1b2c3d4&size=thumb',
      'year': 2014,
      'quality': '2160p',
      'hdr': true,
      'jellyfin_id': 'a1b2c3d4',
    });
    expect(item.posterUrl, contains('artwork'));
    expect(item.year, 2014);
    expect(item.quality, '2160p');
    expect(item.hdr, isTrue);
    expect(item.jellyfinId, 'a1b2c3d4');
  });

  test('LibraryItem without artwork leaves fields null (placeholder path)', () {
    final item = LibraryItem.fromJson(const {'name': 'X', 'path': '/x'});
    expect(item.posterUrl, isNull);
    expect(item.hdr, isFalse); // hdr is never null
  });

  test('TorrentsSummary.clientLabel joins name + version + node', () {
    final s = TorrentsSummary.fromJson(const {
      'reachable': true,
      'client_name': 'qBittorrent',
      'client_version': '4.5.2',
      'node': null,
    });
    expect(s.clientLabel, 'qBittorrent · v4.5.2');
  });

  test('ActionResult parses ok, message, and sync-movies exit_code/output', () {
    final add = ActionResult.fromJson(const {'ok': true, 'message': null});
    expect(add.ok, isTrue);
    expect(add.message, isNull);

    final softFail = ActionResult.fromJson(const {'ok': false, 'message': 'client unreachable'});
    expect(softFail.ok, isFalse);
    expect(softFail.message, 'client unreachable');

    final sync = ActionResult.fromJson(const {
      'ok': true,
      'exit_code': 0,
      'output': 'moved 2 files',
      'message': null,
      'moved': ['Ted (2012) [1080p]', 'Lucy.2014.mkv'],
      'skipped': ['Vanilla Sky'],
      'torrents_removed': 2,
    });
    expect(sync.exitCode, 0);
    expect(sync.moved, hasLength(2));
    expect(sync.skipped, ['Vanilla Sky']);
    expect(sync.torrentsRemoved, 2);
    expect(sync.syncSummary, 'Moved 2 · skipped 1 · removed 2 torrents');
  });

  test('ActionResult.syncSummary omits empty parts', () {
    final r = ActionResult.fromJson(const {'ok': true, 'moved': [], 'torrents_removed': 0});
    expect(r.syncSummary, 'Moved 0');
  });

  group('AppConfig', () {
    test('torrentsWsUri maps http→ws and appends the route + state filter', () async {
      SharedPreferences.setMockInitialValues({'baseUrl': 'http://192.168.1.50:8000/'});
      final config = await AppConfig.load();

      expect(config.torrentsWsUri().toString(), 'ws://192.168.1.50:8000/api/v1/torrents/ws');
      expect(config.torrentsWsUri(state: 'downloading').toString(),
          'ws://192.168.1.50:8000/api/v1/torrents/ws?state=downloading');
    });

    test('resolveUrl joins relative artwork paths and passes absolutes through', () async {
      SharedPreferences.setMockInitialValues({'baseUrl': 'http://host:8000'});
      final config = await AppConfig.load();

      expect(config.resolveUrl('/api/v1/library/artwork?id=x'),
          'http://host:8000/api/v1/library/artwork?id=x');
      expect(config.resolveUrl('https://cdn/x.jpg'), 'https://cdn/x.jpg');
      expect(config.resolveUrl(null), isNull);
    });

    test('actionHeader is null without a key and set with one', () async {
      SharedPreferences.setMockInitialValues({'apiKey': 'secret'});
      final withKey = await AppConfig.load();
      expect(withKey.actionHeader, {'X-API-Key': 'secret'});

      SharedPreferences.setMockInitialValues({});
      final noKey = await AppConfig.load();
      expect(noKey.actionHeader, isNull);
    });
  });
}

