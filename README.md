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

1. Update `assets/env/app.env`:
   - `API_BASE_URL` — Android emulator: `http://10.0.2.2:3000`; iOS simulator / desktop / web: `http://127.0.0.1:3000`
   - Optional `GOOGLE_WEB_CLIENT_ID` — same Web client ID as the backend (`GOOGLE_WEB_CLIENT_ID` in `be-ther-backend/.env`)
2. Install packages:
   - `flutter pub get`
3. Run:
   - `flutter run`

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
