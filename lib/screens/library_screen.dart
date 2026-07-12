import 'package:flutter/material.dart';

import '../api/endpoints.dart';
import '../api/models.dart';
import '../data/polling_view.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../utils/media_title.dart';
import '../widgets/cards.dart';
import '../widgets/poster_image.dart';
import '../widgets/segmented.dart';
import '../widgets/server_app_bar.dart';
import '../widgets/states.dart';

/// Library tab: counts + recently-added strip from `/library/summary`, plus a
/// movies/shows toggle listing `/library/{movies,shows}`. Lists default to
/// `sizes=false` (fast); a toggle loads per-item sizes. Search filters the
/// loaded list client-side.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

enum _Category { movies, shows }

class _LibraryScreenState extends State<LibraryScreen> {
  _Category _category = _Category.movies;
  String _query = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Item sizes are always loaded.
  Future<LibraryList> _fetchList(MediaServerApi api) =>
      _category == _Category.movies ? api.movies(sizes: true) : api.shows(sizes: true);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ServerAppBar(),
      body: PollingView<LibraryList>(
        // refetchKey (not a Key) re-fetches on category switch while keeping
        // the current list on screen — no full-screen loading flash.
        refetchKey: _category.name,
        interval: Duration.zero, // library lists don't need continuous polling
        fetch: _fetchList,
        loadingLabel: 'Loading library…',
        builder: (context, list, controller) {
          final items = _query.isEmpty
              ? list.items
              : list.items.where((i) => i.name.toLowerCase().contains(_query.toLowerCase())).toList();
          return RefreshableBody(
            onRefresh: controller.refresh,
            children: [
              Text('Library Overview', style: AppText.headlineLg()),
              const SizedBox(height: Space.gutter),
              const _LibrarySummary(),
              const SizedBox(height: Space.gutter),
              _segmented(),
              const SizedBox(height: Space.stackGap),
              _searchField(),
              const SizedBox(height: Space.stackGap),
              _controlsRow(list.count, items.length),
              _RefreshLine(active: controller.value.isRefreshing),
              const SizedBox(height: Space.stackGap),
              if (!list.exists)
                DegradedState(
                  title: '${_category.name} path not found',
                  message: list.root,
                  icon: Icons.folder_off_outlined,
                  level: StatusLevel.warning,
                )
              else if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 32),
                  child: EmptyState(
                    title: _query.isEmpty ? 'Empty' : 'No matches',
                    message: _query.isEmpty ? 'Nothing in this library.' : 'No titles match "$_query".',
                    icon: Icons.movie_filter_outlined,
                  ),
                )
              else
                GlassCard(
                  padding: EdgeInsets.zero,
                  child: Column(children: [for (final i in items) _LibraryRow(i)]),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _segmented() {
    return AnimatedSegmented(
      labels: const ['Movies', 'Shows'],
      index: _category.index,
      onChanged: (i) => setState(() => _category = _Category.values[i]),
    );
  }

  Widget _searchField() {
    return TextField(
      controller: _searchController,
      onChanged: (v) => setState(() => _query = v),
      style: AppText.bodySm(color: AppColors.onSurface),
      decoration: InputDecoration(
        hintText: 'Search ${_category.name}…',
        hintStyle: AppText.bodySm(color: AppColors.outline),
        prefixIcon: const Icon(Icons.search, color: AppColors.onSurfaceVariant, size: 20),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close, size: 18, color: AppColors.onSurfaceVariant),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _query = '');
                },
              ),
        filled: true,
        fillColor: AppColors.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(vertical: 4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.chip),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _controlsRow(int total, int shown) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text('$shown / $total titles', style: AppText.labelTechnical()),
    );
  }
}

/// A hairline accent bar that fades in only while a toggle re-fetch is in
/// flight — signals "loading" without the full-screen spinner.
class _RefreshLine extends StatelessWidget {
  const _RefreshLine({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: active ? 1 : 0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        margin: const EdgeInsets.only(top: 6),
        height: 2,
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(Radii.full),
        ),
      ),
    );
  }
}

class _LibrarySummary extends StatelessWidget {
  const _LibrarySummary();

  @override
  Widget build(BuildContext context) {
    return PollingView<LibrarySummary>(
      interval: Duration.zero,
      fetch: (api) => api.librarySummary(),
      builder: (context, s, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: _countCard('MOVIES', s.moviesCount, Icons.movie_rounded, s.moviesExists)),
              const SizedBox(width: Space.stackGap),
              Expanded(child: _countCard('SHOWS', s.showsCount, Icons.tv_rounded, s.showsExists)),
            ]),
            const SizedBox(height: Space.stackGap),
            _rootCard(s),
            if (s.recentlyAdded.isNotEmpty) ...[
              const SizedBox(height: Space.gutter),
              Text('RECENTLY ADDED', style: AppText.labelCaps()),
              const SizedBox(height: Space.stackGap),
              SizedBox(
                height: 196,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: s.recentlyAdded.length,
                  separatorBuilder: (_, _) => const SizedBox(width: Space.stackGap),
                  itemBuilder: (context, i) => _PosterCard(s.recentlyAdded[i]),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _countCard(String label, int count, IconData icon, bool exists) {
    return StatCard(
      label: label,
      trailing: Icon(icon, size: 18, color: AppColors.accent),
      child: Align(alignment: Alignment.centerLeft, child: Text('$count', style: AppText.displayMetrics())),
    );
  }

  Widget _rootCard(LibrarySummary s) {
    final online = s.moviesExists && s.showsExists;
    return GlassCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ROOT PATH', style: AppText.labelTechnical()),
                const SizedBox(height: 6),
                Text(s.moviesRoot, style: AppText.labelTechnical(color: AppColors.onSurface),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Row(children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: (online ? StatusLevel.healthy : StatusLevel.warning).color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(online ? 'ONLINE' : 'CHECK',
                style: AppText.labelTechnical(
                    color: online ? AppColors.statusHealthy : AppColors.statusWarning)),
          ]),
        ],
      ),
    );
  }
}

/// Poster placeholder (the API exposes no artwork) — a tinted gradient tile
/// with a film glyph, title and added-date.
class _PosterCard extends StatelessWidget {
  const _PosterCard(this.item);
  final LibraryItem item;

  @override
  Widget build(BuildContext context) {
    final m = MediaTitle.of(
        rawName: item.name, year: item.year, quality: item.quality, hdr: item.hdr);
    final tag = m.tags.join(' ');
    return SizedBox(
      width: 120,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              PosterImage(
                url: item.posterUrl ?? item.thumbUrl,
                width: 120,
                height: 140,
                showBorder: true,
              ),
              if (tag.isNotEmpty)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(Radii.sm),
                    ),
                    child: Text(tag, style: AppText.labelTechnical(color: AppColors.accentSoft)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(m.title,
              style: AppText.bodySm(color: AppColors.onSurface).copyWith(fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          Text(
            [if (m.year != null) '${m.year}', Fmt.relative(item.modifiedIso)]
                .where((s) => s.isNotEmpty)
                .join(' · '),
            style: AppText.labelTechnical(),
          ),
        ],
      ),
    );
  }
}

class _LibraryRow extends StatelessWidget {
  const _LibraryRow(this.item);
  final LibraryItem item;

  @override
  Widget build(BuildContext context) {
    final hasSize = item.sizeBytes > 0;
    final m = MediaTitle.of(
        rawName: item.name, year: item.year, quality: item.quality, hdr: item.hdr);
    final meta = [
      if (m.year != null) '${m.year}',
      if (hasSize) item.sizeHuman,
      if (item.modifiedIso.isNotEmpty) Fmt.date(item.modifiedIso),
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.all(Space.gutter),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.glassStrokeFaint)),
      ),
      child: Row(
        children: [
          PosterImage(
            url: item.thumbUrl ?? item.posterUrl,
            width: 40,
            height: 40,
            icon: item.isDir ? Icons.folder_outlined : Icons.movie_outlined,
            iconSize: 18,
          ),
          const SizedBox(width: Space.stackGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(m.title,
                          style: AppText.bodyLg().copyWith(fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    for (final t in m.tags) ...[
                      const SizedBox(width: 6),
                      _MetaBadge(t),
                    ],
                  ],
                ),
                if (meta.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(meta, style: AppText.labelTechnical()),
                  ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 20, color: AppColors.onSurfaceVariant),
        ],
      ),
    );
  }
}

/// Small pink-tinted pill for a quality/HDR tag.
class _MetaBadge extends StatelessWidget {
  const _MetaBadge(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.accentDim,
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Text(text, style: AppText.labelTechnical(color: AppColors.accentSoft)),
    );
  }
}
