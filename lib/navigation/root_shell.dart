import 'package:flutter/material.dart';

import '../screens/dashboard_screen.dart';
import '../screens/library_screen.dart';
import '../screens/search_screen.dart';
import '../screens/storage_screen.dart';
import '../screens/system_screen.dart';
import '../screens/torrents_screen.dart';
import '../theme/app_theme.dart';

/// Bottom-tab shell. Each tab is kept alive via [IndexedStack] so its poller
/// and scroll position survive tab switches (Settings is pushed on top, not a
/// tab — reached from the app-bar gear).
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  // Order here == order in the IndexedStack below.
  static const _tabs = <_TabDef>[
    _TabDef('Dashboard', Icons.dashboard_outlined, Icons.dashboard),
    _TabDef('Search', Icons.search, Icons.search_rounded),
    _TabDef('Torrents', Icons.download_outlined, Icons.download),
    _TabDef('Storage', Icons.storage_outlined, Icons.storage),
    _TabDef('System', Icons.terminal_outlined, Icons.terminal),
    _TabDef('Library', Icons.movie_outlined, Icons.movie),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          DashboardScreen(),
          SearchScreen(),
          TorrentsScreen(),
          StorageScreen(),
          SystemScreen(),
          LibraryScreen(),
        ],
      ),
      bottomNavigationBar: _BottomBar(
        tabs: _tabs,
        index: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}

class _TabDef {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  const _TabDef(this.label, this.icon, this.activeIcon);
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.tabs, required this.index, required this.onTap});
  final List<_TabDef> tabs;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.glassStrokeFaint)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (var i = 0; i < tabs.length; i++) _item(i),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(int i) {
    final active = i == index;
    final t = tabs[i];
    final color = active ? AppColors.accent : AppColors.onSurfaceVariant;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(i),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Subtle pop + colour crossfade when a tab becomes active.
            AnimatedScale(
              scale: active ? 1.12 : 1.0,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              child: Icon(active ? t.activeIcon : t.icon, color: color, size: 24),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              style: AppText.labelCaps(color: color).copyWith(fontSize: 10, letterSpacing: 0.2),
              child: Text(t.label, maxLines: 1, overflow: TextOverflow.fade, softWrap: false),
            ),
          ],
        ),
      ),
    );
  }
}
