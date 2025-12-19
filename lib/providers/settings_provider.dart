import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsState {
  final String name;
  final String token;

  const SettingsState({this.name = '', this.token = ''});

  SettingsState copyWith({String? name, String? token}) => SettingsState(
        name: name ?? this.name,
        token: token ?? this.token,
      );
}

class SettingsNotifier extends Notifier<SettingsState> {
  @override
  SettingsState build() => const SettingsState();

  void setName(String name) => state = state.copyWith(name: name);
  void setToken(String token) => state = state.copyWith(token: token);
  void setAll({required String name, required String token}) => state = SettingsState(name: name, token: token);

  // Persistence keys
  static const _kName = 'settings_name';
  static const _kToken = 'settings_token';

  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_kName) ?? '';
    final token = prefs.getString(_kToken) ?? '';
    state = SettingsState(name: name, token: token);
  }

  Future<void> saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kName, state.name);
    await prefs.setString(_kToken, state.token);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);
