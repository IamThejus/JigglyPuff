import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../api/endpoints.dart';
import '../config.dart';
import '../widgets/states.dart';
import 'async_value.dart';

/// Drives one query: fetch-on-mount, auto-refetch on an interval, keep previous
/// data across refetches, pull-to-refresh, and pause while backgrounded. This
/// is the app's equivalent of a React Query `useQuery` + `refetchInterval`.
class PollController<T> extends ChangeNotifier with WidgetsBindingObserver {
  PollController({
    required this.fetch,
    required this.api,
    this.interval,
  }) {
    WidgetsBinding.instance.addObserver(this);
    refresh();
    _arm();
  }

  Future<T> Function(MediaServerApi api) fetch; // mutable: args can change (see refetchKey)
  final MediaServerApi api;
  final Duration? interval;

  AsyncValue<T> _value = const AsyncValue.loading();
  AsyncValue<T> get value => _value;

  Timer? _timer;
  bool _disposed = false;
  int _requestId = 0;

  void _arm() {
    _timer?.cancel();
    if (interval != null) {
      _timer = Timer.periodic(interval!, (_) => refresh());
    }
  }

  /// Runs a fetch. Returns a Future so `RefreshIndicator` can await it.
  Future<void> refresh() async {
    final id = ++_requestId;
    // Preserve on-screen data during the refetch (keepPreviousData).
    _value = AsyncValue.loadingWith(_value.data);
    _safeNotify();
    try {
      final result = await fetch(api);
      if (_disposed || id != _requestId) return;
      _value = AsyncValue.data(result);
    } on ApiException catch (e) {
      if (_disposed || id != _requestId) return;
      _value = AsyncValue.error(e, previous: _value.data);
    } catch (e) {
      if (_disposed || id != _requestId) return;
      _value = AsyncValue.error(e, previous: _value.data);
    }
    _safeNotify();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Stop polling in the background; refetch immediately on resume.
    if (state == AppLifecycleState.resumed) {
      refresh();
      _arm();
    } else {
      _timer?.cancel();
    }
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

/// Declarative wrapper: handles the loading / error (backend down) states for
/// you and hands the widget tree the successful [T]. "Degraded" subsystem
/// states (reachable=false, etc.) live inside [builder] because they are valid
/// successful responses.
class PollingView<T> extends StatefulWidget {
  const PollingView({
    super.key,
    required this.fetch,
    required this.builder,
    this.interval,
    this.loadingLabel,
    this.refetchKey,
  });

  final Future<T> Function(MediaServerApi api) fetch;

  /// Overrides the global refresh cadence. When null, the user's configured
  /// Refresh Interval (Settings) is used. Pass [Duration.zero] to poll once.
  final Duration? interval;
  final String? loadingLabel;

  /// When this value changes, the view re-fetches **keeping the previous data
  /// on screen** (no full-screen spinner) — for query-param toggles like the
  /// Library movies/shows switch or the sizes toggle. Prefer this over a
  /// [Key], which would remount and flash the loading state.
  final Object? refetchKey;

  /// Called with successful data + the controller (for pull-to-refresh).
  final Widget Function(BuildContext context, T data, PollController<T> controller) builder;

  @override
  State<PollingView<T>> createState() => _PollingViewState<T>();
}

class _PollingViewState<T> extends State<PollingView<T>> {
  PollController<T>? _controller;
  String? _boundBaseUrl;
  String? _boundToken;
  int? _boundRefresh;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Rebuild the controller (and re-fetch) whenever the connection config or
    // the refresh cadence changes, e.g. after editing them in Settings.
    final config = context.watch<AppConfig>();
    if (_controller == null ||
        _boundBaseUrl != config.baseUrl ||
        _boundToken != config.authToken ||
        _boundRefresh != config.refreshSeconds) {
      _boundBaseUrl = config.baseUrl;
      _boundToken = config.authToken;
      _boundRefresh = config.refreshSeconds;
      final interval = widget.interval == Duration.zero
          ? null
          : (widget.interval ?? config.refreshInterval);
      _controller?.dispose();
      _controller = PollController<T>(
        api: MediaServerApi(ApiClient(config)),
        fetch: widget.fetch,
        interval: interval,
      );
    }
  }

  @override
  void didUpdateWidget(PollingView<T> old) {
    super.didUpdateWidget(old);
    // A query-param toggle (e.g. movies↔shows, sizes on/off): re-fetch with the
    // new args but keep the current data visible instead of remounting.
    if (_controller != null && widget.refetchKey != old.refetchKey) {
      _controller!.fetch = widget.fetch;
      _controller!.refresh();
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
        if (v.isInitialLoading) {
          return LoadingState(label: widget.loadingLabel);
        }
        if (!v.hasData && v.hasError) {
          return ErrorState(error: v.error!, onRetry: controller.refresh);
        }
        return widget.builder(context, v.data as T, controller);
      },
    );
  }
}
