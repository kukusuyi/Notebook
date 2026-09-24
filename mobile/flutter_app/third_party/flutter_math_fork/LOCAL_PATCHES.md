# Local flutter_math_fork patches

Notebook vendors `flutter_math_fork` 0.7.4 because the application requires a small compatibility change that is not available in the hosted package used by the original project.

`lib/src/render/layout/layout_builder_baseline.dart` uses Flutter's public `LayoutBuilder` implementation instead of private render-object layout callback APIs. This keeps the renderer compatible with the shared Flutter SDK used for Android and iOS builds.

Only the package source, bundled KaTeX fonts, license, upstream README/changelog and this patch note are kept. Upstream examples, documentation and standalone tests are intentionally omitted from the application repository.
