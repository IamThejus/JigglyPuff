# CLAUDE.md

This file orients Claude Code (or any future contributor) working in this
repository. Read this before making changes.

## What this project is

**JigglyPuff** is a read-only Flutter (Android) monitoring dashboard for a
self-hosted Dell home media server. It talks to the `media-server-api` FastAPI
backend (a sibling project — see `../../media-server-api` if present) over
plain HTTP on the LAN, and renders system health, storage, torrent activity,
library contents, and service status, with live auto-refresh.

It is a **pure client**: no local database, no business logic beyond display
formatting, no write operations (v1 is entirely `GET`). Everything the app
shows is a direct, typed reflection of one backend JSON response.

Design references live in `../stitch_dell_server_sentinel/` (Stitch mockups —
HTML + screenshots) and `../mobile-app-prompt.md` (the original build brief).
The shipped visual design diverged from both into a pink-branded "JigglyPuff"
look (see `theme/colors.dart`) — treat the mockups as history, not a spec to
match pixel-for-pixel.

## Source of truth for the API contract

**`../api_change.md`** and **`../API_UPGRADE_SPEC.md`** (one directory up, next
to this project) describe the current and historical backend contract. When
the backend changes again, a new `api_change.md`-style doc is the expected way
that gets communicated — read it, then update `lib/api/models.dart`,
`lib/api/endpoints.dart`, this file, and `README.md` together.

**Golden rule of this API, load-bearing everywhere in the codebase:** the
backend *never* returns an HTTP error for a subsystem being down. Instead a
`200` response carries a boolean flag (`reachable`, `available`, `exists`) and
an optional `message`. qBittorrent offline, SMART unavailable, a missing
library path — none of these are exceptions. They are normal, successful API
responses that the UI renders as a **degraded** state (amber/red inline
banner), never as a connectivity error. Only a real transport failure (timeout,
DNS/connection refused, non-2xx HTTP, malformed JSON) is a "the backend itself
is unreachable" error. This distinction shapes the whole data layer — see
"The four states" below.

## Architecture

```text
lib/
├─ main.dart                    # boot: load AppConfig, provide it, show SplashScreen
├─ config.dart                  # AppConfig: base URL / auth token / actions API key / refresh interval (persisted)
├─ api/
│  ├─ api_client.dart           # ApiClient: GET + POST(json/multipart) wrapper, base-URL/query building, ApiException
│  ├─ models.dart                # every response shape as a typed, defensively-parsed class
│  └─ endpoints.dart             # MediaServerApi: the ONLY file that knows route paths (incl. /actions/* + /ws)
├─ data/
│  ├─ async_value.dart           # AsyncValue<T>: loading / error / data, keeps previous data
│  ├─ polling_view.dart          # PollController + PollingView<T>: the interval-polling engine
│  ├─ torrent_stream.dart        # TorrentStreamController + TorrentStreamView: WebSocket live torrents w/ REST fallback
│  └─ movie_search_controller.dart # debounced (350ms, min-2-char, cancel-stale) movie-search state machine
├─ theme/
│  ├─ colors.dart                # Obsidian palette + JigglyPuff pink accent + status-level logic
│  ├─ typography.dart            # Manrope (headlines/metrics) / Inter (body) / JetBrains Mono (labels)
│  ├─ spacing.dart                # 4px-baseline spacing scale + corner radii
│  └─ app_theme.dart              # ThemeData + re-exports the three files above
├─ widgets/                      # presentational, screen-agnostic components (see below)
├─ screens/                      # one file per screen/tab (see below)
├─ navigation/root_shell.dart     # bottom-tab shell (IndexedStack keeps every tab's pollers alive)
└─ utils/
   ├─ format.dart                 # ISO timestamp → relative/date; byte-count → human; quality-tag inference
   ├─ media_title.dart            # filename → {title, year, quality, hdr} parser (fallback path)
   └─ control_action.dart         # runControlAction(): the ONE gated qBittorrent/actions runner (key gate + toasts)
```

### The data-fetching model (read this before touching any screen)

The app has no global state store. **React Query's cache is the state** —
mirrored here as a small hand-rolled polling engine in `lib/data/`:

- **`AsyncValue<T>`** (`data/async_value.dart`) — a tri-state container:
  `loading` (nothing yet), `error` (with optional previous data still
  attached), `data`. `isInitialLoading` / `isRefreshing` distinguish first load
  from a background refetch.
- **`PollController<T>`** (`data/polling_view.dart`) — fetches on construction,
  re-fetches on a `Timer.periodic`, **keeps previous data visible during
  refetches** (so gauges don't flash to a spinner every poll), cancels/re-arms
  the timer on app lifecycle changes (pauses in background, refetches on
  resume), and guards against races with a monotonic `_requestId`.
- **`PollingView<T>`** — the widget screens actually use. Give it a `fetch:
  (api) => api.someEndpoint()` and a `builder: (context, data, controller) =>
  ...`. It owns a `PollController`, shows `LoadingState` on first load and
  `ErrorState` on a hard transport failure, and otherwise hands your builder
  the typed data plus the controller (call `controller.refresh` from a
  `RefreshIndicator.onRefresh` for pull-to-refresh).
- **Interval resolution**: `PollingView.interval` is optional.
  - omitted → uses the user's configured `AppConfig.refreshInterval`
    (Settings → Refresh Interval, default 10s) and **rebuilds the controller
    automatically** whenever that setting, the base URL, or the auth token
    changes (via `context.watch<AppConfig>()` in `didChangeDependencies`).
  - `Duration.zero` → fetch once, no periodic polling (used by Library, which
    doesn't need continuous refresh).
  - an explicit `Duration` → overrides the global setting for that one view.

**Where "degraded" lives:** `PollingView`'s `builder` receives the typed
response even when a subsystem inside it is down (e.g. `TorrentsSummary` with
`reachable: false`). It is the **screen's** job to branch on that flag and
render `DegradedState` — `PollingView` itself only handles true transport
failures via `ErrorState`. Don't try to make the polling layer detect
degradation; it can't and shouldn't know the shape of every response.

**Real-time variant (`data/torrent_stream.dart`):** the Torrents list uses a
WebSocket (`GET /torrents/ws`) instead of interval polling.
`TorrentStreamController` mirrors `PollController`'s public contract
(`AsyncValue<TorrentList>` + `refresh()` + lifecycle pausing) but is
stream-backed, and — crucially — **degrades to REST polling** if the socket
can't connect or drops (with exponential-backoff reconnect). So it works
whether or not a given backend build actually serves `/ws`; a missing socket
just means it runs as a poller. `TorrentStreamView` is the `PollingView`-shaped
widget wrapper. If you add another real-time surface, follow this same
"WebSocket with REST fallback + same four-state contract" pattern rather than
making the UI care which transport delivered the data.

### The four states every data screen must render

1. **Loading** — `widgets/states.dart` → `LoadingState`. Shown once, before any
   data has ever arrived.
2. **Error** — `ErrorState`. Only for backend-unreachable / HTTP error /
   malformed JSON (an `ApiException` from `api_client.dart`). Shows an
   `ERR_CODE`-style panel with a retry button.
3. **Degraded** — `DegradedState`. Backend is reachable and returned `200`, but
   a subsystem flag inside the payload is `false`/missing (torrents
   unreachable, SMART unavailable, a library path missing). Amber/red inline
   card with the server's `message`, **not** a full-screen error.
4. **Success** — the real screen content.

If you add a new screen or a new subsystem flag from the backend, replicate
this pattern — don't invent a fifth state or collapse degraded into error.

### `api/` layer conventions

- **`endpoints.dart`** is the single place that knows route paths and query
  params. Screens and widgets never call `ApiClient` directly — they go
  through a `MediaServerApi` method. This includes the movie discovery GETs
  (`searchMovies`, `movieTorrents`), the authenticated `POST /actions/*`
  control endpoints (`addTorrentUrl`, `addTorrentFile`, `pauseTorrent`,
  `resumeTorrent`, `deleteTorrent`, `syncMovies`) and the `torrentsWsUri()`
  WebSocket URL builder — any further routes go here too.
- **All qBittorrent/control writes go through `utils/control_action.dart` →
  `runControlAction`.** It is the single gated runner (require API key → toast
  → soft-fail on `ok:false` → map 401/503 to "check the key in Settings"). The
  Search screen's "Add to qBittorrent" button and the Torrents screen's
  add/pause/resume/delete/sync all call it — do NOT re-implement the download
  or reinvent the gating; reuse this.
- **`models.dart`** — one class per response shape, each with a
  `fromJson(Map<String, dynamic>)` factory using the private `_s`/`_d`/`_i`/
  `_b`/`_sn`/`_in`/`_dn`/`_list` helpers at the top of the file. Every parse is
  defensive (missing/wrong-typed fields fall back to `0`/`''`/`false`/`null`
  rather than throwing) because the API's own contract is "never fail," and
  the client should degrade the same way rather than crash on an unexpected
  payload shape.
- **Display rule:** fields ending in `_human` (`uptime_human`, `eta_human`,
  `size_human`, `total_dlspeed_human`, …) are pre-formatted server-side and
  must be **displayed verbatim** — never reformat them client-side. The raw
  `*_bytes` / `*_percent` numeric fields exist only to drive bars/gauges, not
  for display text.
- **`ApiClient`** builds `{baseUrl}/api/v1{path}`, attaches `Authorization:
  Bearer <token>` whenever `AppConfig.hasAuthToken` is true, and converts every
  failure mode (timeout, connection error, non-2xx, bad JSON) into a typed
  `ApiException` with a synthetic `errCode` used by `ErrorState`'s diagnostic
  panel. It also has `postJson` / `postMultipart` for the control endpoints —
  these attach the `X-API-Key` header from `AppConfig.apiKey`, use the longer
  `AppConfig.actionTimeout` (sync-movies moves files and can be slow), and map
  `401` (bad key) and `503` (server has no key configured) to distinct
  `ApiException`s so the UI can show "control actions unavailable — check the
  key in Settings." Note the split: a control action returning HTTP `200` with
  `{"ok": false, "message": …}` is a **soft** failure (surface as a toast),
  distinct from a non-2xx transport error.

### `config.dart` — `AppConfig`

A `ChangeNotifier` holding the runtime-editable state, all persisted via
`SharedPreferences` and edited from the Settings screen: `baseUrl`,
`authToken`, `apiKey` (the `X-API-Key` for control actions), `refreshSeconds`.
Also provides `resolveUrl(String?)` (relative API path → absolute URL against
the current base), `authHeader` / `actionHeader` (header maps for
authenticated / control requests), and `torrentsWsUri({state})` (derives the
`ws://…/torrents/ws` URL from the HTTP base, mapping http→ws / https→wss). It's
provided at the app root (`main.dart`) via `provider` and read/watched with
`context.read<AppConfig>()` / `context.watch<AppConfig>()`.

### `widgets/` — reusable, screen-agnostic

| File | What it is |
|---|---|
| `ring_gauge.dart` | `RingGauge` — CustomPainter circular gauge with a glowing round-capped arc. Color defaults to `barColor()` (pink at nominal, amber/red as usage climbs). |
| `progress_bar.dart` | `ProgressBar` — slim linear bar with the same auto-coloring; `brand: false` switches nominal-load color from pink to green (used for per-volume storage cards, which use classic health semantics). |
| `sparkline.dart` | `Sparkline` — tiny smoothed trend line (used for CPU load average). |
| `status_chip.dart` | `StatusChip` (pill + pulse dot) and `StatusDot` (animated connectivity dot). |
| `cards.dart` | `GlassCard` (base tonal-elevation surface), `StatCard` (labeled card), `Section` (mono section heading), `InfoRow` (key/value row). |
| `states.dart` | `LoadingState`, `ErrorState`, `DegradedState`, `EmptyState` — see "four states" above. |
| `service_widgets.dart` | `ServiceChips` (compact wrap for the Dashboard) and `ServiceRow` (full row with an optional `action` slot reserved for v2 restart/enable controls). |
| `poster_image.dart` | `PosterImage` — loads library artwork via `cached_network_image` (disk-persistent cache, honors server `Cache-Control`/`ETag`), resolving the relative URL through `AppConfig.resolveUrl` and attaching `authHeader`. Falls back to a pink-gradient placeholder on `null` URL, while loading, or on any fetch error — an image failure is never treated as a connectivity error. |
| `jiggly_logo.dart` | `JigglyLogo` — custom-painted mascot (CustomPainter line art, not an asset). `JigglyWordmark` — the `JIGGLYPUFF` mono wordmark. Used in the app bar, Settings, and splash. |
| `segmented.dart` | `AnimatedSegmented` — pill-sliding segmented control (Library/Torrents filters). |
| `shimmer.dart` | `Shimmer` + `SkeletonBox` — animated loading placeholders (Search skeletons). |
| `torrent_sheet.dart` | `showTorrentSheet()` — the movie→torrents modal (sorted by seeds, quality chips, Add-to-qBittorrent button via `runControlAction`). |
| `server_app_bar.dart` | `ServerAppBar` (shared top bar: logo + wordmark + settings gear) and `RefreshableBody` (themed `RefreshIndicator` + `ListView` wrapper every screen uses for pull-to-refresh). |

### `screens/` — one per tab, plus Settings and Splash

Dashboard, Torrents, Storage, System, Library, Search are bottom-tab screens
(`navigation/root_shell.dart`, `IndexedStack` so each keeps its state — pollers,
scroll, the search controller — alive when you switch tabs). Settings is pushed
via the app-bar gear (not a tab). Splash is the `main.dart` initial route, shown
briefly before `RootShell`. The `_tabs` list and the `IndexedStack` children
are positional — keep them in the same order (tab N ↔ child N).

See `README.md` for the endpoint each screen consumes — that mapping is
product-facing documentation and lives there rather than being duplicated here.

### `utils/media_title.dart` — client-side metadata fallback

The backend can (per `API_UPGRADE_SPEC.md`) supply real `year` / `quality` /
`hdr` / `poster_url` fields on `LibraryItem`. Until/unless a given install's
backend does, `MediaTitle.of(rawName: ..., year: item.year, quality:
item.quality, hdr: item.hdr)` parses those from the raw folder name
(`The.Dark.Knight.Rises.2012.2160p.HDR.BluRay.x265` → title/year/quality/hdr)
and **prefers the real backend fields whenever they're non-null**. If you add
more backend-supplied metadata fields, extend this same
prefer-real-then-fall-back-to-parsing pattern rather than branching in the UI.

## Conventions to preserve when extending this app

- **New backend field → defensive parsing in `models.dart` first.** Never
  assume a field is present; use the `_s`/`_d`/`_i`/`_b`/`_sn`/`_in`/`_dn`
  helpers already there.
- **New backend flag that can be false/unavailable → a `DegradedState` in the
  consuming screen,** not an exception, not a hidden empty state.
- **New route → a method on `MediaServerApi`,** never an inline `ApiClient`
  call from a screen or widget.
- **New polling screen → wrap it in `PollingView<T>`** rather than hand-rolling
  a `FutureBuilder`/`Timer`; that's how pull-to-refresh, keep-previous-data,
  lifecycle pausing, and reacting to Settings changes all stay consistent for
  free.
- **Human-formatted strings from the API are never reformatted client-side.**
  If you need a value the API doesn't pre-format, format it in `utils/`, not
  inline in a widget.
- **Never key a cache or persistent match on a `LibraryItem.name`.** A movie's
  `name`/`year` can change once Jellyfin scans it (raw filename → clean title),
  so use `path` or `jellyfin_id` for anything that must stay stable. Today the
  only `name` usages are transient (client-side search filtering, display), and
  poster caching is keyed on the artwork `url` — keep it that way.
- **Color meaning is intentional, not decorative:** JigglyPuff pink =
  brand/nominal load; green = explicit health (services up, SMART passed,
  connectivity online, per-volume storage under threshold); amber/red = actual
  warning/critical thresholds. See `theme/colors.dart` (`barColor`,
  `levelForPercent`, `levelForTemp`, `StatusLevel`) before hardcoding a color.
- **Reads vs. writes.** The dashboard/monitoring surface is read-only and stays
  that way. Write operations are limited to the explicitly-supported control
  actions (add torrent by url/file, pause/resume/delete a torrent, sync-movies),
  all gated behind a configured `X-API-Key`. Do not add further mutating calls
  without being asked; when you do, they belong on `MediaServerApi` and should
  reuse the `_run`-style gate in `torrents_screen.dart` (require key → soft-fail
  toast on `ok:false` → map 401/503 to "check the key in Settings"). Anything
  destructive (like `deleteTorrent`, which deletes files on disk) must go behind
  a confirmation dialog.

## Verifying changes

```bash
flutter analyze   # must be clean — the project currently has zero issues
flutter test      # model-parsing + MediaTitle unit tests; keep these passing
flutter build apk --debug   # confirms the app actually compiles for Android
```

There is no UI/widget test harness beyond the unit tests in `test/`. For
UI-affecting changes, run the app (`flutter run`) against a real or mocked
backend and check the four states (loading/error/degraded/success) render as
expected — analyzer + unit tests alone don't catch a broken layout.

## Known intentional gaps (do not "fix" without asking)

- **No light theme.** The app is dark-theme-only by design (`theme/app_theme.dart`
  → `buildDarkTheme()`); the original brief allowed a light theme "if cheap,"
  but the shipped design committed to dark-only.
- **Placeholder mascot art.** `JigglyLogo` is hand-painted `CustomPainter`
  code, not a designer asset. If real brand art shows up, swap it in as an
  `Image.asset` rather than editing the painter.
- **Cleartext HTTP/WS allowed** (`android:usesCleartextTraffic="true"` in
  `AndroidManifest.xml`) because the backend is plain `http://` / `ws://` on the
  LAN by design (see `api_change.md`). Don't "fix" this to HTTPS-only without
  the backend actually serving TLS.
- **The Torrents realtime socket + control actions can't be exercised by the
  test suite** (they need a live backend). `TorrentStreamController` is written
  to degrade to REST if `/ws` is absent, and the control actions no-op with a
  "add your API key" toast when unconfigured — so the app is safe to run
  against an older backend that lacks these. When changing them, verify against
  a real server; unit tests only cover the parsing/URL-derivation pieces.
- **OS share-target is not wired.** `api_change.md` mentions sharing a link /
  `.torrent` *into* the app from the share sheet. The app supports the same
  actions via in-app entry (paste URL, pick file), but does not yet register as
  an Android `SEND` share target (that needs `receive_sharing_intent` +
  manifest intent-filters). Treat it as an unstarted follow-up, not a bug.
