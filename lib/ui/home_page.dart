import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onlinestatus2/providers/friends_provider.dart';
import 'package:onlinestatus2/providers/settings_provider.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncFriends = ref.watch(friendsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends Online Status'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _openSettingsDialog(context, ref),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: asyncFriends.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error: $err')),
        data: (friends) => ListView.separated(
          itemCount: friends.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final f = friends[index];
            return ListTile(
              leading: Icon(
                Icons.circle,
                color: f.online ? Colors.green : Colors.red,
              ),
              title: Text(f.name),
              subtitle: f.online ? const Text('Online') : Text('Last seen: ${_formatDate(f.lastSeen)}'),
            );
          },
        ),
      ),
    );
  }

  Future<void> _openSettingsDialog(BuildContext context, WidgetRef ref) async {
    final baseUrlController = TextEditingController(text: ref.read(baseUrlProvider));
    final settings = ref.read(settingsProvider);
    final nameController = TextEditingController(text: settings.name);
    final tokenController = TextEditingController(text: settings.token);

    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Settings'),
        content: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: baseUrlController,
              decoration: const InputDecoration(labelText: 'Backend URL', hintText: 'http://host:port'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return 'Enter backend URL';
                final trimmed = value.trim();
                final uri = Uri.tryParse(trimmed);
                if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https') || uri.host.isEmpty) return 'Enter a valid http(s) URL';
                return null;
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Your name'),
              validator: (value) => (value == null || value.trim().isEmpty) ? 'Enter your name' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: tokenController,
              decoration: const InputDecoration(labelText: 'Token (optional)'),
              obscureText: true,
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                final newUrl = baseUrlController.text.trim();
                ref.read(baseUrlProvider.notifier).set(newUrl);

                final newName = nameController.text.trim();
                final newToken = tokenController.text.trim();
                ref.read(settingsProvider.notifier).setAll(name: newName, token: newToken);

                // close dialog before network call to avoid using BuildContext across async gap
                Navigator.of(ctx).pop();
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await ref.read(friendApiProvider).sendPresence(newName, token: newToken);
                } catch (e) {
                  messenger.showSnackBar(SnackBar(content: Text('Failed to notify server: $e')));
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} minutes ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    return '${diff.inDays} days ago';
  }
}
