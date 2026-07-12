import 'api_client.dart';
import 'models.dart';

/// The single place that knows about API routes. Keeping every path here means
/// adding v2 control actions (POST pause/resume/restart/reboot) is a localized
/// change — call sites only ever see typed methods.
class MediaServerApi {
  MediaServerApi(this._client);

  final ApiClient _client;

  Future<Health> health() => _client.getJson('/health', Health.fromJson);

  Future<Dashboard> dashboard() => _client.getJson('/dashboard', Dashboard.fromJson);

  Future<TorrentsSummary> torrentsSummary() =>
      _client.getJson('/torrents/summary', TorrentsSummary.fromJson);

  /// [state] is optional: `downloading` | `seeding` | `completed`.
  Future<TorrentList> torrentsList({String? state}) => _client.getJson(
        '/torrents/list',
        TorrentList.fromJson,
        query: {'state': ?state},
      );

  Future<StorageSummary> storageSummary({bool folderSizes = true}) => _client.getJson(
        '/storage/summary',
        StorageSummary.fromJson,
        query: {'folder_sizes': folderSizes},
      );

  Future<SystemOverview> systemOverview() =>
      _client.getJson('/system/overview', SystemOverview.fromJson);

  Future<LibrarySummary> librarySummary() =>
      _client.getJson('/library/summary', LibrarySummary.fromJson);

  Future<LibraryList> movies({bool sizes = false}) => _client.getJson(
        '/library/movies',
        LibraryList.fromJson,
        query: {'sizes': sizes},
      );

  Future<LibraryList> shows({bool sizes = false}) => _client.getJson(
        '/library/shows',
        LibraryList.fromJson,
        query: {'sizes': sizes},
      );

  Future<ServicesResponse> services() =>
      _client.getJson('/services', ServicesResponse.fromJson);

  // --- Movie discovery (TMDB-backed search + torrent lookup) --------------

  /// Search movies by title. Caller enforces the min-length / debounce.
  Future<MovieSearchResponse> searchMovies(String query) => _client.getJson(
        '/movies/search',
        MovieSearchResponse.fromJson,
        query: {'q': query},
      );

  /// Torrents available for a movie title (sorted highest-seeds-first by the
  /// model). Feed a returned `magnetUrl` into [addTorrentUrl] to download.
  Future<MovieTorrentsResponse> movieTorrents(String title) => _client.getJson(
        '/movies/torrents',
        MovieTorrentsResponse.fromJson,
        query: {'title': title},
      );

  // --- Real-time torrents (WebSocket) -------------------------------------

  /// `ws://…/api/v1/torrents/ws` — pushes a full `TorrentList` snapshot ~every
  /// 2s. Same optional [state] filter as [torrentsList].
  Uri torrentsWsUri({String? state}) => _client.config.torrentsWsUri(state: state);

  // --- Control actions (POST, require X-API-Key) --------------------------

  /// Add a torrent by magnet link or `http(s)` .torrent URL.
  Future<ActionResult> addTorrentUrl(String url) =>
      _client.postJson('/actions/torrents', ActionResult.fromJson, body: {'url': url});

  /// Add a torrent by uploading a local `.torrent` file's [bytes].
  Future<ActionResult> addTorrentFile({required List<int> bytes, required String filename}) =>
      _client.postMultipart('/actions/torrents/file', ActionResult.fromJson,
          bytes: bytes, filename: filename);

  /// Pause a torrent (stays in the list, resumable). [hash] from a list item.
  Future<ActionResult> pauseTorrent(String hash) =>
      _client.postJson('/actions/torrents/pause', ActionResult.fromJson, body: {'hash': hash});

  /// Resume a paused torrent.
  Future<ActionResult> resumeTorrent(String hash) =>
      _client.postJson('/actions/torrents/resume', ActionResult.fromJson, body: {'hash': hash});

  /// Remove a torrent **and delete its files on disk**. Destructive — confirm
  /// in the UI first.
  Future<ActionResult> deleteTorrent(String hash) =>
      _client.postJson('/actions/torrents/delete', ActionResult.fromJson, body: {'hash': hash});

  /// Run the server-side "move completed downloads into the movies library"
  /// script (also clears the qBittorrent entries for moved items). Manual only.
  Future<ActionResult> syncMovies() =>
      _client.postJson('/actions/sync-movies', ActionResult.fromJson);
}
