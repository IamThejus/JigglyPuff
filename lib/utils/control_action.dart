import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../api/endpoints.dart';
import '../api/models.dart';
import '../config.dart';
import '../theme/app_theme.dart';

/// Runs an authenticated `POST /actions/*` control action with the app's shared
/// gating + feedback, and returns the [ActionResult] (or null on hard failure):
///
///  - requires a configured API key (else prompts to add one in Settings),
///  - shows a "$verb…" toast, then a success/soft-fail toast,
///  - a `200` with `ok:false` is a **soft** failure (toast the message), while
///    `401`/`503` map to a single "control actions unavailable — check the key"
///    message.
///
/// This is the single place the "add to qBittorrent" / pause / resume / delete
/// / sync flows go through, so the Search download button and the Torrents
/// screen behave identically.
Future<ActionResult?> runControlAction(
  BuildContext context,
  String verb,
  Future<ActionResult> Function(MediaServerApi api) call, {
  bool silentSuccess = false,
}) async {
  final config = context.read<AppConfig>();
  final messenger = ScaffoldMessenger.of(context);

  void snack(String message, {bool? ok}) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: ok == false
            ? AppColors.errorContainer
            : (ok == true ? null : AppColors.surfaceContainerHigh),
      ));
  }

  if (!config.hasApiKey) {
    snack('Add your Actions API key in Settings to enable control actions.');
    return null;
  }
  snack('$verb…');
  try {
    final result = await performControlAction(config, call);
    if (!context.mounted) return null;
    if (result == null) {
      snack('Add your Actions API key in Settings to enable control actions.');
      return null;
    }
    if (!(silentSuccess && result.ok)) {
      snack(result.message ?? (result.ok ? '$verb complete' : '$verb failed'), ok: result.ok);
    }
    return result;
  } on ApiException catch (e) {
    if (!context.mounted) return null;
    snack(controlActionErrorMessage(e), ok: false);
    return null;
  }
}

/// The UI-less core: runs a control action with the API-key gate but no
/// snackbars, so callers that need **inline** feedback (e.g. the torrent
/// sheet's download button, whose snackbars would be hidden behind the modal)
/// can render their own state.
///
/// Returns `null` when no API key is configured, the [ActionResult] otherwise
/// (which may itself be a soft `ok:false` failure). Throws [ApiException] on a
/// transport/auth failure.
Future<ActionResult?> performControlAction(
  AppConfig config,
  Future<ActionResult> Function(MediaServerApi api) call,
) async {
  if (!config.hasApiKey) return null;
  return call(MediaServerApi(ApiClient(config)));
}

/// Friendly message for a control-action [ApiException] (401/503 → "check key").
String controlActionErrorMessage(ApiException e) {
  final disabled = e.statusCode == 401 || e.statusCode == 503;
  return disabled ? 'Control actions unavailable — check the API key in Settings.' : e.message;
}
