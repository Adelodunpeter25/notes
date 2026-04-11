# Fix: Store Sync Cursor in Database

## Problem
Current sync stores cursor in `localStorage` (desktop) and `AsyncStorage` (mobile), which gets cleared when cache is wiped or app is reinstalled. This breaks sync continuity.

## Solution
Store sync cursor in the **database** (both client SQLite and server PostgreSQL) so it persists across cache clears.

---

## Implementation Steps

### 1. **Server: Add `sync_state` table**

✅ Already added to `server/db/schema/sync_state.ts`

Run migration:
```bash
cd server
bun run db:generate
bun run db:push
```

### 2. **Desktop: Add `sync_state` to SQLite schema**

Add to `desktop/src-tauri/src/db/schema.rs` (or wherever your Tauri SQLite schema is):

```sql
CREATE TABLE IF NOT EXISTS sync_state (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  device_id TEXT NOT NULL,
  last_cursor TEXT,
  last_sync_at TEXT,
  updated_at TEXT NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_sync_state_user_device 
ON sync_state(user_id, device_id);
```

### 3. **Mobile: Add `sync_state` to SQLite schema**

Add to mobile SQLite initialization (e.g., `mobile/src/db/client.ts`):

```typescript
await db.execAsync(`
  CREATE TABLE IF NOT EXISTS sync_state (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    device_id TEXT NOT NULL,
    last_cursor TEXT,
    last_sync_at TEXT,
    updated_at TEXT NOT NULL
  );

  CREATE UNIQUE INDEX IF NOT EXISTS idx_sync_state_user_device 
  ON sync_state(user_id, device_id);
`);
```

### 4. **Update sync logic (Desktop & Mobile)**

#### Desktop (`desktop/src/hooks/useSync.ts`)

Replace:
```typescript
const cursor = localStorage.getItem(CURSOR_KEY);
```

With:
```typescript
const cursor = await invoke<string | null>("get_sync_cursor");
```

Replace:
```typescript
localStorage.setItem(CURSOR_KEY, response.nextCursor);
```

With:
```typescript
await invoke("save_sync_cursor", { cursor: response.nextCursor });
```

Add Tauri command handlers (in Rust):
```rust
#[tauri::command]
async fn get_sync_cursor(state: State<'_, AppState>) -> Result<Option<String>, String> {
    let db = &state.db;
    let device_id = get_device_id(); // Generate once per install
    
    let result: Option<String> = sqlx::query_scalar(
        "SELECT last_cursor FROM sync_state WHERE device_id = ? LIMIT 1"
    )
    .bind(device_id)
    .fetch_optional(db)
    .await
    .map_err(|e| e.to_string())?;
    
    Ok(result)
}

#[tauri::command]
async fn save_sync_cursor(
    cursor: String,
    state: State<'_, AppState>
) -> Result<(), String> {
    let db = &state.db;
    let device_id = get_device_id();
    let now = chrono::Utc::now().to_rfc3339();
    
    sqlx::query(
        "INSERT INTO sync_state (id, user_id, device_id, last_cursor, last_sync_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?)
         ON CONFLICT(device_id) DO UPDATE SET
           last_cursor = excluded.last_cursor,
           last_sync_at = excluded.last_sync_at,
           updated_at = excluded.updated_at"
    )
    .bind(uuid::Uuid::new_v4().to_string())
    .bind("current_user_id") // Get from auth state
    .bind(device_id)
    .bind(cursor)
    .bind(&now)
    .bind(&now)
    .execute(db)
    .await
    .map_err(|e| e.to_string())?;
    
    Ok(())
}
```

#### Mobile (`mobile/src/hooks/useSync.ts`)

Replace:
```typescript
const cursor = await AsyncStorage.getItem(CURSOR_KEY);
```

With:
```typescript
const cursor = await getSyncCursor();
```

Replace:
```typescript
await AsyncStorage.setItem(CURSOR_KEY, response.nextCursor);
```

With:
```typescript
await saveSyncCursor(response.nextCursor);
```

Add helper functions (`mobile/src/db/repos/syncStateRepo.ts`):
```typescript
import { getDb } from '../client';
import { v4 as uuidv4 } from 'uuid';
import * as Device from 'expo-device';

let cachedDeviceId: string | null = null;

async function getDeviceId(): Promise<string> {
  if (cachedDeviceId) return cachedDeviceId;
  
  // Generate stable device ID once per install
  const stored = await AsyncStorage.getItem('device_id');
  if (stored) {
    cachedDeviceId = stored;
    return stored;
  }
  
  const deviceId = `${Device.modelName || 'unknown'}_${uuidv4()}`;
  await AsyncStorage.setItem('device_id', deviceId);
  cachedDeviceId = deviceId;
  return deviceId;
}

export async function getSyncCursor(): Promise<string | null> {
  const db = getDb();
  const deviceId = await getDeviceId();
  
  const result = await db.getFirstAsync<{ last_cursor: string | null }>(
    'SELECT last_cursor FROM sync_state WHERE device_id = ? LIMIT 1',
    [deviceId]
  );
  
  return result?.last_cursor ?? null;
}

export async function saveSyncCursor(cursor: string): Promise<void> {
  const db = getDb();
  const deviceId = await getDeviceId();
  const now = new Date().toISOString();
  const userId = 'current_user_id'; // Get from auth store
  
  await db.runAsync(
    `INSERT INTO sync_state (id, user_id, device_id, last_cursor, last_sync_at, updated_at)
     VALUES (?, ?, ?, ?, ?, ?)
     ON CONFLICT(device_id) DO UPDATE SET
       last_cursor = excluded.last_cursor,
       last_sync_at = excluded.last_sync_at,
       updated_at = excluded.updated_at`,
    [uuidv4(), userId, deviceId, cursor, now, now]
  );
}
```

---

## Benefits

✅ **Survives cache clears** - Cursor stored in SQLite, not volatile storage  
✅ **Per-device tracking** - Each device maintains its own sync state  
✅ **Server can track device sync status** - Optional: server can store per-device cursors too  
✅ **More reliable** - Database transactions ensure atomicity  

---

## Migration Path

1. Run server migration to add `sync_state` table
2. Update desktop/mobile SQLite schemas
3. Deploy updated sync logic
4. Old cursors in localStorage/AsyncStorage are ignored (fresh sync on first run with new code)

---

## Optional: Server-Side Device Sync State

If you want the server to also track per-device sync state (more advanced):

Update `server/routes/sync.ts` to:
- Accept `deviceId` in sync request
- Store/retrieve cursor per `(userId, deviceId)` in server's `sync_state` table
- Return cursor specific to that device

This enables:
- Multi-device sync debugging
- Device-specific cursor management
- Conflict resolution based on device state

Let me know if you want this advanced version! 🚀
