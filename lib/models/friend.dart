// Friend model
class Friend {
  final String name;
  final bool online;
  final DateTime lastSeen;

  Friend({required this.name, required this.online, required this.lastSeen});

  Friend copyWith({String? name, bool? online, DateTime? lastSeen}) {
    return Friend(
      name: name ?? this.name,
      online: online ?? this.online,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'state': online ? 'online' : 'offline',
        'last_seen': lastSeen.toIso8601String(),
      };

  static Friend fromMap(Map<String, dynamic> m) => Friend(
        name: m['name'] as String,
        online: (m['state'] as String) == 'online',
        lastSeen: DateTime.parse(m['last_seen'] as String),
      );
}

