/// Small display helpers. Most human-readable values come pre-formatted from
/// the API; these cover the ISO timestamps that don't.
class Fmt {
  Fmt._();

  /// "3h ago", "2d ago", "just now" from an ISO-8601 string. Empty on failure.
  static String relative(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt.toLocal());
    if (diff.isNegative) return 'just now';
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    final months = diff.inDays ~/ 30;
    if (months < 12) return '${months}mo ago';
    return '${diff.inDays ~/ 365}y ago';
  }

  /// "Jul 08, 2026" from an ISO string. Empty on failure.
  static String date(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final l = dt.toLocal();
    final d = l.day.toString().padLeft(2, '0');
    return '${months[l.month - 1]} $d, ${l.year}';
  }

  /// "629.8 MB" / "1.2 GB" from a raw byte count (torrent search returns raw
  /// `bytes`, not a pre-formatted `*_human` string).
  static String bytes(int b) {
    if (b <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var size = b.toDouble();
    var i = 0;
    while (size >= 1024 && i < units.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(i == 0 ? 0 : 1)} ${units[i]}';
  }
}

/// Quality / source tags inferred from a torrent title, e.g.
/// "Just Friends (2005) 720p BrRip x264" → ["720p", "BRRip"].
List<String> inferQualityTags(String title) {
  final tags = <String>[];

  final res = RegExp(r'\b(2160p|4k|uhd|1080p|720p|480p)\b', caseSensitive: false).firstMatch(title);
  if (res != null) {
    var q = res.group(1)!.toLowerCase();
    if (q == '4k' || q == 'uhd') q = '2160p';
    tags.add(q);
  }

  const sources = <String, String>{
    r'blu-?ray': 'BluRay',
    r'brrip': 'BRRip',
    r'bdrip': 'BDRip',
    r'web-?dl': 'WEB-DL',
    r'web-?rip': 'WEBRip',
    r'hdrip': 'HDRip',
    r'hdtv': 'HDTV',
    r'remux': 'REMUX',
    r'hdr10\+?|hdr': 'HDR',
  };
  for (final entry in sources.entries) {
    if (RegExp('\\b(?:${entry.key})\\b', caseSensitive: false).hasMatch(title) &&
        !tags.contains(entry.value)) {
      tags.add(entry.value);
    }
  }
  return tags;
}
