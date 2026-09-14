import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/channels_service.dart';

/// Join Channel screen (spec §5: "Users can join through... Channel
/// code"). Enter a 6-character invite code to join.
class JoinChannelScreen extends ConsumerStatefulWidget {
  const JoinChannelScreen({super.key});

  @override
  ConsumerState<JoinChannelScreen> createState() => _JoinChannelScreenState();
}

class _JoinChannelScreenState extends ConsumerState<JoinChannelScreen> {
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Enter an invite code.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final channelId = await ref.read(channelsRepositoryProvider).joinByCode(code);
      refreshChannelsProviders(ref, channelId: channelId);
      if (!mounted) return;
      context.go('/channel/$channelId');
    } on Object catch (e) {
      if (!mounted) return;
      final text = e.toString();
      final match = RegExp(r'message: ([^,]+)').firstMatch(text);
      setState(() {
        _error = match?.group(1) ?? text;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join Channel')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            Text('Enter invite code', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 24),
            TextField(
              controller: _codeCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Invite Code',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _join,
              style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
              child: _loading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('JOIN'),
            ),
          ],
        ),
      ),
    );
  }
}
