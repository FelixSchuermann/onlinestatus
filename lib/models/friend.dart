/// Represents the connection/activity state of a friend
enum FriendState {
  online,   // Active and connected
  idle,     // Connected but AFK (no mouse/keyboard activity)
  offline,  // Not connected (no recent heartbeat)
}

// Friend model
class Friend {
  final String? uuid;
  final String name;
  final FriendState state;
  final DateTime lastSeen;

  Friend({this.uuid, required this.name, required this.state, required this.lastSeen});

  /// Convenience getter - true if online or idle (still "connected")
  bool get online => state == FriendState.online || state == FriendState.idle;

  /// True only if actively using the computer
  bool get isActive => state == FriendState.online;

  /// True if AFK but still connected
  bool get isIdle => state == FriendState.idle;

  /// True if disconnected
  bool get isOffline => state == FriendState.offline;

  Friend copyWith({String? uuid, String? name, FriendState? state, DateTime? lastSeen}) {
    return Friend(
      uuid: uuid ?? this.uuid,
      name: name ?? this.name,
      state: state ?? this.state,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  Map<String, dynamic> toMap() => {
        if (uuid != null) 'uuid': uuid,
        'name': name,
        'state': state.name,
        'last_seen': lastSeen.toIso8601String(),
      };

  static Friend fromMap(Map<String, dynamic> m) {
    final stateStr = m['state'] as String;
    final state = switch (stateStr) {
      'online' => FriendState.online,
      'idle' => FriendState.idle,
      'offline' => FriendState.offline,
      _ => FriendState.offline,
    };
    return Friend(
      uuid: m['uuid'] as String?,
      name: m['name'] as String,
      state: state,
      lastSeen: DateTime.parse(m['last_seen'] as String),
    );
  }
}

