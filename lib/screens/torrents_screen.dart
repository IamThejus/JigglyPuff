import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../api/endpoints.dart';
import '../api/models.dart';
import '../data/polling_view.dart';
import '../data/torrent_stream.dart';
import '../theme/app_theme.dart';
import '../utils/control_action.dart';
import '../widgets/cards.dart';
import '../widgets/progress_bar.dart';
import '../widgets/segmented.dart';
import '../widgets/server_app_bar.dart';
import '../widgets/states.dart';

/// Torrents tab: a **real-time** list over `GET /torrents/ws` (falling back to
/// polling `/torrents/list` when the socket is unavailable), a stats header
/// from `/torrents/summary`, and control actions (add torrent by link/file,
/// sync movies) via the authenticated `POST /actions/*` endpoints.
class TorrentsScreen extends StatefulWidget {
  const TorrentsScreen({super.key});

  @override
  State<TorrentsScreen> createState() => _TorrentsScreenState();
}

enum _Filter { all, downloading, seeding, completed }

enum _RowAction { pause, resume, delete }

extension on _Filter {
  String get label => switch (this) {
        _Filter.all => 'All',
        _Filter.downloading => 'Downloading',
        _Filter.seeding => 'Seeding',
        _Filter.completed => 'Completed',
      };
  String? get param => this == _Filter.all ? null : name;
}

class _TorrentsScreenState extends State<TorrentsScreen> {
  _Filter _filter = _Filter.all;

  // Shared control-action runner (key gate + toasts + soft-fail handling).
  Future<ActionResult?> _run(
    String verb,
    Future<ActionResult> Function(MediaServerApi) call, {
    bool silentSuccess = false,
  }) =>
      runControlAction(context, verb, call, silentSuccess: silentSuccess);

  // --- per-row torrent controls (pause / resume / delete) -----------------

  Future<void> _torrentAction(_RowAction action, Torrent t) async {
    switch (action) {
      case _RowAction.pause:
        await _run('Pausing', (api) => api.pauseTorrent(t.hash));
      case _RowAction.resume:
        await _run('Resuming', (api) => api.resumeTorrent(t.hash));
      case _RowAction.delete:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surfaceContainer,
            title: Text('Delete torrent', style: AppText.headlineMd()),
            content: Text(
              'Remove “${t.name}” and delete its files on disk? This cannot be undone.',
              style: AppText.bodySm(color: AppColors.onSurface),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.statusError),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (confirmed == true) await _run('Deleting', (api) => api.deleteTorrent(t.hash));
    }
  }

  Future<void> _addTorrent() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.card)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 36, height: 4, decoration: BoxDecoration(
                color: AppColors.outlineVariant, borderRadius: BorderRadius.circular(2))),
            ListTile(
              leading: const Icon(Icons.link, color: AppColors.accent),
              title: Text('Paste magnet / URL', style: AppText.bodyLg()),
              onTap: () => Navigator.pop(ctx, 'url'),
            ),
            ListTile(
              leading: const Icon(Icons.attach_file, color: AppColors.accent),
              title: Text('Pick .torrent file', style: AppText.bodyLg()),
              onTap: () => Navigator.pop(ctx, 'file'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == 'url') await _addTorrentUrl();
    if (choice == 'file') await _addTorrentFile();
  }

  Future<void> _addTorrentUrl() async {
    final controller = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainer,
        title: Text('Add torrent', style: AppText.headlineMd()),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: AppText.bodySm(color: AppColors.onSurface),
          decoration: const InputDecoration(hintText: 'magnet:?xt=…  or  https://…/file.torrent'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Add')),
        ],
      ),
    );
    if (url == null || url.trim().isEmpty) return;
    await _run('Adding torrent', (api) => api.addTorrentUrl(url.trim()));
  }

  Future<void> _addTorrentFile() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['torrent'],
      withData: true,
    );
    final file = picked?.files.firstOrNull;
    if (file == null) return;
    final bytes = file.bytes;
    if (bytes == null) {
      _snack('Could not read the selected file.', ok: false);
      return;
    }
    await _run('Adding torrent', (api) => api.addTorrentFile(bytes: bytes, filename: file.name));
  }

  Future<void> _syncMovies() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainer,
        title: Text('Sync movies', style: AppText.headlineMd()),
        content: Text(
          'Run the server-side script that moves completed downloads into the movies library?',
          style: AppText.bodySm(color: AppColors.onSurface),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Run')),
        ],
      ),
    );
    if (confirmed != true) return;
    final result = await _run('Syncing movies', (api) => api.syncMovies(), silentSuccess: true);
    if (result != null && mounted) _showSyncResult(result);
  }

  void _showSyncResult(ActionResult result) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainer,
        title: Text(result.ok ? 'Sync complete' : 'Sync failed', style: AppText.headlineMd()),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(result.syncSummary,
                    style: AppText.bodyLg().copyWith(fontWeight: FontWeight.w600)),
                if (result.message != null) ...[
                  const SizedBox(height: 8),
                  Text(result.message!, style: AppText.bodySm()),
                ],
                if (result.moved.isNotEmpty) ...[
                  const SizedBox(height: Space.gutter),
                  Text('MOVED', style: AppText.labelTechnical()),
                  const SizedBox(height: 4),
                  for (final m in result.moved)
                    Text('• $m', style: AppText.labelTechnical(color: AppColors.onSurface)),
                ],
                if (result.skipped.isNotEmpty) ...[
                  const SizedBox(height: Space.gutter),
                  Text('SKIPPED (already in library)', style: AppText.labelTechnical()),
                  const SizedBox(height: 4),
                  for (final s in result.skipped)
                    Text('• $s', style: AppText.labelTechnical(color: AppColors.onSurface)),
                ],
              ],
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  void _snack(String message, {bool? ok}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: ok == false
            ? AppColors.errorContainer
            : (ok == true ? null : AppColors.surfaceContainerHigh),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ServerAppBar(),
      body: TorrentStreamView(
        state: _filter.param,
        loadingLabel: 'Loading torrents…',
        builder: (context, list, controller) {
          return RefreshableBody(
            onRefresh: controller.refresh,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text('Torrents', style: AppText.headlineLg()),
                  const SizedBox(width: Space.stackGap),
                  if (controller.isLive) _liveBadge(),
                ],
              ),
              const SizedBox(height: 6),
              _TorrentsHeader(onAddTorrent: _addTorrent, onSyncMovies: _syncMovies),
              const SizedBox(height: Space.gutter),
              _segmented(),
              const SizedBox(height: Space.gutter),
              if (!list.reachable)
                DegradedState(
                  title: 'qBittorrent is Offline',
                  message: list.message ?? 'The torrent client did not respond.',
                  icon: Icons.cloud_off_rounded,
                )
              else if (list.torrents.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: EmptyState(
                    title: 'No torrents',
                    message: 'Nothing matches this filter right now.',
                    icon: Icons.download_done_outlined,
                  ),
                )
              else
                ...list.torrents.map((t) => Padding(
                      padding: const EdgeInsets.only(bottom: Space.stackGap),
                      child: _TorrentTile(t, onAction: _torrentAction),
                    )),
            ],
          );
        },
      ),
    );
  }

  Widget _liveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.statusHealthy.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(Radii.full),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 5, height: 5,
            decoration: const BoxDecoration(color: AppColors.statusHealthy, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text('LIVE', style: AppText.labelTechnical(color: AppColors.statusHealthy)),
      ]),
    );
  }

  Widget _segmented() {
    return AnimatedSegmented(
      height: 36,
      labels: _Filter.values.map((f) => f.label).toList(),
      index: _filter.index,
      onChanged: (i) => setState(() => _filter = _Filter.values[i]),
    );
  }
}

/// Client subtitle + action buttons + stat cards + aggregate speeds, all from
/// a single `/torrents/summary` fetch.
class _TorrentsHeader extends StatelessWidget {
  const _TorrentsHeader({required this.onAddTorrent, required this.onSyncMovies});
  final VoidCallback onAddTorrent;
  final VoidCallback onSyncMovies;

  @override
  Widget build(BuildContext context) {
    return PollingView<TorrentsSummary>(
      fetch: (api) => api.torrentsSummary(),
      builder: (context, s, _) {
        final subtitle = !s.reachable
            ? 'Client offline'
            : (s.clientLabel.isNotEmpty ? s.clientLabel : 'qBittorrent client');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle, style: AppText.bodySm()),
            const SizedBox(height: Space.gutter),
            Row(children: [
              Expanded(child: _ghostButton('Add Torrent', Icons.add, onAddTorrent)),
              const SizedBox(width: Space.stackGap),
              Expanded(child: _ghostButton('Sync Movies', Icons.sync, onSyncMovies)),
            ]),
            if (!s.reachable)
              const SizedBox.shrink()
            else ...[
              const SizedBox(height: Space.gutter),
              Row(children: [
              Expanded(child: _stat('TOTAL', s.total, AppColors.accent)),
              const SizedBox(width: Space.stackGap),
              Expanded(child: _stat('DOWNLOADING', s.downloading, AppColors.accent, accentBar: true)),
            ]),
            const SizedBox(height: Space.stackGap),
            Row(children: [
              Expanded(child: _stat('SEEDING', s.seeding, AppColors.statusHealthy, accentBar: true)),
              const SizedBox(width: Space.stackGap),
              Expanded(child: _stat('COMPLETED', s.completed, AppColors.onSurface)),
            ]),
            const SizedBox(height: Space.stackGap),
            GlassCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _speed(Icons.arrow_downward, s.totalDlspeedHuman, AppColors.accent),
                  Container(width: 1, height: 28, color: AppColors.glassStroke),
                  _speed(Icons.arrow_upward, s.totalUpspeedHuman, AppColors.onSurface),
                ],
              ),
            ),
            ],
          ],
        );
      },
    );
  }

  Widget _ghostButton(String label, IconData icon, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: AppColors.onSurface),
      label: Text(label, style: AppText.bodySm(color: AppColors.onSurface)),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppColors.glassStroke),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.chip)),
      ),
    );
  }

  Widget _stat(String label, int value, Color dot, {bool accentBar = false}) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: AppText.labelTechnical()),
              Container(width: 6, height: 6, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
            ],
          ),
          const SizedBox(height: Space.stackGap),
          Text('$value', style: AppText.displayMetrics()),
          const SizedBox(height: Space.stackGap),
          Container(
            height: 3,
            width: 48,
            decoration: BoxDecoration(
              color: accentBar ? dot : AppColors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(Radii.full),
            ),
          ),
        ],
      ),
    );
  }

  Widget _speed(IconData icon, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(value, style: AppText.labelTechnical(color: AppColors.primary)),
      ],
    );
  }
}

class _TorrentTile extends StatelessWidget {
  const _TorrentTile(this.torrent, {required this.onAction});
  final Torrent torrent;
  final Future<void> Function(_RowAction, Torrent) onAction;

  bool get _isPaused => torrent.state.toLowerCase().contains('paus');

  @override
  Widget build(BuildContext context) {
    final downloading = torrent.state == 'downloading';
    final badgeColor = downloading ? AppColors.accent : AppColors.statusHealthy;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accentDim,
                  borderRadius: BorderRadius.circular(Radii.chip),
                ),
                child: Icon(downloading ? Icons.download_rounded : Icons.arrow_upward_rounded,
                    size: 18, color: AppColors.accent),
              ),
              const SizedBox(width: Space.stackGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(torrent.name,
                        style: AppText.bodyLg().copyWith(fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(
                      '${torrent.sizeHuman}${torrent.category.isNotEmpty ? ' · ${torrent.category}' : ''}',
                      style: AppText.labelTechnical(),
                    ),
                  ],
                ),
              ),
              _actionMenu(),
            ],
          ),
          const SizedBox(height: Space.stackGap),
          Row(children: [
            _badge(torrent.state.toUpperCase(), badgeColor),
          ]),
          const SizedBox(height: Space.stackGap),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${torrent.progressPercent.toStringAsFixed(1)}%',
                  style: AppText.labelTechnical(color: AppColors.onSurface)),
              if (downloading && torrent.etaHuman.isNotEmpty)
                Text('ETA ${torrent.etaHuman}', style: AppText.labelTechnical()),
              if (!downloading) Text('Ratio ${torrent.ratio.toStringAsFixed(2)}', style: AppText.labelTechnical()),
            ],
          ),
          const SizedBox(height: 6),
          ProgressBar(
            percent: torrent.progressPercent,
            color: downloading ? AppColors.accent : AppColors.statusHealthy,
          ),
          const SizedBox(height: Space.stackGap),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                const Icon(Icons.arrow_downward, size: 13, color: AppColors.accent),
                const SizedBox(width: 4),
                Text(torrent.dlspeedHuman, style: AppText.labelTechnical(color: AppColors.onSurface)),
              ]),
              Row(children: [
                const Icon(Icons.arrow_upward, size: 13, color: AppColors.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(torrent.upspeedHuman, style: AppText.labelTechnical(color: AppColors.onSurface)),
              ]),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 5, height: 5, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(text, style: AppText.labelTechnical(color: color)),
      ]),
    );
  }

  Widget _actionMenu() {
    return PopupMenuButton<_RowAction>(
      icon: const Icon(Icons.more_vert, size: 20, color: AppColors.onSurfaceVariant),
      color: AppColors.surfaceContainerHigh,
      padding: EdgeInsets.zero,
      onSelected: (a) => onAction(a, torrent),
      itemBuilder: (_) => [
        if (_isPaused)
          _menuItem(_RowAction.resume, Icons.play_arrow_rounded, 'Resume', AppColors.onSurface)
        else
          _menuItem(_RowAction.pause, Icons.pause_rounded, 'Pause', AppColors.onSurface),
        _menuItem(_RowAction.delete, Icons.delete_outline, 'Delete & remove files',
            AppColors.errorText),
      ],
    );
  }

  PopupMenuItem<_RowAction> _menuItem(_RowAction value, IconData icon, String label, Color color) {
    return PopupMenuItem(
      value: value,
      child: Row(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: Space.stackGap),
        Text(label, style: AppText.bodySm(color: color)),
      ]),
    );
  }
}
