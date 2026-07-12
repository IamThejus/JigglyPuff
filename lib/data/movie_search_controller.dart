import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../api/endpoints.dart';
import '../api/models.dart';
import '../config.dart';

/// The visible state of the search screen.
enum SearchPhase { idle, loading, results, empty, error }

/// Debounced movie-search state machine.
///
///  - fires the API only after the user pauses typing for [debounce],
///  - ignores queries shorter than [minChars] (and empty ones) → [idle],
///  - cancels stale in-flight requests via a monotonic request id, so a slow
///    response for an old query can never overwrite a newer one,
///  - keeps the previous results on screen while a new query debounces, then
///    shows skeletons once the request actually starts.
class MovieSearchController extends ChangeNotifier {
  MovieSearchController(this._config);

  final AppConfig _config;

  static const int minChars = 2;
  static const Duration debounce = Duration(milliseconds: 350);

  Timer? _timer;
  int _requestId = 0;
  String _query = '';

  SearchPhase _phase = SearchPhase.idle;
  Object? _error;
  List<MovieSearchResult> _results = const [];

  String get query => _query;
  SearchPhase get phase => _phase;
  Object? get error => _error;
  List<MovieSearchResult> get results => _results;

  /// Call on every keystroke. Handles debounce, min-length and cancellation.
  void onQueryChanged(String raw) {
    _query = raw;
    _timer?.cancel();
    final q = raw.trim();

    if (q.length < minChars) {
      // Too short / empty → cancel any pending request and reset to idle.
      _requestId++;
      _set(phase: SearchPhase.idle, results: const [], error: null);
      return;
    }
    _timer = Timer(debounce, () => _search(q));
  }

  /// Re-run the current query (used by the error state's Retry).
  void retry() {
    final q = _query.trim();
    if (q.length >= minChars) _search(q);
  }

  Future<void> _search(String q) async {
    final id = ++_requestId;
    _set(phase: SearchPhase.loading);
    try {
      final res = await MediaServerApi(ApiClient(_config)).searchMovies(q);
      if (id != _requestId) return; // superseded by a newer keystroke
      _set(
        phase: res.results.isEmpty ? SearchPhase.empty : SearchPhase.results,
        results: res.results,
        error: null,
      );
    } on ApiException catch (e) {
      if (id != _requestId) return;
      _set(phase: SearchPhase.error, error: e);
    } catch (e) {
      if (id != _requestId) return;
      _set(phase: SearchPhase.error, error: e);
    }
  }

  void _set({required SearchPhase phase, List<MovieSearchResult>? results, Object? error}) {
    _phase = phase;
    if (results != null) _results = results;
    _error = error;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _requestId++; // invalidate any in-flight response
    super.dispose();
  }
}
