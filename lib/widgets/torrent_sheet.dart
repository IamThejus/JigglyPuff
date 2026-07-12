import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../api/endpoints.dart';
import '../api/models.dart';
import '../config.dart';
import '../theme/app_theme.dart';
import '../utils/control_action.dart';
import '../widgets/states.dart';

/// Opens the torrents-for-a-movie modal bottom sheet.
Future<void> showTorrentSheet(BuildContext context, MovieSearchResult movie) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TorrentSheet(movie: movie),
  );
}

class _TorrentSheet extends StatefulWidget {
  const _TorrentSheet({required this.movie});
  final MovieSearchResult movie;

  @override
  State<_TorrentSheet> createState() => _TorrentSheetState();
}

class _TorrentSheetState extends State<_TorrentSheet> {
  late Future<MovieTorrentsResponse> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<MovieTorrentsResponse> _load() =>
      MediaServerApi(ApiClient(context.read<AppConfig>())).movieTorrents(widget.movie.title);

  void _retry() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: AppColors.glassStroke)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.outlineVariant, borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.containerPadding, Space.gutter,
                    Space.containerPadding, Space.stackGap),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Available torrents', style: AppText.labelTechnical()),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.movie.title}${widget.movie.year.isNotEmpty ? ' (${widget.movie.year})' : ''}',
                      style: AppText.headlineMd(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.glassStrokeFaint),
              Expanded(child: _body(scrollController)),
            ],
          ),
        );
      },
    );
  }

  Widget _body(ScrollController scrollController) {
    return FutureBuilder<MovieTorrentsResponse>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _TorrentLoading();
        }
        if (snapshot.hasError) {
          return _SheetError(error: snapshot.error!, onRetry: _retry);
        }
        final torrents = snapshot.data?.results ?? const [];
        if (torrents.isEmpty) {
          return const EmptyState(
            title: 'No torrents found',
            message: 'No sources are available for this title right now.',
            icon: Icons.travel_explore_outlined,
          );
        }
        return ListView.separated(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(
              Space.containerPadding, Space.gutter, Space.containerPadding, 40),
          itemCount: torrents.length,
          separatorBuilder: (_, _) => const SizedBox(height: Space.stackGap),
          itemBuilder: (context, i) => _TorrentCard(torrent: torrents[i]),
        );
      },
    );
  }
}

class _TorrentCard extends StatelessWidget {
  const _TorrentCard({required this.torrent});
  final MovieTorrent torrent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Space.gutter),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: AppColors.glassStrokeFaint),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(torrent.title,
              style: AppText.bodyLg().copyWith(fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: Space.stackGap),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tag in torrent.qualityTags) _chip(tag, accent: true),
              if (torrent.source.isNotEmpty) _chip(torrent.source),
            ],
          ),
          const SizedBox(height: Space.stackGap),
          Row(
            children: [
              _stat(Icons.arrow_upward_rounded, '${torrent.seeds}', AppColors.statusHealthy, 'seeds'),
              const SizedBox(width: Space.gutter),
              _stat(Icons.arrow_downward_rounded, '${torrent.peers}', AppColors.onSurfaceVariant, 'peers'),
              const SizedBox(width: Space.gutter),
              _stat(Icons.sd_storage_outlined, torrent.sizeHuman, AppColors.onSurfaceVariant, null),
              const Spacer(),
            ],
          ),
          const SizedBox(height: Space.gutter),
          _DownloadButton(magnetUrl: torrent.magnetUrl),
        ],
      ),
    );
  }

  Widget _chip(String text, {bool accent = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accent ? AppColors.accentDim : AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Text(text,
          style: AppText.labelTechnical(
              color: accent ? AppColors.accentSoft : AppColors.onSurfaceVariant)),
    );
  }

  Widget _stat(IconData icon, String value, Color color, String? label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 4),
        Text(value, style: AppText.labelTechnical(color: AppColors.onSurface)),
        if (label != null) ...[
          const SizedBox(width: 3),
          Text(label, style: AppText.labelTechnical()),
        ],
      ],
    );
  }
}

enum _DlState { idle, loading, done, error }

/// "Add to qBittorrent" with **inline** feedback (spinner → "Added ✓" or an
/// error), because a snackbar would be hidden behind the modal sheet.
class _DownloadButton extends StatefulWidget {
  const _DownloadButton({required this.magnetUrl});
  final String magnetUrl;

  @override
  State<_DownloadButton> createState() => _DownloadButtonState();
}

class _DownloadButtonState extends State<_DownloadButton> {
  _DlState _state = _DlState.idle;
  String? _error;

  Future<void> _add() async {
    setState(() {
      _state = _DlState.loading;
      _error = null;
    });
    final config = context.read<AppConfig>();
    try {
      final result = await performControlAction(config, (api) => api.addTorrentUrl(widget.magnetUrl));
      if (!mounted) return;
      setState(() {
        if (result == null) {
          _state = _DlState.error;
          _error = 'Add an Actions API key in Settings';
        } else if (result.ok) {
          _state = _DlState.done;
        } else {
          _state = _DlState.error;
          _error = result.message ?? 'qBittorrent rejected the request';
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _DlState.error;
        _error = controlActionErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_state == _DlState.done) {
      return _StatusPill(
        icon: Icons.check_circle_rounded,
        label: 'Added to qBittorrent',
        color: AppColors.statusHealthy,
      );
    }

    final loading = _state == _DlState.loading;
    final isError = _state == _DlState.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: loading ? null : _add,
            icon: loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onAccent),
                  )
                : Icon(isError ? Icons.refresh_rounded : Icons.download_rounded, size: 18),
            label: Text(loading
                ? 'Adding…'
                : (isError ? 'Retry' : 'Add to qBittorrent')),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.onAccent,
              disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.6),
              disabledForegroundColor: AppColors.onAccent,
              textStyle:
                  AppText.bodySm(color: AppColors.onAccent).copyWith(fontWeight: FontWeight.w700),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.chip)),
            ),
          ),
        ),
        if (isError && _error != null) ...[
          const SizedBox(height: 6),
          Text(_error!, style: AppText.labelTechnical(color: AppColors.errorText)),
        ],
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(Radii.chip),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(label, style: AppText.bodySm(color: color).copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _TorrentLoading extends StatelessWidget {
  const _TorrentLoading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
          ),
          const SizedBox(height: Space.gutter),
          Text('Finding torrents…', style: AppText.labelTechnical()),
        ],
      ),
    );
  }
}

class _SheetError extends StatelessWidget {
  const _SheetError({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final api = error is ApiException ? error as ApiException : null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.sectionMargin),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: AppColors.errorText, size: 34),
            const SizedBox(height: Space.stackGap),
            Text('Could not load torrents', style: AppText.headlineMd(), textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(api?.message ?? 'Please try again.',
                style: AppText.bodySm(), textAlign: TextAlign.center),
            const SizedBox(height: Space.gutter),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18, color: AppColors.onSurface),
              label: Text('Retry', style: AppText.bodySm(color: AppColors.onSurface)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.glassStroke),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.chip)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
