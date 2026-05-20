import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences provider must be overridden.');
});

final keyValueStoreProvider = Provider<KeyValueStore>((ref) {
  return KeyValueStore(ref.watch(sharedPreferencesProvider));
});

class KeyValueStore {
  KeyValueStore(this._preferences);

  final SharedPreferences _preferences;

  String? readString(String key) => _preferences.getString(key);

  int? readInt(String key) => _preferences.getInt(key);

  Future<bool> writeString(String key, String value) {
    return _preferences.setString(key, value);
  }

  Future<bool> writeInt(String key, int value) {
    return _preferences.setInt(key, value);
  }

  Future<bool> remove(String key) {
    return _preferences.remove(key);
  }
}

