# Note

A minimal, offline-first note-taking app with sync across devices.

## Architecture

```
┌───────────────┐     ┌─────────────────────┐     ┌───────────────┐
│  Flutter App  │◄───►│  Cloudflare Worker  │◄───►│  Turso        │
│ (Drift / FTS5)│     │  (Hono + Drizzle)   │     │  (libSQL)     │
└───────────────┘     └─────────────────────┘     └───────────────┘
        ▲                        ▲
        │                        │
┌───────┴────────┐               │
│   macOS App    │◄──────────────┘
│ (Swift/SQLite) │
└────────────────┘
```

### Mobile (`lib/`)

- **Flutter** (Dart), Android and iOS
- **Drift** (SQLite) for local persistence with reactive streams
- **FTS5** full-text search on title and plain-text content
- **AppFlowy Editor** for rich-text editing (block-based JSON)
- **Operation queue** (`SyncOps` table) for offline changes, pushed on the next sync
- Two Android flavors: `dev` (`.dev` application id suffix) and `prod`

### Backend (`server/`)

- **Cloudflare Workers** running a **Hono** app, deployed with the `cf` CLI
- **Turso** (libSQL) through **Drizzle ORM**, using the web client
- JWT auth with `jose` (HS256) and `bcryptjs` password hashing
- A sync endpoint with cursor-based pulls and per-operation conflict resolution

### Desktop (`note-desktop/`)

- **Swift** / Swift Package Manager, macOS 14+
- Three-pane split view (folders / notes / editor) with a native toolbar, context menus, search and inline rename
- Local SQLite persistence with FTS5, same schema as the mobile app
- Shared AppFlowy JSON content format, so notes are compatible with mobile
- Auth, note and folder CRUD, trash, pin, and sync

## Sync protocol

```
POST /api/sync   (Authorization: Bearer <jwt>)
Client → Server:  { cursor, ops: [{ id, type, entityType, entityId, updatedAt, payload }] }
Server → Client:  { nextCursor, notes[], folders[], deleted[], processedOpIds[], errors? }
```

- **Conflict resolution:** last write wins by `updatedAt`.
- **Soft deletes:** tombstones are sent in `deleted`. A folder delete is always a soft delete on the server, so other devices learn about it; notes inside are detached.
- **Offline queue:** local changes go to `SyncOps`. Every op carries the full row, so clients keep only the newest op per entity and push in batches of 100.
- **Acknowledgement:** a client deletes a queued op only when its id appears in `processedOpIds`.
- **Cursor:** on mobile it is stored with the user and server URL it came from. If either changes, the next sync does a full pull instead of skipping older rows.
- **Expired session:** a `401` signs the app out and returns to the login screen. Local notes and queued ops are kept.

## Getting started

### Prerequisites

- Flutter SDK >= 3.5.4
- Node.js 22.18+ (the `cf` CLI cannot load its config under Bun)
- A Turso database and a Cloudflare account
- macOS with Xcode command line tools (Swift 6, for the desktop app)

### Mobile app

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run --flavor dev
```

Release APKs, one per ABI:

```bash
flutter build apk --release --split-per-abi --flavor prod
# build/app/outputs/flutter-apk/app-<abi>-prod-release.apk
```

Flutter may print "Gradle build failed to produce an .apk file" for flavored builds. The files are still written to the path above.

The API URL is set in `lib/services/api_service.dart` (mobile) and `note-desktop/Sources/Services/ApiService.swift` (desktop).

### Server

```bash
cd server
npm install
cp .env.example .dev.vars   # TURSO_DATABASE_URL, TURSO_AUTH_TOKEN, JWT_SECRET
npm run dev                 # cf dev on http://localhost:5173
npm run typecheck
```

Schema changes (needs `TURSO_DATABASE_URL` and `TURSO_AUTH_TOKEN` in the environment):

```bash
npm run db:generate
npm run db:migrate
```

Deploy:

```bash
npm run deploy                          # cf deploy
cf deploy --secrets-file <file>         # first deploy only: NAME=value lines
cf workers secrets update <NAME> --worker notes-api --type secret_text   # later secret changes
```

`.dev.vars` is gitignored. The Worker needs three secrets: `TURSO_DATABASE_URL`, `TURSO_AUTH_TOKEN` and `JWT_SECRET`. Changing `JWT_SECRET` invalidates every issued token, so all clients must sign in again.

### Desktop (macOS)

```bash
cd note-desktop
swift build
swift run
```

To build a `.app` and `.dmg`, run `scripts/package.sh`.
