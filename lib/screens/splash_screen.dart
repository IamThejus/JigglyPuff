import 'dart:async';

import 'package:flutter/material.dart';

import '../navigation/root_shell.dart';
import '../theme/app_theme.dart';
import '../widgets/jiggly_logo.dart';

/// Branded launch screen shown briefly on cold start, then replaced by the
/// tab shell. A faint radar ring backs the mascot.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 1900), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 400),
          pageBuilder: (_, a, _) => FadeTransition(opacity: a, child: const RootShell()),
        ),
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: FadeTransition(
          opacity: _c,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  // Radar rings backdrop.
                  for (final r in [70.0, 110.0, 150.0])
                    Container(
                      width: r,
                      height: r,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.accent.withValues(alpha: 0.08)),
                      ),
                    ),
                  const JigglyLogo(size: 96, sparkle: true),
                ],
              ),
              const SizedBox(height: Space.sectionMargin),
              Text(
                'JIGGLYPUFF',
                style: AppText.headlineLg().copyWith(letterSpacing: 6, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text('MEDIA SERVER DASHBOARD', style: AppText.labelCaps()),
              const SizedBox(height: 60),
              Icon(Icons.graphic_eq, color: AppColors.accent.withValues(alpha: 0.7), size: 26),
              const SizedBox(height: Space.gutter),
              Text('Monitoring your ecosystem', style: AppText.bodySm()),
            ],
          ),
        ),
      ),
    );
  }
}
