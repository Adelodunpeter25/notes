# Flutter Desktop Rewrite Plan

## Goal

Rewrite the macOS desktop client in Flutter while using the same AppFlowy Editor engine and document format as the rest of the product. The rewrite removes the current Swift/AppKit rich-text conversion layer and keeps editor content in the canonical AppFlowy format.

## Guiding Principles

- AppFlowy Editor/AppFlowy JSON is the canonical document representation.
- The editor edits local state first; synchronization runs independently.
- Keep domain, persistence, and sync logic separate from Flutter widgets.
- Preserve offline functionality and existing user data.
- Prefer small, testable vertical slices over a big-bang rewrite.
- Do not add conversion logic unless it is required for importing legacy Swift data.

## Phase 0: Confirm Scope and Contracts

### Tasks

- [ ] Confirm supported desktop platforms, initially macOS.
- [ ] Confirm the Flutter and Dart versions to standardize across development and CI.
- [ ] Confirm the AppFlowy Editor package/version and supported document schema.
- [ ] Document the existing authentication API endpoints and response formats.
- [ ] Document the existing sync API request and response contract.
- [ ] Define the canonical note, folder, user, and sync-operation models.
- [ ] Define sync behavior for offline mode, retries, duplicate operations, conflicts, and deletions.
- [ ] Decide how legacy Swift notes will be imported.

### Exit Criteria

- The editor document format is explicitly defined.
- The API and sync contracts are written down.
- Migration compatibility requirements are agreed upon.

## Phase 1: Create the Flutter Desktop Application

### Tasks

- [ ] Create the Flutter application structure.
- [ ] Enable the required desktop target(s).
- [ ] Add application environment/configuration handling.
- [ ] Establish formatting, linting, and analysis rules.
- [ ] Add a predictable application entry point.
- [ ] Create the base theme and platform-specific window setup.
- [ ] Add unit-test and widget-test targets.
- [ ] Add a basic CI check for formatting, analysis, and tests.

### Suggested Structure

```text
lib/
  app/
    app.dart
    router.dart
    theme.dart
  core/
    config/
    errors/
    result/
  data/
    database/
    repositories/
    api/
    sync/
  domain/
    models/
    services/
  features/
    auth/
    folders/
    notes/
    editor/
    search/
  main.dart
 test/
```

### Exit Criteria

- The app launches as a desktop Flutter application.
- Static analysis and the initial test suite pass.

## Phase 2: Local Data and Domain Layer

### Tasks

- [ ] Implement local database initialization and migrations.
- [ ] Model users, folders, notes, and sync operations.
- [ ] Add repositories for users, folders, and notes.
- [ ] Add active-note, folder, trash, and pinned-note queries.
- [ ] Add soft-delete, restore, and permanent-delete operations.
- [ ] Add folder assignment and folder deletion behavior.
- [ ] Add search over note titles and content.
- [ ] Add timestamps and consistent date serialization.
- [ ] Add database transaction helpers where multiple records change together.
- [ ] Add tests equivalent to the current Swift service tests.

### Exit Criteria

- Notes and folders can be created, updated, searched, moved, trashed, restored, and deleted locally.
- Local behavior is covered by automated tests.

## Phase 3: AppFlowy Editor Integration

### Tasks

- [ ] Integrate AppFlowy Editor into the note editing screen.
- [ ] Load the stored AppFlowy document directly without Swift conversion.
- [ ] Save editor changes as canonical AppFlowy JSON.
- [ ] Preserve block IDs, formatting, lists, checkboxes, links, and nested content.
- [ ] Implement note title handling without rewriting the document unnecessarily.
- [ ] Add editor commands for formatting, headings, lists, and checkboxes.
- [ ] Add keyboard shortcuts used by the current desktop application.
- [ ] Add find-in-note behavior.
- [ ] Add autosave/debouncing so every keystroke does not create excessive sync operations.
- [ ] Add tests for loading, editing, saving, and reopening rich documents.

### Exit Criteria

- A document can be edited, closed, and reopened with no formatting loss.
- AppFlowy JSON remains unchanged except for intentional edits.
- No Swift-specific rich-text conversion is required in the normal path.

## Phase 4: Authentication and Session Management

### Tasks

- [ ] Implement the existing signup flow.
- [ ] Implement the existing login flow.
- [ ] Add token refresh behavior if supported by the API.
- [ ] Store credentials using a secure desktop credential mechanism rather than plain preferences where possible.
- [ ] Restore the session on application startup.
- [ ] Implement logout and local-session cleanup.
- [ ] Add loading, error, and retry states.
- [ ] Add tests using a mocked API client.

### Exit Criteria

- Users can sign up, log in, restart the application, and log out.
- Authentication failures are presented clearly and do not corrupt local data.

## Phase 5: Sync Engine

### Tasks

- [ ] Implement a local pending-operation queue.
- [ ] Record note, folder, move, pin, restore, and delete mutations.
- [ ] Make every operation idempotent using stable operation IDs.
- [ ] Implement push of pending operations.
- [ ] Implement pull of remote changes.
- [ ] Persist a cursor per account/user.
- [ ] Apply folders before notes when relationships require it.
- [ ] Apply soft-delete tombstones safely.
- [ ] Handle permanent deletes and missing remote records.
- [ ] Add retry with bounded exponential backoff.
- [ ] Prevent concurrent sync runs for the same account.
- [ ] Handle app restart while operations are pending.
- [ ] Define and implement conflict resolution for simultaneous edits.
- [ ] Expose sync status: idle, syncing, offline, failed, and pending count.
- [ ] Add structured logging for sync failures without logging note contents or tokens.
- [ ] Add unit tests for ordering, retries, duplicate operations, cursors, conflicts, and partial failures.

### Exit Criteria

- Offline edits are eventually synchronized after reconnecting.
- Repeating a request does not duplicate or corrupt data.
- A failed sync can resume without losing queued changes.
- Conflicts follow the documented resolution policy.

## Phase 6: Desktop UI Parity

### Tasks

- [ ] Build the three-pane layout: folders, notes, and editor.
- [ ] Implement folder selection and note filtering.
- [ ] Implement all notes, folder notes, and trash views.
- [ ] Implement note creation and automatic selection.
- [ ] Implement folder creation, rename, and deletion.
- [ ] Implement note pinning, moving, trashing, restoring, and permanent deletion.
- [ ] Preserve empty-note cleanup behavior where still desired.
- [ ] Add desktop context menus.
- [ ] Add keyboard navigation and Escape behavior.
- [ ] Add responsive pane sizing and resizing persistence.
- [ ] Add empty, loading, and error states.
- [ ] Add accessibility labels and focus behavior.
- [ ] Match the existing visual hierarchy before introducing new design changes.

### Exit Criteria

- Existing core workflows are available in Flutter.
- The app remains usable with keyboard and mouse only.

## Phase 7: Legacy Data Migration

### Tasks

- [ ] Inventory existing Swift database records and content formats.
- [ ] Create a one-time importer for legacy notes and folders.
- [ ] Preserve IDs, timestamps, folder relationships, pin state, and deletion state.
- [ ] Validate imported AppFlowy documents before inserting them.
- [ ] Keep backups before migration.
- [ ] Produce a migration report with imported, skipped, and failed records.
- [ ] Test migration on copies of representative real-world databases.
- [ ] Make the importer rerunnable without duplicating records.

### Exit Criteria

- Existing user notes are available in Flutter with acceptable formatting fidelity.
- Migration failures are visible and recoverable.

## Phase 8: Verification and Release Hardening

### Tasks

- [ ] Run unit, widget, integration, and migration tests.
- [ ] Test offline editing and reconnection.
- [ ] Test large notes and large note collections.
- [ ] Test rapid edits, app termination, and restart during sync.
- [ ] Test malformed server responses and expired authentication.
- [ ] Check memory usage and editor responsiveness.
- [ ] Add crash/error reporting only after reviewing privacy requirements.
- [ ] Package and sign the macOS application.
- [ ] Verify update/install behavior.
- [ ] Define rollback and data-backup procedures.
- [ ] Run a controlled beta alongside the Swift app if feasible.

### Exit Criteria

- Release-critical workflows pass on supported desktop environments.
- Data backup, migration, and rollback procedures are documented.
- The Flutter client can safely replace the Swift client.

## Recommended Implementation Order

1. Establish API and AppFlowy document contracts.
2. Build the Flutter shell and three-pane navigation.
3. Implement local database and repositories.
4. Integrate AppFlowy Editor with local save/load.
5. Implement authentication.
6. Implement sync against test fixtures or a mock server.
7. Connect the real sync API.
8. Add legacy data migration.
9. Complete parity, performance, packaging, and release testing.

## Definition of Done

The rewrite is complete when:

- The Flutter desktop app uses AppFlowy Editor directly.
- Normal editing requires no Swift/AppFlowy conversion layer.
- Existing notes can be migrated safely.
- Offline edits synchronize reliably and idempotently.
- Rich text, lists, links, checkboxes, and formatting survive reloads and sync.
- Authentication, folders, search, trash, and note management match the required product behavior.
- Automated tests cover local data, editor persistence, sync, and migration.
- The packaged desktop application is ready for a controlled release.
