import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/key_value_store.dart';
import '../../core/storage/storage_keys.dart';
import '../../core/config/effective_api_base_url.dart';
import '../../shared/models/question_models.dart';

final questionDraftRepositoryProvider =
    Provider<QuestionDraftRepository>((ref) {
  return QuestionDraftRepository(
      ref.watch(keyValueStoreProvider), ref.watch(effectiveApiBaseUrlProvider));
});

class QuestionDraftRepository {
  QuestionDraftRepository(this._store, [String server = ''])
      : _key = '${StorageKeys.questionDraft}:$server';
  final String _key;

  final KeyValueStore _store;

  QuestionDraft? readDraft() {
    final raw = _store.readString(_key);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    return QuestionDraft.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveDraft(QuestionDraft draft) async {
    await _store.writeString(
      _key,
      jsonEncode(draft.toJson()),
    );
  }

  Future<void> saveAnalysisSnapshot(QuestionDraft draft) async {
    if (_store.readString('$_key:before-analysis') == null)
      await _store.writeString(
          '$_key:before-analysis', jsonEncode(draft.toJson()));
  }

  QuestionDraft? readAnalysisSnapshot() {
    final raw = _store.readString('$_key:before-analysis');
    if (raw == null) return null;
    return QuestionDraft.fromJson(jsonDecode(raw));
  }

  Future<void> clearAnalysisSnapshot() async {
    await _store.remove('$_key:before-analysis');
  }

  Future<void> clearDraft() async {
    await clearAnalysisSnapshot();
    await _store.remove(_key);
  }
}
