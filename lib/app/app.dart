import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/settings/theme_controller.dart';
import '../services/connectivity_service.dart';
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
      builder: (context, child) => _OfflineBanner(child: child),
    );
  }
}

/// A thin app-wide banner shown whenever the device has no network path
/// (spec §19) — separate from any one screen's own connection state, since
/// losing network affects everything, not just an open voice channel.
class _OfflineBanner extends ConsumerWidget {
  final Widget? child;

  const _OfflineBanner({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider).value ?? true;
    return Column(
      children: [
        if (!isOnline)
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.error,
            padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top, bottom: 6),
            child: const Text(
              'No internet connection',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        Expanded(child: child ?? const SizedBox.shrink()),
      ],
    );
  }
}
