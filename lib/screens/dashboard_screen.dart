import 'package:flutter/material.dart';

import '../api/models.dart';
import '../data/polling_view.dart';
import '../theme/app_theme.dart';
import '../widgets/cards.dart';
import '../widgets/progress_bar.dart';
import '../widgets/ring_gauge.dart';
import '../widgets/server_app_bar.dart';
import '../widgets/service_widgets.dart';
import '../widgets/states.dart';
import '../widgets/status_chip.dart';

/// Home screen — at-a-glance server health from `/dashboard`, auto-refreshing
/// at the user's configured cadence. The "online" dot is driven by the poll
/// succeeding.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ServerAppBar(),
      body: PollingView<Dashboard>(
        fetch: (api) => api.dashboard(),
        loadingLabel: 'Fetching server status…',
        builder: (context, d, controller) {
          return Column(
            children: [
              _TechSubheader(hostname: d.hostname, uptime: d.uptimeHuman, online: true),
              Expanded(
                child: RefreshableBody(
                  onRefresh: controller.refresh,
                  children: [
                    _gaugeRow(context, d),
                    const SizedBox(height: Space.stackGap),
                    _storageCard(context, d.storage),
                    const SizedBox(height: Space.stackGap),
                    _servicesCard(d.services),
                    const SizedBox(height: Space.stackGap),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _torrentsCard(context, d)),
                          const SizedBox(width: Space.stackGap),
                          Expanded(child: _libraryCard(context, d)),
                        ],
                      ),
                    ),
                    if (!d.torrentsReachable) ...[
                      const SizedBox(height: Space.stackGap),
                      const DegradedState(
                        title: 'qBittorrent Offline',
                        message: 'Torrent stats are unavailable.',
                        icon: Icons.warning_amber_rounded,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _gaugeRow(BuildContext context, Dashboard d) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // CPU ring rendered in neutral white; memory in brand pink.
          Expanded(
            child: _gaugeCard('CPU', d.cpuPercent,
                color: AppColors.onSurface,
                trailing: const Icon(Icons.memory, size: 16, color: AppColors.onSurfaceVariant)),
          ),
          const SizedBox(width: Space.stackGap),
          Expanded(
            child: _gaugeCard('Memory', d.memoryPercent,
                color: AppColors.accent, trailing: _dot(levelForPercent(d.memoryPercent))),
          ),
        ],
      ),
    );
  }

  Widget _gaugeCard(String label, double percent, {required Color color, required Widget trailing}) {
    return GlassCard(
      padding: const EdgeInsets.all(Space.gutter),
      child: RingGauge(percent: percent, label: label, color: color, trailing: trailing),
    );
  }

  Widget _dot(StatusLevel level) => Container(
      width: 6, height: 6, decoration: BoxDecoration(color: level.color, shape: BoxShape.circle));

  Widget _storageCard(BuildContext context, StorageBrief s) {
    return StatCard(
      label: 'Storage Pool',
      trailing: const Icon(Icons.dns_outlined, size: 18, color: AppColors.onSurfaceVariant),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(s.primaryPath, style: AppText.headlineMd()),
              Text('${s.totalHuman} Total', style: AppText.labelTechnical()),
            ],
          ),
          const SizedBox(height: Space.gutter),
          ProgressBar(percent: s.percentUsed),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${s.usedHuman} Used', style: AppText.labelTechnical(color: AppColors.onSurface)),
              Text('${s.percentUsed.toStringAsFixed(0)}%', style: AppText.labelCaps(color: AppColors.accent)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _servicesCard(List<ServiceInfo> services) {
    return GlassCard(
      color: AppColors.surfaceContainerLowest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('SERVICES', style: AppText.labelTechnical()),
              const Icon(Icons.chevron_right, size: 18, color: AppColors.onSurfaceVariant),
            ],
          ),
          const SizedBox(height: Space.stackGap),
          ServiceChips(services: services),
        ],
      ),
    );
  }

  Widget _torrentsCard(BuildContext context, Dashboard d) {
    final reachable = d.torrentsReachable;
    return StatCard(
      label: 'Torrents',
      trailing: const Icon(Icons.download_rounded, size: 18, color: AppColors.accent),
      child: Opacity(
        opacity: reachable ? 1 : 0.4,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${d.torrentsActive}', style: AppText.displayMetrics()),
            Text('ACTIVE', style: AppText.labelTechnical()),
            const SizedBox(height: Space.gutter),
            _speedLine(Icons.arrow_downward, d.torrentsDownloading, 'DL'),
            const SizedBox(height: 4),
            _speedLine(Icons.arrow_upward, d.torrentsSeeding, 'SD'),
          ],
        ),
      ),
    );
  }

  Widget _speedLine(IconData icon, int n, String label) => Row(
        children: [
          Icon(icon, size: 13, color: AppColors.onSurfaceVariant),
          const SizedBox(width: 6),
          Text('$n $label', style: AppText.labelTechnical(color: AppColors.onSurface)),
        ],
      );

  Widget _libraryCard(BuildContext context, Dashboard d) {
    return StatCard(
      label: 'Library',
      trailing: const Icon(Icons.movie_rounded, size: 18, color: AppColors.accent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _count(d.moviesCount, 'Movies', Icons.movie_outlined),
          const SizedBox(height: Space.gutter),
          _count(d.showsCount, 'Shows', Icons.tv_outlined),
        ],
      ),
    );
  }

  Widget _count(int n, String label, IconData icon) => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: AppColors.accent),
          const SizedBox(width: 10),
          Text('$n', style: AppText.headlineLg()),
          const SizedBox(width: 6),
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(label, style: AppText.labelTechnical()),
          ),
        ],
      );
}

/// The thin "HOST · UPTIME · ONLINE" technical strip beneath the app bar.
class _TechSubheader extends StatelessWidget {
  const _TechSubheader({required this.hostname, required this.uptime, required this.online});
  final String hostname;
  final String uptime;
  final bool online;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceContainerLowest,
      padding: const EdgeInsets.symmetric(horizontal: Space.containerPadding, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Text('HOST: ', style: AppText.labelTechnical(color: AppColors.onSurfaceVariant)),
            Text(hostname, style: AppText.labelTechnical(color: AppColors.onSurface)),
          ]),
          Row(children: [
            Text('UPTIME: ', style: AppText.labelTechnical(color: AppColors.onSurfaceVariant)),
            Text(uptime, style: AppText.labelTechnical(color: AppColors.onSurface)),
            const SizedBox(width: Space.gutter),
            StatusDot(level: online ? StatusLevel.healthy : StatusLevel.error, size: 7),
            const SizedBox(width: 8),
            Text(online ? 'ONLINE' : 'OFFLINE',
                style: AppText.labelTechnical(
                    color: online ? AppColors.statusHealthy : AppColors.errorText)),
          ]),
        ],
      ),
    );
  }
}
