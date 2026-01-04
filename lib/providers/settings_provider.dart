import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class SettingsState {
  final String name;
  final String token;
  final String uuid;

  const SettingsState({this.name = '', this.token = '', this.uuid = ''});

  SettingsState copyWith({String? name, String? token, String? uuid}) => SettingsState(
        name: name ?? this.name,
        token: token ?? this.token,
        uuid: uuid ?? this.uuid,
      );
}

class SettingsNotifier extends Notifier<SettingsState> {
  @override
  SettingsState build() => const SettingsState();

  void setName(String name) => state = state.copyWith(name: name);
  void setToken(String token) => state = state.copyWith(token: token);
  void setAll({required String name, required String token}) => state = state.copyWith(name: name, token: token);

  // Persistence keys
  static const _kName = 'settings_name';
  static const _kToken = 'settings_token';
  static const _kUuid = 'settings_uuid';

  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_kName) ?? '';
    final token = prefs.getString(_kToken) ?? '';
    var uuid = prefs.getString(_kUuid) ?? '';

    // Generate UUID if not exists
    if (uuid.isEmpty) {
      uuid = const Uuid().v4();
      await prefs.setString(_kUuid, uuid);
    }

    state = SettingsState(name: name, token: token, uuid: uuid);
  }

  Future<void> saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kName, state.name);
    await prefs.setString(_kToken, state.token);
    await prefs.setString(_kUuid, state.uuid);
  }

  /// Regenerate UUID (useful for testing)
  Future<void> regenerateUuid() async {
    final newUuid = const Uuid().v4();
    state = state.copyWith(uuid: newUuid);
    await saveToPrefs();
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);
