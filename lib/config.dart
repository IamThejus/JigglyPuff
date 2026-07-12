import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Runtime app configuration, persisted with SharedPreferences.
///
/// The base URL changes between LAN IP and remote access, so it must be
/// editable in-app (see the Settings screen). [authToken] is unused in the
/// read-only v1 API but is wired end-to-end so v2 control actions can send an
/// `Authorization` header without touching call sites.
class AppConfig extends ChangeNotifier {
  AppConfig._(this._prefs)
      : _baseUrl = _prefs.getString(_kBaseUrl) ?? defaultBaseUrl,
        _authToken = _prefs.getString(_kAuthToken) ?? '',
        _apiKey = _prefs.getString(_kApiKey) ?? '',
        _refreshSeconds = _prefs.getInt(_kRefreshSeconds) ?? 10;

  static const _kBaseUrl = 'baseUrl';
  static const _kAuthToken = 'authToken';
  static const _kApiKey = 'apiKey';
  static const _kRefreshSeconds = 'refreshSeconds';

  /// Sensible LAN default matching the backend dev instructions.
  static const defaultBaseUrl = 'http://192.168.1.50:8000';

  /// User-selectable auto-refresh cadences (Settings → Refresh Interval).
  static const refreshOptions = <int>[5, 10, 15, 30, 60];

  static const Duration requestTimeout = Duration(seconds: 10);

  /// Control actions (esp. sync-movies, which moves files) can run much longer
  /// than a read request, so POSTs get a generous timeout.
  static const Duration actionTimeout = Duration(minutes: 3);

  final SharedPreferences _prefs;

  String _baseUrl;
  String _authToken;
  String _apiKey;
  int _refreshSeconds;

  String get baseUrl => _baseUrl;
  String get authToken => _authToken;
  bool get hasAuthToken => _authToken.trim().isNotEmpty;

  /// Key for the authenticated `POST /actions/*` control endpoints, sent as the
  /// `X-API-Key` header (matches the server's `ACTIONS_API_KEY`). Empty = the
  /// control actions are disabled in the UI.
  String get apiKey => _apiKey;
  bool get hasApiKey => _apiKey.trim().isNotEmpty;

  /// Header map for authenticated requests (images/future POSTs). Null in v1.
  Map<String, String>? get authHeader =>
      hasAuthToken ? {'Authorization': 'Bearer $_authToken'} : null;

  /// `X-API-Key` header for `POST /actions/*`. Null when no key is configured.
  Map<String, String>? get actionHeader =>
      hasApiKey ? {'X-API-Key': _apiKey.trim()} : null;

  /// Resolves a possibly-relative API URL (e.g. `poster_url` = `/api/v1/...`)
  /// against the configured base URL. Returns null for null/empty input.
  String? resolveUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    final base = _baseUrl.replaceAll(RegExp(r'/+$'), '');
    return '$base${url.startsWith('/') ? '' : '/'}$url';
  }

  /// Base URL trimmed of any trailing slashes, e.g. `http://host:8000`.
  String get normalizedBase => _baseUrl.replaceAll(RegExp(r'/+$'), '');

  /// Builds the `ws://…/api/v1/torrents/ws` URL (with an optional `state`
  /// filter) from the HTTP base URL, mapping http→ws / https→wss.
  Uri torrentsWsUri({String? state}) {
    final ws = normalizedBase
        .replaceFirst(RegExp(r'^http://'), 'ws://')
        .replaceFirst(RegExp(r'^https://'), 'wss://');
    return Uri.parse('$ws/api/v1/torrents/ws')
        .replace(queryParameters: state == null ? null : {'state': state});
  }

  /// The primary polling cadence for live screens (dashboard/system/torrents…).
  int get refreshSeconds => _refreshSeconds;
  Duration get refreshInterval => Duration(seconds: _refreshSeconds);

  static Future<AppConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppConfig._(prefs);
  }

  Future<void> update({
    String? baseUrl,
    String? authToken,
    String? apiKey,
    int? refreshSeconds,
  }) async {
    var changed = false;
    if (baseUrl != null && baseUrl.trim() != _baseUrl) {
      _baseUrl = baseUrl.trim();
      await _prefs.setString(_kBaseUrl, _baseUrl);
      changed = true;
    }
    if (authToken != null && authToken != _authToken) {
      _authToken = authToken;
      await _prefs.setString(_kAuthToken, _authToken);
      changed = true;
    }
    if (apiKey != null && apiKey != _apiKey) {
      _apiKey = apiKey;
      await _prefs.setString(_kApiKey, _apiKey);
      changed = true;
    }
    if (refreshSeconds != null && refreshSeconds != _refreshSeconds) {
      _refreshSeconds = refreshSeconds;
      await _prefs.setInt(_kRefreshSeconds, _refreshSeconds);
      changed = true;
    }
    if (changed) notifyListeners();
  }
}
