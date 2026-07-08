import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import 'router.dart';
import 'theme.dart';

class KageApp extends ConsumerStatefulWidget {
  const KageApp({super.key});

  @override
  ConsumerState<KageApp> createState() => _KageAppState();
}

class _KageAppState extends ConsumerState<KageApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref.read(themeModeProvider.notifier).init();
      final s = await ref.read(settingsServiceProvider.future);
      ref.read(activeModelProvider.notifier).state = s.claudeModel;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'Kage',
      debugShowCheckedModeBanner: false,
      theme: KageTheme.light,
      darkTheme: KageTheme.dark,
      themeMode: themeMode,
      routerConfig: kageRouter,
    );
  }
}
