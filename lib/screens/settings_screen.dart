import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../api/endpoints.dart';
import '../config.dart';
import '../theme/app_theme.dart';
import '../widgets/cards.dart';
import '../widgets/jiggly_logo.dart';

/// Network configuration: base URL, refresh interval + (v2) auth token,
/// persisted via SharedPreferences, plus a "Test Connection" that hits
/// `/health`.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

enum _TestState { idle, testing, ok, failed }

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _url;
  late final TextEditingController _token;
  late final TextEditingController _apiKey;
  bool _obscure = true;
  bool _obscureKey = true;
  _TestState _test = _TestState.idle;
  String? _testMessage;

  @override
  void initState() {
    super.initState();
    final config = context.read<AppConfig>();
    _url = TextEditingController(text: config.baseUrl);
    _token = TextEditingController(text: config.authToken);
    _apiKey = TextEditingController(text: config.apiKey);
  }

  @override
  void dispose() {
    _url.dispose();
    _token.dispose();
    _apiKey.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await context
        .read<AppConfig>()
        .update(baseUrl: _url.text, authToken: _token.text, apiKey: _apiKey.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Configuration saved'), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _testConnection() async {
    setState(() {
      _test = _TestState.testing;
      _testMessage = null;
    });
    final cfg = context.read<AppConfig>();
    await cfg.update(baseUrl: _url.text, authToken: _token.text, apiKey: _apiKey.text);
    final api = MediaServerApi(ApiClient(cfg));
    try {
      final health = await api.health();
      if (!mounted) return;
      setState(() {
        _test = health.isOk ? _TestState.ok : _TestState.failed;
        _testMessage = health.isOk
            ? 'Server is reachable and responding · v${health.version}'
            : 'Server responded with status "${health.status}"';
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _test = _TestState.failed;
        _testMessage = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<AppConfig>();
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        leading: const BackButton(color: AppColors.onSurface),
        title: const JigglyWordmark(fontSize: 15),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            Space.containerPadding, Space.gutter, Space.containerPadding, 40),
        children: [
          Text('Settings', style: AppText.headlineLg()),
          const SizedBox(height: 6),
          Text('Configure media server connectivity and core parameters.', style: AppText.bodySm()),
          const SizedBox(height: Space.gutter),

          _label('API BASE URL'),
          _field(_url, hint: 'http://192.168.1.50:8000', keyboard: TextInputType.url, suffixIcon: Icons.link),
          const SizedBox(height: Space.gutter),

          _label('API AUTH TOKEN'),
          _field(
            _token,
            hint: 'optional bearer token',
            obscure: _obscure,
            suffix: IconButton(
              icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: AppColors.onSurfaceVariant, size: 20),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          const SizedBox(height: 6),
          Text('Reserved for secure remote access.', style: AppText.labelTechnical()),
          const SizedBox(height: Space.gutter),

          _label('ACTIONS API KEY'),
          _field(
            _apiKey,
            hint: 'enables Add Torrent / Sync',
            obscure: _obscureKey,
            suffix: IconButton(
              icon: Icon(_obscureKey ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: AppColors.onSurfaceVariant, size: 20),
              onPressed: () => setState(() => _obscureKey = !_obscureKey),
            ),
          ),
          const SizedBox(height: 6),
          Text('Sent as X-API-Key for control actions (add torrent, sync movies). '
              'Leave blank to keep those actions disabled.',
              style: AppText.labelTechnical()),
          const SizedBox(height: Space.gutter),

          _label('REFRESH INTERVAL'),
          _RefreshDropdown(
            value: config.refreshSeconds,
            onChanged: (v) => config.update(refreshSeconds: v),
          ),
          const SizedBox(height: Space.gutter),

          _label('THEME'),
          _staticRow('Obsidian (Dark)', Icons.dark_mode_outlined),
          const SizedBox(height: Space.sectionMargin),

          _primaryButton('Test Connection', Icons.wifi_tethering,
              _test == _TestState.testing ? null : _testConnection,
              busy: _test == _TestState.testing),
          const SizedBox(height: Space.stackGap),
          _ghostButton('Save Changes', Icons.save_outlined, _save),

          if (_test != _TestState.idle) ...[
            const SizedBox(height: Space.gutter),
            _statusBanner(),
          ],

          const SizedBox(height: Space.sectionMargin),
          _label('ABOUT'),
          const SizedBox(height: 6),
          Center(
            child: Column(
              children: [
                const JigglyLogo(size: 40, sparkle: true),
                const SizedBox(height: 8),
                Text('Jigglypuff v1.0.0', style: AppText.labelTechnical(color: AppColors.onSurface)),
                Text('Dell Media Server Monitor · read-only', style: AppText.labelTechnical()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBanner() {
    final ok = _test == _TestState.ok;
    final testing = _test == _TestState.testing;
    final level = testing
        ? StatusLevel.warning
        : ok
            ? StatusLevel.healthy
            : StatusLevel.error;
    return GlassCard(
      color: AppColors.surfaceContainerLow,
      borderColor: level.color.withValues(alpha: 0.3),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle : (testing ? Icons.sync : Icons.error_outline),
              color: level.color, size: 20),
          const SizedBox(width: Space.stackGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ok ? 'Connection Successful' : (testing ? 'Testing…' : 'Connection Failed'),
                  style: AppText.bodySm(color: AppColors.onSurface).copyWith(fontWeight: FontWeight.w600),
                ),
                if (_testMessage != null)
                  Text(_testMessage!, style: AppText.labelTechnical()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t, style: AppText.labelTechnical()),
      );

  Widget _staticRow(String value, IconData icon) {
    return GlassCard(
      color: AppColors.surfaceContainerLowest,
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.onSurfaceVariant),
          const SizedBox(width: Space.stackGap),
          Expanded(child: Text(value, style: AppText.bodySm(color: AppColors.onSurface))),
          Text('v1', style: AppText.labelTechnical()),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController c, {
    String? hint,
    bool obscure = false,
    Widget? suffix,
    IconData? suffixIcon,
    TextInputType? keyboard,
  }) {
    return TextField(
      controller: c,
      obscureText: obscure,
      keyboardType: keyboard,
      autocorrect: false,
      enableSuggestions: false,
      style: AppText.labelTechnical(color: AppColors.onSurface).copyWith(fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppText.labelTechnical(color: AppColors.outline),
        filled: true,
        fillColor: AppColors.surfaceContainerLowest,
        suffixIcon: suffix ??
            (suffixIcon != null ? Icon(suffixIcon, color: AppColors.onSurfaceVariant, size: 18) : null),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.chip),
          borderSide: const BorderSide(color: AppColors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.chip),
          borderSide: const BorderSide(color: AppColors.accent),
        ),
      ),
    );
  }

  Widget _primaryButton(String label, IconData icon, VoidCallback? onTap, {bool busy = false}) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: busy
            ? const SizedBox(
                width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onAccent))
            : Icon(icon, size: 18),
        label: Text(busy ? 'Testing…' : label),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.onAccent,
          disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.5),
          disabledForegroundColor: AppColors.onAccent,
          textStyle: AppText.bodySm(color: AppColors.onAccent).copyWith(fontWeight: FontWeight.w700),
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.chip)),
        ),
      ),
    );
  }

  Widget _ghostButton(String label, IconData icon, VoidCallback? onTap) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: AppColors.onSurface),
        label: Text(label, style: AppText.bodySm(color: AppColors.onSurface)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.glassStroke),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.chip)),
        ),
      ),
    );
  }
}

class _RefreshDropdown extends StatelessWidget {
  const _RefreshDropdown({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(Radii.chip),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          isExpanded: true,
          dropdownColor: AppColors.surfaceContainerHigh,
          icon: const Icon(Icons.expand_more, color: AppColors.onSurfaceVariant),
          borderRadius: BorderRadius.circular(Radii.chip),
          style: AppText.bodySm(color: AppColors.onSurface),
          items: [
            for (final s in AppConfig.refreshOptions)
              DropdownMenuItem(value: s, child: Text('$s seconds')),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}
