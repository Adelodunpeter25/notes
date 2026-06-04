# Note

A minimal, offline-first note-taking app with real-time sync across devices.

## Architecture

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  Flutter App  │◄───►│  Fastify API  │◄───►│  PostgreSQL   │
│  (Drift/FTS5) │     │  (Bun + Drizzle)│    │              │
└──────────────┘     └──────────────┘     └──────────────┘
       ▲
       │  (planned)
┌──────┴───────┐
│  macOS App    │
│  (Swift/SwiftUI)│
└──────────────┘
```

### Frontend (`lib/`)

- **Flutter** (Dart) — iOS & Android
- **Drift** (SQLite) for local persistence with reactive streams
- **FTS5** full-text search indexed on title and plain-text content
- **AppFlowy Editor** for rich-text editing (block-based JSON format)
- **Operation queue** (`SyncOps` table) for offline mutations pushed on next sync

### Backend (`server/`)

- **Bun** runtime with **Fastify** HTTP server
- **Drizzle ORM** with **PostgreSQL**
- JWT authentication (bcrypt password hashing)
- Sync endpoint with cursor-based pagination and per-operation conflict resolution

### Desktop (`note-desktop/`)

- **Swift** / Swift Package Manager (macOS 13+)
- **NoteKit** — custom TextKit 2 block editor engine (early stage)
- Intended to share the same sync protocol as the mobile app

## Sync Protocol

```
Client → Server:  { cursor, ops: [{ id, type, entityType, entityId, updatedAt, payload }] }
Server → Client:  { nextCursor, notes[], folders[], deleted[], processedOpIds[], errors? }
```

- **Conflict resolution**: last-write-wins by `updatedAt` timestamp
- **Soft deletes**: tombstones propagated via the `deleted` array
- **Offline queue**: local mutations stored in `SyncOps`, drained FIFO on each sync
- **Idempotency**: each op has a client-generated UUID used as the server's ack key

## Key Features

- Rich text editing with headings, checklists, code blocks
- Folders for organizing notes
- Pin notes to the top
- Soft delete with trash and permanent empty
- Full-text search (FTS5) across title and content
- Automatic background sync with conflict resolution
- Session persistence across app restarts

## Getting Started

### Prerequisites

- Flutter SDK >= 3.5.4
- Bun (for the server)
- PostgreSQL

### Mobile App

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

### Server

```bash
cd server
bun install
cp .env.example .env   # configure DATABASE_URL, JWT_SECRET
bun run db:push         # apply schema to PostgreSQL
bun run dev
```

### Desktop (macOS)

```bash
cd note-desktop
swift build
swift run
```

## Project Structure

```
notes/
├── lib/
│   ├── database/        # Drift schema, DAOs, FTS helpers
│   ├── services/        # Auth, Note, Folder, Sync services
│   ├── widgets/         # UI components (NoteCard, EditorAppBar, AppBottomSheet, etc.)
│   ├── pages/           # Screen-level widgets (AuthPage)
│   ├── layouts/         # App layout shell
│   ├── models/          # Dart data models
│   ├── utils/           # Helpers (time formatting, dialogs, note content parsing)
│   ├── theme.dart       # Dark/light theme definitions
│   └── main.dart        # App entry, service initialization
├── server/
│   ├── routes/          # Fastify route handlers (auth, sync, health)
│   ├── services/        # Business logic (auth, sync with retry + conflict resolution)
│   ├── db/schema/       # Drizzle table definitions (users, notes, folders, sync_state)
│   ├── types/           # TypeScript type definitions
│   ├── middleware/       # Auth middleware (JWT verification)
│   └── index.ts         # Server entry point
├── note-desktop/
│   ├── Sources/         # Swift app sources
│   └── vendor/NoteKit/  # TextKit 2 block editor engine
└── pubspec.yaml
```
