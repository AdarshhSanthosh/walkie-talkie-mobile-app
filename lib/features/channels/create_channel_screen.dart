import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/channel.dart';
import '../../services/channels_service.dart';

/// Create Channel screen (spec §11): name/description/privacy/max members,
/// then shows a share code + QR code for the new channel. Real Supabase
/// channel creation (Phase 4) via the create_channel RPC.
class CreateChannelScreen extends ConsumerStatefulWidget {
  const CreateChannelScreen({super.key});

  @override
  ConsumerState<CreateChannelScreen> createState() => _CreateChannelScreenState();
}

class _CreateChannelScreenState extends ConsumerState<CreateChannelScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _maxMembersCtrl = TextEditingController(text: '10');
  ChannelPrivacy _privacy = ChannelPrivacy.private;
  VoiceChannel? _created;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _maxMembersCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Enter a channel name.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(channelsRepositoryProvider);
      final id = await repo.createChannel(
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        privacy: _privacy,
        maxMembers: int.tryParse(_maxMembersCtrl.text) ?? 10,
      );
      final channel = await repo.fetchChannel(id);
      refreshChannelsProviders(ref);
      if (!mounted) return;
      setState(() {
        _created = channel;
        _loading = false;
      });
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
    final created = _created;
    return Scaffold(
      appBar: AppBar(title: const Text('Create Channel')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: created == null ? _buildForm(context) : _buildResult(context, created),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return ListView(
      children: [
        TextField(
          controller: _nameCtrl,
          decoration: const InputDecoration(labelText: 'Channel Name', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _descCtrl,
          decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 24),
        Text('Privacy', style: Theme.of(context).textTheme.titleSmall),
        RadioGroup<ChannelPrivacy>(
          groupValue: _privacy,
          onChanged: (v) => setState(() => _privacy = v!),
          child: Column(
            children: ChannelPrivacy.values
                .where((p) => p != ChannelPrivacy.temporary)
                .map((p) => RadioListTile<ChannelPrivacy>(value: p, title: Text(p.label)))
                .toList(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _maxMembersCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Maximum Members', border: OutlineInputBorder()),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _loading ? null : _create,
          style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
          child: _loading
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('CREATE'),
        ),
      ],
    );
  }

  Widget _buildResult(BuildContext context, VoiceChannel channel) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('"${channel.name}" created!', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 24),
          QrImageView(data: channel.inviteCode ?? channel.id, size: 200),
          const SizedBox(height: 16),
          Text('Invite code', style: Theme.of(context).textTheme.labelMedium),
          SelectableText(
            channel.inviteCode ?? '',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(letterSpacing: 4),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: () => context.go('/channel/${channel.id}'),
            child: const Text('GO TO CHANNEL'),
          ),
        ],
      ),
    );
  }
}
