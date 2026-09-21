import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:math_notebook_flutter/core/storage/key_value_store.dart';
import 'package:math_notebook_flutter/core/storage/auth_session_repository.dart';
import 'package:math_notebook_flutter/features/question_create/question_draft_repository.dart';
import 'package:math_notebook_flutter/shared/models/question_models.dart';

void main() {
  test('drafts are isolated by server and preserved when switching back',
      () async {
    SharedPreferences.setMockInitialValues({});
    final store = KeyValueStore(await SharedPreferences.getInstance());
    final a = QuestionDraftRepository(store, 'http://192.168.1.2:8080');
    final b = QuestionDraftRepository(store, 'http://192.168.1.3:8080');
    await a.saveDraft(QuestionDraft.emptyManual());
    expect(a.readDraft(), isNotNull);
    expect(b.readDraft(), isNull);
  });
  test('unscoped legacy credentials are never used for a new server', () async {
    SharedPreferences.setMockInitialValues(
        {'math-notebook:auth-session': '{"token":"legacy"}'});
    final store = KeyValueStore(await SharedPreferences.getInstance());
    expect(AuthSessionRepository(store, 'http://192.168.1.3:8080').readToken(),
        isNull);
  });
}
