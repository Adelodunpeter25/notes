# Note

A minimal, offline-first note-taking app with real-time sync across devices.

## Architecture

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  Flutter App  │◄───►│  Fastify API  │◄───►│  PostgreSQL   │
│ (Drift / FTS5)│     │  (Bun + Drizzle)│    │              │
└──────────────┘     └──────────────┘     └──────────────┘
       ▲                     ▲
       │                     │
┌──────┴───────┐             │
│  macOS App    │◄────────────┘
│ (Swift/SQLite) │
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
- **NoteKit** — custom TextKit 2 block editor with inline markdown (bold, italic, links), 8 block types, checkbox attachments, and a rendering cache
- Three-pane split view (folders / note list / editor) with context menus, search, and inline rename
- Local SQLite persistence with FTS5 search (same schema as the mobile app)
- Shared AppFlowy JSON content format — notes are cross-compatible with the mobile app
- Auth, note/folder CRUD, trash, pin, and sync op recording

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
- macOS with Xcode Command Line Tools (Swift 5.9+, for the desktop app)

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
