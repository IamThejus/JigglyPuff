import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../theme/app_theme.dart';

/// Loads library artwork from a (possibly relative) `poster_url` / `thumb_url`,
/// resolving it against the configured base URL and attaching the auth header.
///
/// Backed by [CachedNetworkImage], so fetched posters are **cached on disk**
/// (persisting across app restarts) and revalidated via the server's
/// Cache-Control/ETag. Falls back to the pink-gradient placeholder for a null
/// URL, while loading, or on any fetch error — a failed image is expected &
/// harmless, never a "Server Unreachable" state.
class PosterImage extends StatelessWidget {
  const PosterImage({
    super.key,
    required this.url,
    required this.width,
    required this.height,
    this.radius = Radii.chip,
    this.icon = Icons.movie_outlined,
    this.iconSize = 30,
    this.showBorder = false,
  });

  final String? url;
  final double width;
  final double height;
  final double radius;
  final IconData icon;
  final double iconSize;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    final config = context.watch<AppConfig>();
    final abs = config.resolveUrl(url);
    final placeholder = _placeholder();

    final child = abs == null
        ? placeholder
        : CachedNetworkImage(
            imageUrl: abs,
            width: width,
            height: height,
            fit: BoxFit.cover,
            httpHeaders: config.authHeader,
            fadeInDuration: const Duration(milliseconds: 200),
            // Cache key excludes the base URL so a LAN↔remote base switch
            // reuses the same cached art (same id/path, different host).
            cacheKey: url,
            placeholder: (_, _) => placeholder,
            errorWidget: (_, _, _) => placeholder,
          );

    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: child);
  }

  Widget _placeholder() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.accentDim, AppColors.surfaceContainerHigh],
        ),
        border: showBorder ? Border.all(color: AppColors.glassStrokeFaint) : null,
      ),
      child: Center(child: Icon(icon, color: AppColors.accentSoft, size: iconSize)),
    );
  }
}
