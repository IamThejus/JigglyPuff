// TypeScript-parity models for every /api/v1 response shape.
//
// Design rule from the API contract: the backend NEVER fails when a subsystem
// is down. It returns `reachable` / `available` / `exists` flags + an optional
// `message`. Those flags are modelled as plain fields here and rendered as
// first-class "degraded" UI states — never thrown as errors.
//
// `*_human`, `uptime_human`, `eta_human` come pre-formatted from the API and
// are displayed verbatim; raw `*_bytes` / `*_percent` numbers only drive
// bars & gauges.

import '../utils/format.dart';

// ---------------------------------------------------------------------------
// Parsing helpers (defensive: the payloads carry many nullable / mixed fields).
// ---------------------------------------------------------------------------
double _d(Object? v, [double fallback = 0]) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? fallback;
  return fallback;
}

double? _dn(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

int _i(Object? v, [int fallback = 0]) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

int? _in(Object? v) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

bool _b(Object? v, [bool fallback = false]) => v is bool ? v : fallback;

String _s(Object? v, [String fallback = '']) => v is String ? v : (v?.toString() ?? fallback);

String? _sn(Object? v) => v is String ? v : null;

List<Map<String, dynamic>> _list(Object? v) => v is List
    ? v.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
    : const [];

List<String> _strings(Object? v) =>
    v is List ? v.map((e) => e.toString()).toList() : const [];

// ---------------------------------------------------------------------------
// GET /api/v1/health
// ---------------------------------------------------------------------------
class Health {
  final String status;
  final String version;
  final String time;

  const Health({required this.status, required this.version, required this.time});

  bool get isOk => status.toLowerCase() == 'ok';

  factory Health.fromJson(Map<String, dynamic> j) => Health(
        status: _s(j['status']),
        version: _s(j['version']),
        time: _s(j['time']),
      );
}

// ---------------------------------------------------------------------------
// Shared: a systemd-style service row.
// ---------------------------------------------------------------------------
class ServiceInfo {
  final String name;
  final bool active;
  final String state;
  final String subState;
  final bool enabled;

  const ServiceInfo({
    required this.name,
    required this.active,
    required this.state,
    required this.subState,
    required this.enabled,
  });

  factory ServiceInfo.fromJson(Map<String, dynamic> j) => ServiceInfo(
        name: _s(j['name']),
        active: _b(j['active']),
        state: _s(j['state']),
        subState: _s(j['sub_state']),
        enabled: _b(j['enabled']),
      );
}

// ---------------------------------------------------------------------------
// GET /api/v1/dashboard
// ---------------------------------------------------------------------------
class StorageBrief {
  final String primaryPath;
  final String totalHuman;
  final String usedHuman;
  final String freeHuman;
  final double percentUsed;

  const StorageBrief({
    required this.primaryPath,
    required this.totalHuman,
    required this.usedHuman,
    required this.freeHuman,
    required this.percentUsed,
  });

  factory StorageBrief.fromJson(Map<String, dynamic> j) => StorageBrief(
        primaryPath: _s(j['primary_path']),
        totalHuman: _s(j['total_human']),
        usedHuman: _s(j['used_human']),
        freeHuman: _s(j['free_human']),
        percentUsed: _d(j['percent_used']),
      );
}

class Dashboard {
  final String hostname;
  final String serverName;
  final int uptimeSeconds;
  final String uptimeHuman;
  final double cpuPercent;
  final double memoryPercent;
  final double diskPercentUsed;
  final StorageBrief storage;
  final int torrentsActive;
  final int torrentsDownloading;
  final int torrentsSeeding;
  final bool torrentsReachable;
  final int moviesCount;
  final int showsCount;
  final List<ServiceInfo> services;
  final String generatedAtIso;

  const Dashboard({
    required this.hostname,
    required this.serverName,
    required this.uptimeSeconds,
    required this.uptimeHuman,
    required this.cpuPercent,
    required this.memoryPercent,
    required this.diskPercentUsed,
    required this.storage,
    required this.torrentsActive,
    required this.torrentsDownloading,
    required this.torrentsSeeding,
    required this.torrentsReachable,
    required this.moviesCount,
    required this.showsCount,
    required this.services,
    required this.generatedAtIso,
  });

  factory Dashboard.fromJson(Map<String, dynamic> j) => Dashboard(
        hostname: _s(j['hostname']),
        serverName: _s(j['server_name']),
        uptimeSeconds: _i(j['uptime_seconds']),
        uptimeHuman: _s(j['uptime_human']),
        cpuPercent: _d(j['cpu_percent']),
        memoryPercent: _d(j['memory_percent']),
        diskPercentUsed: _d(j['disk_percent_used']),
        storage: StorageBrief.fromJson((j['storage'] as Map?)?.cast<String, dynamic>() ?? const {}),
        torrentsActive: _i(j['torrents_active']),
        torrentsDownloading: _i(j['torrents_downloading']),
        torrentsSeeding: _i(j['torrents_seeding']),
        torrentsReachable: _b(j['torrents_reachable'], true),
        moviesCount: _i(j['movies_count']),
        showsCount: _i(j['shows_count']),
        services: _list(j['services']).map(ServiceInfo.fromJson).toList(),
        generatedAtIso: _s(j['generated_at_iso']),
      );
}

// ---------------------------------------------------------------------------
// GET /api/v1/torrents/summary
// ---------------------------------------------------------------------------
class TorrentsSummary {
  final bool reachable;
  final int total;
  final int downloading;
  final int seeding;
  final int completed;
  final int paused;
  final int error;
  final int totalDlspeedBytes;
  final int totalUpspeedBytes;
  final String totalDlspeedHuman;
  final String totalUpspeedHuman;
  final String? message;

  // Client identity (nullable; all null when reachable == false).
  final String? clientName;
  final String? clientVersion;
  final String? node;

  const TorrentsSummary({
    required this.reachable,
    required this.total,
    required this.downloading,
    required this.seeding,
    required this.completed,
    required this.paused,
    required this.error,
    required this.totalDlspeedBytes,
    required this.totalUpspeedBytes,
    required this.totalDlspeedHuman,
    required this.totalUpspeedHuman,
    required this.message,
    this.clientName,
    this.clientVersion,
    this.node,
  });

  /// Human subtitle, e.g. "qBittorrent · v4.5.2 · Node 01". Empty if unknown.
  String get clientLabel => [
        if (clientName != null && clientName!.isNotEmpty) clientName!,
        if (clientVersion != null && clientVersion!.isNotEmpty) 'v$clientVersion',
        if (node != null && node!.isNotEmpty) node!,
      ].join(' · ');

  factory TorrentsSummary.fromJson(Map<String, dynamic> j) => TorrentsSummary(
        reachable: _b(j['reachable']),
        total: _i(j['total']),
        downloading: _i(j['downloading']),
        seeding: _i(j['seeding']),
        completed: _i(j['completed']),
        paused: _i(j['paused']),
        error: _i(j['error']),
        totalDlspeedBytes: _i(j['total_dlspeed_bytes']),
        totalUpspeedBytes: _i(j['total_upspeed_bytes']),
        totalDlspeedHuman: _s(j['total_dlspeed_human'], '0 B/s'),
        totalUpspeedHuman: _s(j['total_upspeed_human'], '0 B/s'),
        message: _sn(j['message']),
        clientName: _sn(j['client_name']),
        clientVersion: _sn(j['client_version']),
        node: _sn(j['node']),
      );
}

// ---------------------------------------------------------------------------
// GET /api/v1/torrents/list
// ---------------------------------------------------------------------------
class Torrent {
  final String hash;
  final String name;
  final String state;
  final String category;
  final double progress; // 0..1
  final double progressPercent; // 0..100
  final int sizeBytes;
  final String sizeHuman;
  final int downloadedBytes;
  final int dlspeedBytes;
  final int upspeedBytes;
  final String dlspeedHuman;
  final String upspeedHuman;
  final int etaSeconds;
  final String etaHuman;
  final double ratio;
  final int numSeeds;
  final int numLeechs;
  final String addedOnIso;

  const Torrent({
    required this.hash,
    required this.name,
    required this.state,
    required this.category,
    required this.progress,
    required this.progressPercent,
    required this.sizeBytes,
    required this.sizeHuman,
    required this.downloadedBytes,
    required this.dlspeedBytes,
    required this.upspeedBytes,
    required this.dlspeedHuman,
    required this.upspeedHuman,
    required this.etaSeconds,
    required this.etaHuman,
    required this.ratio,
    required this.numSeeds,
    required this.numLeechs,
    required this.addedOnIso,
  });

  factory Torrent.fromJson(Map<String, dynamic> j) => Torrent(
        hash: _s(j['hash']),
        name: _s(j['name']),
        state: _s(j['state']),
        category: _s(j['category']),
        progress: _d(j['progress']),
        progressPercent: _d(j['progress_percent']),
        sizeBytes: _i(j['size_bytes']),
        sizeHuman: _s(j['size_human']),
        downloadedBytes: _i(j['downloaded_bytes']),
        dlspeedBytes: _i(j['dlspeed_bytes']),
        upspeedBytes: _i(j['upspeed_bytes']),
        dlspeedHuman: _s(j['dlspeed_human'], '0 B/s'),
        upspeedHuman: _s(j['upspeed_human'], '0 B/s'),
        etaSeconds: _i(j['eta_seconds']),
        etaHuman: _s(j['eta_human']),
        ratio: _d(j['ratio']),
        numSeeds: _i(j['num_seeds']),
        numLeechs: _i(j['num_leechs']),
        addedOnIso: _s(j['added_on_iso']),
      );
}

class TorrentList {
  final bool reachable;
  final int count;
  final String? message;
  final List<Torrent> torrents;

  const TorrentList({
    required this.reachable,
    required this.count,
    required this.message,
    required this.torrents,
  });

  factory TorrentList.fromJson(Map<String, dynamic> j) => TorrentList(
        reachable: _b(j['reachable']),
        count: _i(j['count']),
        message: _sn(j['message']),
        torrents: _list(j['torrents']).map(Torrent.fromJson).toList(),
      );
}

// ---------------------------------------------------------------------------
// GET /api/v1/storage/summary
// ---------------------------------------------------------------------------
class DiskInfo {
  final String path;
  final bool exists;
  final int totalBytes;
  final int usedBytes;
  final int freeBytes;
  final double percentUsed;
  final String totalHuman;
  final String usedHuman;
  final String freeHuman;

  const DiskInfo({
    required this.path,
    required this.exists,
    required this.totalBytes,
    required this.usedBytes,
    required this.freeBytes,
    required this.percentUsed,
    required this.totalHuman,
    required this.usedHuman,
    required this.freeHuman,
  });

  factory DiskInfo.fromJson(Map<String, dynamic> j) => DiskInfo(
        path: _s(j['path']),
        exists: _b(j['exists'], true),
        totalBytes: _i(j['total_bytes']),
        usedBytes: _i(j['used_bytes']),
        freeBytes: _i(j['free_bytes']),
        percentUsed: _d(j['percent_used']),
        totalHuman: _s(j['total_human']),
        usedHuman: _s(j['used_human']),
        freeHuman: _s(j['free_human']),
      );
}

class FolderInfo {
  final String path;
  final bool exists;
  final int sizeBytes;
  final String sizeHuman;
  final int entryCount;

  const FolderInfo({
    required this.path,
    required this.exists,
    required this.sizeBytes,
    required this.sizeHuman,
    required this.entryCount,
  });

  factory FolderInfo.fromJson(Map<String, dynamic> j) => FolderInfo(
        path: _s(j['path']),
        exists: _b(j['exists'], true),
        sizeBytes: _i(j['size_bytes']),
        sizeHuman: _s(j['size_human']),
        entryCount: _i(j['entry_count']),
      );
}

class SmartInfo {
  final bool available;
  final String? device;
  final bool healthy;
  final String? status;
  final int? temperatureCelsius;
  final int? powerOnHours;
  final String? message;

  const SmartInfo({
    required this.available,
    required this.device,
    required this.healthy,
    required this.status,
    required this.temperatureCelsius,
    required this.powerOnHours,
    required this.message,
  });

  factory SmartInfo.fromJson(Map<String, dynamic>? j) => SmartInfo(
        available: _b(j?['available']),
        device: _sn(j?['device']),
        healthy: _b(j?['healthy']),
        status: _sn(j?['status']),
        temperatureCelsius: _in(j?['temperature_celsius']),
        powerOnHours: _in(j?['power_on_hours']),
        message: _sn(j?['message']),
      );
}

class StorageSummary {
  final List<DiskInfo> disks;
  final List<FolderInfo> folders;
  final SmartInfo smart;

  const StorageSummary({required this.disks, required this.folders, required this.smart});

  factory StorageSummary.fromJson(Map<String, dynamic> j) => StorageSummary(
        disks: _list(j['disks']).map(DiskInfo.fromJson).toList(),
        folders: _list(j['folders']).map(FolderInfo.fromJson).toList(),
        smart: SmartInfo.fromJson((j['smart'] as Map?)?.cast<String, dynamic>()),
      );
}

// ---------------------------------------------------------------------------
// GET /api/v1/system/overview
// ---------------------------------------------------------------------------
class LoadAverage {
  final double one;
  final double five;
  final double fifteen;
  const LoadAverage({required this.one, required this.five, required this.fifteen});

  static LoadAverage? fromJson(Map<String, dynamic>? j) => j == null
      ? null
      : LoadAverage(one: _d(j['one']), five: _d(j['five']), fifteen: _d(j['fifteen']));
}

class MemoryInfo {
  final int totalBytes;
  final int usedBytes;
  final int availableBytes;
  final double percent;
  final String totalHuman;
  final String usedHuman;

  const MemoryInfo({
    required this.totalBytes,
    required this.usedBytes,
    required this.availableBytes,
    required this.percent,
    required this.totalHuman,
    required this.usedHuman,
  });

  factory MemoryInfo.fromJson(Map<String, dynamic>? j) => MemoryInfo(
        totalBytes: _i(j?['total_bytes']),
        usedBytes: _i(j?['used_bytes']),
        availableBytes: _i(j?['available_bytes']),
        percent: _d(j?['percent']),
        totalHuman: _s(j?['total_human']),
        usedHuman: _s(j?['used_human']),
      );
}

class SwapInfo {
  final int totalBytes;
  final int usedBytes;
  final double percent;
  final String totalHuman;

  const SwapInfo({
    required this.totalBytes,
    required this.usedBytes,
    required this.percent,
    required this.totalHuman,
  });

  factory SwapInfo.fromJson(Map<String, dynamic>? j) => SwapInfo(
        totalBytes: _i(j?['total_bytes']),
        usedBytes: _i(j?['used_bytes']),
        percent: _d(j?['percent']),
        totalHuman: _s(j?['total_human']),
      );
}

class TemperatureInfo {
  final String label;
  final double currentCelsius;
  final double? highCelsius;
  final double? criticalCelsius;

  const TemperatureInfo({
    required this.label,
    required this.currentCelsius,
    required this.highCelsius,
    required this.criticalCelsius,
  });

  factory TemperatureInfo.fromJson(Map<String, dynamic> j) => TemperatureInfo(
        label: _s(j['label']),
        currentCelsius: _d(j['current_celsius']),
        highCelsius: _dn(j['high_celsius']),
        criticalCelsius: _dn(j['critical_celsius']),
      );
}

class BatteryInfo {
  final double percent;
  final bool? powerPlugged;
  final int? secsLeft;

  const BatteryInfo({required this.percent, required this.powerPlugged, required this.secsLeft});

  static BatteryInfo? fromJson(Map<String, dynamic>? j) => j == null
      ? null
      : BatteryInfo(
          percent: _d(j['percent']),
          powerPlugged: j['power_plugged'] is bool ? j['power_plugged'] as bool : null,
          secsLeft: _in(j['secs_left']),
        );
}

class NetInterface {
  final String name;
  final List<String> addresses;
  const NetInterface({required this.name, required this.addresses});

  factory NetInterface.fromJson(Map<String, dynamic> j) => NetInterface(
        name: _s(j['name']),
        addresses: (j['addresses'] is List)
            ? (j['addresses'] as List).map((e) => e.toString()).toList()
            : const [],
      );
}

class SystemOverview {
  final String hostname;
  final String os;
  final String kernel;
  final String architecture;
  final int uptimeSeconds;
  final String uptimeHuman;
  final String bootTimeIso;
  final double cpuPercent;
  final int cpuCountLogical;
  final int cpuCountPhysical;
  final LoadAverage? loadAverage;
  final MemoryInfo memory;
  final SwapInfo swap;
  final List<TemperatureInfo> temperatures;
  final BatteryInfo? battery;
  final List<NetInterface> interfaces;

  const SystemOverview({
    required this.hostname,
    required this.os,
    required this.kernel,
    required this.architecture,
    required this.uptimeSeconds,
    required this.uptimeHuman,
    required this.bootTimeIso,
    required this.cpuPercent,
    required this.cpuCountLogical,
    required this.cpuCountPhysical,
    required this.loadAverage,
    required this.memory,
    required this.swap,
    required this.temperatures,
    required this.battery,
    required this.interfaces,
  });

  factory SystemOverview.fromJson(Map<String, dynamic> j) => SystemOverview(
        hostname: _s(j['hostname']),
        os: _s(j['os']),
        kernel: _s(j['kernel']),
        architecture: _s(j['architecture']),
        uptimeSeconds: _i(j['uptime_seconds']),
        uptimeHuman: _s(j['uptime_human']),
        bootTimeIso: _s(j['boot_time_iso']),
        cpuPercent: _d(j['cpu_percent']),
        cpuCountLogical: _i(j['cpu_count_logical']),
        cpuCountPhysical: _i(j['cpu_count_physical']),
        loadAverage: LoadAverage.fromJson((j['load_average'] as Map?)?.cast<String, dynamic>()),
        memory: MemoryInfo.fromJson((j['memory'] as Map?)?.cast<String, dynamic>()),
        swap: SwapInfo.fromJson((j['swap'] as Map?)?.cast<String, dynamic>()),
        temperatures: _list(j['temperatures']).map(TemperatureInfo.fromJson).toList(),
        battery: BatteryInfo.fromJson((j['battery'] as Map?)?.cast<String, dynamic>()),
        interfaces: _list(j['interfaces']).map(NetInterface.fromJson).toList(),
      );
}

// ---------------------------------------------------------------------------
// GET /api/v1/library/summary  &  /library/{movies,shows}
// ---------------------------------------------------------------------------
class LibraryItem {
  final String name;
  final String path;
  final bool isDir;
  final int sizeBytes;
  final String sizeHuman;
  final String modifiedIso;

  // Optional enrichment (see API_UPGRADE_SPEC.md). All null until the backend
  // ships them; the UI falls back to parsing the [name] client-side.
  final String? posterUrl;
  final String? thumbUrl;
  final int? year;
  final String? quality;
  final bool hdr;
  final String? jellyfinId;

  const LibraryItem({
    required this.name,
    required this.path,
    required this.isDir,
    required this.sizeBytes,
    required this.sizeHuman,
    required this.modifiedIso,
    this.posterUrl,
    this.thumbUrl,
    this.year,
    this.quality,
    this.hdr = false,
    this.jellyfinId,
  });

  factory LibraryItem.fromJson(Map<String, dynamic> j) => LibraryItem(
        name: _s(j['name']),
        path: _s(j['path']),
        isDir: _b(j['is_dir'], true),
        sizeBytes: _i(j['size_bytes']),
        sizeHuman: _s(j['size_human'], '0 B'),
        modifiedIso: _s(j['modified_iso']),
        posterUrl: _sn(j['poster_url']),
        thumbUrl: _sn(j['thumb_url']),
        year: _in(j['year']),
        quality: _sn(j['quality']),
        hdr: _b(j['hdr']),
        jellyfinId: _sn(j['jellyfin_id']),
      );
}

class LibrarySummary {
  final int moviesCount;
  final int showsCount;
  final String moviesRoot;
  final String showsRoot;
  final bool moviesExists;
  final bool showsExists;
  final List<LibraryItem> recentlyAdded;

  const LibrarySummary({
    required this.moviesCount,
    required this.showsCount,
    required this.moviesRoot,
    required this.showsRoot,
    required this.moviesExists,
    required this.showsExists,
    required this.recentlyAdded,
  });

  factory LibrarySummary.fromJson(Map<String, dynamic> j) => LibrarySummary(
        moviesCount: _i(j['movies_count']),
        showsCount: _i(j['shows_count']),
        moviesRoot: _s(j['movies_root']),
        showsRoot: _s(j['shows_root']),
        moviesExists: _b(j['movies_exists'], true),
        showsExists: _b(j['shows_exists'], true),
        recentlyAdded: _list(j['recently_added']).map(LibraryItem.fromJson).toList(),
      );
}

class LibraryList {
  final String category;
  final String root;
  final bool exists;
  final int count;
  final List<LibraryItem> items;

  const LibraryList({
    required this.category,
    required this.root,
    required this.exists,
    required this.count,
    required this.items,
  });

  factory LibraryList.fromJson(Map<String, dynamic> j) => LibraryList(
        category: _s(j['category']),
        root: _s(j['root']),
        exists: _b(j['exists'], true),
        count: _i(j['count']),
        items: _list(j['items']).map(LibraryItem.fromJson).toList(),
      );
}

// ---------------------------------------------------------------------------
// GET /api/v1/services
// ---------------------------------------------------------------------------
class ServicesResponse {
  final bool available;
  final String? message;
  final List<ServiceInfo> services;

  const ServicesResponse({required this.available, required this.message, required this.services});

  factory ServicesResponse.fromJson(Map<String, dynamic> j) => ServicesResponse(
        available: _b(j['available'], true),
        message: _sn(j['message']),
        services: _list(j['services']).map(ServiceInfo.fromJson).toList(),
      );
}

// ---------------------------------------------------------------------------
// POST /api/v1/actions/* (control actions — require X-API-Key)
// ---------------------------------------------------------------------------
/// Reply shape for the control endpoints. `ok: false` with a `message` is a
/// *soft* failure (e.g. qBittorrent briefly unreachable) surfaced as a toast,
/// not a hard error. `exitCode`/`output`/`moved`/`skipped`/`torrentsRemoved`
/// are only populated by `sync-movies`.
class ActionResult {
  final bool ok;
  final String? message;
  final int? exitCode;
  final String? output;
  final List<String> moved;
  final List<String> skipped;
  final int? torrentsRemoved;

  const ActionResult({
    required this.ok,
    this.message,
    this.exitCode,
    this.output,
    this.moved = const [],
    this.skipped = const [],
    this.torrentsRemoved,
  });

  factory ActionResult.fromJson(Map<String, dynamic> j) => ActionResult(
        ok: _b(j['ok']),
        message: _sn(j['message']),
        exitCode: _in(j['exit_code']),
        output: _sn(j['output']),
        moved: _strings(j['moved']),
        skipped: _strings(j['skipped']),
        torrentsRemoved: _in(j['torrents_removed']),
      );

  /// A one-line summary for sync-movies, e.g. "Moved 2 · removed 2 torrents".
  String get syncSummary {
    final parts = <String>[
      'Moved ${moved.length}',
      if (skipped.isNotEmpty) 'skipped ${skipped.length}',
      if ((torrentsRemoved ?? 0) > 0) 'removed $torrentsRemoved torrents',
    ];
    return parts.join(' · ');
  }
}

// ---------------------------------------------------------------------------
// GET /api/v1/movies/search?q=  &  /movies/torrents?title=
// ---------------------------------------------------------------------------
class MovieSearchResult {
  final int id;
  final String title;
  final String year;
  final String language;
  final double rating;
  final String overview;
  final String thumbnail;

  const MovieSearchResult({
    required this.id,
    required this.title,
    required this.year,
    required this.language,
    required this.rating,
    required this.overview,
    required this.thumbnail,
  });

  factory MovieSearchResult.fromJson(Map<String, dynamic> j) => MovieSearchResult(
        id: _i(j['id']),
        title: _s(j['title']),
        year: _s(j['year']),
        language: _s(j['language']),
        rating: _d(j['rating']),
        overview: _s(j['overview']),
        thumbnail: _s(j['thumbnail']),
      );
}

class MovieSearchResponse {
  final bool success;
  final List<MovieSearchResult> results;

  const MovieSearchResponse({required this.success, required this.results});

  factory MovieSearchResponse.fromJson(Map<String, dynamic> j) => MovieSearchResponse(
        success: _b(j['success'], true),
        results: _list(j['results']).map(MovieSearchResult.fromJson).toList(),
      );
}

class MovieTorrent {
  final String title;
  final int seeds;
  final int peers;
  final int bytes;
  final String magnetUrl;
  final String hash;
  final String source;

  const MovieTorrent({
    required this.title,
    required this.seeds,
    required this.peers,
    required this.bytes,
    required this.magnetUrl,
    required this.hash,
    required this.source,
  });

  factory MovieTorrent.fromJson(Map<String, dynamic> j) => MovieTorrent(
        title: _s(j['title']),
        seeds: _i(j['seeds']),
        peers: _i(j['peers']),
        bytes: _i(j['bytes']),
        magnetUrl: _s(j['magnetUrl']),
        hash: _s(j['hash']),
        source: _s(j['source']),
      );

  /// Human file size from the raw byte count.
  String get sizeHuman => Fmt.bytes(bytes);

  /// Quality/source chips inferred from the title (720p, BluRay, …).
  List<String> get qualityTags => inferQualityTags(title);
}

class MovieTorrentsResponse {
  final bool success;
  final List<MovieTorrent> results;

  const MovieTorrentsResponse({required this.success, required this.results});

  factory MovieTorrentsResponse.fromJson(Map<String, dynamic> j) => MovieTorrentsResponse(
        success: _b(j['success'], true),
        // Sorted highest-seeds-first for display.
        results: _list(j['results']).map(MovieTorrent.fromJson).toList()
          ..sort((a, b) => b.seeds.compareTo(a.seeds)),
      );
}
