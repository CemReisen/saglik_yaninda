# Copilot Instructions for AI Agents

## Project Overview
- **saglik_yaninda** is a Flutter application targeting mobile and desktop platforms (Android, iOS, Windows, macOS, Linux, Web).
- The main entry point is `lib/main.dart`. Core UI components are organized under `lib/pages/` and `lib/widgets/`.
- Theming is managed in `lib/core/theme/`.

## Architecture & Patterns
- **Page-based navigation**: Each major feature (Home, Calendar, Add Medicine, Notifications, Profile) is implemented as a separate widget in `lib/pages/`.
- **Widget composition**: Reusable UI elements are placed in `lib/widgets/` (e.g., `section_card.dart`).
- **No explicit state management package detected**; use standard Flutter stateful/stateless widgets unless otherwise specified.
- **Platform assets**: Launch images and icons are managed in platform-specific folders (e.g., `ios/Runner/Assets.xcassets`, `web/icons/`).

## Developer Workflows
- **Build**: Use `flutter build <platform>` (e.g., `flutter build apk`, `flutter build ios`).
- **Run**: Use `flutter run` for local development.
- **Test**: Run widget tests with `flutter test` (see `test/widget_test.dart`).
- **Debug**: Use Flutter DevTools or IDE-integrated debugging.
- **Dependencies**: Managed via `pubspec.yaml`. Run `flutter pub get` after changes.

## Conventions & Practices
- **File organization**: Keep feature pages in `lib/pages/`, core utilities in `lib/core/`, and reusable widgets in `lib/widgets/`.
- **Naming**: Use descriptive names for pages and widgets (e.g., `add_medicine_page.dart`).
- **Platform support**: Project is multi-platform; check platform folders for platform-specific code/assets.
- **No custom build scripts or agent rules detected**; follow standard Flutter conventions unless otherwise documented.

## Integration Points
- **External packages**: Refer to `pubspec.yaml` for dependencies.
- **Platform channels**: If integrating with native code, see `android/` and `ios/Runner/` for entry points.

## Key Files & Directories
- `lib/main.dart`: App entry point
- `lib/pages/`: Feature pages
- `lib/widgets/`: Reusable widgets
- `pubspec.yaml`: Dependency management
- `test/`: Widget tests
- `android/`, `ios/`, `web/`, `windows/`, `macos/`, `linux/`: Platform-specific code/assets

## Example Patterns
- To add a new feature page, create a widget in `lib/pages/` and add navigation logic in `main.dart`.
- To add a reusable UI element, implement it in `lib/widgets/` and import where needed.

---

For questions about project-specific conventions, review this file and the main `README.md`. If unclear, ask for clarification before making major changes.
