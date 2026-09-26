import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:questrace_flutter/core/storage/key_value_store.dart';
import 'package:questrace_flutter/core/storage/app_settings_controller.dart';
import 'package:questrace_flutter/core/storage/auth_session_repository.dart';
import 'package:questrace_flutter/core/config/effective_api_base_url.dart';
import 'package:questrace_flutter/features/question_create/question_draft_repository.dart';
import 'package:questrace_flutter/shared/models/question_models.dart';

void main() {
  test(
    'same device retains storage across addresses; mismatched discovery cannot replace it',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      String device = 'aabbccddeeff';
      server.listen((request) {
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'data': {
              'version': '2.1.1',
              'ocr_enabled': false,
              'embedding_enabled': false,
              'discovery': {'device_id': device},
            },
          }),
        );
        request.response.close();
      });
      final next = 'http://127.0.0.1:${server.port}';
      const old = 'http://192.168.1.10:8080';
      SharedPreferences.setMockInitialValues({
        'questrace:api-base-url': old,
        'questrace:device-id': device,
        'questrace:server-key': old,
        'questrace:auth-session:$old': jsonEncode({
          'token': 'keep-token',
          'user_id': 1,
          'username': 'student',
        }),
      });
      final store = KeyValueStore(await SharedPreferences.getInstance());
      final container = ProviderContainer(
        overrides: [keyValueStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      await container
          .read(questionDraftRepositoryProvider)
          .saveDraft(QuestionDraft.emptyManual());
      final controller = container.read(appSettingsControllerProvider.notifier);
      await controller.setApiBaseUrlOverride(
        next,
        expectedDeviceId: device,
        reconnect: true,
      );
      expect(container.read(effectiveApiBaseUrlProvider), next);
      expect(container.read(serverStorageKeyProvider), old);
      expect(
        container.read(authSessionRepositoryProvider).readToken(),
        'keep-token',
      );
      expect(
        container.read(questionDraftRepositoryProvider).readDraft(),
        isNotNull,
      );
      device = '112233445566';
      await expectLater(
        controller.setApiBaseUrlOverride(
          next,
          expectedDeviceId: 'aabbccddeeff',
          reconnect: true,
        ),
        throwsFormatException,
      );
      expect(
        container.read(appSettingsControllerProvider).deviceId,
        'aabbccddeeff',
      );
      await controller.setApiBaseUrlOverride(next, expectedDeviceId: device);
      expect(container.read(serverStorageKeyProvider), 'device:$device');
      expect(container.read(authSessionRepositoryProvider).readToken(), isNull);
      expect(
        container.read(questionDraftRepositoryProvider).readDraft(),
        isNull,
      );
      expect(QuestionDraftRepository(store, old).readDraft(), isNotNull);
      device = 'aabbccddeeff';
      await controller.setApiBaseUrlOverride(next, expectedDeviceId: device);
      expect(container.read(serverStorageKeyProvider), old);
      expect(
        container.read(questionDraftRepositoryProvider).readDraft(),
        isNotNull,
      );
    },
  );
}
