/// Parsed presentation metadata for a library folder name.
///
/// The v1 API only exposes the raw directory `name` (e.g.
/// `The.Dark.Knight.Rises.2012.2160p.HDR.BluRay.x265`), so we derive a clean
/// display title + year/quality/HDR tags on the client. When the backend later
/// supplies real `year`/`quality`/`hdr`/`poster_url` fields
/// (see API_UPGRADE_SPEC.md), prefer those via [MediaTitle.of].
class MediaTitle {
  final String title;
  final int? year;
  final String? quality; // normalised: 2160p | 1080p | 720p | 480p
  final bool hdr;

  const MediaTitle({required this.title, this.year, this.quality, this.hdr = false});

  /// Small tags for the UI, e.g. ["2160p", "HDR"]. Year is shown separately.
  List<String> get tags => [
        ?quality,
        if (hdr) 'HDR',
      ];

  static final _yearRe = RegExp(r'(?:^|[^\d])((?:19|20)\d{2})(?:[^\d]|$)');
  static final _qualityRe = RegExp(r'\b(2160p|1080p|720p|480p|4k|uhd)\b', caseSensitive: false);
  static final _hdrRe = RegExp(r'\b(hdr10\+?|hdr|dolby[\s._-]*vision|dovi|dv)\b', caseSensitive: false);
  static final _sep = RegExp(r'[._]+');
  static final _ws = RegExp(r'\s+');

  // Release-junk tokens dropped from the title when there is no year to cut at.
  static final _junkRe = RegExp(
    r'\b(2160p|1080p|720p|480p|4k|uhd|hdr10\+?|hdr|dovi|dv|bluray|blu-ray|brrip|bdrip'
    r'|web-?dl|web-?rip|webrip|hdtv|remux|x264|x265|h\.?264|h\.?265|hevc|avc'
    r'|aac|ac3|dts(?:-hd)?|truehd|atmos|ddp?5\.1|10bit|8bit|repack|proper|extended|imax)\b',
    caseSensitive: false,
  );

  /// Prefer backend-supplied fields; fall back to parsing [rawName].
  factory MediaTitle.of({
    required String rawName,
    int? year,
    String? quality,
    bool hdr = false,
  }) {
    final parsed = MediaTitle.parse(rawName);
    return MediaTitle(
      title: parsed.title,
      year: year ?? parsed.year,
      quality: _normalizeQuality(quality) ?? parsed.quality,
      hdr: hdr || parsed.hdr,
    );
  }

  factory MediaTitle.parse(String raw) {
    final yearMatch = _yearRe.firstMatch(raw);
    final year = yearMatch == null ? null : int.tryParse(yearMatch.group(1)!);
    final quality = _normalizeQuality(_qualityRe.firstMatch(raw)?.group(1));
    final hdr = _hdrRe.hasMatch(raw);

    // Title = everything before the year token; else the whole name minus junk.
    var titlePart = yearMatch != null ? raw.substring(0, yearMatch.start) : raw;
    titlePart = titlePart.replaceAll(_sep, ' ');
    if (yearMatch == null) {
      titlePart = titlePart.replaceAll(_junkRe, ' ');
    }
    // Strip a dangling opening paren/bracket left by "Title (2014)".
    var title = titlePart.replaceAll(RegExp(r'[\(\[\{]\s*$'), '').replaceAll(_ws, ' ').trim();
    if (title.isEmpty) title = raw.replaceAll(_sep, ' ').trim();

    return MediaTitle(title: title, year: year, quality: quality, hdr: hdr);
  }

  static String? _normalizeQuality(String? q) {
    if (q == null) return null;
    final l = q.toLowerCase();
    if (l == '4k' || l == 'uhd' || l == '2160p') return '2160p';
    return l;
  }
}
