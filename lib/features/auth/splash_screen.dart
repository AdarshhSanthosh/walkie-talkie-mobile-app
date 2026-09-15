import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/auth_service.dart';

/// Splash screen (spec §11): logo + loading, then redirects based on
/// (fake) auth state. Phase 2 will check a real Supabase session instead.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      final loggedIn = ref.read(authServiceProvider);
      context.go(loggedIn ? '/home' : '/login');
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset('assets/icon/app_icon_source.png', width: 96, height: 96),
            ),
            const SizedBox(height: 16),
            Text(
              'Chick Talk',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: colors.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 32),
            CircularProgressIndicator(color: colors.onPrimary),
            const SizedBox(height: 12),
            Text('Loading...', style: TextStyle(color: colors.onPrimary)),
          ],
        ),
      ),
    );
  }
}
