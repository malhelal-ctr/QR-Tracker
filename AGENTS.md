# Repository Guidelines

## Project Structure & Module Organization

The Flutter application starts in `lib/main.dart`. Shared models, persistence, formatting, themes, and reusable widgets live under `lib/core/`. Product areas are organized by feature in `lib/features/<feature>/`, typically split into `screen/`, `widget/`, `model/`, and `cubit/`. Keep new code in the owning feature; move it to `core/` only when multiple features reuse it.

Tests are in `test/`; the current regression suite is `test/widget_test.dart`. Fonts and launcher artwork belong in `assets/` and must be registered in `pubspec.yaml`. `widgetbook/` is a separate UI-catalog entry point. Platform configuration is under `android/` and `web/`, while local Supabase configuration is under `supabase/`. Do not edit generated output in `build/` or `.dart_tool/`.

## Build, Test, and Development Commands

- `flutter pub get` installs dependencies from `pubspec.lock`.
- `flutter run -d chrome` runs the web app locally.
- `flutter run -t widgetbook/main.dart -d chrome` opens the component catalog.
- `flutter analyze` applies the analyzer and `flutter_lints` rules.
- `flutter test` runs all automated tests.
- `flutter build apk --release` creates the Android release APK.
- `flutter build web --release` produces the deployable PWA in `build/web`.

Run `dart format .` before submitting changes.

## Coding Style & Naming Conventions

Use standard Dart formatting with two-space indentation and trailing commas for multiline declarations. Name files and directories `snake_case`, classes and enums `UpperCamelCase`, and variables/methods `lowerCamelCase`. Prefer small widgets and immutable state. Screens should provide their Cubit with `BlocProvider`, render state with `BlocBuilder`, and access persisted data through `TrackerRepository` rather than opening Hive boxes directly.

## Testing Guidelines

Use `flutter_test`; name tests as observable behaviors, for example `ProgressStats computes position, today and plan`. Add unit tests for parsing, calculations, persistence migrations, and Cubit state changes. Use temporary Hive directories and register cleanup with `addTearDown`. There is no fixed coverage threshold, but every bug fix should include a regression test.

## Commit & Pull Request Guidelines

Recent history uses concise, imperative subjects such as `fix manual scan` and occasionally Conventional Commit prefixes such as `chore:`. Keep each commit focused and describe the user-visible outcome. Pull requests should include a short summary, testing performed, linked issue when applicable, and screenshots or recordings for UI changes. Call out data-format, backup/restore, permission, or platform-specific impacts explicitly.
