import 'package:flutter/material.dart';

import '../api/models.dart';
import '../data/polling_view.dart';
import '../theme/app_theme.dart';
import '../widgets/cards.dart';
import '../widgets/progress_bar.dart';
import '../widgets/server_app_bar.dart';
import '../widgets/status_chip.dart';

/// Storage tab: a card per disk (health-colored), folder sizes, and a SMART
/// health card that collapses to "SMART unavailable" when unavailable.
class StorageScreen extends StatefulWidget {
  const StorageScreen({super.key});

  @override
  State<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends State<StorageScreen> {
  bool _folderSizes = true; // heavy but on by default per the contract

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ServerAppBar(),
      body: PollingView<StorageSummary>(
        refetchKey: _folderSizes, // re-fetch on toggle, keep current data (no flash)
        fetch: (api) => api.storageSummary(folderSizes: _folderSizes),
        loadingLabel: 'Scanning storage…',
        builder: (context, s, controller) {
          final online = s.disks.where((d) => d.exists).length;
          final optimal = s.disks.isNotEmpty && s.disks.every((d) => d.exists && d.percentUsed < 92);
          return RefreshableBody(
            onRefresh: controller.refresh,
            children: [
              Text('Storage Architecture', style: AppText.headlineLg()),
              const SizedBox(height: 6),
              Text(
                'ARRAY STATUS: ${optimal ? 'OPTIMAL' : 'CHECK'} | VOLUMES: $online ONLINE',
                style: AppText.labelTechnical(
                    color: optimal ? AppColors.statusHealthy : AppColors.statusWarning),
              ),
              const SizedBox(height: Space.gutter),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('VOLUME ALLOCATIONS', style: AppText.labelCaps()),
                  _folderToggle(),
                ],
              ),
              const SizedBox(height: Space.stackGap),
              for (final d in s.disks) ...[
                _DiskCard(d),
                const SizedBox(height: Space.stackGap),
              ],
              if (s.disks.isEmpty) Text('No volumes reported', style: AppText.labelTechnical()),
              const SizedBox(height: Space.base),
              Section(
                title: 'Directory Hierarchy',
                child: GlassCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final f in s.folders) _FolderRow(f),
                      if (s.folders.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(Space.gutter),
                          child: Text('Folder sizing disabled', style: AppText.labelTechnical()),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Space.gutter),
              Section(title: 'Hardware Diagnostics', child: _SmartCard(s.smart)),
            ],
          );
        },
      ),
    );
  }

  Widget _folderToggle() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('SIZES', style: AppText.labelTechnical()),
        Switch(
          value: _folderSizes,
          activeThumbColor: AppColors.accent,
          onChanged: (v) => setState(() => _folderSizes = v),
        ),
      ],
    );
  }
}

class _DiskCard extends StatelessWidget {
  const _DiskCard(this.disk);
  final DiskInfo disk;

  @override
  Widget build(BuildContext context) {
    if (!disk.exists) {
      return GlassCard(
        borderColor: AppColors.statusError.withValues(alpha: 0.3),
        child: Row(children: [
          const Icon(Icons.error_outline, color: AppColors.statusError),
          const SizedBox(width: Space.stackGap),
          Expanded(child: Text('${disk.path} — path not found', style: AppText.bodySm())),
        ]),
      );
    }
    // Per-volume cards use classic green→amber→red health semantics.
    final c = barColor(disk.percentUsed, brand: false);
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(Radii.sm),
                ),
                child: Text(disk.path, style: AppText.labelTechnical(color: AppColors.onSurface)),
              ),
              Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
            ],
          ),
          const SizedBox(height: Space.gutter),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              RichText(
                text: TextSpan(
                  text: disk.percentUsed.toStringAsFixed(0),
                  style: AppText.displayMetrics(),
                  children: [TextSpan(text: '%', style: AppText.headlineMd(color: AppColors.onSurfaceVariant))],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('${disk.usedHuman} / ${disk.totalHuman}', style: AppText.labelTechnical()),
              ),
            ],
          ),
          const SizedBox(height: Space.stackGap),
          ProgressBar(percent: disk.percentUsed, autoLevel: true, brand: false),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text('${disk.freeHuman} free', style: AppText.labelTechnical()),
          ),
        ],
      ),
    );
  }
}

class _FolderRow extends StatelessWidget {
  const _FolderRow(this.folder);
  final FolderInfo folder;

  IconData get _icon {
    final n = folder.path.toLowerCase();
    if (n.contains('movie')) return Icons.movie_outlined;
    if (n.contains('show') || n.contains('tv') || n.contains('series')) return Icons.tv_outlined;
    if (n.contains('download')) return Icons.download_outlined;
    return Icons.folder_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final name = folder.path.split('/').where((p) => p.isNotEmpty).last;
    return Container(
      padding: const EdgeInsets.all(Space.gutter),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.glassStrokeFaint)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(Radii.chip),
            ),
            child: Icon(_icon, size: 20, color: AppColors.accent),
          ),
          const SizedBox(width: Space.stackGap),
          Expanded(
            child: Text(name[0].toUpperCase() + name.substring(1),
                style: AppText.bodyLg().copyWith(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: Space.stackGap),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(folder.exists ? folder.sizeHuman : 'missing',
                  style: AppText.labelTechnical(color: AppColors.onSurface)),
              Text('${folder.entryCount} items', style: AppText.labelTechnical()),
            ],
          ),
        ],
      ),
    );
  }
}

class _SmartCard extends StatelessWidget {
  const _SmartCard(this.smart);
  final SmartInfo smart;

  @override
  Widget build(BuildContext context) {
    if (!smart.available) {
      return GlassCard(
        color: AppColors.surfaceContainerLowest,
        child: Row(
          children: [
            const Icon(Icons.help_outline, size: 20, color: AppColors.outline),
            const SizedBox(width: Space.stackGap),
            Expanded(
              child: Text(smart.message ?? 'SMART unavailable',
                  style: AppText.labelTechnical(color: AppColors.outline)),
            ),
          ],
        ),
      );
    }
    final healthy = smart.healthy;
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('SMART STATUS', style: AppText.labelTechnical()),
              StatusChip(
                label: smart.status ?? (healthy ? 'PASSED' : 'FAILED'),
                level: healthy ? StatusLevel.healthy : StatusLevel.error,
              ),
            ],
          ),
          const Divider(height: 24, color: AppColors.glassStrokeFaint),
          if (smart.device != null) InfoRow('Device', smart.device!),
          if (smart.temperatureCelsius != null)
            InfoRow('Temperature', '${smart.temperatureCelsius}°C',
                valueColor: levelForTemp(smart.temperatureCelsius!.toDouble(), high: 55, critical: 65).color),
          if (smart.powerOnHours != null) InfoRow('Power-on hours', '${smart.powerOnHours} h'),
        ],
      ),
    );
  }
}
