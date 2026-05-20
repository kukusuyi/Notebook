import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/auth_models.dart';
import 'key_value_store.dart';
import 'storage_keys.dart';

final authSessionRepositoryProvider = Provider<AuthSessionRepository>((ref) {
  return AuthSessionRepository(ref.watch(keyValueStoreProvider));
});

class AuthSessionRepository {
  AuthSessionRepository(this._store);

  final KeyValueStore _store;

  AuthSession? readSession() {
    final raw = _store.readString(StorageKeys.authSession);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    return AuthSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  String? readToken() {
    return readSession()?.token;
  }

  Future<void> saveSession(AuthSession session) async {
    await _store.writeString(
      StorageKeys.authSession,
      jsonEncode(session.toJson()),
    );
  }

  Future<void> clearSession() async {
    await _store.remove(StorageKeys.authSession);
  }
}

