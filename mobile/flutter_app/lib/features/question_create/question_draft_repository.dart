import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/key_value_store.dart';
import '../../core/storage/storage_keys.dart';
import '../../shared/models/question_models.dart';

final questionDraftRepositoryProvider = Provider<QuestionDraftRepository>((ref) {
  return QuestionDraftRepository(ref.watch(keyValueStoreProvider));
});

class QuestionDraftRepository {
  QuestionDraftRepository(this._store);

  final KeyValueStore _store;

  QuestionDraft? readDraft() {
    final raw = _store.readString(StorageKeys.questionDraft);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    return QuestionDraft.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveDraft(QuestionDraft draft) async {
    await _store.writeString(
      StorageKeys.questionDraft,
      jsonEncode(draft.toJson()),
    );
  }

  Future<void> clearDraft() async {
    await _store.remove(StorageKeys.questionDraft);
  }
}

