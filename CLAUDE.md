# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AI Personal Assistant Flutter app (Chinese UI). Core flow: read notifications → AI analysis → auto-generate todo items and billing records. Targets Android, macOS, and HarmonyOS NEXT.

The repo root holds design docs and specs; the Flutter app lives in `ai_assistant/`.

## Verification Workflow

**IMPORTANT: After every implementation, rebuild and reinstall before testing.**

Hot reload (`flutter run`) does NOT pick up Dart code changes on macOS — the app binary is not updated. To verify UI/logic changes:

```bash
# Kill any running instance first
killall ai_assistant 2>/dev/null || true

# Rebuild
flutter build macos --release

# Install / open
open build/macos/Build/Products/Release/ai_assistant.app
```

## Build & Run Commands

```bash
cd ai_assistant

# Install dependencies (uses Chinese mirrors, see scripts/setup_flutter.sh)
flutter pub get

# Generate Drift/Freezed code (required after schema or model changes)
dart run build_runner build --delete-conflicting-outputs

# Run on macOS
flutter run -d macos

# Run on Android
flutter run -d android

# Run tests (currently empty)
flutter test

# Lint / analyze
dart analyze
```

## Architecture

**State management**: Riverpod 3.x with `NotifierProvider` pattern. All providers registered in `lib/core/providers/core_providers.dart`.

**Navigation**: `IndexedStack` + `NavigationBar` (4 tabs: 待办, 记账, 随手记, Copilot). go_router is a declared dependency but unused due to macOS compatibility issues.

**App entry flow**: `main.dart` → `ProviderScope` → `App` → `AuthWrapper` (auto-login via saved JWT) → `HomePage`.

**Data layer** (loosely clean architecture):
- `domain/models/` — Plain Dart classes with hand-written `copyWith` (Freezed declared but not used for models)
- `data/api/` — HTTP client + services (base URL hardcoded to `localhost:23110`, JWT auth, file-based token storage)
- `data/datasources/` — `LocalDatasource` (Drift queries), `LocalSyncDatasource` (sync index), `WebDavDatasource`
- `data/repositories/` — Thin wrappers over datasources; sync is captured by database triggers, not repository calls
- `core/database/` — Drift database (schema v11+, sync/sync_index/sync_data/sync_control), generated code in `*.g.dart`

**Sync engine** (`features/sync/`): Bidirectional WebDAV sync with Last-Write-Wins conflict resolution. Cloud root is the user-selected WebDAV directory plus `MyAssistant/`; table changes enqueue `sync_data` automatically and sync writes use `sync_control` mute mode.

**Database tables**: Todos, Routines, ChangeRecords, SyncIndex, SyncData, SyncFiles (`sync`), SyncControl, DeviceSyncState, Tags, MetadataOptions. Schema migrations are incremental in `database.dart`.

## Key Conventions

- **Interaction language**: Chinese (zh-CN) for all UI text and user-facing strings
- **Linting**: Strict rules — `prefer_single_quotes`, `prefer_const_constructors`, `avoid_print`, `sort_child_properties_last`, `prefer_final_locals`
- **Generated files**: `*.g.dart` and `*.freezed.dart` are excluded from analysis; regenerate with `build_runner`
- **KeychainService** uses file-based JSON storage (not native OS keychain)
- **API base URL** is hardcoded in `api_client.dart` — no environment configuration

## Spec-Driven Development

Feature specs live in `specs/` with SpecKit structure (`spec.md → plan.md → tasks.md`). The `.specify/` directory contains the workflow engine. Current active spec: `specs/004-webdav-sync-revamp/`.

## Known Gaps

- No tests exist yet (`test/` is empty)
- Several runtime packages are incorrectly placed in `dev_dependencies` (webdav_plus, connectivity_plus, xml, file_picker, pointycastle)
- Bookkeeping and Notes tabs are placeholder pages
- `features/home/home_shell.dart` is an unused alternative HomePage
