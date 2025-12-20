import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'package:onlinestatus2/providers/friends_provider.dart';
import 'package:onlinestatus2/providers/settings_provider.dart';
import '../services/notification_service.dart';
import '../services/idle_service.dart';
import 'package:onlinestatus2/models/friend.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});
  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  String _idleStatus = 'checking...';
  int _idleSeconds = 0;

  @override
  void initState() {
    super.initState();
    _updateIdleStatus();
  }

  Future<void> _updateIdleStatus() async {
    while (mounted) {
      final seconds = await IdleService.getIdleTimeSeconds();
      final status = await IdleService.getUserActivityStatus();
      if (mounted) {
        setState(() {
          _idleSeconds = seconds;
          _idleStatus = status;
        });
      }
      await Future.delayed(const Duration(seconds: 5));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Register listener during build (allowed). This will be correctly managed by Riverpod.
    ref.listen<AsyncValue<List<Friend>>>(friendsProvider, (previous, next) {
      final prevList = previous?.whenOrNull(data: (d) => d);
      final nextList = next.whenOrNull(data: (d) => d);
      if (prevList == null || nextList == null) return;

      final prevMap = {for (var f in prevList) f.name: f.online};
      for (final f in nextList) {
        final wasOnline = prevMap[f.name] ?? false;
        if (!wasOnline && f.online) {
          // Show desktop notification
          NotificationService.showNotification('${f.name} is online', '${f.name} just came online');
        }
      }
    });

    final asyncFriends = ref.watch(friendsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Friends Online Status'),
            Text(
              'You: $_idleStatus (idle: ${_idleSeconds}s)',
              style: TextStyle(
                fontSize: 12,
                color: _idleStatus == 'online' ? Colors.green[200] : Colors.orange[200],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _openSettingsDialog(context),
            tooltip: 'Settings',
          ),
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.notification_add),
              onPressed: () async {
                // Trigger a test notification for debugging
                NotificationService.showNotification('Test Notification', 'This is a test from HomePage');
              },
              tooltip: 'Debug: show notification',
            ),
          IconButton(
            icon: const Icon(Icons.minimize),
            onPressed: () async {
              if (Platform.isWindows || Platform.isLinux) {
                final doHide = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Minimize to tray'),
                    content: const Text('Hide the window to the system tray?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                      ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('OK')),
                    ],
                  ),
                );
                if (doHide == true) {
                  await windowManager.hide();
                }
              }
            },
            tooltip: 'Minimize to tray',
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

  Future<void> _openSettingsDialog(BuildContext context) async {
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
