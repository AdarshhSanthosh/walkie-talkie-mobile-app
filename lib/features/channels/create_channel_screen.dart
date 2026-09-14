import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/channel.dart';
import '../../services/database_service.dart';

/// Create Channel screen (spec §11): name/description/privacy/max members,
/// then shows a share code + QR code for the new channel.
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

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _maxMembersCtrl.dispose();
    super.dispose();
  }

  void _create() {
    if (_nameCtrl.text.trim().isEmpty) return;
    final channel = ref.read(databaseServiceProvider.notifier).createChannel(
          name: _nameCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          privacy: _privacy,
          maxMembers: int.tryParse(_maxMembersCtrl.text) ?? 10,
        );
    setState(() => _created = channel);
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
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _create,
          style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
          child: const Text('CREATE'),
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
