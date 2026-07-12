import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../theme/app_theme.dart';

/// Full-screen first-load spinner.
class LoadingState extends StatelessWidget {
  const LoadingState({super.key, this.label});
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: Space.gutter),
          Text(label ?? 'Loading…', style: AppText.labelTechnical()),
        ],
      ),
    );
  }
}

/// The backend itself is unreachable / returned an HTTP error. This is a hard
/// error (distinct from a "degraded" subsystem) and mirrors the Sentinel
/// "Server Unreachable" panel with an ERR_CODE / retry affordance.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.error, required this.onRetry});
  final Object error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final api = error is ApiException ? error as ApiException : null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.containerPadding),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(Radii.card),
            border: Border.all(color: AppColors.glassStroke),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.errorContainer.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cloud_off_rounded, color: AppColors.errorText, size: 30),
              ),
              const SizedBox(height: Space.gutter),
              Text('Server Unreachable', style: AppText.headlineMd(), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                '$error',
                style: AppText.bodySm(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Space.gutter),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(Radii.sm),
                ),
                child: Column(
                  children: [
                    _kv('ERR_CODE', api?.errCode ?? '0x0000_UNKNOWN'),
                    if (api?.statusCode != null) _kv('HTTP', '${api!.statusCode}'),
                  ],
                ),
              ),
              const SizedBox(height: Space.gutter),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.chip)),
                  ),
                  onPressed: onRetry,
                  child: Text('Retry Connection',
                      style: AppText.bodySm(color: AppColors.onPrimary)
                          .copyWith(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k, style: AppText.labelTechnical()),
            Text(v, style: AppText.labelTechnical(color: AppColors.errorText)),
          ],
        ),
      );
}

/// Neutral empty result (e.g. no torrents match a filter).
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, this.message, this.icon});
  final String title;
  final String? message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.sectionMargin),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon ?? Icons.inbox_outlined, color: AppColors.outline, size: 40),
            const SizedBox(height: Space.stackGap),
            Text(title, style: AppText.headlineMd(color: AppColors.onSurfaceVariant),
                textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(message!, style: AppText.bodySm(), textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}

/// The backend is reachable but a subsystem flag is false (qBittorrent offline,
/// path missing, SMART unavailable). A first-class, non-error state: amber/red
/// accent, optional server `message`, and an optional action slot for v2.
class DegradedState extends StatelessWidget {
  const DegradedState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.warning_amber_rounded,
    this.level = StatusLevel.error,
    this.action,
  });

  final String title;
  final String? message;
  final IconData icon;
  final StatusLevel level;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = level.color;
    return Container(
      padding: const EdgeInsets.all(Space.gutter),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: c.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(width: 3, height: 40, color: c.withValues(alpha: 0.6)),
          const SizedBox(width: Space.gutter),
          Icon(icon, color: c),
          const SizedBox(width: Space.stackGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.bodyLg().copyWith(fontWeight: FontWeight.w600)),
                if (message != null) ...[
                  const SizedBox(height: 2),
                  Text(message!, style: AppText.labelTechnical()),
                ],
              ],
            ),
          ),
          if (action != null) ...[const SizedBox(width: Space.stackGap), action!],
        ],
      ),
    );
  }
}
