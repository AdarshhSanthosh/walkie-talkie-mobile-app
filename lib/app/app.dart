import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/settings/theme_controller.dart';
import 'routes.dart';
import 'theme.dart';

class WalkieTalkieApp extends ConsumerWidget {
  const WalkieTalkieApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeControllerProvider);
    return MaterialApp.router(
      title: 'Walkie Talkie',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: appRouter,
    );
  }
}
