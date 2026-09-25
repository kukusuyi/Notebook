import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questrace_flutter/shared/widgets/appearance_color_picker.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'appearance palette selects and returns a color in $brightness',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        Color? result;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await showModalBottomSheet<Color>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) =>
                          const AppearanceColorPicker(initial: Colors.blue),
                    );
                  },
                  child: const Text('选择'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('选择'));
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsNothing);
        expect(find.text('选择外观颜色'), findsOneWidget);
        expect(find.byType(Tooltip), findsNWidgets(16));
        await tester.tap(find.byTooltip('鸢尾'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('应用颜色'));
        await tester.tap(find.text('应用颜色'));
        await tester.pumpAndSettle();
        expect(result, const Color(0xff9333ea));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
