import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/auth_models.dart';
import 'key_value_store.dart';
import '../config/effective_api_base_url.dart';
import 'storage_keys.dart';

final authSessionRepositoryProvider = Provider<AuthSessionRepository>((ref) {
  return AuthSessionRepository(
    ref.watch(keyValueStoreProvider),
    ref.watch(serverStorageKeyProvider),
  );
});

class AuthSessionRepository {
  AuthSessionRepository(this._store, [String server = ''])
    : _key = '${StorageKeys.authSession}:$server';
  final String _key;

  final KeyValueStore _store;

  AuthSession? readSession() {
    final raw = _store.readString(_key);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    return AuthSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  String? readToken() {
    return readSession()?.token;
  }

  Future<void> saveSession(AuthSession session) async {
    await _store.writeString(_key, jsonEncode(session.toJson()));
  }

  Future<void> clearSession() async {
    await _store.remove(_key);
  }
}
