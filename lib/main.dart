import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'config.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.background,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Load persisted config (base URL / auth token) before the first frame.
  final config = await AppConfig.load();

  runApp(
    ChangeNotifierProvider<AppConfig>.value(
      value: config,
      child: const JigglyPuffApp(),
    ),
  );
}

class JigglyPuffApp extends StatelessWidget {
  const JigglyPuffApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JigglyPuff',
      debugShowCheckedModeBanner: false,
      theme: buildDarkTheme(),
      home: const SplashScreen(),
    );
  }
}
