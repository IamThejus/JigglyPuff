/// A minimal React-Query-style async container: the view is always in exactly
/// one of loading / error / success, with optional "previous data" retained
/// across refetches so gauges don't flash back to a spinner every poll.
class AsyncValue<T> {
  final T? data;
  final Object? error;
  final bool isLoading; // a fetch is currently in flight

  const AsyncValue._({this.data, this.error, this.isLoading = false});

  /// First load, nothing cached yet.
  const AsyncValue.loading() : this._(isLoading: true);

  /// Refetch in flight but we still have previous data to show.
  const AsyncValue.loadingWith(T? previous) : this._(data: previous, isLoading: true);

  const AsyncValue.data(T value) : this._(data: value);

  const AsyncValue.error(Object err, {T? previous}) : this._(error: err, data: previous);

  bool get hasData => data != null;
  bool get hasError => error != null;

  /// First-load spinner: loading with nothing to show yet.
  bool get isInitialLoading => isLoading && data == null;

  /// Background refetch while we already have data on screen.
  bool get isRefreshing => isLoading && data != null;
}
