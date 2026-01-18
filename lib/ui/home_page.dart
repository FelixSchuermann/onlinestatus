import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onlinestatus2/providers/friends_provider.dart';
import 'package:onlinestatus2/providers/settings_provider.dart';
import '../services/notification_service.dart';
import '../services/idle_service.dart';
import '../services/heartbeat_service.dart';
import 'package:onlinestatus2/models/friend.dart';
import 'package:onlinestatus2/main.dart' show trayService, isDesktop;

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});
  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  String _idleStatus = 'checking...';
  int _idleSeconds = 0;

  // Track the last known state for each user to detect actual state changes
  final Map<String, FriendState> _lastKnownStates = {};

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
    // Start heartbeat service (auto-disposed when not watched)
    ref.watch(heartbeatServiceProvider);

    // Register listener during build for notifications
    ref.listen<AsyncValue<List<Friend>>>(friendsProvider, (previous, next) {
      final nextList = next.whenOrNull(data: (d) => d);
      if (nextList == null) return;

      for (final f in nextList) {
        final lastState = _lastKnownStates[f.name];
        final currentState = f.state;

        // Only notify if user was offline (or unknown) and is now online/idle/busy
        final wasOffline = lastState == null || lastState == FriendState.offline;
        final isNowOnline = currentState == FriendState.online ||
                            currentState == FriendState.idle ||
                            currentState == FriendState.busy;

        if (wasOffline && isNowOnline) {
          NotificationService.showNotification('${f.name} is online', '${f.name} just came online');
        }

        // Update last known state
        _lastKnownStates[f.name] = currentState;
      }
    });

    final asyncFriends = ref.watch(friendsProvider);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Friends Online Status'),
            Text(
              'You: ${settings.name.isNotEmpty ? settings.name : "unnamed"} ($_idleStatus, idle: ${_idleSeconds}s)',
              style: TextStyle(
                fontSize: 12,
                color: _idleStatus == 'online'
                    ? Colors.green[200]
                    : _idleStatus == 'busy'
                        ? Colors.purple[200]
                        : Colors.orange[200],
              ),
            ),
          ],
        ),
        actions: [
          // Minimize to tray button (Desktop only: Windows, Linux, macOS)
          if (isDesktop)
            IconButton(
              icon: const Icon(Icons.minimize),
              onPressed: () async {
                if (trayService.isAvailable) {
                  await trayService.minimizeToTray();
                } else {
                  // Fallback: show message
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Tray not available')),
                  );
                }
              },
              tooltip: 'Minimize to Tray',
            ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _openSettingsDialog(context),
            tooltip: 'Settings',
          ),
          if (kDebugMode) ...[
            IconButton(
              icon: const Icon(Icons.notification_add),
              onPressed: () async {
                NotificationService.showNotification('Test Notification', 'This is a test from HomePage');
              },
              tooltip: 'Debug: show notification',
            ),
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: () async {
                final service = ref.read(heartbeatServiceProvider);
                final success = await service.sendNow();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(success ? 'Heartbeat sent!' : 'Heartbeat failed')),
                  );
                }
              },
              tooltip: 'Debug: send heartbeat now',
            ),
          ],
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
            final Color stateColor = switch (f.state) {
              FriendState.online => Colors.green,
              FriendState.idle => Colors.orange,
              FriendState.busy => Colors.purple,
              FriendState.offline => Colors.red,
            };
            final String stateText = switch (f.state) {
              FriendState.online => 'Online',
              FriendState.idle => 'Idle (AFK)',
              FriendState.busy => 'Busy (In Game/Fullscreen)',
              FriendState.offline => 'Last seen: ${_formatDate(f.lastSeen)}',
            };
            return ListTile(
              leading: Icon(Icons.circle, color: stateColor),
              title: Text(f.name),
              subtitle: Text(stateText),
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
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                initialValue: settings.uuid,
                decoration: const InputDecoration(
                  labelText: 'Your UUID (auto-generated)',
                  helperText: 'Unique identifier for this device',
                ),
                readOnly: true,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Your name'),
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Enter your name' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: tokenController,
                decoration: const InputDecoration(labelText: 'Access Token'),
                obscureText: true,
              ),
              const SizedBox(height: 12),
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
            ]),
          ),
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
                await ref.read(settingsProvider.notifier).saveToPrefs();

                if (!ctx.mounted) return;
                Navigator.of(ctx).pop();

                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Settings saved! Heartbeat will use new name.')),
                  );
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
