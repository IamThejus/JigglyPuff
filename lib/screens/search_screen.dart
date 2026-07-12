import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../config.dart';
import '../data/movie_search_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/poster_image.dart';
import '../widgets/server_app_bar.dart';
import '../widgets/shimmer.dart';
import '../widgets/states.dart';
import '../widgets/torrent_sheet.dart';

/// Movie discovery: a debounced search bar over `GET /movies/search`, a
/// streaming-app-style result list, and a tap-through to the torrent sheet.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final MovieSearchController _search;
  final _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Controller holds the stable AppConfig and builds a fresh ApiClient per
    // request, so a base-URL change in Settings is picked up automatically.
    _search = MovieSearchController(context.read<AppConfig>());
  }

  @override
  void dispose() {
    _textController.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ServerAppBar(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Space.containerPadding, Space.gutter, Space.containerPadding, Space.stackGap),
            child: _searchField(),
          ),
          Expanded(
            child: AnimatedBuilder(
              animation: _search,
              builder: (context, _) => _resultsArea(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchField() {
    // Scoped to the text value so only the field (its clear button) rebuilds
    // on keystrokes — the results area rebuilds separately via the controller.
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _textController,
      builder: (context, value, _) => TextField(
        controller: _textController,
        onChanged: _search.onQueryChanged,
        autocorrect: false,
        textInputAction: TextInputAction.search,
        style: AppText.bodyLg(color: AppColors.onSurface),
        decoration: InputDecoration(
          hintText: 'Search movies…',
          hintStyle: AppText.bodyLg(color: AppColors.outline),
          prefixIcon: const Icon(Icons.search, color: AppColors.onSurfaceVariant),
          suffixIcon: value.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, color: AppColors.onSurfaceVariant),
                  onPressed: () {
                    _textController.clear();
                    _search.onQueryChanged('');
                  },
                ),
          filled: true,
          fillColor: AppColors.surfaceContainerLow,
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Radii.chip),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Radii.chip),
            borderSide: const BorderSide(color: AppColors.glassStrokeFaint),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Radii.chip),
            borderSide: const BorderSide(color: AppColors.accent),
          ),
        ),
      ),
    );
  }

  Widget _resultsArea() {
    final Widget child = switch (_search.phase) {
      SearchPhase.idle => const _Hint(),
      SearchPhase.loading => const _SkeletonList(),
      SearchPhase.error => _SearchError(error: _search.error!, onRetry: _search.retry),
      SearchPhase.empty => const EmptyState(
          title: 'No movies found',
          message: 'Try another search.',
          icon: Icons.movie_filter_outlined,
        ),
      SearchPhase.results => _ResultsList(results: _search.results),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      switchInCurve: Curves.easeOut,
      child: KeyedSubtree(key: ValueKey(_search.phase), child: child),
    );
  }
}

/// Idle prompt shown before a valid query is entered.
class _Hint extends StatelessWidget {
  const _Hint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.sectionMargin),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.travel_explore_outlined, size: 44, color: AppColors.outline),
            const SizedBox(height: Space.gutter),
            Text('Discover movies', style: AppText.headlineMd(color: AppColors.onSurfaceVariant)),
            const SizedBox(height: 6),
            Text('Type at least 2 characters to search.',
                style: AppText.bodySm(), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ResultsList extends StatelessWidget {
  const _ResultsList({required this.results});
  final List<MovieSearchResult> results;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
          Space.containerPadding, 0, Space.containerPadding, 120),
      itemCount: results.length,
      separatorBuilder: (_, _) => const SizedBox(height: Space.stackGap),
      itemBuilder: (context, i) => _MovieTile(movie: results[i]),
    );
  }
}

class _MovieTile extends StatelessWidget {
  const _MovieTile({required this.movie});
  final MovieSearchResult movie;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(Radii.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.card),
        onTap: () => showTorrentSheet(context, movie),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PosterImage(
                url: movie.thumbnail,
                width: 92,
                height: 138,
                radius: Radii.chip,
                showBorder: true,
              ),
              const SizedBox(width: Space.gutter),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(movie.title,
                        style: AppText.bodyLg().copyWith(fontWeight: FontWeight.w600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    _metaRow(),
                    const SizedBox(height: 8),
                    Text(
                      movie.overview.isEmpty ? 'No overview available.' : movie.overview,
                      style: AppText.bodySm(),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metaRow() {
    return Wrap(
      spacing: 10,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (movie.year.isNotEmpty)
          Text(movie.year, style: AppText.labelTechnical(color: AppColors.onSurface)),
        if (movie.rating > 0)
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.star_rounded, size: 15, color: AppColors.statusWarning),
            const SizedBox(width: 3),
            Text(movie.rating.toStringAsFixed(1),
                style: AppText.labelTechnical(color: AppColors.onSurface)),
          ]),
        if (movie.language.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(Radii.sm),
            ),
            child: Text(movie.language.toUpperCase(), style: AppText.labelTechnical()),
          ),
      ],
    );
  }
}

/// Animated skeleton placeholders while a search is in flight.
class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
            Space.containerPadding, 0, Space.containerPadding, 120),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 6,
        separatorBuilder: (_, _) => const SizedBox(height: Space.stackGap),
        itemBuilder: (_, _) => Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(Radii.card),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SkeletonBox(width: 92, height: 138, radius: Radii.chip),
              const SizedBox(width: Space.gutter),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    SkeletonBox(width: 160, height: 16),
                    SizedBox(height: 10),
                    SkeletonBox(width: 100, height: 12),
                    SizedBox(height: 14),
                    SkeletonBox(height: 10),
                    SizedBox(height: 6),
                    SkeletonBox(height: 10),
                    SizedBox(height: 6),
                    SkeletonBox(width: 180, height: 10),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchError extends StatelessWidget {
  const _SearchError({required this.error, required this.onRetry});
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
            const Icon(Icons.cloud_off_rounded, color: AppColors.errorText, size: 40),
            const SizedBox(height: Space.stackGap),
            Text('Search failed', style: AppText.headlineMd(), textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(api?.message ?? 'Check your connection and try again.',
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
