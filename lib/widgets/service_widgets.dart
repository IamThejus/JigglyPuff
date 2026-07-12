import 'package:flutter/material.dart';

import '../api/models.dart';
import '../theme/app_theme.dart';
import 'status_chip.dart';

StatusLevel serviceLevel(ServiceInfo s) => s.active ? StatusLevel.healthy : StatusLevel.error;

/// Compact wrap of service status chips (used on the Dashboard).
class ServiceChips extends StatelessWidget {
  const ServiceChips({super.key, required this.services});
  final List<ServiceInfo> services;

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) {
      return Text('No services reported', style: AppText.labelTechnical());
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final s in services)
          StatusChip(label: _pretty(s.name), level: serviceLevel(s)),
      ],
    );
  }
}

/// A full-width service list row: name + state, with an optional [action] slot
/// so a v2 restart/enable control can be dropped in without a rewrite.
class ServiceRow extends StatelessWidget {
  const ServiceRow({super.key, required this.service, this.action});
  final ServiceInfo service;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final level = serviceLevel(service);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.glassStrokeFaint)),
      ),
      child: Row(
        children: [
          Icon(
            service.active ? Icons.check_circle_outline : Icons.cancel_outlined,
            color: level.color,
            size: 20,
          ),
          const SizedBox(width: Space.stackGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_pretty(service.name),
                    style: AppText.bodyLg().copyWith(fontWeight: FontWeight.w500)),
                Text(
                  '${service.state} · ${service.subState}${service.enabled ? '' : ' · disabled'}',
                  style: AppText.labelTechnical(),
                ),
              ],
            ),
          ),
          if (action != null) action! else StatusChip(label: service.active ? 'UP' : 'DOWN', level: level),
        ],
      ),
    );
  }
}

String _pretty(String raw) {
  var s = raw.replaceAll('.service', '').replaceAll(RegExp(r'[-_]'), ' ');
  if (s.isEmpty) return raw;
  return s
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}
