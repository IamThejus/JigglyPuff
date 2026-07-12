import 'package:flutter/material.dart';

import '../api/models.dart';
import '../data/polling_view.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/cards.dart';
import '../widgets/progress_bar.dart';
import '../widgets/server_app_bar.dart';
import '../widgets/sparkline.dart';
import '../widgets/status_chip.dart';

/// System tab: rich host detail from `/system/overview`, refreshing live.
/// Temperatures / battery / load / interfaces render only when present.
class SystemScreen extends StatelessWidget {
  const SystemScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ServerAppBar(),
      body: PollingView<SystemOverview>(
        fetch: (api) => api.systemOverview(),
        loadingLabel: 'Reading system…',
        builder: (context, s, controller) {
          return RefreshableBody(
            onRefresh: controller.refresh,
            children: [
              Text('System Overview', style: AppText.headlineLg()),
              const SizedBox(height: 6),
              Row(children: [
                const StatusDot(level: StatusLevel.healthy, size: 7),
                const SizedBox(width: 8),
                Text('ONLINE · ${s.hostname}', style: AppText.labelTechnical(color: AppColors.onSurface)),
              ]),
              const SizedBox(height: Space.gutter),

              // Overview
              Section(
                title: 'Overview',
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: Column(children: [
                    InfoRow('Hostname', s.hostname),
                    const Divider(height: 1, color: AppColors.glassStrokeFaint),
                    InfoRow('OS', s.os),
                    const Divider(height: 1, color: AppColors.glassStrokeFaint),
                    InfoRow('Kernel', s.kernel),
                    const Divider(height: 1, color: AppColors.glassStrokeFaint),
                    InfoRow('Architecture', s.architecture),
                    const Divider(height: 1, color: AppColors.glassStrokeFaint),
                    InfoRow('Uptime', s.uptimeHuman),
                    if (s.bootTimeIso.isNotEmpty) ...[
                      const Divider(height: 1, color: AppColors.glassStrokeFaint),
                      InfoRow('Boot Time', Fmt.date(s.bootTimeIso)),
                    ],
                  ]),
                ),
              ),
              const SizedBox(height: Space.gutter),

              // CPU
              Section(
                title: 'CPU',
                child: GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${s.cpuCountLogical} threads',
                              style: AppText.labelTechnical(color: AppColors.onSurface)),
                          Text('${s.cpuPercent.toStringAsFixed(0)}%', style: AppText.headlineLg()),
                        ],
                      ),
                      const SizedBox(height: Space.stackGap),
                      ProgressBar(percent: s.cpuPercent, autoLevel: true),
                      const Divider(height: 28, color: AppColors.glassStrokeFaint),
                      InfoRow('Logical cores', '${s.cpuCountLogical}'),
                      InfoRow('Physical cores', '${s.cpuCountPhysical}'),
                      if (s.loadAverage != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('LOAD AVERAGE', style: AppText.labelTechnical()),
                              Row(children: [
                                Text(
                                  '${s.loadAverage!.one.toStringAsFixed(2)}  ${s.loadAverage!.five.toStringAsFixed(2)}  ${s.loadAverage!.fifteen.toStringAsFixed(2)}',
                                  style: AppText.labelTechnical(color: AppColors.onSurface),
                                ),
                                const SizedBox(width: Space.stackGap),
                                Sparkline(values: [
                                  s.loadAverage!.fifteen,
                                  s.loadAverage!.five,
                                  s.loadAverage!.one,
                                ], width: 48, height: 20),
                              ]),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Space.gutter),

              // Memory & swap
              Section(
                title: 'Memory & Swap',
                child: Column(children: [
                  _BarCard(
                    label: 'Memory',
                    detail: '${s.memory.usedHuman} / ${s.memory.totalHuman}',
                    percent: s.memory.percent,
                  ),
                  const SizedBox(height: Space.stackGap),
                  _BarCard(
                    label: 'Swap',
                    detail: s.swap.totalHuman,
                    percent: s.swap.percent,
                  ),
                ]),
              ),

              if (s.temperatures.isNotEmpty) ...[
                const SizedBox(height: Space.gutter),
                Section(
                  title: 'Thermals',
                  child: GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(children: [for (final t in s.temperatures) _TempRow(t)]),
                  ),
                ),
              ],

              if (s.battery != null) ...[
                const SizedBox(height: Space.gutter),
                Section(
                  title: 'Battery',
                  child: _BarCard(
                    label: (s.battery!.powerPlugged ?? false) ? 'Charging' : 'On battery',
                    detail: '${s.battery!.percent.toStringAsFixed(0)}%',
                    percent: s.battery!.percent,
                  ),
                ),
              ],

              if (s.interfaces.isNotEmpty) ...[
                const SizedBox(height: Space.gutter),
                Section(
                  title: 'Network',
                  child: GlassCard(
                    padding: EdgeInsets.zero,
                    child: Column(children: [for (final iface in s.interfaces) _InterfaceRow(iface)]),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _BarCard extends StatelessWidget {
  const _BarCard({required this.label, required this.percent, required this.detail});
  final String label;
  final double percent;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: AppText.labelTechnical(color: AppColors.onSurface)),
              Row(children: [
                Text(detail, style: AppText.labelTechnical()),
                const SizedBox(width: Space.stackGap),
                Text('${percent.toStringAsFixed(0)}%', style: AppText.labelCaps(color: AppColors.accent)),
              ]),
            ],
          ),
          const SizedBox(height: Space.stackGap),
          ProgressBar(percent: percent, autoLevel: true),
        ],
      ),
    );
  }
}

class _TempRow extends StatelessWidget {
  const _TempRow(this.temp);
  final TemperatureInfo temp;

  @override
  Widget build(BuildContext context) {
    final level = levelForTemp(temp.currentCelsius, high: temp.highCelsius, critical: temp.criticalCelsius);
    final ceiling = temp.criticalCelsius ?? temp.highCelsius ?? 100;
    final pct = (temp.currentCelsius / ceiling * 100).clamp(0, 100).toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(temp.label, style: AppText.labelTechnical(color: AppColors.onSurface)),
              Text('${temp.currentCelsius.toStringAsFixed(0)}°C',
                  style: AppText.labelTechnical(color: level.color)),
            ],
          ),
          const SizedBox(height: 6),
          ProgressBar(percent: pct, color: level == StatusLevel.healthy ? AppColors.accent : level.color, height: 4),
        ],
      ),
    );
  }
}

class _InterfaceRow extends StatelessWidget {
  const _InterfaceRow(this.iface);
  final NetInterface iface;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Space.gutter),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.glassStrokeFaint)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lan_outlined, size: 20, color: AppColors.accent),
          const SizedBox(width: Space.stackGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(iface.name, style: AppText.bodyLg().copyWith(fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                if (iface.addresses.isEmpty)
                  Text('no addresses', style: AppText.labelTechnical())
                else
                  for (final a in iface.addresses)
                    Text(a, style: AppText.labelTechnical(color: AppColors.onSurface)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
