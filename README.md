# Be Ther Frontend (Flutter)

Flutter app using a scalable, feature-first architecture.

## Tech Choices

- State management: `flutter_riverpod`
- Navigation: `go_router`
- HTTP client: `dio`
- Environment config: `flutter_dotenv`
- Auth: email OTP and Google Sign-In (tokens in secure storage)

## Folder Structure

```text
lib/
  app.dart
  main.dart
  core/
    design/
    network/
    routing/
    storage/
    theme/
  features/
    auth/
    feed/
    explore/
    launch/
    notifications/
    onboarding/
    profile/
    settings/
```

## Run Locally

1. Environments (`assets/env/`):
   - `prod.env` — production API (`https://be-ther.com/api/`). **Release builds (AAB / App Store) always use this.**
   - `dev.env` — dev API with its own database (`https://dev.be-ther.com/api/`). For a local backend set
     `API_BASE_URL` to `http://10.0.2.2:3000` (Android emulator) or `http://127.0.0.1:3000` (iOS simulator).
2. Install packages:
   - `flutter pub get`
3. Run (debug):
   - Prod: `flutter run` (or "Be Ther (prod)" in Cursor / VS Code)
   - Dev: `flutter run --dart-define=APP_ENV=dev` (or "Be Ther (dev)") — shows a red DEV banner
4. Release (always prod, no flags needed):
   - `flutter build appbundle` / Xcode Archive

## Connect Mongo, R2, OTP email, and Google

See the repository docs: [docs/STACK_AND_ARCHITECTURE.md](../docs/STACK_AND_ARCHITECTURE.md) and [docs/FEATURE_NOTE_AUTH_MEDIA.md](../docs/FEATURE_NOTE_AUTH_MEDIA.md).

## Quality Checks

- `flutter analyze`
- `flutter test`

## How to Build New Features

For each feature, keep this pattern:

- `features/<feature>/data`: API/data code
- `features/<feature>/presentation`: UI + Riverpod providers
- Reuse shared services from `core/`
