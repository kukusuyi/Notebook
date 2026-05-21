import 'package:flutter/widgets.dart';

/// Flutter's built-in [LayoutBuilder] already forwards baseline information on
/// current stable releases, while the older custom render-object based
/// implementation in this fork depended on private framework details that
/// changed across Flutter versions.
///
/// Keeping this as a thin wrapper around [LayoutBuilder] makes the math fork
/// compile reliably on both Android and iOS with the same Flutter SDK.
class LayoutBuilderPreserveBaseline extends StatelessWidget {
  const LayoutBuilderPreserveBaseline({
    super.key,
    required this.builder,
  });

  final LayoutWidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: builder);
  }
}
