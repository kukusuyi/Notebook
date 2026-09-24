import 'package:shared_preferences/shared_preferences.dart';

/// The Questrace rename changed every stored key. Values written by earlier
/// builds are copied to the current keys on startup while the old keys are kept,
/// so rolling back to an earlier build still finds its session, draft and
/// preferences.
const legacyStoragePrefixes = <String, String>{
  'math-notebook:': 'questrace:',
  'notebook:': 'questrace:',
};

/// Returns the current key for [key], or null when the key is not renamed.
String? currentStorageKey(String key) {
  for (final entry in legacyStoragePrefixes.entries) {
    if (key.startsWith(entry.key)) {
      return '${entry.value}${key.substring(entry.key.length)}';
    }
  }
  return null;
}

/// Copies pre-rename entries to their current keys and returns the copied keys.
/// A value already stored under the current key always wins.
Future<List<String>> migrateLegacyStorage(SharedPreferences preferences) async {
  final pending = <String, Object>{};
  for (final key in preferences.getKeys()) {
    final current = currentStorageKey(key);
    if (current == null || preferences.containsKey(current)) {
      continue;
    }
    final value = preferences.get(key);
    if (value != null) {
      pending[current] = value;
    }
  }

  final copied = <String>[];
  for (final entry in pending.entries) {
    final value = entry.value;
    final stored = switch (value) {
      String() => await preferences.setString(entry.key, value),
      int() => await preferences.setInt(entry.key, value),
      bool() => await preferences.setBool(entry.key, value),
      double() => await preferences.setDouble(entry.key, value),
      List<String>() => await preferences.setStringList(entry.key, value),
      _ => false,
    };
    if (stored) {
      copied.add(entry.key);
    }
  }
  return copied;
}
