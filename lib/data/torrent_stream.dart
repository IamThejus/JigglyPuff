import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../api/api_client.dart';
import '../api/endpoints.dart';
import '../api/models.dart';
import '../config.dart';
import '../widgets/states.dart';
import 'async_value.dart';
import 'polling_view.dart';

/// Streams live `TorrentList` snapshots from `GET /api/v1/torrents/ws` (~every
/// 2s), and degrades gracefully:
///  - seeds immediately with a REST `torrents/list` fetch (no long spinner),
///  - if the WebSocket can't connect or drops, **falls back to REST polling**
///    at the configured refresh interval and keeps retrying the socket with
///    exponential backoff,
///  - pauses while the app is backgrounded, resumes on foreground.
///
/// So this works whether or not a given backend build actually has the `/ws`
/// route — a missing socket just means it runs as a normal poller.
class TorrentStreamController extends ChangeNotifier with WidgetsBindingObserver {
  TorrentStreamController({
    required this.api,
    required this.state,
    required this.pollFallback,
  }) {
    WidgetsBinding.instance.addObserver(this);
    _seedAndConnect();
  }

  final MediaServerApi api;
  String? state; // the active `?state=` filter; changeable via [changeFilter]
  final Duration pollFallback;

  AsyncValue<TorrentList> _value = const AsyncValue.loading();
  AsyncValue<TorrentList> get value => _value;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _reconnect;
  Timer? _restTimer;
  int _attempt = 0;
  bool _live = false; // WS is delivering messages
  bool _disposed = false;

  /// True while the WebSocket is actively pushing snapshots (vs. REST fallback).
  bool get isLive => _live;

  Future<void> _seedAndConnect() async {
    await _restFetch(); // fast first paint via REST
    _connectWs();
  }

  Future<void> _connectWs() async {
    if (_disposed) return;
    try {
      final channel = WebSocketChannel.connect(api.torrentsWsUri(state: state));
      await channel.ready; // throws if the connection fails
      if (_disposed) {
        channel.sink.close();
        return;
      }
      _channel = channel;
      _attempt = 0;
      _sub = channel.stream.listen(
        _onMessage,
        onError: (_) => _onDisconnected(),
        onDone: _onDisconnected,
        cancelOnError: true,
      );
    } catch (_) {
      _onDisconnected();
    }
  }

  void _onMessage(dynamic raw) {
    _live = true;
    _stopRestFallback();
    if (raw is! String) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        _value = AsyncValue.data(TorrentList.fromJson(decoded));
        _safeNotify();
      }
    } catch (_) {
      // Ignore a single malformed frame; the next snapshot is a full replace.
    }
  }

  void _onDisconnected() {
    if (_disposed) return;
    _live = false;
    _sub?.cancel();
    _sub = null;
    _channel = null;
    _startRestFallback();
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnect?.cancel();
    // 2, 4, 8, 16, 30, 30… seconds.
    final secs = (1 << (_attempt + 1)).clamp(2, 30);
    _attempt = (_attempt + 1).clamp(0, 5);
    _reconnect = Timer(Duration(seconds: secs), _connectWs);
  }

  void _startRestFallback() {
    if (_restTimer != null) return;
    _restFetch();
    _restTimer = Timer.periodic(pollFallback, (_) {
      if (!_live) _restFetch();
    });
  }

  void _stopRestFallback() {
    _restTimer?.cancel();
    _restTimer = null;
  }

  Future<void> _restFetch() async {
    try {
      final list = await api.torrentsList(state: state);
      if (_disposed || _live) return; // a WS frame already won
      _value = AsyncValue.data(list);
    } on ApiException catch (e) {
      if (_disposed) return;
      if (!_value.hasData) _value = AsyncValue.error(e); // only if we have nothing to show
    }
    _safeNotify();
  }

  /// Pull-to-refresh: a one-off REST fetch (the socket keeps streaming anyway).
  Future<void> refresh() => _restFetch();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _seedAndConnect();
    } else {
      _teardownConnection();
    }
  }

  void _teardownConnection() {
    _reconnect?.cancel();
    _stopRestFallback();
    _sub?.cancel();
    _sub = null;
    _channel?.sink.close();
    _channel = null;
    _live = false;
  }

  /// Switch the `?state=` filter in place — reconnects for the new filter while
  /// **keeping the current list on screen** (no spinner flash on tab switch).
  void changeFilter(String? newState) {
    if (newState == state || _disposed) return;
    state = newState;
    _attempt = 0;
    _teardownConnection(); // keeps _value (previous list) intact
    _seedAndConnect();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _teardownConnection();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

/// Declarative wrapper mirroring [PollingView], but backed by the live torrent
/// socket. Handles loading / hard-error; the builder handles the degraded
/// (`reachable == false`) case since that's a valid snapshot.
class TorrentStreamView extends StatefulWidget {
  const TorrentStreamView({
    super.key,
    required this.state,
    required this.builder,
    this.loadingLabel,
  });

  final String? state;
  final String? loadingLabel;
  final Widget Function(BuildContext context, TorrentList data, TorrentStreamController controller)
      builder;

  @override
  State<TorrentStreamView> createState() => _TorrentStreamViewState();
}

class _TorrentStreamViewState extends State<TorrentStreamView> {
  TorrentStreamController? _controller;
  String? _boundBase;
  String? _boundState;
  int? _boundRefresh;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final config = context.watch<AppConfig>();
    if (_controller == null ||
        _boundBase != config.baseUrl ||
        _boundState != widget.state ||
        _boundRefresh != config.refreshSeconds) {
      _boundBase = config.baseUrl;
      _boundState = widget.state;
      _boundRefresh = config.refreshSeconds;
      _controller?.dispose();
      _controller = TorrentStreamController(
        api: MediaServerApi(ApiClient(config)),
        state: widget.state,
        pollFallback: config.refreshInterval,
      );
    }
  }

  @override
  void didUpdateWidget(TorrentStreamView old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state) {
      // Switch the filter in place so the current list stays visible (no flash).
      _boundState = widget.state;
      _controller?.changeFilter(widget.state);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller!;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final v = controller.value;
        if (v.isInitialLoading) return LoadingState(label: widget.loadingLabel);
        if (!v.hasData && v.hasError) {
          return ErrorState(error: v.error!, onRetry: controller.refresh);
        }
        return widget.builder(context, v.data as TorrentList, controller);
      },
    );
  }
}
