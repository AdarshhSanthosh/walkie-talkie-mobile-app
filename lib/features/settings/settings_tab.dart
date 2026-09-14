import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/auth_service.dart';
import 'theme_controller.dart';

/// Settings screen (spec §20). Phase 1 delivers a real, working Appearance
/// section; Account/Audio/Notifications/Privacy/Security are stubbed as
/// "coming soon" placeholders until their backing services exist.
class SettingsTab extends ConsumerWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Appearance', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode)),
              ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode)),
              ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.brightness_auto)),
            ],
            selected: {mode},
            onSelectionChanged: (selection) {
              ref.read(themeControllerProvider.notifier).setMode(selection.first);
            },
          ),
          const SizedBox(height: 24),
          const _ComingSoonSection(title: 'Account'),
          const _ComingSoonSection(title: 'Audio'),
          const _ComingSoonSection(title: 'Notifications'),
          const _ComingSoonSection(title: 'Privacy'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Security'),
            subtitle: const Text('Blocked users'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/blocked-users'),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              ref.read(authServiceProvider.notifier).signOut();
              context.go('/login');
            },
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

class _ComingSoonSection extends StatelessWidget {
  final String title;
  const _ComingSoonSection({required this.title});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: const Text('Coming soon'),
      trailing: const Icon(Icons.chevron_right),
      enabled: false,
    );
  }
}
