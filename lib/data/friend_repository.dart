import 'dart:math';

class FriendRepository {
  final _random = Random();

  // initial mock data
  Future<List<Map<String, dynamic>>> fetchFriends() async {
    await Future.delayed(const Duration(milliseconds: 300));
    final now = DateTime.now();
    final data = [
      {'name': 'Alice', 'state': 'online', 'last_seen': now.toIso8601String()},
      {'name': 'Bob', 'state': 'offline', 'last_seen': now.subtract(const Duration(minutes: 5)).toIso8601String()},
      {'name': 'Charlie', 'state': 'offline', 'last_seen': now.subtract(const Duration(hours: 1)).toIso8601String()},
      {'name': 'Diana', 'state': 'online', 'last_seen': now.toIso8601String()},
    ];
    return data;
  }

  // simulate random update by flipping states randomly
  List<Map<String, dynamic>> randomUpdate(List<Map<String, dynamic>> current) {
    final out = current.map((m) => Map<String, dynamic>.from(m)).toList();
    for (var i = 0; i < out.length; i++) {
      if (_random.nextBool()) {
        final wasOnline = out[i]['state'] == 'online';
        if (wasOnline) {
          out[i]['state'] = 'offline';
          out[i]['last_seen'] = DateTime.now().subtract(Duration(minutes: _random.nextInt(60))).toIso8601String();
        } else {
          out[i]['state'] = 'online';
          out[i]['last_seen'] = DateTime.now().toIso8601String();
        }
      }
    }
    return out;
  }
}
