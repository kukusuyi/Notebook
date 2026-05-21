import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:math_notebook_flutter/app/app.dart';
import 'package:math_notebook_flutter/core/storage/key_value_store.dart';

void main() {
  testWidgets('shows auth page when no session is stored', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('题迹 Notebook'), findsOneWidget);
    expect(find.text('登录'), findsOneWidget);
  });
}
